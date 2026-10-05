// Manual integration test. Writes clearly marked disposable reports only.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {MAX_BYTES} from '../supabase/functions/gg-ingest-run/validation.ts';

if (!process.argv.includes('--live-report-test')) {
  console.log('Run with --live-report-test to upload disposable verification reports.');
  process.exit(0);
}
const config = fs.readFileSync('web/dashboard/config.js','utf8');
const url = config.match(/supabaseUrl:\s*'([^']+)'/)[1];
const key = config.match(/publishableKey:\s*'([^']+)'/)[1];
const endpoint = url + '/functions/v1/gg-ingest-run';
const id = crypto.randomUUID(), token = crypto.randomBytes(32).toString('hex');
const now = new Date().toISOString();
const report = {schema:1,id,revision:1,build:'0.7.0-verification',started_at:now,updated_at:now,
  status:'active',coverage:'full',seed:'9223372036854775807',platform:'Verification',
  summary:{},dropped_events:0,dropped_attempts:0,events:[]};
fs.mkdirSync('build',{recursive:true});
fs.writeFileSync('build/reports-live-http.json',JSON.stringify({ids:[id]}));
let checks = 0;
function check(value,expected,label) { assert.deepEqual(value,expected,label); checks++; }
async function send(value=report,options={}) {
  const response = await fetch(endpoint,{
    method:options.method||'POST',headers:{'Content-Type':'application/json','X-Run-Token':token,...options.headers},
    ...(options.method==='GET'?{}:{body:options.body??JSON.stringify({report:value})})
  });
  return {status:response.status,headers:response.headers,body:await response.text()};
}
check((await send(report,{method:'GET'})).status,405,'no report reads through ingestion');
check((await send(report,{headers:{'X-Run-Token':''}})).status,401,'missing write capability');
check((await send(report,{headers:{origin:'https://unrelated.invalid'}})).status,403,'unapproved origin');
check((await send(report,{body:'{bad'})).status,400,'invalid JSON');
check((await send({...report,status:['active']})).status,400,'strict field types');
check((await send(report,{body:'x'.repeat(MAX_BYTES+1)})).status,413,'bounded body');
const first = await send();
check(first.status,200,'new report');
check(JSON.parse(first.body),{id,revision:1},'first acknowledgement');
report.revision=2;
const second = await send();
check(second.status,200,'new revision');
check(JSON.parse(second.body).revision,2,'latest acknowledgement');
const stale = await send({...report,revision:1});
check(stale.status,200,'stale retry is safe');
check(JSON.parse(stale.body).revision,2,'stale retry retains newest version');
check((await send(report,{headers:{'X-Run-Token':crypto.randomBytes(32).toString('hex')}})).status,403,'different writer denied');
report.revision=3; report.status='victory';
check((await send()).status,200,'terminal report');
check((await send()).status,200,'terminal retry');
check((await send({...report,revision:4})).status,403,'terminal report immutable');
const preflight = await fetch(endpoint,{method:'OPTIONS',headers:{origin:'https://joeypshell.github.io'}});
check(preflight.status,204,'web preflight');
check(preflight.headers.get('access-control-allow-origin'),'https://joeypshell.github.io','production web origin');
const read = await fetch(url+'/rest/v1/gg_run_reports?select=id&limit=1',{headers:{apikey:key}});
check([401,403].includes(read.status),true,'anonymous report read denied');
const rpc = await fetch(url+'/rest/v1/rpc/gg_store_report',{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:'{}'});
check([401,403,404].includes(rpc.status),true,'anonymous storage RPC inaccessible');
const settings = await fetch(url+'/auth/v1/settings',{headers:{apikey:key}});
check(settings.status,200,'Auth settings readable');
check((await settings.json()).mailer_autoconfirm,false,'email ownership confirmation required');
console.log(`LIVE INGEST: ${checks} checks passed; disposable report ${id}`);
