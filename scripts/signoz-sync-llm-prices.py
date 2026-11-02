#!/usr/bin/env python3
"""Sync LLM model prices from OpenRouter into self-hosted SigNoz.

Based on the SigNoz self-host sync script:
https://signoz.io/docs/ai-observability-model-pricing/#sync-prices-from-openrouter-in-self-hosted-signoz

Configuration comes from the environment, then the repo-root .env (existing
environment variables win):

  SIGNOZ_API_KEY          Admin service-account key (required)
  SIGNOZ_URL              SigNoz base URL. Default: http://localhost:$SIGNOZ_UI_PORT
  SIGNOZ_UI_PORT          Used only when SIGNOZ_URL is unset. Default: 8080
  SIGNOZ_LLM_PROVIDERS    Comma-separated OpenRouter provider prefixes.
                          Default: openai, anthropic, google, mistralai,
                          deepseek, qwen, x-ai, meta-llama, cohere, amazon
"""

import fnmatch
import json
import os
import re
import ssl
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PROVIDERS = {
    "openai",
    "anthropic",
    "google",
    "mistralai",
    "deepseek",
    "qwen",
    "x-ai",
    "meta-llama",
    "cohere",
    "amazon",
}
CACHE_MODES = {"openai": "subtract", "anthropic": "additive"}


def load_dotenv(path):
    """Load KEY=VALUE lines. Does not override variables already in the environment."""
    if not path.is_file():
        return
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if not key or key in os.environ:
            continue
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
            value = value[1:-1]
        os.environ[key] = value


def providers():
    raw = os.environ.get("SIGNOZ_LLM_PROVIDERS", "").strip()
    if not raw:
        return DEFAULT_PROVIDERS
    selected = {part.strip() for part in raw.split(",") if part.strip()}
    if not selected:
        return DEFAULT_PROVIDERS
    return selected


def price(pricing, key):
    try:
        return float(pricing[key]) * 1_000_000
    except (KeyError, TypeError, ValueError):
        return None


def source_id(model_id):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"https://openrouter.ai/{model_id}"))


def to_rule(model, allowed):
    model_id = model["id"]
    provider, _, name = model_id.partition("/")
    if provider not in allowed or not name or ":" in model_id or model_id.startswith("~"):
        return None
    if provider == "qwen" and not re.search("max|plus|flash|turbo", name):
        return None
    pricing = model.get("pricing", {})
    input_price, output_price = price(pricing, "prompt"), price(pricing, "completion")
    if (input_price or 0) <= 0 or (output_price or 0) <= 0:
        return None
    rule_pricing = {"input": input_price, "output": output_price}
    read, write = price(pricing, "input_cache_read"), price(pricing, "input_cache_write")
    if read is not None or write is not None:
        rule_pricing["cache"] = {
            "mode": CACHE_MODES.get(provider, "unknown"),
            "read": read or 0,
            "write": write or 0,
        }
    return {
        "sourceId": source_id(model_id),
        "modelName": name,
        "provider": provider,
        "modelPattern": [model_id, name],
        "unit": "per_million_tokens",
        "pricing": rule_pricing,
        "enabled": True,
    }


def tls_context():
    """Verify TLS, but accept CAs whose basicConstraints extension is not critical.

    Python 3.13 turns on VERIFY_X509_STRICT. Some intercepting CAs fail that
    check with "Basic Constraints of CA cert not marked critical".
    """
    context = ssl.create_default_context()
    strict = getattr(ssl, "VERIFY_X509_STRICT", 0)
    if strict:
        context.verify_flags &= ~strict
    return context


def open_url(request, context):
    try:
        return urllib.request.urlopen(request, timeout=60, context=context)
    except urllib.error.HTTPError:
        raise
    except urllib.error.URLError as error:
        target = request.full_url if isinstance(request, urllib.request.Request) else request
        print(f"Could not reach {target}: {error.reason}", file=sys.stderr)
        raise SystemExit(1) from error


def open_json(request, context):
    with open_url(request, context) as response:
        return json.load(response)


def signoz(base_url, api_key, path, context, body=None):
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=body and json.dumps(body).encode(),
        headers={"SIGNOZ-API-KEY": api_key, "Content-Type": "application/json"},
        method="PUT" if body else "GET",
    )
    if body:
        with open_url(request, context) as response:
            response.read()
        return None
    return open_json(request, context)


def matches(name, pattern):
    # Same as the collector's path.Match: * and ? do not cross "/".
    names, patterns = name.split("/"), pattern.split("/")
    return len(names) == len(patterns) and all(map(fnmatch.fnmatchcase, names, patterns))


def main():
    load_dotenv(ROOT / ".env")

    api_key = os.environ.get("SIGNOZ_API_KEY", "").strip()
    if not api_key:
        print(
            "SIGNOZ_API_KEY is unset. Create an Admin service account in SigNoz "
            "and set the key in .env.",
            file=sys.stderr,
        )
        return 1

    base_url = os.environ.get("SIGNOZ_URL", "").strip().rstrip("/")
    if not base_url:
        port = os.environ.get("SIGNOZ_UI_PORT", "8080").strip() or "8080"
        base_url = f"http://localhost:{port}"

    context = tls_context()
    allowed = providers()
    existing = []
    while True:
        page = signoz(
            base_url,
            api_key,
            f"/api/v1/llm_pricing_rules?limit=100&offset={len(existing)}",
            context,
        )["data"]["items"]
        existing += page
        if len(page) < 100:
            break

    override_patterns = [
        pattern
        for rule in existing
        if rule["isOverride"] and rule["enabled"]
        for pattern in rule["modelPattern"]
    ]

    def overridden(name):
        return any(matches(name, pattern) for pattern in override_patterns)

    models = open_json("https://openrouter.ai/api/v1/models", context)["data"]

    rules = [rule for rule in (to_rule(model, allowed) for model in models) if rule]
    previous = {rule["sourceId"]: rule for rule in existing if rule.get("sourceId")}
    for rule in rules:
        # Keep names mapped to this rule, and drop names a User override rule prices.
        mapped = previous.get(rule["sourceId"], {}).get("modelPattern", [])
        names = rule["modelPattern"] + [name for name in mapped if name not in rule["modelPattern"]]
        kept = [name for name in names if not overridden(name)]
        rule["modelPattern"], rule["enabled"] = (kept, True) if kept else (names, False)

    # Disable rules from earlier runs for models OpenRouter no longer lists or prices.
    synced = {rule["sourceId"] for rule in rules}
    fields = ("sourceId", "modelName", "provider", "modelPattern", "unit", "pricing")
    stale = [
        {**{field: rule[field] for field in fields}, "enabled": False}
        for rule in existing
        if not rule["isOverride"]
        and rule.get("sourceId") not in synced
        and rule.get("sourceId") == source_id(f"{rule['provider']}/{rule['modelName']}")
    ]

    enabled = sum(rule["enabled"] for rule in rules)
    print(f"Syncing {enabled} model prices to {base_url}")
    print(
        f"Disabling {len(rules) + len(stale) - enabled} rules that User override "
        "rules cover or OpenRouter dropped"
    )
    signoz(base_url, api_key, "/api/v1/llm_pricing_rules", context, {"rules": rules + stale})
    print("Done")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace").strip()
        print(f"HTTP {error.code} from {error.url}", file=sys.stderr)
        if detail:
            print(detail, file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as error:
        print(f"Could not reach SigNoz or OpenRouter: {error.reason}", file=sys.stderr)
        sys.exit(1)
