export const MAX_BYTES = 393216 + 32;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const FIELDS = new Set(['schema','id','revision','build','started_at','updated_at','status',
  'coverage','seed','platform','summary','events','dropped_events','dropped_attempts']);
const object = (v: unknown): v is Record<string, unknown> => !!v && typeof v === 'object' && !Array.isArray(v);
const integer = (v: unknown, max = 2147483647) => Number.isInteger(v) && Number(v) >= 0 && Number(v) <= max;
function bounded(value: unknown, depth = 0): boolean {
  if (depth > 16) return false;
  if (value === null || typeof value === 'boolean') return true;
  if (typeof value === 'number') return Number.isFinite(value) && Math.abs(value) <= Number.MAX_SAFE_INTEGER;
  if (typeof value === 'string') return value.length <= 12000;
  if (Array.isArray(value)) return value.length <= 2000 && value.every(v => bounded(v, depth + 1));
  return object(value) && Object.keys(value).length <= 256 && Object.entries(value).every(
    ([k,v]) => k.length <= 80 && !['__proto__','constructor','prototype'].includes(k) && bounded(v, depth + 1));
}
export function validateReport(value: unknown): string | null {
  if (!object(value) || Object.keys(value).some(k => !FIELDS.has(k))) return 'Invalid report fields';
  if (value.schema !== 1 || typeof value.id !== 'string' || !UUID.test(value.id)) return 'Invalid report ID';
  if (!integer(value.revision) || Number(value.revision) < 1) return 'Invalid revision';
  if (typeof value.build !== 'string' || !/^\d+\.\d+\.\d+(?:-[a-z0-9]+)?$/.test(value.build)) return 'Invalid build';
  if (typeof value.status !== 'string' || !['active','victory','defeat','abandoned'].includes(value.status)) return 'Invalid status';
  if (typeof value.coverage !== 'string' || !['full','partial'].includes(value.coverage)) return 'Invalid coverage';
  if (typeof value.seed !== 'string' || !/^-?\d{1,20}$/.test(value.seed) ||
      BigInt(value.seed) < -9223372036854775808n || BigInt(value.seed) > 9223372036854775807n) return 'Invalid seed';
  for (const key of ['started_at','updated_at']) {
    if (typeof value[key] !== 'string' || !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z$/.test(String(value[key])) ||
        !Number.isFinite(Date.parse(String(value[key])))) return 'Invalid timestamp';
  }
  if (typeof value.platform !== 'string' || value.platform.length > 40) return 'Invalid platform';
  if (!integer(value.dropped_events) || !integer(value.dropped_attempts)) return 'Invalid history counts';
  if (!object(value.summary) || !Array.isArray(value.events) || value.events.length > 2000 || !bounded(value)) return 'Invalid history';
  let previous = 0;
  for (const event of value.events) {
    if (!object(event) || !integer(event.seq) || Number(event.seq) <= previous || Number(event.seq) > Number(value.revision) ||
        typeof event.kind !== 'string' || !/^[a-z_]{1,40}$/.test(event.kind) ||
        !integer(event.raid,100) || typeof event.phase !== 'string' || !object(event.data) ||
        typeof event.at !== 'string' || !Number.isFinite(Date.parse(event.at))) return 'Invalid event';
    previous = Number(event.seq);
  }
  return null;
}
export const validToken = (token: string) => /^[0-9a-f]{64}$/.test(token);
