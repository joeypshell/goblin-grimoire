# Verification

## v0.13.0 champion countdown and build receipts

The recap/feedback checks exercise accepted and rejected cards, stored charges carried across turns, one activation for a complete area card, Armor/Block/Evade/overkill, and the winning card. Snapshots and replay retain exact counters without advancing RNG. Missing legacy counters start explicitly partial; later observed actions cannot fabricate prior history. Victory captures pre-recovery HP and real trait triggers, persists through feeding, trait choice, recovery and Continue, and clears on the next raid, a new run or defeat. The focused model/feedback suite passes **254 checks**.

The tactical UI checks pass in headless and native modes at **1280×720, 375×667, 390×844 and 844×320**, with **6,750 assertions / 76 layouts/screenshots** in each run. They cover Volley countdowns across rounds 1–6, locked intentions, Stun, Resolve, knockout, rotation and playback; charged attack receipts including an entirely blocked hit; and the real feeding/recovery/save flow for full, partial and health-only recaps. Rendering and repeated recap queries preserve gameplay/RNG. Native screenshots were inspected in narrow portrait and short landscape; combat actions remain reachable and the fixed End turn control remains visible. Native ScreenTouch regression checks pass **385 assertions / four screenshots**; the existing mobile suite passes **17,623 assertions / 189 layouts**.

The full gameplay suite passes **8,279 checks across 21 groups**, with zero failures. Existing mobile, turn-flow, first-act UI, trait, pacing, art and audio checks pass. The bounded first-act diagnostic passes **1,185 checks**, with all nine developer policies completing the first three raids. These policies are regression evidence, not human enjoyment or win-rate estimates. Ingestion fixtures pass **40 checks** without contacting the deferred backend. All final Godot logs are free of script/engine errors and warnings.

Windows and Web release exports succeed; Windows file/product metadata is **0.13.0**, and its ZIP contains the executable, launch instructions and music credits. Tests use isolated profiles. Native logical phone sizes and touch checks do not establish physical iPhone Safari playback or performance, which remains untested.

## v0.12.0 full party wipe ends the run

Losing all monsters now resolves one terminal defeat, with zero HP retained and no defeat recovery, feeding rewards, Core budget or retry. New runs omit Core entirely. Victory recovery still revives individually knocked-out teammates; real six-raid campaigns remain reachable. The broad gameplay run passed **8,018 checks / 19 groups**. The final load-order change received **100 focused checks**, including report-less old defeats, stable repeat loading, unchanged RNG and immutable historical reports. The first-act diagnostic passes **1,185 checks** with all nine developer policies completing the first three raids.

Legacy saves waiting to retry a lost raid in result, preparation or trait selection become defeats, with fallen HP restored to zero. Already living combat, feeding and victories continue without changing their party, hand or gameplay RNG. A persisted full-wipe combat resolves on load without another action or draw. Old terminal reports stay frozen; new views identify the `party_wipe_ends_run` loss rule and omit Core. The dashboard displays the old Core metric only when a historical report actually contains it. No backend configuration is changed.

Final UI checks pass: turn flow **2,388 assertions**, mobile **17,623 / 189 layouts**, party routes **7,966 / 52**, report controls **1,084 / 28**, music settings **1,782 / 24**, pacing **1,697 / six**, and traits **2,929 / 56**. Native ScreenTouch passes **385 assertions / four screenshots** at 375×667 and 844×320. Fifteen additional native screens verify desktop loss presentation. Loss screens show all three zero-HP monsters and a new-run action, with no recovery, retry or future-reward prompt. The energy warning retains its cancellation, stale-input and actual Space/Escape/Tab/Enter checks. Logs are scanned for diagnostics independently of exit status; all final checks exit zero with clean logs. Verification profiles remain isolated. Physical iPhone Safari is unavailable.

A separate ignored diagnostic compared tactical and random legal combat through three raids, using four seeds, the standard second-raid route, actual concentrated corpse feeding, earned forms and the same learned-loadout/War Drums policy. Tactical play completed **4/4**; random play completed **1/4**, with two losses on raid two and one on raid three. No policy timed out. **1,121 mechanics checks** passed, including independent random-decision RNG. Tactical completed-run medians were **10 ended turns / 35.5 card plays**; random's one completion took **10 / 31**. Random's all-run median was **14 / 42**, including truncated defeats. These are developer policies, not player win rates or enjoyment evidence: the helpers know form/loadout priorities, the sample is small, and decisions change later draws, inheritance and forms. The next proposed design experiment makes the approaching champion attack and earned build payoff easier to see, followed by a human first-act playtest.

## v0.11.1 dungeon health and unspent energy

The **CORE HP** header opens a read-only explanation of dungeon health, the 25-HP breach when all three monsters fall, retry after recovery, and defeat at zero. End Turn and Space both warn whenever positive energy remains. Opening and cancelling preserve the entire battle, run, hand, selected card, RNG and save counters; zero-energy turns proceed directly. Explicit confirmation is compared with the ordinary production turn, including once-only saving and replay. Duplicate, stale and changed-energy confirmations cannot commit another turn. Confirmation retains a numeric modal identity instead of a freed node reference.

Focused turn-flow checks pass **2,437 headless assertions** with no issues or engine diagnostics. Actual `Input.parse_input_event` press/release checks verify that opening Space leaves the warning open, Keep playing receives initial focus, Escape cancels, and Tab followed by Enter explicitly confirms. Existing pacing checks pass **1,709 assertions / six layouts**. Mobile checks pass **19,555 assertions / 198 headless layouts**; native ScreenTouch passes **591 assertions / four screenshots** at **375×667** and **844×320**, covering Core help and both warning actions. The warning uses a compact centered panel, with touch controls at least 44 logical pixels tall.

The full gameplay suite passes **7,995 checks / 18 groups / zero failures**. Existing audio settings pass **1,806 assertions / 24 layouts**; party routes **8,680 / 52**, tactical UI **3,354 / 32**, first-act UI **3,278 / 36**, art **8,476 / 74**, and traits **2,985 / 56**. Logs are checked for errors and warnings independently of exit status. Windows and Web exports succeed. Tests use isolated verification profiles; physical iPhone Safari remains unavailable.

## v0.11.0 continuous music and sound controls

The soundtrack uses credited, licensed **Darkest Child** and its faster **var A** by Kevin MacLeod. Creator pages and CC BY 4.0 terms are linked in the game and recorded in `assets/audio/LICENSE.txt`. The OGG loops last **233.03 and 192.64 seconds**, total **5,592,921 bytes**, and are normalized to **−23.0 LUFS**. Measured encoded true peaks are **−10.38 and −10.01 dB**, leaving headroom for equal-power context fades and the champion gain. Source/asset hashes, modifications and measurements are in `assets/audio/track-info.json`; `tools/prepare_music.py` reproduces the preparation from the creator MP3s using numpy, soundfile and imageio-ffmpeg.

The music director passes **45 focused checks in both headless and native Dummy-audio modes**. Two persistent looping players use 1.5-second equal-power transitions; tests cover the midpoint, reversal during a fade, repeated context queries without restarting, mute/zero-volume/background pause, resume, explicit preference persistence, missing tracks and a single-track fallback. Loop preparation leaves shared stream resources unchanged. Browser gesture gating is exercised through the production director API; native focus handling and document-visibility wiring receive a source review.

Sound-control checks using the actual imported OGGs pass **1,806 headless assertions across 24 layouts** and **1,832 native assertions across 24 screenshots**, with zero issues. Sizes are 1280×720, 375×667, 390×844 and 844×320. Native ScreenTouch opens, mutes, restores and closes settings; ScreenDrag changes the volume slider without stealing vertical scrolling. The title and Log & rules entries, reachable 44-pixel controls, saved level/mute, intact credits and return flow are verified. Settings and the Grimoire preserve the battle playback object, complete gameplay snapshot, save bytes and RNG. Existing speed/motion preferences survive audio updates. Normal profiles and reporting endpoints are not used.

Screenshots were reviewed at desktop, narrow portrait and short landscape sizes. A desktop title-row allocation issue was corrected by putting Sound settings under the title art there; compact screens place it below New run/Continue. Tests that free scenes with active audio wait briefly for AudioServer's mixing callback to retire stopped playback references before quitting; the production director stops its players and removes its web visibility callback on exit.

Final existing headless regressions pass with the actual music assets: mobile **16,435 assertions / 180 layouts**, turn flow **2,394**, pacing **1,694 / six layouts**, art **8,474 / 74**, traits **2,977 / 56**, party routes **8,680 / 52**, rewards **2,395 / 32**, tactical UI **3,354 / 32**, first-act UI **3,278 / 36** and report UI **1,088 / 28**. Every run exits zero with no script/engine errors or warnings. The teardown waits change no assertions, fixtures, gameplay or reporting behavior.

These checks establish routing, continuity, saved settings and native touch behavior. Browser tools and a physical iPhone Safari device are unavailable in this session, so audible Safari playback, background/resume and hardware performance remain untested. Music generation through the connected service required a paid plan, so this pass uses the credited free license without a purchase. Reporting backend work remains deferred.

```sh
godot --headless --path . --script tests/test_music_director.gd
godot --headless --path . --script tests/audio_ui_smoke.gd
godot --audio-driver Dummy --path . --script tests/audio_ui_smoke.gd
```

## v0.10.0 first-act build experiment

The integrated gameplay suite passes **7,995 checks across 18 groups**, with zero failures. Focused stored-Bulwark/War Drums checks pass **1,521 assertions**; encounter-rule checks pass **206**. Coverage includes persistent charges, complete-card consumption, same-turn recharge limits, legal teammate protection, once-per-turn energy/draw, combined Pack Instinct rewards, exact snapshots and read-only previews. Ward checks exercise actual HP loss after Armor/Block/Evade, surviving captains, stable lowest-HP-percentage recipients and deferred area-card resolution. Ritual checks cover rounds 2/5/8, wounded teammates, stun/KO interruption, stable dead-target fallback, repeatable inherited healing and unchanged RNG.

`tests/first_act_playtest.gd` passes **1,176 checks** using actual generated parties, learned skills, earned traits/forms and weighted corpse rolls. Eight comparison policies (four seeds, both raid-two routes) finish the first three raids in **7–12 End Turns / 27–38 card plays**, without breaches or timeouts. They activate earned War Drums **21 times**. Standard seed `730205` naturally earns Green Ogre, stores a charge on turn one and spends it on turn two; alternate seed `730215` announces Renewal Ritual and cancels it with stun. A separately labelled captain-first policy triggers three wards and completes raid two in five End Turns, versus four when attacking allies first. The JSON report and actual corpse-roll journal are written only to ignored `build/` files.

These are bounded developer policies, not human win rates or evidence of enjoyment. Feeding uses the existing helper that knows developer recipe ordering, and combat scores cloned production battles. No abilities, forms or rewards are granted to the campaign; changing decisions also changes later RNG. The intended human follow-up is a new run through the first three raids, choosing War Drums and checking whether setup, reward and encounter choices feel satisfying.

| Check | Recorded result |
| --- | --- |
| Focused first-act UI, native and headless | 3,278 assertions in each mode / 36 screens or layouts / zero issues |
| Full mobile UI and native touch | 16,626 assertions / 180 screenshots / zero issues |
| Party preparation, headless | 8,680 assertions / 52 layouts / zero issues |
| Trait/champion UI, headless | 2,977 assertions / 56 layouts / zero issues |
| Turn flow, headless | 2,394 assertions / zero issues |
| Illustrated cards and motion, headless | 8,474 assertions / 74 layouts / zero issues |
| Combat pacing, headless | 1,689 assertions / six layouts / zero issues |
| Reward/form UI, headless | 2,395 assertions / 32 layouts / zero issues |
| Existing tactical UI, headless | 3,354 assertions / 32 layouts / zero issues |

Focused screenshots were reviewed at 1280×720, 375×667, 390×844 and 844×320. All four initial trait choices and three remaining choices stay reachable; the immediate Guard payoff, stored charge, actual ward forecast and cancelled ritual remain readable. Changing from an ally-targeted protection card to an attack resets the portrait actor scroll so the invader's name, HP and Armor appear. The fixed short-landscape footer stays visible. Native ScreenTouch/ScreenDrag checks pass; physical iPhone Safari remains untested. All final engine logs are free of script errors and warnings, and profiles/uploader bindings stay isolated under `user://verification/`.

CI includes both new first-act harnesses alongside the existing regression suites. The campaign still has six raids; generated legacy parties and locked actions are preserved, while future eligible parties receive the new encounter flags. The fixed twelve-card deck, repeatable healing and 4:2:1 random inheritance remain intact. Reporting backend work remains deferred.

Browser and Windows release exports complete without errors or warnings. Windows file/product metadata is `0.10.0`; its ZIP contains the standalone executable and matching launch/playtest instructions.

```sh
godot --headless --path . --script tests/test_runner.gd
godot --headless --path . --script tests/first_act_playtest.gd
godot --headless --path . --script tests/slice_ui_smoke.gd
godot --path . --script tests/slice_ui_smoke.gd
```

## v0.9.0 combat, transformations and reward clarity

The new form suite passes **1,395 focused checks**. It exercises all eight evolved forms through accepted card actions: setup before payoff, wrong-order exclusions, per-owner once-per-turn limits, area damage, lethal targets, Resolve, rejected plays, save/Continue, and exact combined form/trait draw and energy rewards. Sequential previews remove Block before forecasting a hit, include evolved self-Block modifiers, omit impossible post-KO stun/draw, and preserve the complete snapshot and RNG. Actual generated invader kits follow six-round role schedules; legacy unflagged parties retain their prior selection behavior and locked actions. The Marshal's scheduled Breach Order tests Block removal, armor, Evade and stun counterplay.

The v0.8 diagnostic baseline used four seeds and three policies. The tactical driver won all four runs in **37, 43, 46 and 44 player rounds**. Random legal cards and targets with tactical loadouts won two runs, needing **177 and 48 rounds**; one winning run used **484 cards**, with a longest fight of **30 rounds**. Its announced actions were nearly half support and it recovered 742 HP through direct healing. A blind starter-loadout policy won none. These are scripted diagnostics, not human win rates or measures of enjoyment.

The updated driver evaluates actual learned skills and the currently visible form with isolated production-resolution probes. It gives zero-cost and refunded attacks a finite hand-slot value instead of assuming unlimited free-card throughput. It does not inspect hidden recipes when configuring skills. Macro feeding still uses the existing developer campaign policy, so comparisons across releases also reflect changed decisions and RNG; they do not isolate one balance change. Candidate testing exposed another 16-round fight caused by overvaluing Quick Jab as the only selected attack in a defensive form. The final driver corrects that valuation; production still permits players to select a weak or defensive deck. Standard milestone parties now guarantee possession of one introduced skill, while random inheritance remains unchanged.

Fast combat is separate from reduced motion and saved outside run data. The final headless pacing harness passes **1,707 checks across six layouts**, preserving the same committed result through fast/normal playback, Skip and Continue. Native checks passed **1,599 assertions**, including real ScreenTouch, reload of the Normal preference and measured durations around **2.5 seconds Fast / 4.9 seconds Normal** for an ordinary three-invader turn.

Reward/form UI tests pass **2,383 assertions in both headless and native modes**, covering **32 layouts/screenshots** at 1280×720, 375×667, 390×844 and 844×320. Actual Devour and Replace controls equip either slot explicitly without rerolling, auto-equipping, changing feeds or adding deck cards. Latest-meal receipts survive Continue, lower-index newest claims and legacy fallback; recovery clears the pointer. Earned chooser/reveal shows actual HP, signature effects and tactics while unmet forms stay hidden. Discovered Grimoire and preparation descriptions remain correct. Native captures were inspected.

Existing headless turn-flow and trait UI checks pass **2,394 and 2,866 assertions**, respectively, with zero issues. Node ingestion fixtures pass **40 checks**. Profiles and upload bindings remain isolated; reporting backend work remains deferred. Physical iPhone Safari remains untested.

The final integrated gameplay suite passes **7,690 checks across 16 groups**, with zero failures. The primary seed `730204` clears the six raids in **23 ended turns / 75 real card plays**. Four additional concentrated/spread campaigns also reach victory with zero breaches. The focused party-route suite passes **1,171 checks**, including an all-alternate victory with seed `101` in **21 ended turns / 68 plays**. The bounded test also tried seed `730204`, which loses its final raid; it does not establish universal reachability for every strategy and seed.

The final four-seed diagnostic cohort passes **1,844 checks**, with no timeouts. Tactical runs all win without breaches in **29, 27, 41 and 32 battle rounds**, averaging **32.25**, versus the earlier 42.5. Mean End Turn actions fall from 38 to 27.5. The longest tactical fight is ten rounds. Random legal combat with strategic builds wins **0/4** (previously 2/4), with a longest fight of fifteen rounds (previously thirty). Blind default-loadout runs remain 0/4. The sample and changed driver limit these comparisons; neither wins nor duration establishes human enjoyment.

Final rendered regression checks pass **8,474 art assertions / 74 screenshots**, **16,566 mobile assertions / 180 screenshots**, and **3,354 tactical UI assertions in each mode / 32 layouts or screenshots**, with zero issues and clean logs. Native ScreenTouch and ScreenDrag exercise gameplay. Tactical UI checks show actual round-two Marshal counterplay, Resolve, Block-removal/armor forecasts, real target presses, a payable zero-energy card, and available/readied/used form combos at four sizes. Native pixel inspection confirms the cues are readable. The battlefield minimum derives from intrinsic wrapped columns, retains at least 60 pixels for creatures, and remains stable through 1280×720 → 1920×1080 → 1280×720. A root margin allocation fix prevents a tall preparation screen from leaving the short-landscape combat footer outside the viewport. The native touch fixture now assigns its isolated state before scene `_ready` binds the uploader.

Both final browser and Windows exports complete without errors or warnings. Windows file/product metadata is `0.9.0`. CI now includes pacing, reward and tactical UI harnesses alongside the integrated gameplay and existing regression checks.

```sh
godot --headless --path . --script tests/test_runner.gd
godot --headless --path . --script tests/pacing_smoke.gd
godot --headless --path . --script tests/reward_tactics_smoke.gd
godot --path . --script tests/reward_tactics_smoke.gd
godot --headless --path . --script tests/tactical_ui_smoke.gd
godot --path . --script tests/tactical_ui_smoke.gd
```

## v0.8.0 party choices

The focused party-choice suite passed **903 assertions with zero failures**. It checks the six released baseline parties against independently captured fixed-seed fixtures, caches deterministic alternatives without consuming gameplay RNG, rejects invalid or locked choices without mutation, and restores the selected party through preparation, combat, breaches and retries. Actual chosen invader abilities become the real corpse pools; inheritance keeps its existing 4:2:1 rarity weights. Legacy saves preserve an already generated party and receive choices at a future eligible raid.

A campaign choosing every offered alternate completed all six raids with seed `730204`, using **85 card plays over 29 ended turns, six attempts and zero breaches** through normal RunState APIs. It performed two Oni evolutions and reached victory with production health, card costs and weighted random inheritance. This establishes campaign reachability; it does not measure human enjoyment or compare strategy strength under matched conditions. The driver knows developer recipes, and changing parties changes later decisions and RNG consumption.

Save-boundary checks exposed loss of low bits when a full-width seed was stored as a JSON number. New saves now store the seed's exact decimal spelling and restore the live integer API. Tests with ordinary and full-width signed 64-bit seeds confirm that future options generated after reload match uninterrupted play.

| Check | Recorded result |
| --- | --- |
| Party preparation, headless | 8,377 assertions / 52 layouts / zero issues |
| Party preparation, native | 8,665 assertions / 54 screenshots / zero issues |
| Existing mobile screens, headless | 16,027 assertions / 180 views / zero issues |
| Existing trait/champion UI, headless | 2,837 assertions / 56 layouts / zero issues |

The party harness covers raids 2, 4 and 5 at **1280×720, 375×667, 390×844 and 844×320**, checking real button closures, numeric Armor, affinities from actual unknown skills, skill-selection advice updates, continued saves, orientation changes, locked retries and reachable 44-pixel controls. Native ScreenTouch selects alternate, standard and alternate again, then Defend starts exactly the selected encounter. Rendered desktop, portrait and short-landscape captures were inspected. Logs contain no script/engine errors or warnings. Profiles and uploader bindings stay isolated under `user://verification/`; normal player saves and live reports are not used. Physical iPhone Safari remains untested.

```sh
godot --headless --path . --script tests/test_runner.gd
godot --headless --path . --script tests/party_routes_smoke.gd
godot --path . --script tests/party_routes_smoke.gd
```

The Verify and publish workflow includes the new party UI harness alongside the full gameplay, mobile, turn-flow, art, trait and existing reporting checks. Browser and Windows v0.8 exports finish cleanly. Screenshots are in the ignored `tests/artifacts/routes/` directory.

## v0.7.0 playtest reporting

The game connects to the approved separate Supabase Free project **`kuokxkgujawxvtfgefsw`**. The ingestion function is deployed, and the game endpoint and public dashboard configuration are filled. The Auth Site URL is `https://joeypshell.github.io/goblin-grimoire/dashboard/`; email confirmation is enabled. The selected reviewer is approved in the private database allowlist; reviewer email addresses are not included in public source. The Verify and publish workflow exports the game and copies its static dashboard into the Pages artifact after all CI checks pass.

The final full gameplay run passed **5,299 checks across 14 groups**, with zero failures and a clean engine/script log. Reporting fixtures compare ordinary and instrumented play, preserve complete battle/progression/RNG state, exercise partial legacy observation, continuation, per-action combat logs, cumulative summaries, historical decks and energy, and bounded event/journal storage. The final isolated report-core run passed **2,082 assertions**, including terminal reports remaining byte-identical through later metadata changes, saves and reloads.

| Check | Recorded result | Scope |
| --- | --- | --- |
| General mobile layout/actions, headless | 16,018 assertions / 180 views / zero issues | Existing gameplay screens with reporting entry points |
| Report controls, headless | 1,064 assertions / 28 layouts / zero issues | Status, upload toggle, summaries, rotation and reachable 44-pixel actions |
| Report controls, native | 1,064 assertions / 28 screenshots / zero issues | Same controls with rendered pixel review |
| Uploader | 63 checks / 8 loopback HTTP requests / zero failures | Local requests, acknowledgments, preference persistence and retry/disable behavior |
| Dashboard browser fixtures | 89 checks / 8 screenshots / zero issues | Mocked REST authentication and report responses at four sizes |
| Live database | 75 assertions / zero failures | Actual database roles, reviewer-policy fixtures, write capability, revision and terminal rules; transaction rolled back |
| Live HTTP integration | 22 checks / zero failures | Deployed ingestion, malformed/oversized payloads, capabilities, revisions, terminal protection, CORS, anonymous denial and public email-confirmation settings |
| Live native Godot uploader | 17 checks / 1 HTTP 200 completion / zero failures | Actual isolated run/card/turn payload, exact acknowledgement, durable reload and opt-out |
| Connected dashboard UI | 4 browser sizes / zero layout issues | Initial sign-in and account-mode guidance through CUA; no authentication submitted |
| Live mobile browser collection | CORS HTTP 204 / 4 collector POST HTTP 200 acknowledgements | Actual isolated run actions, revisions 2–5 for one report ID, synced status and opt-out |

The locally served release candidate's dashboard HTML, configuration, JavaScript and CSS each returned **HTTP 200** with their expected content types. The public configuration points to the approved project and uses a publishable key. A separate public-key-only report read returned **HTTP 401 / PostgreSQL 42501**, with no report rows. These static and anonymous checks made no signup, sign-in or credential requests. They do not establish a human reviewer's browser session.

Report UI sizes are **1280×720, 375×667, 390×844 and 844×320**. Native review confirms readable partial-coverage guidance and status, scrollable short-landscape controls, and the unchanged 44-pixel minimum. The desktop title's report action shares its existing action row so the footer remains in bounds. Rotation retains the same open modal, upload choice and report data. Captures are in ignored `tests/artifacts/reports/`.

Dashboard checks use isolated browser fixtures at the same four sizes. They cover explicit first-time signup and email-confirmation instructions, sign-in failure and password clearing, access-token refresh, sign-out and stale-response rejection, pagination deduplication, safe text rendering, 64-bit decimal seed preservation, ordered events, deck owner/costs, per-attempt unused energy, trait activations, and exact JSON export. Mocked authentication does not verify a real reviewer account or database authorization. Screenshots are in ignored `tests/artifacts/dashboard/`. The Node.js 24 ingestion harness passed **40 checks** against a mocked RPC backend. Its validator also accepted **18 actual isolated Godot report snapshots**, including bounded reports and terminal outcomes.

The connected candidate was separately inspected through CUA at **1280×720, 375×667, 390×844 and 844×320**. Initial sign-in fields and buttons remained within the page width, with no horizontal overflow; email/password fields were at least 44 pixels high and action buttons measured 44.797 pixels. Switching to **Create a reviewer account** and back showed the own-password, email-confirmation and approved-reviewer guidance without submitting either form or making Auth requests. The viewport override was reset afterward. Captures are in ignored `tests/artifacts/reports-live/dashboard-<width>x<height>.png`.

The actual game was played in an isolated browser origin at **390×844 with device-pixel ratio configured to 3**. A new run played one **Goblin Stab** and ended two turns; the recorded summary showed **1 card, 2 ended turns and 5 unused energy**, without player identity. The browser observed a successful **HTTP 204 CORS preflight** and **four collector POST responses with HTTP 200**, acknowledging revisions **2, 3, 4 and 5** for the same report ID. **Playtest reports** showed **Saved gameplay reports synced**, then **Automatic sharing paused** after opt-out. Reload initialized the expected **1170×2532** retina canvas; Continue restored round three, HP, energy, hand and locked targets. The report retained revision five, the same counts and the paused upload setting. Browser warnings/errors were empty. Test reports were removed by their captured UUIDs, leaving the dashboard empty for real playtests. These observations do not establish a physical Safari session.

The browser and Windows release-candidate exports finish without errors or warnings. The browser artifact includes the static dashboard with its real public connection settings. The normal player's run and grimoire hashes remain unchanged.

Run the reporting checks with isolated profiles:

```sh
godot --headless --path . --script tests/report_core_smoke.gd
godot --headless --path . --script tests/report_upload_smoke.gd
godot --headless --path . --script tests/report_ui_smoke.gd
godot --path . --script tests/report_ui_smoke.gd
# Requires Node.js 24.
node tools/test_report_ingest.mjs
```

The gameplay suite also includes report regressions through `tests/test_runner.gd`. Ordinary Godot harnesses use named `user://verification/` profiles and disable live uploads; the loopback uploader fixture explicitly enables only its local test server. Mocked dashboard fixtures do not touch real reports or reviewer accounts. No normal player save is reset or uploaded by these checks.

The following **manual integration commands write disposable verification reports to the approved live backend**. They require the explicit flag, are excluded from CI and normal gameplay checks, and perform no reviewer signup or sign-in:

```sh
# Requires Node.js 24; stores the generated UUID in build/reports-live-http.json.
node tools/test_report_live.mjs --live-report-test
# Prints its generated UUID and uses a unique user://verification/report_live_* profile.
godot --path . --script tests/report_live_smoke.gd -- --live-report-test
```

Both live harnesses mark their report **build `0.7.0-verification` / platform `Verification`**. The native test plays an actual drawn card and ends a turn through RunState before uploading, then reloads the durable acknowledgement and paused preference without changing gameplay RNG. Cleanup is an owner database action limited to the captured test UUIDs, with both markers checked before deletion; deleting those report rows also removes their private per-run keys through the foreign-key cascade. It must not delete ordinary reports, reviewer accounts, the reviewer allowlist or unrelated upload counters. SQL role/policy fixtures are rolled back and do not leave test users or rows behind.

Actual human reviewer signup, password entry, email confirmation and sign-in still require the user. Browser-issued reviewer JWTs, concurrent live writers and a physical iPhone Safari session have not been verified. Connected browser coverage establishes the initial forms and layout; authenticated archive behavior is covered by mocked browser fixtures and database role/policy checks.

## v0.6.0 dungeon builds and champion payoff

The gameplay suite passed **3,217 checks across 13 groups**, with zero failures. New coverage exercises earned choices after the first raid and F champion, rejection before an earned reward, no duplicate traits, exactly-once recovery and choice saves, pending-choice reload, two missed legacy milestones at a safe boundary, and no RNG consumption from reward queries or selection. Tests use isolated verification profiles; the normal native run and grimoire hashes remain unchanged.

Combat regressions cover direct and status-tick poisoned deaths, independent fresh poison layers, enemy-array order independence, no same-tick spread chain, once-only corpse marking, and no activation report when no recipients survive. Shield retaliation checks Armor/Evasion/status exclusions, lethal defenders, once per recipient per announced attack, defended retaliation, area attacks and a poisoned KO caused by retaliation. Pack checks distinct owners, shared-card exclusion, failed plays, once-per-turn activation, saved two-owner progress, draw/shuffle and exact replay state. Captain tests cover scheduled rounds, ordinary actions between volleys, locked previews, Stun cancellation, Resolve, defeat cancellation, and the transferable ability's relative targeting.

Five bounded campaigns used production cards, party generation, weighted inheritance and ordinary trait-selection APIs:

| Seed / feeding policy | Traits | Result | Ended turns / card plays |
| --- | --- | --- | ---: |
| 730204 / discovery driver | Venom Nest + Spiteful Shields | Victory | 33 / 96 |
| 101 / concentrated | Venom Nest + Spiteful Shields | Victory | 38 / 110 |
| 101 / spread | Pack Instinct + Venom Nest | Defeat at raid index 4 after four breaches | 53 / 151 |
| 730205 / concentrated | Venom Nest + Spiteful Shields | Victory | 35 / 97 |
| 730205 / spread | Pack Instinct + Venom Nest | Victory | 47 / 142 |

These demonstrate reachable victories and normal failure/retry behavior, not human win rates or trait rankings. Feeding policies and combat decisions consume the shared RNG differently; their later encounters are not matched comparisons. The driver knows developer recipes and is not tuned to each trait. Whether players find the builds more engaging remains a human playtest question.

Final UI checks passed **15,916 headless / 16,124 native mobile assertions across 180 views**, including 28 native touch assertions; **2,415 native flow assertions with 24 sequence captures**; **8,397 art assertions in each mode across 74 views**; and **2,749 trait assertions in each mode across 56 views**. The dedicated trait suite covers first/second choices, scrolling to the lower choice actions, learned but unequipped poison guidance, the visible champion numbers and counterplay, cancelling its announced volley, saved Pack progress and named compound activations at 1280×720, 390×844, 375×667 and 844×320. Native pixel review caught Captain caption overflow and compact callouts obscuring names; the final captions retain numeric intentions, the existing wide counter carries champion guidance, and mobile actor flashes plus written numeric feedback keep names and HP visible. Desktop floating feedback fits only inside creature art. No minimum-size feedback loop was introduced.

The exported browser build completed a real first raid through card/target controls, consumed all three actual bodies, and reached the first trait reward. At emulated **390×844 / DPR 3** (canvas **1170×2532**), reload/Continue preserved the pending options and learned-but-unequipped Poisoned Blade guidance. Scrolling reached all three choices. Selecting the third option awarded Pack Instinct, showed the champion milestone and capped recovery, and another reload preserved the selected trait without reopening the reward or applying recovery twice. Browser warnings and errors were empty. Windows version metadata reads 0.6.0 and the exported game's headless startup exits cleanly. Physical iPhone Safari is unavailable; these are emulated browser and native Godot touch checks.

## v0.5.0 balance pass

The gameplay and persistence suite passed **3,162 checks across 11 groups**, with zero failures. Five actual six-raid campaigns completed through ordinary play, feeding, evolution, recovery and save APIs, with no breaches:

| Seed / feeding policy | Ended turns | Card plays |
| --- | ---: | ---: |
| 730204 / discovery driver | 37 | 106 |
| 101 / concentrated | 43 | 122 |
| 101 / spread | 53 | 158 |
| 730205 / concentrated | 41 | 119 |
| 730205 / spread | 45 | 132 |

These runs use production HP, card costs, enemy targeting and weighted random inheritance. They include actual routes to both newly added advanced branches, with Nightstalker and Ancient Ogre reached in seed 101 campaigns. They demonstrate campaign reachability, not a human win rate or an optimal strategy ranking: the driver knows developer recipes, and its actions consume shared RNG, so later encounters and rewards can differ between feeding policies. The tactical driver now values removing enemy Block/Evasion and respects varying energy costs; older pacing measurements included its former reluctance to attack defended foes.

Regressions cover nonstacking Stun in both factions, a skipped action atomically granting Resolve, immunity through the next normal action/turn and then expiry, independent Poison/Burn/Regeneration applications, lethal status damage before healing, cleanse removing both display totals and layers, two-energy actions, and each advanced signature and passive. Seeded offensive targets reach all living monsters, preserve announced actions through queries and reload, and retain deterministic KO redirection. Generated priests always have and use offense; continuing an older heal-only priest party supplies Arcane Bolt without changing its already locked intent or RNG. Legacy aggregate-only statuses migrate as one application; layered saves continue identically through actions, decay, targeting and shuffle. All profiles are explicitly isolated under `user://verification/`.

Final UI checks passed **15,097 headless / 15,287 native mobile assertions across 162 views**, including 28 native touch checks; **2,390 headless / 2,414 native flow assertions**, with 24 rendered sequence captures; and **8,397 art assertions in each mode across 74 views**. Every UI harness injects its isolated bootstrap profile before scene startup, so even profile and motion-preference reads avoid the player's normal directory. Catalog fixtures separately check Resolve warnings, full-HP Mend cleansing, new signatures and owner Evasion, long card-detail scrolling, and consumed-affinity history. Native pixel review at 375×667, 390×844, 844×320 and 1920×1080 confirms the changed copy, cards and new creature forms; all final logs contain zero script/engine errors or warnings.

The browser build was checked at 1280×720 and emulated 390×844 with a 1170×2532 canvas: an actual Strike spent one energy and dealt its predicted six damage, and reload/Continue preserved that result and the locked targets. Mobile Log & rules fit and scrolled; browser warnings/errors were empty. Windows version metadata and headless startup were verified. Physical iPhone Safari remains unavailable; browser emulation and native Godot touch tests do not establish its hardware performance.

Legacy saves with multiple stun charges normalize to one displayed skipped turn, then grant Resolve and restore owned-card play. Both normalization and status consumption preserve the locked intentions and RNG.

## Previous release: v0.4.0

Run the simulation and persistence suite with Godot 4.7:

```sh
godot --headless --path . --script tests/test_runner.gd
```

The v0.4.0 gameplay run passed **1,584 assertions in nine groups**. A bounded tactical driver completed the six real F/E campaign raids with seed `730204`, using **107 card plays across 47 ended turns** through the ordinary `RunState.play_card` and `end_turn` APIs. It consumed actual generated adventurer bodies, accepted each random inherited skill once, performed Basilisk → Ember Basilisk and another first evolution, defeated both champions, and recorded promotion to D. Combat, card draws, costs, enemy HP, armor, and enemy intentions remain at production values. The driver scores candidate moves on cloned battles, then plays its chosen move on the actual run; it does not modify health or give rewards during that campaign. It chooses recipients and may decline an earned evolution, just as a player can; it cannot choose the inherited skill.

Random inheritance tests cover actual defeated bodies, invalid recipients/indices/phases, duplicate/unknown ability filtering, empty eligible pools, read-only previews, exactly-once consumption/save, and continuation with the exact result and post-roll RNG. Two separate fixed-seed sets of 512 fixture bodies reproduce identical outcomes, with common/uncommon/rare results near the declared 4:2:1 weights. These probability fixtures are separate from the real campaign. Armor tests cover repeated direct hits, Armor before spent Block, full prevention without healing, evasion, poison/burn bypass, turn persistence, class values, old saves without an armor field, combat save restoration, and no armor transfer on devouring.

The final v0.4.0 UI checks pass **14,373 headless / 14,554 native mobile assertions across 153 views**, including 28 native touch checks; **2,366 headless / 2,390 native flow assertions with 24 screenshots**; and **5,668 art assertions in each mode across 49 views**. Each combat actor's Armor and Block labels are checked for their actual independent values, visibility and containment. Feeding checks operate the real Devour control on an actual mage-corpse skill pool, verify read-only weighted odds without RNG changes, and capture the immediate saved receipt at every size. Pixel review at 375×667, 390×844, 1280×720 and 844×320 confirms readable odds, the Devour action, and the recipient/skill/source result. All final logs are free of engine/script errors and warnings.

The exported browser build was checked at 1280×720 and emulated phone 390×844 with a 1170×2532 backing canvas. A real Goblin Stab preview showed 4 HP loss against Armor 1; playing it removed exactly 4 HP, spent one energy, and left armor intact. Reload/Continue on the phone retained that result and both independent defense values. Browser warnings/errors were empty. The v0.4.0 Windows export's version metadata and headless launch also passed. A physical iPhone/Safari device remains unavailable; emulation and native touch coverage do not replace that hardware check.

The same suite separately uses explicit fixtures for rare situations: healing the same reshuffled Mend repeatedly, invalid targeting and insufficient energy, owner-specific knockouts and removal from every pile, empty decks, faction-relative healing, block expiration, poison/burning before regeneration, additive regeneration and decay, stun in both factions, locked intentions and dead-target rotation, all six evolved innate passives, feeding/evolving a knocked-out recipient, declined eligible branches, one transformation per feeding decision, restoration of the owner's cards in the next raid, four breaches ending the run, and recovery exactly once.

Save checks include continuing an active battle with its hand, piles, energy, turn, statuses, intentions and RNG state intact; a partly consumed feeding screen with unchanged bodies and claim flags; and both victorious and breached results without duplicated recovery. New profiles have no discoveries; eligibility alone reveals no grimoire entry; performed evolutions persist across a new run. JSON numeric comparisons normalize the format's float decoding while still comparing every saved field.

Tests use freshly named `user://verification/` subdirectories. They do not reset or write the normal player's run or grimoire.

## Turn flow and action clarity

```sh
godot --headless --path . --script tests/flow_smoke.gd
godot --path . --script tests/flow_smoke.gd
```

The final v0.3.1 flow run passes **1,983 headless assertions** and **2,007 native assertions**, with **24 native screenshots**, zero issues, and no engine/script errors. The suite compares the isolated replay with the ordinary battle simulation, including RNG state and every combat field. Fixtures exercise monster effects before invaders, invader effects after actions, stunned and defeated actors, knockout retargeting, empty decks, and terminal victory/breach snapshots. It verifies that ending a turn commits and saves exactly once before playback; repeated End turn, Space and stale card/target callbacks cannot resolve it again. Reload during playback restores the committed result, while Skip cancels only presentation. Resizing preserves the live result and the visible action sequence. Breach frames show knockout before exactly-once recovery, and victory transitions to actual feeding rewards.

Read-only intent and card queries cover numeric damage, block absorption, evasion, capped healing, enemy support recipients, shared/owned cards, and unavailable reasons without consuming RNG or mutating combat. Native captures show the player turn, faction effects, precise acting invader/recipient, actual HP/block changes, drawing, and the next player turn at desktop and portrait phone dimensions. The CI runs the headless flow suite on each push alongside gameplay and responsive layout checks.

Pixel review confirms all three default desktop monsters are visible on the battlefield, and narrow `375×667` phone guidance shows the owner, action, cost, target instruction and numeric effect without internal scrolling. Invader intentions remain visible alongside selected-card previews. Long actor descriptions and temporary action callouts fit their panels or clipped scroll regions. Turn captures are saved in ignored `tests/artifacts/flow/`.

The final browser build was played at `390×844` and `844×390`, both at a 3× device-pixel ratio. Checks covered readable numeric intentions, card-owner and healing-target guidance, immediate card results, the visible handoff, rotation with a selected card followed by playing it, and reload during the enemy sequence. Continue restored the committed next round with its knockout, remaining HP, hand, energy and new intentions. The browser reported no warnings or errors. Missing arrow glyphs discovered during browser inspection were replaced with readable words.

## Illustrated cards, battlefield and motion

```sh
godot --headless --path . --script tests/art_smoke.gd
godot --path . --script tests/art_smoke.gd
```

The final v0.3.1 art suite passes **4,480 assertions in each mode**, with **49 headless layouts or native screenshots** and zero issues. Sizes are `1280×720`, `1920×1080`, `1920×900`, tablet `1024×768`, smaller landscape window `1050×640`, phones `390×844` and `375×667`, and short landscape `844×320`. Captures are in ignored `tests/artifacts/art/<width>x<height>/`. The short-landscape hand is explicitly scrolled into view for review of its art strip, numeric effects and disabled badges. Linux CI caught an initial container allocation feedback loop that could enlarge the stage minimum before card faces finished layout. The corrected holder keeps a fixed 140-pixel minimum and sizes its stage within allocated space. A regression resizes 1280×720 to 1920×1080 and back, verifies stable minimum and geometry after deferred card layout, checks fully visible cards and the end-turn action, and preserves combat and RNG.

Checks verify real loaded card textures, visible owner/cost/title/numeric-effect labels, label containment in every card, selected and disabled faces, and normal availability rules. A real card from the ordinary seeded raid is selected and played through its actual target control: the result commits immediately and matches the ordinary simulation exactly, including every combat field and RNG. Hover preserves the card's target rectangle; hover, idle and action animations preserve combat and RNG. Explicit catalog fixtures cover long multi-effect cards, selected Regrowth with stacked statuses, area targets, and all six evolved creature forms; these fixtures do not earn discoveries or substitute for the real-card campaign.

Desktop and tablet checks cover all six full-body creatures and readable numerical intentions, every unit label staying within its control and viewport, and a minimum creature drawing-control height of 60 logical pixels even with selection/status rows. Native pixel review covers baseline and selected lineups, larger displays, narrow portrait cards, and the short-landscape hand. It detected a Basilisk coil overlapping its form/status caption; the drawing extent was corrected and both lineage captures were reviewed again. Reduced motion keeps idle, lunge and hit-reaction drawing transforms still; enabling motion produces an actual lunge. The production preference is saved and reloaded from an isolated profile, while the separately saved battle and RNG remain unchanged. Reload during presentation and Skip retain the already committed result. All final suite runs exit zero, and their logs contain no engine/script warnings or errors.

The v0.3 web export was played at desktop `1280×720`, phone `390×844` with canvas `1170×2532`, and rotated `844×390` with canvas `2532×1170` (3× device-pixel ratio). Illustrated card owners, costs and numerical effects remained readable. Strike dealt 6 HP immediately, spending one energy and adding one discard. Reload/Continue preserved the battle; selecting Goblin Stab, rotating and playing it dealt 5 HP with another energy/discard update. Ending a turn displayed the faction handoff, and reload during playback restored round two with its remaining HP, fresh hand, energy and intentions. Patch Up healed from 5 to 11 HP and spent one energy. Short landscape scrolling revealed the hand while retaining the fixed footer. The browser reported no warnings or errors.

## Earlier native presentation baseline

For the earlier 15-screen presentation harness, run without `--headless`:

```sh
godot --path . --script tests/visual_smoke.gd
```

This creates **15 screenshots at 1280×720** in the ignored `tests/artifacts/` directory and checks visible buttons and labels against viewport bounds and actor-panel containment. It also checks that no undiscovered form name appears in the initial screens and that a discovered recipe and signature render in the grimoire. Its prior v0.2 run passed with **zero layout/content issues** and no script errors on Godot 4.7 Compatibility/OpenGL; this harness was not rerun for the v0.3 art slice. Current v0.3 evidence comes from the flow, mobile and art suites above. Screens cover title, empty grimoire, preparation, combat, targeting, feeding, evolution reveal, discovered grimoire, raid result, promotion, defeat, evolved combat, a selected area attack, Regrowth targeting, and shared Dungeon Rally targeting. These screenshots render the actual scenes; later-screen UI fixtures complement the mechanically played campaign.

The native checks detected and led to fixes for a discovered-recipe type mismatch, actor status text outside its panel, repeated multi-target previews overflowing rows, and a clipped combat footer. Both native screenshots and simulation checks were rerun after those fixes. Automated checks exit nonzero on failed assertions. Inspect the engine console as well for unexpected script errors when changing presentation code.

The earlier export was also played through browser UI controls: New Run, incoming preview, card selection and legal targets, direct damage/energy/discard updates, repeated healing, area block, poison, evasion, stun, and Space to end turns. The first raid was won with 15 cards over five player turns. An active battle survived Save & title and a browser reload with its existing hand, HP, energy, and locked intentions. The browser playtest consumed all three actual bodies, performed a first evolution, displayed its discovered recipe, selected a newly learned skill, applied recovery, and returned to preparation for the next raid. The browser console reported no warnings or errors. Bundled fonts replaced system fonts to keep browser glyphs and layout consistent with the native screenshot checks.

## Mobile layout and touch verification

```sh
godot --path . --script tests/mobile_smoke.gd
godot --headless --path . --script tests/mobile_smoke.gd
godot --path . --script tests/mobile_smoke.gd -- --touch-only
```

The final v0.3 native mobile run passed **11,857 assertions with zero issues**, producing **135 screenshots**: fifteen phases at each of `375×667`, `390×844`, `430×932`, `844×390`, `844×320`, `756×330`, and desktop `1280×720`, `1920×1080`, `1920×900`. The two shorter landscape dimensions exercise reduced space from browser controls and safe-area margins. Captures use exact logical-size native Godot viewports and are saved in ignored `tests/artifacts/mobile/<width>x<height>/`; the harness creates `.gdignore` so captures are excluded from game imports and exports.

Checks cover every phase, targeted and area cards, long Regrowth text, actual damage/energy changes through the UI, enabled tap targets of at least 44 logical pixels in compact layouts, 44-pixel skill-menu rows, bounded popup dimensions, and feeding/continuation actions fully reachable through scrolling. Intentional scrollable content is distinguished from unintended horizontal or vertical clipping. Rotating preserves the selected card, complete battle state and RNG; rotating an open evolution reveal preserves the modal, run and discovery. The screenshots were visually inspected, including narrow portrait results/promotion, evolved area targeting, short landscape combat with a fixed End Turn button, and desktop results.

Native `Input.parse_input_event` tests inject real `InputEventScreenTouch` press/release and `InputEventScreenDrag` events into the game window with production input settings. The **28 touch assertions pass as part of the final v0.3 native run**: New Run, Defend, illustrated card selection, legal enemy targeting, damage/energy, and End Turn; vertical preparation scrolling; horizontal hand scrolling to the final card using ordinary repeated finger gestures; no accidental card selection on drag release; and selecting and playing the final card reached by that drag. These checks found and led to fixes for touch events consumed before reaching scroll containers and a landscape actor-height feedback loop. The final run was repeated after the fixes.

The headless version passes **11,694 layout/state assertions across 135 views**, skips PNG rendering and native touch injection, and exits nonzero on failure. It is suitable for CI; native touch checks require a graphical Godot run. Mobile browser rendering was also checked with device emulation at a 3× device-pixel ratio. A physical iPhone and Safari were unavailable, so these results establish native touch behavior and emulated mobile browser/layout coverage rather than a hardware Safari playtest.

The previous responsive web export was interacted with at `390×844` and `844×390` with a 3× device-pixel ratio (canvas backing sizes `1170×2532` and `2532×1170`). Browser checks covered New Run, preparation, targeted damage/energy/discard updates, the complete horizontal card hand, automatic friendly-target selection for healing, reload/Continue restoring the existing battle, rotation with a selected card and playing that card afterward, and ending a turn. `844×320` retained the fixed combat footer and scrollable battle body. The browser console contained no warnings or errors. Browser pointer controls and emulated dimensions complement the separate native ScreenTouch/ScreenDrag checks; they do not substitute for an actual Safari device test. The current illustrated v0.3 browser evidence appears in the art section above.
