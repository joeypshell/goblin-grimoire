/* Public publishable key only. Report authorization is enforced by database RLS. */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const config = window.GG_REPORTS_CONFIG || {};
  const base = String(config.supabaseUrl || '').replace(/\/$/, '');
  const key = String(config.publishableKey || '');
  const storageKey = `gg-reviewer-session:${base}`;
  const pageSize = 50;
  let session = null, refreshFlight = null, authGeneration = 0;
  let rows = [], total = 0, selectedId = '', detailGeneration = 0, loading = false;
  let listGeneration = 0, listOffset = 0, moreRows = false;
  let accountMode = 'signin';
  const completed = status => ['victory', 'defeat', 'completed', 'won', 'lost'].includes(status);
  const full = coverage => coverage === 'full';
  const label = value => String(value == null ? 'Unknown' : value).replace(/_/g, ' ').replace(/\b[a-z]/g, letter => letter.toUpperCase());
  const abilityName = value => ({stab:'Goblin Stab',rally:'Dungeon Rally',snare_dungeon:'Dungeon Snare'}[value] || label(value));
  const number = value => Number.isFinite(Number(value)) && value !== null ? Number(value) : null;
  const fmt = value => number(value) === null ? 'Not recorded' : Number(value).toLocaleString();
  const array = value => Array.isArray(value) ? value : [];
  const object = value => value && typeof value === 'object' && !Array.isArray(value) ? value : {};
  const date = value => {
    const stamp = new Date(value);
    return value && Number.isFinite(stamp.getTime()) ? stamp.toLocaleString() : 'Date not recorded';
  };
  function node(tag, text, className = '') {
    const element = document.createElement(tag);
    if (text !== undefined) element.textContent = String(text);
    if (className) element.className = className;
    return element;
  }
  function notice(message, error = false) {
    $('feedback').textContent = message;
    $('feedback').classList.toggle('error', error);
  }
  function showLogin(message = 'Sign in with an approved reviewer account.', error = false) {
    $('login').hidden = false;
    $('dashboard').hidden = true;
    notice(message, error);
  }
  function setAccountMode(mode) {
    accountMode = mode;
    const signup = mode === 'signup';
    $('login-heading').textContent = signup ? 'Create a reviewer account' : 'Open the archive';
    $('login-explanation').textContent = signup ? 'First-time reviewer? Enter the email approved by the project owner and choose your own password.' : 'Sign in with an approved reviewer account. Reports are available only to the project’s reviewers.';
    $('sign-in').textContent = signup ? 'Create account' : 'Sign in';
    $('account-mode').textContent = signup ? 'I already have an account' : 'Create a reviewer account';
    $('confirmation-help').hidden = !signup;
    $('password').autocomplete = signup ? 'new-password' : 'current-password';
    $('password').minLength = signup ? 8 : 1;
    $('password').value = '';
  }
  function clearSession() {
    authGeneration++;
    detailGeneration++;
    listGeneration++;
    loading = false;
    listOffset = 0;
    session = null;
    refreshFlight = null;
    rows = [];
    selectedId = '';
    $('report-list').replaceChildren();
    $('report-content').replaceChildren();
    $('report-content').hidden = true;
    $('detail-empty').hidden = false;
    $('report-detail').removeAttribute('aria-busy');
    $('report-detail').setAttribute('aria-labelledby','detail-placeholder');
    $('detail-empty').querySelector('h2').id = 'detail-placeholder';
    try { sessionStorage.removeItem(storageKey); } catch (_) { /* memory-only session */ }
  }
  function saveSession(data, generation) {
    if (generation !== authGeneration) throw new Error('This reviewer session has ended.');
    if (!data.access_token || !data.refresh_token) throw new Error('The sign-in response was incomplete.');
    session = {access_token:data.access_token, refresh_token:data.refresh_token,
      expires_at:Number(data.expires_at) || Math.floor(Date.now() / 1000) + Number(data.expires_in || 3600)};
    try { sessionStorage.setItem(storageKey, JSON.stringify(session)); } catch (_) { /* current tab memory still works */ }
  }
  async function raw(path, options = {}) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 20000);
    try {
      const response = await fetch(base + path, {...options, credentials:'omit', cache:'no-store',
        signal:controller.signal, headers:{apikey:key, 'Content-Type':'application/json', ...options.headers}});
      let body = null;
      try { body = await response.json(); } catch (_) { /* empty/non-JSON error handled by status */ }
      return {response, body};
    } catch (error) {
      throw new Error(error.name === 'AbortError' ? 'The request timed out. Try Refresh reports.' : 'Cannot reach the report service. Check your connection and try again.');
    } finally { clearTimeout(timer); }
  }
  async function accessToken(force = false) {
    if (!session) throw new Error('Sign in to read the report archive.');
    if (!force && session.expires_at * 1000 > Date.now() + 90000) return session.access_token;
    if (!refreshFlight) {
      const generation = authGeneration;
      const token = session.refresh_token;
      refreshFlight = (async () => {
        const result = await raw('/auth/v1/token?grant_type=refresh_token', {method:'POST', body:JSON.stringify({refresh_token:token})});
        if (!result.response.ok) {
          if (generation === authGeneration && [400,401,403].includes(result.response.status)) {
            clearSession();
            showLogin('Your reviewer session has expired. Sign in again.', true);
          }
          throw new Error('Unable to renew your reviewer session. Sign in again or retry shortly.');
        }
        saveSession(result.body || {}, generation);
        return session.access_token;
      })().finally(() => { if (generation === authGeneration) refreshFlight = null; });
    }
    return refreshFlight;
  }
  async function read(path, retry = true) {
    const generation = authGeneration;
    const token = await accessToken();
    const result = await raw('/rest/v1/' + path, {headers:{Authorization:`Bearer ${token}`, Prefer:'count=exact'}});
    if (generation !== authGeneration) throw new Error('This reviewer session has ended.');
    if (result.response.status === 401 && retry) {
      await accessToken(true);
      return read(path, false);
    }
    if (!result.response.ok) {
      if (result.response.status === 401) { clearSession(); showLogin('Your reviewer session has expired. Sign in again.', true); }
      throw new Error([401,403].includes(result.response.status) ? 'This account cannot read playtest reports. Ask the project owner to approve reviewer access.' : `Reports could not load (HTTP ${result.response.status}). Try Refresh reports.`);
    }
    return result;
  }
  async function signIn(event) {
    event.preventDefault();
    const generation = ++authGeneration;
    const button = $('sign-in');
    button.disabled = true;
    $('account-mode').disabled = true;
    $('login-form').setAttribute('aria-busy', 'true');
    const signup = accountMode === 'signup';
    notice(signup ? 'Creating your reviewer account…' : 'Signing in…');
    try {
      const result = await raw(signup ? '/auth/v1/signup' : '/auth/v1/token?grant_type=password', {method:'POST',
        body:JSON.stringify({email:$('email').value.trim(), password:$('password').value})});
      if (!result.response.ok) throw new Error(result.response.status === 429 ? 'Too many account requests. Wait a moment and try again.' : signup ? 'Account creation failed. Use a valid email and a password of at least 8 characters, or sign in if you already have an account.' : 'Sign-in failed. Check your email and password, then try again.');
      if (signup && !result.body?.access_token) {
        setAccountMode('signin');
        showLogin('Check your email for a confirmation message. After confirming, return to this dashboard and sign in. Report access requires the owner’s approved email list.');
        return;
      }
      saveSession(result.body || {}, generation);
      await loadRows(true);
    } catch (error) {
      if (generation === authGeneration) {
        if ($('dashboard').hidden) showLogin(error.message,true);
        else notice(error.message,true);
      }
    }
    finally { $('password').value = ''; button.disabled = false; $('account-mode').disabled = false; $('login-form').removeAttribute('aria-busy'); }
  }
  async function signOut() {
    const token = session?.access_token;
    clearSession();
    showLogin('Signed out. This tab’s saved reviewer session has been cleared.');
    if (token) {
      try { await raw('/auth/v1/logout?scope=local', {method:'POST', headers:{Authorization:`Bearer ${token}`}}); }
      catch (_) { /* local token is removed even when offline */ }
    }
  }
  async function loadRows(reset = false) {
    if (loading) return;
    loading = true;
    const generation = authGeneration;
    const request = ++listGeneration;
    $('refresh').disabled = true;
    $('load-more').disabled = true;
    notice('Reading latest run snapshots…');
    try {
      const offset = reset ? 0 : listOffset;
      const columns = 'id,revision,build,status,seed,coverage,started_at,updated_at,received_at';
      const result = await read(`gg_run_reports?select=${columns}&order=received_at.desc,id.desc&limit=${pageSize}&offset=${offset}`);
      if (generation !== authGeneration || request !== listGeneration) return;
      const next = array(result.body);
      const merged = new Map((reset ? [] : rows).map(row=>[row.id,row]));
      for (const row of next) {
        if (!merged.has(row.id) || Number(row.revision) >= Number(merged.get(row.id).revision)) merged.set(row.id,row);
      }
      rows = Array.from(merged.values());
      listOffset = offset + next.length;
      const range = result.response.headers.get('Content-Range') || '';
      const rangeTotal = Number(range.split('/')[1]);
      total = Number.isFinite(rangeTotal) ? rangeTotal : rows.length;
      moreRows = next.length >= pageSize && listOffset < total;
      $('login').hidden = true;
      $('dashboard').hidden = false;
      renderList();
      notice(`Loaded ${rows.length} of ${total} run snapshots. Each run appears once at its latest received revision. Refresh if the archive changes while paging.`);
      if (selectedId && rows.some(row => row.id === selectedId)) await selectReport(selectedId, false);
      else if (selectedId && reset) {
        selectedId = ''; $('report-content').hidden = true; $('detail-empty').hidden = false;
        $('report-detail').setAttribute('aria-labelledby','detail-placeholder'); renderList();
      }
    } catch (error) {
      if (generation === authGeneration && request === listGeneration) {
        if ($('dashboard').hidden) showLogin(error.message,true);
        else notice(error.message,true);
      }
    }
    finally {
      if (request === listGeneration) { loading = false; $('refresh').disabled = false; $('load-more').disabled = false; }
    }
  }
  function renderList() {
    $('loaded-count').textContent = `${rows.length} loaded`;
    $('archive-status').textContent = `${total.toLocaleString()} runs in archive · counts below use loaded reports`;
    const stats = [['Completed', rows.filter(row => completed(row.status)).length],
      ['Active', rows.filter(row => row.status === 'active').length],
      ['Full coverage', rows.filter(row => full(row.coverage)).length],
      ['Partial coverage', rows.filter(row => !full(row.coverage)).length]];
    $('metrics').replaceChildren(...stats.map(([name,value]) => {
      const item = node('div', undefined, 'metric'); item.append(node('strong',value), node('span',`${name} · loaded`)); return item;
    }));
    const filter = $('status-filter').value;
    const visible = rows.filter(row => filter === 'all' || (filter === 'completed' ? completed(row.status) : row.status === filter));
    $('report-list').replaceChildren(...visible.map(row => {
      const button = node('button', undefined, 'run-button'); button.type = 'button';
      button.setAttribute('aria-current', String(row.id === selectedId));
      button.append(node('strong', `${label(row.status)} · Seed ${row.seed}`),
        node('span', `${row.build || 'Build not recorded'} · ${full(row.coverage) ? 'Full coverage' : 'Partial coverage'}`),
        node('span', date(row.updated_at)));
      button.addEventListener('click', () => selectReport(row.id)); return button;
    }));
    $('empty-list').hidden = visible.length > 0;
    $('empty-list').textContent = rows.length ? 'No loaded reports match this status. Try All statuses or load more runs.' : 'No reports have arrived yet, or this account has no reviewer access. Automatic collection sends the latest run snapshot; ask the owner to confirm access if a report is expected.';
    $('load-more').hidden = !moreRows;
  }
  async function selectReport(id, moveFocus = true) {
    selectedId = id;
    const generation = ++detailGeneration;
    const authentication = authGeneration;
    renderList();
    $('detail-empty').hidden = true;
    $('report-content').hidden = false;
    $('report-content').replaceChildren(node('p', 'Reading this run…', 'muted'));
    $('report-detail').setAttribute('aria-busy','true');
    if (moveFocus && matchMedia('(max-width:760px)').matches) {
      $('report-detail').scrollIntoView({block:'start'}); $('report-detail').focus({preventScroll:true});
    }
    try {
      const result = await read(`gg_run_reports?select=*&id=eq.${encodeURIComponent(id)}&limit=1`);
      if (generation !== detailGeneration || authentication !== authGeneration) return;
      if (!array(result.body).length) throw new Error('This report is unavailable to the current reviewer.');
      renderReport(result.body[0]);
      if (moveFocus && matchMedia('(max-width:760px)').matches) $('report-detail').scrollIntoView({block:'start'});
    } catch (error) {
      if (generation === detailGeneration && authentication === authGeneration) $('report-content').replaceChildren(node('p',error.message,'notice error'));
    } finally { if (generation === detailGeneration) $('report-detail').removeAttribute('aria-busy'); }
  }
  function section(parent, title) {
    const part = node('section', undefined, 'report-section'); part.append(node('h3',title)); parent.append(part); return part;
  }
  function stat(parent, title, value) {
    const item = node('div', undefined, 'data-item'); item.append(node('dt',title), node('dd',value)); parent.append(item);
  }
  function tags(parent, values) {
    const line = node('div', undefined, 'tags');
    for (const value of values) line.append(node('span',label(value),'badge'));
    parent.append(line);
  }
  function download(row) {
    const blob = new Blob([JSON.stringify(row.report, null, 2)], {type:'application/json'});
    const url = URL.createObjectURL(blob), anchor = document.createElement('a');
    anchor.href = url; anchor.download = `goblin-grimoire-${row.id}.json`; anchor.hidden = true;
    document.body.append(anchor); anchor.click(); anchor.remove();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
    notice('Report JSON prepared for download.');
  }
  async function copy(row) {
    try { await navigator.clipboard.writeText(JSON.stringify(row.report,null,2)); notice('Report JSON copied.'); }
    catch (_) { notice('Clipboard access is unavailable. Use Download JSON, or select the text in Raw report JSON.', true); }
  }
  function renderReport(row) {
    const content = $('report-content'); content.replaceChildren();
    const report = object(row.report);
    const heading = node('div',undefined,'section-heading');
    const oldHeading = $('detail-empty').querySelector('h2'); if (oldHeading) oldHeading.id = 'detail-placeholder';
    const title = node('h2',`${label(row.status)} · Seed ${row.seed}`); title.id = 'detail-heading';
    $('report-detail').setAttribute('aria-labelledby','detail-heading');
    const actions = node('div',undefined,'actions');
    for (const [text,callback] of [['Download JSON',()=>download(row)],['Copy JSON',()=>copy(row)]]) {
      const button = node('button',text); button.type='button'; button.addEventListener('click',callback); actions.append(button);
    }
    heading.append(title,actions); content.append(heading);
    content.append(node('p',`${row.build || 'Build not recorded'} · Revision ${fmt(row.revision)} · Updated ${date(row.updated_at)}`,'detail-meta'));
    content.append(node('p',full(row.coverage) ? 'Full coverage from the start of this run. Client actions are observational and may be incomplete if collection stopped.' : 'Partial coverage: this run began before reporting was available. Its earlier actions and totals are not reconstructed; comparisons use only the recorded interval.',`coverage${full(row.coverage)?'':' partial'}`));
    if (Number(report.dropped_events) > 0 || Number(report.dropped_attempts) > 0) content.append(node('p',`${fmt(report.dropped_events || 0)} older timeline entries and ${fmt(report.dropped_attempts || 0)} older attempt details were trimmed for storage. Cumulative recorded totals remain available.`, 'coverage partial'));
    renderReportBody(content, report);
    const rawDetail = node('details'), summary = node('summary','Raw report JSON');
    rawDetail.append(summary,node('pre',JSON.stringify(report,null,2))); content.append(rawDetail);
    content.append(node('p',`Started ${date(row.started_at)} · Received ${date(row.received_at)} · Report ${row.id}`,'small muted'));
  }
  function renderReportBody(content, report) {
    // The report recorder supplies these fields; rendering never derives gameplay events.
    const summary = object(report.summary), current = object(summary.current);
    const totals = section(content,'Recorded totals');
    const grid = node('dl',undefined,'detail-grid'); content.append(grid);
    totals.append(grid);
    const recordedTotals = [['Raids won',summary.raids_won],['Cards played',summary.cards_played],['Turns ended',summary.turns_ended],['Unused energy',summary.unused_energy],['Breaches',summary.breaches],['Energy spent',summary.energy_spent],['Bodies devoured',summary.bodies_claimed],['Evolutions',summary.evolutions]];
    if (Object.prototype.hasOwnProperty.call(current,'core')) recordedTotals.push(['Legacy core HP',current.core]);
    for (const [name,value] of recordedTotals) stat(grid,name,fmt(value));
    totals.append(node('p','Unused energy is summed when a player ends their turn; it excludes energy left when a raid ends immediately. Partial reports count only observed actions.','small muted'));
    const traits = section(content,'Dungeon traits');
    tags(traits,array(current.traits));
    const activations = Object.entries(object(summary.trait_triggers)).map(([name,count])=>`${label(name)}: ${fmt(count)} activations`);
    traits.append(node('p',activations.join(' · ') || 'No trait activations recorded.','small muted'));
    const raids = section(content,'Raid results');
    const raidList = node('ul',undefined,'compact-list'); raids.append(raidList);
    for (const raid of array(summary.attempts)) {
      const item = node('li'); item.append(node('strong',`Raid ${Number(raid.raid) + 1} · Attempt ${fmt(raid.id)} · ${label(raid.result)}`));
      item.append(node('p',`${fmt(raid.turns_ended)} turns ended · ${fmt(raid.cards_played)} cards · ${fmt(raid.energy_spent)} energy spent · ${fmt(raid.unused_energy)} unused energy`));
      if (!full(raid.coverage)) item.append(node('p','Partial attempt: observation began after the raid started.'));
      const party = array(object(raid.end || raid.start).monsters);
      item.append(node('p',party.map(actor=>`${actor.name || actor.id}: ${fmt(actor.hp)}/${fmt(actor.max_hp)} HP`).join(' · ')));
      const triggers = Object.entries(object(raid.trait_triggers)).map(([name,count])=>`${label(name)} ×${fmt(count)}`);
      if (triggers.length) item.append(node('p',triggers.join(' · '))); raidList.append(item);
    }
    if (!raidList.children.length) raids.append(node('p','No raid result is recorded yet.','muted'));
    renderDeck(content,current);
    renderCardUse(content,summary,current);
    renderTimeline(content,array(report.events),current);
  }
  function renderDeck(content, current) {
    const cards = array(current.deck);
    const part = section(content,'Latest recorded deck'), list = node('ul',undefined,'compact-list'); part.append(list);
    for (const card of cards) {
      const item = node('li'); item.append(node('strong',card.name || abilityName(card.ability)),node('p',`${card.owner_name || actorName(current,card.owner)} · ${fmt(card.cost)} energy`)); list.append(item);
    }
    if (!cards.length) {
      part.append(node('p','Full card composition is not recorded in this older snapshot. Equipped skills shown below are the latest observed loadout.','small muted'));
      for (const actor of array(current.monsters)) {
        const item = node('li'); item.append(node('strong',`${actor.name || actor.id} · ${label(actor.form)}`),node('p',`Equipped: ${array(actor.selected).map(abilityName).join(', ') || 'Not recorded'}`)); list.append(item);
      }
    }
  }
  function renderCardUse(content, summary, current) {
    const part = section(content,'Recorded card use'), list = node('ul',undefined,'compact-list'); part.append(list);
    const use = object(summary.cards_by_ability);
    for (const [name,count] of Object.entries(use).sort((a,b)=>Number(b[1])-Number(a[1]))) {
      const item = node('li'); item.append(node('strong',`${abilityName(name)} · ${fmt(count)} plays`)); list.append(item);
    }
    if (!list.children.length) part.append(node('p','No card plays are recorded yet.','muted'));
    const owners = Object.entries(object(summary.cards_by_owner)).map(([id,count])=>`${actorName(current,id)}: ${fmt(count)} plays`);
    if (owners.length) part.append(node('p',owners.join(' · '),'small muted'));
  }
  function actorName(snapshot, id) {
    const actor = array(snapshot.monsters).concat(array(snapshot.enemies)).find(entry=>entry.id === id);
    return actor?.name || (id ? label(id) : 'Dungeon');
  }
  function eventText(entry, current) {
    const data = object(entry.data), before = object(data.before), card = object(data.card);
    const recipient = data.recipient || data.monster || data.monster_id;
    switch (entry.kind) {
      case 'run_started': return 'A new run began.';
      case 'collection_started': return 'Observation began on an existing save; earlier play is not reconstructed.';
      case 'raid_started': return `Raid attempt ${fmt(data.attempt)} began${data.partial_start ? ' with partial coverage' : ''}.`;
      case 'card_played': return `${data.owner_name || actorName(before,card.owner)} played ${abilityName(card.ability)} for ${fmt(data.cost)} energy on ${array(data.targets).map(id=>actorName(before,id)).join(', ') || 'the announced targets'}.`;
      case 'turn_ended': return `Round ${fmt(before.turn)}: End Turn resolved with ${fmt(before.energy)} unused energy. See combat context for the announced intentions and results.`;
      case 'raid_resolved': return `Raid attempt ${fmt(data.attempt)} ended: ${label(data.outcome)}.`;
      case 'selection_changed': return `${actorName(current,recipient)} equipped ${abilityName(data.to)} in skill slot ${Number(data.slot) + 1}, replacing ${abilityName(data.from)}.`;
      case 'body_claimed': return `${actorName(current,recipient)} devoured ${object(data.body).name || 'a fallen invader'} and inherited ${abilityName(data.taken)}.`;
      case 'body_skipped': return `${object(data.body).name || 'A fallen body'} was skipped.`;
      case 'evolved': return `${actorName(current,recipient)} evolved from ${label(data.from)} to ${label(data.to)}.`;
      case 'recovered': return 'The team recovered after the raid.';
      case 'trait_chosen': return `${label(data.trait)} was chosen at milestone ${fmt(data.milestone)}.`;
      case 'feeding_finished': return `Feeding finished${data.promotion ? `; promoted to rank ${data.promotion}` : ''}.`;
      case 'preparation_entered': return 'Returned to preparation for the next raid.';
      case 'phase_changed': return `Next phase: ${label(data.to)}.`;
      case 'run_ended': return `Run ended: ${label(data.status)}${data.reason === 'new_run' ? ' because a new run was started' : ''}.`;
      default: return label(entry.kind);
    }
  }
  function renderTimeline(content, events, current) {
    const part = section(content,'Recorded timeline'), list = node('ol',undefined,'timeline'); part.append(list);
    for (const entry of events.slice().sort((a,b)=>Number(a.seq)-Number(b.seq))) {
      const location = entry.phase === 'victory' ? 'Campaign complete' : `Raid ${Number(entry.raid) + 1}`;
      const item = node('li'); item.append(node('span',eventText(entry,current)),
        node('span',`#${entry.seq} · ${location} · ${label(entry.phase)} · ${date(entry.at)}`,'event-meta'));
      const data = object(entry.data), logs = array(data.recent_log), intents = array(object(data.before).intents);
      if (logs.length || (entry.kind === 'turn_ended' && intents.length)) {
        const details = node('details'); details.append(node('summary','Combat context'));
        const context = [];
        if (entry.kind === 'turn_ended') context.push(...intents.map(intent=>`Announced: ${intent.text || abilityName(intent.ability)}`));
        if (logs.length) context.push('This action’s combat log:',...logs);
        details.append(node('pre',context.join('\n'))); item.append(details);
      }
      list.append(item);
    }
    if (!events.length) part.append(node('p','No timeline entries are recorded yet.','muted'));
  }
  $('login-form').addEventListener('submit',signIn);
  $('account-mode').addEventListener('click',()=>setAccountMode(accountMode === 'signup' ? 'signin' : 'signup'));
  $('sign-out').addEventListener('click',signOut);
  $('refresh').addEventListener('click',()=>loadRows(true));
  $('load-more').addEventListener('click',()=>loadRows(false));
  $('status-filter').addEventListener('change',renderList);
  if (!/^https:\/\//.test(base) || !key.startsWith('sb_publishable_')) {
    notice('Report service is not configured. The project owner must provide its public dashboard configuration.',true);
    return;
  }
  try { session = object(JSON.parse(sessionStorage.getItem(storageKey) || 'null')); }
  catch (_) { session = null; }
  if (!session?.access_token || !session?.refresh_token) { session = null; showLogin(); }
  else loadRows(true);
})();
