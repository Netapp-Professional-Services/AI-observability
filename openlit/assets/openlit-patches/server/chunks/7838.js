"use strict";exports.id=7838,exports.ids=[7838],exports.modules={44999:(e,t,r)=>{function a(e){return function(e){let t=3735928559,r=1103547991,a=e.join("\0");for(let e=0;e<a.length;e++){let i=a.charCodeAt(e);t=Math.imul(t^i,2654435761),r=Math.imul(r^i,1597334677)}return t=Math.imul(t^t>>>16,2246822507)^Math.imul(r^r>>>13,3266489909),String(4294967296*(2097151&(r=Math.imul(r^r>>>16,2246822507)^Math.imul(t^t>>>13,3266489909)))+(t>>>0))}([e.timestamp,e.traceId||"",e.spanId||"",e.severityText||"",e.body])}function i(e){return null==e?"":String(e)}function s(e){let t=Number(e);return Number.isFinite(t)?t:0}function n(e){if(!e||"object"!=typeof e)return{};let t={};for(let[r,a]of Object.entries(e))t[r]=i(a);return t}function o(e){let t=(e.events||[]).map(e=>({Name:e.name,Timestamp:e.timestamp||"",Attributes:e.attributes||{}})),r={...e.spanAttributes};return void 0!==e.cost&&void 0===r["gen_ai.usage.cost"]&&(r["gen_ai.usage.cost"]=String(e.cost)),{TraceId:e.traceId,SpanId:e.spanId,ParentSpanId:e.parentSpanId||"",SpanName:e.name,ServiceName:e.serviceName,Timestamp:e.timestamp,Duration:e.durationNs,StatusCode:e.statusCode,StatusMessage:e.statusMessage||"",SpanKind:e.spanKind||"",TraceState:"",ScopeName:"",ScopeVersion:"",SpanAttributes:r,ResourceAttributes:e.resourceAttributes||{},Events:t,Links:[],Cost:e.cost,agentLoop:e.agentLoop}}function u(e){let t=n(e.SpanAttributes),r=n(e.ResourceAttributes),a=void 0!==e.Cost?s(e.Cost):void 0!==t["gen_ai.usage.cost"]?s(t["gen_ai.usage.cost"]):void 0;return{traceId:i(e.TraceId),spanId:i(e.SpanId),parentSpanId:i(e.ParentSpanId),name:i(e.SpanName),serviceName:i(e.ServiceName),timestamp:i(e.Timestamp),durationNs:s(e.Duration),statusCode:i(e.StatusCode),statusMessage:e.StatusMessage?i(e.StatusMessage):void 0,spanKind:e.SpanKind?i(e.SpanKind):void 0,spanAttributes:t,resourceAttributes:r,events:function(e){if(Array.isArray(e.Events))return e.Events.map(e=>{let t=e||{};return{name:i(t.Name),timestamp:t.Timestamp?i(t.Timestamp):void 0,attributes:n(t.Attributes)}});let t=e["Events.Name"];if(Array.isArray(t)){let r=e["Events.Timestamp"]||[],a=e["Events.Attributes"]||[];return t.map((e,t)=>({name:i(e),timestamp:r[t]?i(r[t]):void 0,attributes:n(a[t])}))}return[]}(e),cost:a}}function m(e){return{rowId:e.rowId||a(e),Timestamp:e.timestamp,TraceId:e.traceId||"",SpanId:e.spanId||"",SeverityText:e.severityText||"",SeverityNumber:e.severityNumber??0,Body:e.body,ServiceName:e.serviceName||"",ScopeName:"",ScopeVersion:"",LogAttributes:e.logAttributes||{},ResourceAttributes:e.resourceAttributes||{},ScopeAttributes:e.scopeAttributes||{}}}function c(e){let t=new Map;for(let r of e){let e=r.serviceName||"",a=`${r.metricName}\u0000${e}`,i=new Date(r.timestamp).getTime(),s=t.get(a);if(!s){t.set(a,{metricName:r.metricName,serviceName:e,description:r.description,unit:r.unit,values:[r.value],latest:{value:r.value,ts:Number.isFinite(i)?i:0},lastSeen:r.timestamp});continue}s.values.push(r.value),Number.isFinite(i)&&i>=s.latest.ts&&(s.latest={value:r.value,ts:i},s.lastSeen=r.timestamp)}return Array.from(t.values()).map(e=>{let t=e.values.length,r=e.values.reduce((e,t)=>e+t,0);return{metricName:e.metricName,metricType:"gauge",serviceName:e.serviceName,metricDescription:e.description||"",metricUnit:e.unit||"",latestValue:e.latest.value,avgValue:t?r/t:0,minValue:t?Math.min(...e.values):0,maxValue:t?Math.max(...e.values):0,pointCount:t,observationCount:t,lastSeen:e.lastSeen}})}function S(e){return{rowId:null!=e.rowId?String(e.rowId):void 0,timestamp:i(e.Timestamp),traceId:e.TraceId?i(e.TraceId):void 0,spanId:e.SpanId?i(e.SpanId):void 0,severityText:e.SeverityText?i(e.SeverityText):void 0,severityNumber:void 0!==e.SeverityNumber?s(e.SeverityNumber):void 0,body:i(e.Body),serviceName:e.ServiceName?i(e.ServiceName):void 0,logAttributes:n(e.LogAttributes),resourceAttributes:n(e.ResourceAttributes),scopeAttributes:e.ScopeAttributes?n(e.ScopeAttributes):void 0}}r.d(t,{OH:()=>m,TE:()=>c,denormalizeSpanToTraceRow:()=>o,jP:()=>S,ud:()=>u,wH:()=>a})},45280:(e,t,r)=>{r.d(t,{Bs:()=>v,C3:()=>A,Kt:()=>R,Lu:()=>y,MH:()=>N,RS:()=>c,YG:()=>T,iL:()=>E,yr:()=>d,zc:()=>I});var a=r(87330),i=r(65100),s=r(74181);let n=[{table:a.rR,type:"gauge",valueExpr:"Value",countExpr:"1"},{table:a.nt,type:"sum",valueExpr:"Value",countExpr:"1"},{table:a.eK,type:"histogram",valueExpr:"Sum",countExpr:"Count"},{table:a.u9,type:"summary",valueExpr:"Sum",countExpr:"Count"},{table:a.uA,type:"exponential_histogram",valueExpr:"Sum",countExpr:"Count"}],o=new Set(["Timestamp","TraceId","SpanId","SeverityText","SeverityNumber","ServiceName","Body","ScopeName","ScopeVersion"]),u=new Set(["ServiceName","MetricName","MetricDescription","MetricUnit","ScopeName","ScopeVersion","TimeUnix"]);function m(e){return e.replace(/\\/g,"\\\\").replace(/'/g,"\\'")}function c(e){let t=new Date(e.timeLimit.start),r=Math.max(1,(new Date(e.timeLimit.end).getTime()-t.getTime())/864e5);return r<=2?"hour":r<=45?"day":r<=370?"week":"month"}function S(e){return e.map(e=>`'${m(e)}'`).join(", ")}function l(e,t){let r=[],a="logs"===t?"Timestamp":"TimeUnix",{start:i,end:s}=e.timeLimit||{};i&&s&&r.push(`${a} >= parseDateTimeBestEffort('${i}') AND ${a} <= parseDateTimeBestEffort('${s}')`);let n=e.selectedConfig||{},c=Array.from(new Set([...n.services||[],...n.serviceNames||[],...n.applicationNames||[]].map(String).filter(Boolean)));c.length&&r.push(`ServiceName IN (${S(c)})`);let l=(n.environments||[]).map(String).filter(Boolean);if(l.length&&!(1===l.length&&"default"===l[0])&&r.push(`ResourceAttributes['deployment.environment'] IN (${S(l)})`),"logs"===t&&n.severities?.length){let e=n.severities.map(e=>e.toLowerCase());r.push(`lower(SeverityText) IN (${S(e)})`)}return"metrics"===t&&n.metricNames?.length&&r.push(`MetricName IN (${S(n.metricNames)})`),n.customFilters?.length&&n.customFilters.forEach(({attributeType:e,key:a,value:i})=>{if(!a||!i)return;let s=function(e,t,r,a){let i=m(a),s=m(r),n=r.replace(/[^A-Za-z0-9_.]/g,"");return"ResourceAttributes"===t?`ResourceAttributes['${s}'] = '${i}'`:"ScopeAttributes"===t?`ScopeAttributes['${s}'] = '${i}'`:"LogAttributes"===t&&"logs"===e?`LogAttributes['${s}'] = '${i}'`:"Attributes"===t&&"metrics"===e?`Attributes['${s}'] = '${i}'`:"Field"===t&&n&&("logs"===e?o:u).has(n)?`${n} = '${i}'`:""}(t,e,a,i);s&&r.push(s)}),"logs"===t&&n.traceIds?.length&&r.push(`TraceId IN (${S(n.traceIds)})`),"logs"===t&&n.spanIds?.length&&r.push(`SpanId IN (${S(n.spanIds)})`),r.length?r.join(" AND "):"1 = 1"}function p(e,t){let r=l(e,"metrics"),a=e.selectedConfig?.metricTypes;return(a?.length?n.filter(({type:e})=>a.includes(e)):n).map(({table:e,type:a,valueExpr:i,countExpr:s})=>`
			SELECT
				'${a}' AS metric_type,
				${i} AS metric_value,
				${s} AS metric_sample_count,
				${t}
			FROM ${e}
			WHERE ${r}
		`).join(" UNION ALL ")}async function T(e){let t=`
		SELECT
			arrayFilter(x -> x != '', ARRAY_AGG(DISTINCT ServiceName)) AS services,
			arrayFilter(x -> x != '', ARRAY_AGG(DISTINCT SeverityText)) AS severities,
			CAST(COUNT(*) AS INTEGER) AS totalRows
		FROM ${a.tk}
		WHERE ${l(e,"logs")}
	`;return(0,a.b$)({query:t},"query",e.databaseConfigId)}async function A(e){let t=l(e,"logs"),r=[{key:"logAttributeKeys",query:`SELECT DISTINCT arrayJoin(mapKeys(LogAttributes)) AS key FROM ${a.tk} WHERE ${t} ORDER BY key LIMIT 500`},{key:"resourceAttributeKeys",query:`SELECT DISTINCT arrayJoin(mapKeys(ResourceAttributes)) AS key FROM ${a.tk} WHERE ${t} ORDER BY key LIMIT 500`},{key:"scopeAttributeKeys",query:`SELECT DISTINCT arrayJoin(mapKeys(ScopeAttributes)) AS key FROM ${a.tk} WHERE ${t} ORDER BY key LIMIT 500`}],i=await Promise.all(r.map(({query:t})=>(0,a.b$)({query:t},"query",e.databaseConfigId)));return{err:i.find(e=>e.err)?.err??null,spanAttributeKeys:[],resourceAttributeKeys:i[1].data?.map(e=>e.key)??[],logAttributeKeys:i[0].data?.map(e=>e.key)??[],scopeAttributeKeys:i[2].data?.map(e=>e.key)??[]}}async function d(e){let{limit:t=25,offset:r=0}=e,i=l(e,"logs"),n=`SELECT CAST(COUNT(*) AS INTEGER) AS total FROM ${a.tk} WHERE ${i}`,{data:o,err:u}=await (0,a.b$)({query:n},"query",e.databaseConfigId);if(u)return{err:u};let m=e.sorting?.type?`${e.sorting.type.replace(/[^A-Za-z0-9_.]/g,"")} ${(0,s.lw)(e.sorting.direction)}`:"Timestamp desc",c=`
		SELECT
			toString(cityHash64(toString(Timestamp), TraceId, SpanId, SeverityText, Body)) AS rowId,
			*
		FROM ${a.tk}
		WHERE ${i}
		ORDER BY ${m}
		LIMIT ${t}
		OFFSET ${r}
	`,{data:S,err:p}=await (0,a.b$)({query:c},"query",e.databaseConfigId);return{err:p,records:S,total:o?.[0]?.total||0}}async function E(e,t){let r=c(e),s="hour"===r?"%m/%d %H:00":"month"===r?"%Y/%m":"%Y/%m/%d",n="";if("traces"===t||"exceptions"===t){let o={...e,..."exceptions"===t?{statusCode:["STATUS_CODE_ERROR","Error","ERROR"]}:{}},u=(0,i.getFilterWhereCondition)(o,!0);n=`
			SELECT
				formatDateTime(DATE_TRUNC('${r}', Timestamp), '${s}') AS label,
				CAST(COUNT(*) AS INTEGER) AS count,
				CAST(avg(Duration) * 1e-9 AS FLOAT) AS avgDuration,
				CAST(SUM(toFloat64OrZero(SpanAttributes['gen_ai.usage.cost'])) AS FLOAT) AS cost,
				CAST(SUM(toInt64OrZero(SpanAttributes['gen_ai.usage.total_tokens'])) AS INTEGER) AS tokens
			FROM ${a.y9}
			WHERE ${u}
			GROUP BY label
			ORDER BY min(Timestamp)
		`}else if("logs"===t){let t=l(e,"logs");n=`
			SELECT
				formatDateTime(DATE_TRUNC('${r}', Timestamp), '${s}') AS label,
				CAST(COUNT(*) AS INTEGER) AS count,
				CAST(countIf(SeverityText IN ('ERROR', 'Error', 'error', 'FATAL', 'Fatal', 'fatal')) AS INTEGER) AS errors,
				CAST(uniqExact(ServiceName) AS INTEGER) AS services
			FROM ${a.tk}
			WHERE ${t}
			GROUP BY label
			ORDER BY min(Timestamp)
		`}else{let t=p(e,"ServiceName, MetricName, TimeUnix");n=`
			SELECT
				formatDateTime(DATE_TRUNC('${r}', TimeUnix), '${s}') AS label,
				CAST(COUNT(*) AS INTEGER) AS count,
				CAST(uniqExact(MetricName) AS INTEGER) AS metrics,
				CAST(uniqExact(ServiceName) AS INTEGER) AS services
			FROM (${t})
			GROUP BY label
			ORDER BY min(TimeUnix)
		`}let{data:o,err:u}=await (0,a.b$)({query:n},"query",e.databaseConfigId),m=o||[],S=m.reduce((e,t)=>e+Number(t.count||0),0);return{err:u,bucket:r,buckets:m,total:S,peak:m.reduce((e,t)=>Math.max(e,Number(t.count||0)),0)}}async function y(e,t){let r=e.replace(/[^0-9]/g,""),i=`
		SELECT
			toString(cityHash64(toString(Timestamp), TraceId, SpanId, SeverityText, Body)) AS rowId,
			*
		FROM ${a.tk}
		WHERE toString(cityHash64(toString(Timestamp), TraceId, SpanId, SeverityText, Body)) = '${r||"0"}'
		LIMIT 1
	`,{data:s,err:n}=await (0,a.b$)({query:i},"query",t);return{err:n,record:s?.[0]}}async function N(e){let t=`
		SELECT
			arrayFilter(x -> x != '', ARRAY_AGG(DISTINCT ServiceName)) AS services,
			arrayFilter(x -> x != '', ARRAY_AGG(DISTINCT MetricName)) AS metricNames,
			arrayFilter(x -> x != '', ARRAY_AGG(DISTINCT metric_type)) AS metricTypes,
			CAST(COUNT(*) AS INTEGER) AS totalRows
		FROM (${p(e,"ServiceName, MetricName")})
	`;return(0,a.b$)({query:t},"query",e.databaseConfigId)}async function I(e){let t=n.map(({table:t})=>({metric:`SELECT DISTINCT arrayJoin(mapKeys(Attributes)) AS key FROM ${t} WHERE ${l(e,"metrics")}`,resource:`SELECT DISTINCT arrayJoin(mapKeys(ResourceAttributes)) AS key FROM ${t} WHERE ${l(e,"metrics")}`,scope:`SELECT DISTINCT arrayJoin(mapKeys(ScopeAttributes)) AS key FROM ${t} WHERE ${l(e,"metrics")}`})),[r,i,s]=await Promise.all([(0,a.b$)({query:`${t.map(e=>e.metric).join(" UNION DISTINCT ")} ORDER BY key LIMIT 500`},"query",e.databaseConfigId),(0,a.b$)({query:`${t.map(e=>e.resource).join(" UNION DISTINCT ")} ORDER BY key LIMIT 500`},"query",e.databaseConfigId),(0,a.b$)({query:`${t.map(e=>e.scope).join(" UNION DISTINCT ")} ORDER BY key LIMIT 500`},"query",e.databaseConfigId)]);return{err:r.err||i.err||s.err,spanAttributeKeys:[],resourceAttributeKeys:i.data?.map(e=>e.key)??[],metricAttributeKeys:r.data?.map(e=>e.key)??[],scopeAttributeKeys:s.data?.map(e=>e.key)??[]}}async function R(e){let{limit:t=25,offset:r=0}=e,i=p(e,"ServiceName, MetricName, MetricDescription, MetricUnit, TimeUnix, Attributes, ResourceAttributes, ScopeName, ScopeVersion, ScopeAttributes"),s=`
		SELECT CAST(COUNT(*) AS INTEGER) AS total
		FROM (
			SELECT MetricName, metric_type, ServiceName
			FROM (${i})
			GROUP BY MetricName, metric_type, ServiceName
		)
	`,{data:n,err:o}=await (0,a.b$)({query:s},"query",e.databaseConfigId);if(o)return{err:o};let u=`
		SELECT
			MetricName AS metricName,
			metric_type AS metricType,
			ServiceName AS serviceName,
			anyLast(MetricDescription) AS metricDescription,
			anyLast(MetricUnit) AS metricUnit,
			CAST(argMax(metric_value, TimeUnix) AS FLOAT) AS latestValue,
			CAST(avg(metric_value) AS FLOAT) AS avgValue,
			CAST(min(metric_value) AS FLOAT) AS minValue,
			CAST(max(metric_value) AS FLOAT) AS maxValue,
			CAST(COUNT(*) AS INTEGER) AS pointCount,
			CAST(SUM(metric_sample_count) AS INTEGER) AS observationCount,
			max(TimeUnix) AS lastSeen
		FROM (${i})
		GROUP BY MetricName, metric_type, ServiceName
		ORDER BY lastSeen DESC
		LIMIT ${t}
		OFFSET ${r}
	`,{data:m,err:c}=await (0,a.b$)({query:u},"query",e.databaseConfigId);return{err:c,records:m,total:n?.[0]?.total||0}}async function v(e,t,r,s){let n=m(e),o={...s?.selectedConfig||{},metricNames:[e],...t?{metricTypes:[t]}:{},...r?{services:[r]}:{}},u={...s,timeLimit:s?.timeLimit||{type:"24H",start:new Date(Date.now()-864e5),end:new Date},selectedConfig:o},c=new Date(u.timeLimit.start),S=new Date(u.timeLimit.end),l=(0,i.gj)(S,c),T=p(u,"ServiceName, MetricName, MetricDescription, MetricUnit, TimeUnix, Attributes, ResourceAttributes, ScopeName, ScopeVersion, ScopeAttributes"),A=`
		SELECT
			formatDateTime(DATE_TRUNC('${l}', TimeUnix), '%Y/%m/%d %R') AS request_time,
			CAST(avg(metric_value) AS FLOAT) AS value
		FROM (${T})
		WHERE MetricName = '${n}'
		GROUP BY request_time
		ORDER BY request_time
	`,d=`
		SELECT *
		FROM (${T})
		WHERE MetricName = '${n}'
		ORDER BY TimeUnix DESC
		LIMIT 100
	`,[E,y]=await Promise.all([(0,a.b$)({query:A},"query",u.databaseConfigId),(0,a.b$)({query:d},"query",u.databaseConfigId)]);return{err:E.err||y.err,series:E.data??[],points:y.data??[]}}}};