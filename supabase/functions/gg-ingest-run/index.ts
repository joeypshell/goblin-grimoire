import { MAX_BYTES, validateReport, validToken } from './validation.ts';

const allowedOrigins = new Set(['https://joeypshell.github.io','http://127.0.0.1:8068','http://localhost:8068']);
async function hash(value: string) {
  const bytes = await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value));
  return [...new Uint8Array(bytes)].map(v=>v.toString(16).padStart(2,'0')).join('');
}

// JWT verification is replaced by the persisted per-run write capability. This
// handler cannot read reports; approved reviewers use Auth plus database RLS.
Deno.serve(async (request: Request) => {
  const origin = request.headers.get('origin');
  const headers: Record<string,string> = {'Content-Type':'application/json','Cache-Control':'no-store','Vary':'Origin'};
  if (origin && allowedOrigins.has(origin)) headers['Access-Control-Allow-Origin'] = origin;
  const reply = (status: number, body: unknown) => new Response(JSON.stringify(body),{status,headers});
  if (origin && !allowedOrigins.has(origin)) return reply(403,{error:'Origin not allowed'});
  if (request.method === 'OPTIONS') {
    headers['Access-Control-Allow-Headers'] = 'content-type,x-run-token';
    headers['Access-Control-Allow-Methods'] = 'POST,OPTIONS';
    headers['Access-Control-Max-Age'] = '600';
    return new Response(null,{status:204,headers});
  }
  if (request.method !== 'POST') return reply(405,{error:'POST required'});
  const token = request.headers.get('x-run-token') || '';
  if (!validToken(token)) return reply(401,{error:'Run write key required'});
  if (Number(request.headers.get('content-length') || 0) > MAX_BYTES) return reply(413,{error:'Report too large'});
  let validated = false;
  try {
    const reader = request.body?.getReader();
    if (!reader) return reply(400,{error:'Report required'});
    const chunks: Uint8Array[] = [];
    let size = 0;
    while (true) {
      const {done,value} = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_BYTES) { await reader.cancel(); return reply(413,{error:'Report too large'}); }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk,offset); offset += chunk.byteLength; }
    const payload = JSON.parse(new TextDecoder().decode(bytes));
    if (!payload || Object.keys(payload).length !== 1 || !payload.report) return reply(400,{error:'Report required'});
    const error = validateReport(payload.report);
    if (error) return reply(400,{error});
    validated = true;
    const url = Deno.env.get('SUPABASE_URL')!;
    const serverKeys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') || '{}');
    const serverKey = serverKeys.default;
    if (typeof serverKey !== 'string' || !serverKey.startsWith('sb_secret_')) return reply(503,{error:'Collection not configured'});
    const address = request.headers.get('x-forwarded-for')?.split(',')[0].trim() || 'native';
    const response = await fetch(url+'/rest/v1/rpc/gg_store_report',{
      method:'POST',headers:{'Content-Type':'application/json','apikey':serverKey},
      body:JSON.stringify({p_report:payload.report,p_token_hash:await hash(token),p_rate_hash:await hash(serverKey+':'+address)})
    });
    if (!response.ok) return reply(503,{error:'Collection temporarily unavailable'});
    const result = await response.json();
    if (result.error === 'forbidden' || result.error === 'terminal') return reply(403,{error:result.error});
    if (result.error === 'rate_limit') return reply(429,{error:'Retry later'});
    if (result.error) return reply(503,{error:'Collection capacity reached'});
    return reply(200,result);
  } catch {
    return validated
      ? reply(503,{error:'Collection temporarily unavailable'})
      : reply(400,{error:'Invalid report request'});
  }
});
