# Automatic playtest reports

The game records accepted RunState actions, not clicks or cosmetic replays. A new
run gets a random UUID independent of the gameplay RNG. The exact seed is a
decimal string so JavaScript preserves all 64 bits. Reports include the build,
deck and skill selections, cards and their owners/targets, end-turn intentions
and actual combat logs, before/after HP/defenses/statuses, inheritance odds and
rolled results, traits and activations, transformations, raid results, recovery,
and the final outcome. Team state is captured before recovery changes it. From
v0.14.0, the current run view retains its saved first trait offer, and each accepted
trait choice records the actual offered IDs alongside the selected ID. Older
reports do not reconstruct offers that were never recorded.

The dashboard can compare recorded card use, energy spent and voluntarily left
at End Turn, breaches, builds, and ordered decisions. Combat snapshots show net
changes: they do not establish exact aggregate damage, healing or overhealing
attribution. These are client-reported observations, not controlled comparisons,
verified competitive results, or human win rates. Active runs can be paused;
closing the app does not prove abandonment. Replacing a run explicitly marks it
abandoned. Older saves start partial coverage without reconstructing old events.

The local report journal retains ten reports. Each keeps at most 2,000 events and
384 KiB, trimming oldest events while retaining cumulative summaries. Truncation
is visible in the dashboard. Reloads do not duplicate accepted actions. Reports
save with the run before an upload signal is emitted. Diagnostics use isolated
verification prefixes and never upload automatically.

Automatic collection shows a notice on the title screen. **Playtest reports** on
the title, results and battle rules screens exposes its saved on/off switch.
Turning it off stops future uploads; local and already submitted reports remain.
Uploads are asynchronous, normally coalesced every 15 seconds with faster result
uploads. Failed requests retry with bounded backoff, and pending reports retry on
the next launch. Last actions cannot be guaranteed uploaded if a player closes
the game before the request completes and never reopens it. More than ten runs
played entirely offline can roll older local reports out of the journal.

No player accounts or names are needed to play. Reports contain gameplay data and
platform names, not email, location, browser histories or stable player IDs. The
backend provider handles ordinary network metadata. A private per-run write key
is kept in the device's upload_state.json, sent only over HTTPS, and hashed on the
server. It is excluded from reports and exports. A report cannot be overwritten
without its write key; revisions are monotonic and terminal reports are immutable.

The separate Supabase project uses an ingestion Edge Function and row-level
security. Anonymous players cannot read reports, write tables directly, or call
the storage RPC. Approved reviewers use verified email/password accounts to read
the dashboard. Reviewer authorization checks auth.uid() and the private email
allowlist, never user-editable metadata. The server secret key exists only in the
Edge Function's server environment (the modern SUPABASE_SECRET_KEYS value). Only its public URL and publishable key go
into the static dashboard config. The ingestion function validates payload sizes
and fields, browser origins, per-run keys and write revisions; database limits
bound request rates and admission to 500 runs. Existing runs can keep updating at
capacity. Capacity stops admitting new reports until an owner manages storage;
it does not automatically delete gameplay reports or upgrade billing.

## Backend setup

The current project is `kuokxkgujawxvtfgefsw`, created in the approved Free
organization at the quoted $0/month. The report endpoint and public dashboard
configuration are connected, and the confirmation Site URL points at the
dashboard. First-time approved reviewers create an account with their own
password, confirm their email and return to sign in. Reviewer credentials and
email addresses are kept outside the public repository.

Live role, RPC, HTTP and native/browser upload checks passed. Security advisors
returned only the informational [RLS enabled without policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
notice for the private tables: those tables intentionally deny all client access
and are used by the server role. Performance advisors reported [unused indexes](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index)
on the newly created tables; these indexes support dashboard ordering and counter
expiry. No warning or error advisories were reported.

For a replacement backend:

Create the user-approved separate Free project, then apply the canonical SQL in
supabase/migrations. Deploy gg-ingest-run with its custom per-run authentication
and configure the Auth Site URL from supabase/config.toml. Keep email confirmation
enabled so reviewers must prove ownership of an approved address. Add emails to
private.gg_reviewers outside Git; reviewer emails do not belong in public source.
Set scripts/report_config.gd's ENDPOINT to the Edge Function URL and create
web/dashboard/config.js with window.GG_REPORTS_CONFIG={supabaseUrl,publishableKey}.
Apply grants/RLS and run real RPC, capability, role and HTTP checks plus Supabase
advisors before enabling the endpoint. The connected Supabase tools can query
the reports for subsequent design reviews.

The dashboard is copied into the Pages artifact after Godot exports the game.
Backend SQL, functions and admin tooling are excluded from both game packages.
Empty connection config keeps reports local when connecting a replacement backend.
