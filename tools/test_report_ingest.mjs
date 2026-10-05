import assert from 'node:assert/strict';
import {validateReport,validToken,MAX_BYTES} from '../supabase/functions/gg-ingest-run/validation.ts';

let checks = 0;
const check = (actual,expected,label) => { assert.deepEqual(actual,expected,label); checks++; };
const sample = () => ({schema:1,id:'0e88d516-6fba-4e9b-8aeb-847690ced822',revision:1,build:'0.7.0',
  started_at:'2026-10-05T20:00:00Z',updated_at:'2026-10-05T20:00:00Z',status:'active',coverage:'full',
  seed:'9223372036854775807',platform:'Windows',summary:{cards_played:0},dropped_events:0,dropped_attempts:0,
  events:[{seq:1,at:'2026-10-05T20:00:00Z',kind:'run_started',raid:0,phase:'prep',data:{}}]});
check(validateReport(sample()),null,'valid full report');
for (const [key,value] of [['id','bad'],['revision',0],['schema',2],['seed',Number.MAX_SAFE_INTEGER],
  ['seed','9223372036854775808'],['seed','-9223372036854775809'],['started_at','bad'],['status','cheated'],
  ['coverage','guess'],['platform','x'.repeat(41)],['dropped_events',-1],['summary',[]]]) {
  check(typeof validateReport({...sample(),[key]:value}),'string',`reject ${key}`);
}
check(validateReport({...sample(),seed:'-9223372036854775808'}),null,'minimum seed preserved');
check(typeof validateReport({...sample(),password:'never'}),'string','reject identity fields');
check(typeof validateReport({...sample(),status:['active']}),'string','status must be a string');
check(typeof validateReport({...sample(),coverage:['full']}),'string','coverage must be a string');
check(typeof validateReport({...sample(),events:[sample().events[0],sample().events[0]]}),'string','event sequences unique');
check(validToken('a'.repeat(64)),true,'valid scoped write key');
check(validToken('public'),false,'no guessable keys');

let handler;
let rpcRequests = [];
let result = {id:sample().id,revision:1};
globalThis.Deno = {serve:fn=>handler=fn,env:{get:key=>key==='SUPABASE_URL'?'https://test.invalid':JSON.stringify({default:'sb_secret_test_only'})}};
const realFetch = globalThis.fetch;
globalThis.fetch = async (url,options) => {
  rpcRequests.push({url,options,body:JSON.parse(options.body)});
  return new Response(JSON.stringify(result),{status:200});
};
await import('../supabase/functions/gg-ingest-run/index.ts');
const request = (options={}) => new Request('https://test.invalid/ingest',{
  method:options.method||'POST',headers:{'content-type':'application/json','x-run-token':'a'.repeat(64),...options.headers},
  ...(options.method === 'GET' ? {} : {body:options.body??JSON.stringify({report:sample()})})});
try {
  check((await handler(request())).status,200,'valid upload');
  check(rpcRequests.length,1,'one atomic server RPC');
  check(rpcRequests[0].body.p_report.seed,'9223372036854775807','no seed precision loss');
  check(validToken(rpcRequests[0].body.p_token_hash),true,'only token hash sent to database');
  check(rpcRequests[0].body.p_token_hash==='a'.repeat(64),false,'raw write key not stored');
  check((await handler(request({method:'GET'}))).status,405,'no read endpoint');
  check((await handler(request({headers:{'x-run-token':''}}))).status,401,'missing run key');
  check((await handler(request({headers:{origin:'https://unrelated.invalid'}}))).status,403,'unapproved browser origin');
  const browser = await handler(request({headers:{origin:'https://joeypshell.github.io'}}));
  check(browser.headers.get('access-control-allow-origin'),'https://joeypshell.github.io','production CORS');
  const preflight = await handler(request({method:'OPTIONS',headers:{origin:'https://joeypshell.github.io'}}));
  check(preflight.status,204,'CORS preflight');
  check(preflight.headers.get('access-control-allow-headers'),'content-type,x-run-token','only required headers');
  check((await handler(request({body:'{broken'}))).status,400,'invalid JSON');
  check((await handler(request({body:JSON.stringify({report:{...sample(),status:['active']}})}))).status,400,'malformed types are invalid requests');
  check((await handler(request({body:JSON.stringify({report:sample(),extra:true})}))).status,400,'unknown envelope field');
  check((await handler(request({body:'x'.repeat(MAX_BYTES+1)}))).status,413,'bounded streamed body');
  result={error:'forbidden'};
  check((await handler(request())).status,403,'writer cannot replace another run');
  result={error:'rate_limit'};
  check((await handler(request())).status,429,'rate limited');
  result={error:'capacity'};
  check((await handler(request())).status,503,'capacity limited');
  check(rpcRequests.every(r=>r.options.headers.apikey==='sb_secret_test_only' && !r.options.headers.Authorization),true,'modern server key belongs in apikey header');
  globalThis.fetch=async()=>{throw new Error('network unavailable');};
  check((await handler(request())).status,503,'server connection failure remains retryable');
} finally { globalThis.fetch=realFetch; delete globalThis.Deno; }
console.log(`INGEST CHECKS: ${checks} passed`);
