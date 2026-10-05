-- Reports are readable only by approved, verified reviewers. Players use a
-- per-run write capability through the ingestion function, never direct SQL.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;

create table public.gg_run_reports (
  id uuid primary key,
  revision integer not null check (revision > 0),
  build text not null,
  status text not null check (status in ('active','victory','defeat','abandoned')),
  coverage text not null check (coverage in ('full','partial')),
  seed text not null,
  started_at timestamptz not null,
  updated_at timestamptz not null,
  received_at timestamptz not null default now(),
  report jsonb not null check (octet_length(report::text) <= 800000)
);
create index gg_run_reports_received on public.gg_run_reports (received_at desc);
alter table public.gg_run_reports enable row level security;
revoke all on public.gg_run_reports from anon, authenticated;
grant select on public.gg_run_reports to authenticated;
grant all on public.gg_run_reports to service_role;

create table private.gg_reviewers (email text primary key check (email = lower(email)));
create table private.gg_report_keys (
  id uuid primary key references public.gg_run_reports(id) on delete cascade,
  token_hash text not null check (token_hash ~ '^[0-9a-f]{64}$')
);
create table private.gg_upload_limits (
  bucket text not null, hour timestamptz not null, requests integer not null,
  primary key (bucket,hour)
);
create index gg_upload_limits_hour on private.gg_upload_limits (hour);
alter table private.gg_reviewers enable row level security;
alter table private.gg_report_keys enable row level security;
alter table private.gg_upload_limits enable row level security;
grant all on private.gg_reviewers, private.gg_report_keys, private.gg_upload_limits to service_role;

-- This private helper deliberately reads the private reviewer allowlist, using
-- the signed-in auth.uid(), never editable user_metadata or a supplied user ID.
create function private.gg_is_reviewer() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from auth.users u join private.gg_reviewers r on r.email = lower(u.email)
    where u.id = auth.uid() and u.email_confirmed_at is not null
  );
$$;
revoke all on function private.gg_is_reviewer() from public, anon;
grant execute on function private.gg_is_reviewer() to authenticated;
create policy "Approved reviewers can read" on public.gg_run_reports
for select to authenticated using ((select private.gg_is_reviewer()));

-- Only the server service role can invoke this atomic write path. It is an
-- invoker function; no anonymous table access or elevated public RPC is granted.
create function public.gg_store_report(p_report jsonb, p_token_hash text, p_rate_hash text)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  run_id uuid := (p_report->>'id')::uuid;
  incoming integer := (p_report->>'revision')::integer;
  known_hash text;
  known_revision integer;
  known_status text;
  request_count integer;
  report_count integer;
  clock_hour timestamptz := date_trunc('hour', now());
begin
  if p_token_hash !~ '^[0-9a-f]{64}$' or p_rate_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid capability';
  end if;
  -- Expire counters even when all incoming reports are rejected at capacity.
  delete from private.gg_upload_limits where hour < now()-interval '48 hours';
  perform pg_advisory_xact_lock(hashtextextended(run_id::text,0));
  select k.token_hash,r.revision,r.status into known_hash,known_revision,known_status
    from private.gg_report_keys k join public.gg_run_reports r on r.id=k.id where k.id=run_id;
  if known_hash is not null and known_hash <> p_token_hash then
    return jsonb_build_object('error','forbidden');
  end if;
  if known_hash is not null and incoming <= known_revision then
    return jsonb_build_object('id',run_id,'revision',known_revision);
  end if;
  if known_status is not null and known_status <> 'active' then
    return jsonb_build_object('error','terminal');
  end if;
  insert into private.gg_upload_limits values ('global',clock_hour,1)
    on conflict (bucket,hour) do update set requests=private.gg_upload_limits.requests+1
    returning requests into request_count;
  if request_count > 1800 then return jsonb_build_object('error','rate_limit'); end if;
  insert into private.gg_upload_limits values (p_rate_hash,clock_hour,1)
    on conflict (bucket,hour) do update set requests=private.gg_upload_limits.requests+1
    returning requests into request_count;
  if request_count > 300 then return jsonb_build_object('error','rate_limit'); end if;
  if known_hash is null then
    perform pg_advisory_xact_lock(hashtextextended('gg_report_capacity',0));
    select count(*) into report_count from public.gg_run_reports;
    if report_count >= 500 then return jsonb_build_object('error','capacity'); end if;
  end if;
  insert into public.gg_run_reports (id,revision,build,status,coverage,seed,started_at,updated_at,report)
    values (run_id,incoming,p_report->>'build',p_report->>'status',p_report->>'coverage',
      p_report->>'seed',(p_report->>'started_at')::timestamptz,(p_report->>'updated_at')::timestamptz,p_report)
    on conflict (id) do update set revision=excluded.revision,status=excluded.status,
      updated_at=excluded.updated_at,received_at=now(),report=excluded.report;
  if known_hash is null then insert into private.gg_report_keys values (run_id,p_token_hash); end if;
  return jsonb_build_object('id',run_id,'revision',incoming);
end;
$$;
revoke all on function public.gg_store_report(jsonb,text,text) from public, anon, authenticated;
grant execute on function public.gg_store_report(jsonb,text,text) to service_role;
