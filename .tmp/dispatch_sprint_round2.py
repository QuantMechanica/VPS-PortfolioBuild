"""Dispatch round-2 sprint: 6 issues + Gmail activation + daily routine + QUA-807 escalation.
Standalone script to avoid bash heredoc quote-escape mess.
"""
import sys, urllib.request, urllib.error, json
sys.stdout.reconfigure(encoding='utf-8')

API = 'http://127.0.0.1:3100/api'
COMPANY = '03d4dcc8-4cea-4133-9f68-90c0d99628fb'
GOAL = '4662e91e-8e9b-458e-9383-b1f67751965b'

AGENTS = {
    'Research':     '7aef7a17-d010-4f6e-a198-4a8dc5deb40d',
    'QB':           '0ab3d743-e3fb-44e5-8d35-c05d0d78715d',
    'QT':           'c1f90ba8-d637-46d9-8895-ead705bb4933',
    'DocKM':        '8c85f83f-db7e-4414-8b85-aa558987a13e',
    'CEO':          '7795b4b0-8ecd-46da-ab22-06def7c8fa2d',
    'CTO':          '241ccf3c-ab68-40d6-b8eb-e03917795878',
}

# Resolve Gmail-Monitor full UUID
agents_list = json.load(urllib.request.urlopen(f'{API}/companies/{COMPANY}/agents'))
agents_list = agents_list if isinstance(agents_list, list) else agents_list.get('data', [])
GMAIL_ID = next((a['id'] for a in agents_list if (a.get('id') or '').startswith('6dcf0a42')), None)
print(f'Resolved Gmail-Monitor: {GMAIL_ID}')

def post(path, body):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode('utf-8'),
                                  headers={'Content-Type': 'application/json'}, method='POST')
    try:
        return json.loads(urllib.request.urlopen(req).read()), None
    except urllib.error.HTTPError as e:
        return None, f'HTTP {e.status}: {e.read().decode()[:200]}'

def patch(path, body):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode('utf-8'),
                                  headers={'Content-Type': 'application/json'}, method='PATCH')
    try:
        return json.loads(urllib.request.urlopen(req).read()), None
    except urllib.error.HTTPError as e:
        return None, f'HTTP {e.status}: {e.read().decode()[:200]}'

def make_issue(title, short_desc, assignee, full_body, priority='high'):
    data, err = post(f'/companies/{COMPANY}/issues', {
        'title': title, 'description': short_desc, 'priority': priority,
        'assigneeAgentId': assignee, 'goalId': GOAL, 'createdByUserId': 'local-board',
    })
    if err:
        return None, err
    iid = data['id']
    ident = data['identifier']
    patch(f'/issues/{iid}', {'status': 'todo'})
    cdata, cerr = post(f'/issues/{iid}/comments', {'body': full_body})
    return ident, cerr

# Bodies stored as plain strings (no f-string interpolation needed)
BODY_A = """## Aufgabe
Erweitere die Strategy Card Pipeline um 10-15 neue G0-Karten waehrend Codex throttled ist (Codex weekly bei 90%, Reset 2026-05-14). Anthropic Subscription hat Luft (week 51%, Sonnet 33%, Opus 4.7 fuer dich verfuegbar).

## Was zu tun
1. Weiter mit SRC04 Chan-Extraktion wo offen (QUA-352 / Memory project_qb_reputable_source_binding)
2. Neue SRC-Chains anstossen wenn SRC04 ausgeschoepft - SRC05/06 Bookkeeping, mechanische Trading-Buecher, Conference-Papers, Fundpicker-Studien
3. Pro Karte: Strategy-Card-Schema (siehe processes/13-strategy-research.md), R1-R4 Reputable-Source-Attribution dokumentiert (binding per memory project_qb_reputable_source_binding.md), Hard-Rule-Filter angewendet
4. Output: mindestens 10 neue Karten mit voller Schema-Compliance, ready fuer QB G1 Review

## Anti-Patterns (DL-046)
- Keine "still working" Liveness-Comments
- Wenn blocked (Quelle nicht erreichbar) -> comment with reason, status=blocked, weiter zur naechsten Quelle
- Wake-Condition Memory project_qm_research_wake_condition ist temporaer override durch OWNER expliziten Auftrag

## Acceptance
- mindestens 10 neue Karten committed in framework/EAs/<ID>/CHECKLIST.md oder processes/strategy_cards/
- Jede mit Source-Provenance + R1-R4 Verdict-Vorbereitung
- Comment mit Karten-Liste auf diesem Issue + Status PATCH zu in_review

## Pfade
- processes/13-strategy-research.md
- processes/qb_reputable_source_criteria.md
- framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/ - Beispiel
"""

BODY_B = """## Aufgabe
G1 Verdicts auf alle pending Strategy Cards. R1-R4 Reputable-Source-Check ist binding per memory project_qb_reputable_source_binding.md (processes/qb_reputable_source_criteria.md).

## Was zu tun
1. Liste alle Karten ohne G1-Verdict (Status g1_pending oder ohne Decision)
2. Pro Karte: R1 (Source-Quality), R2 (Author-Reputation), R3 (Replicability), R4 (No-snake-oil) durchgehen
3. Verdict: APPROVED / REJECTED / NEEDS_REVISION mit Begruendung
4. APPROVED -> Karte ist ready fuer CTO/Development build
5. Wenn Research weitere Karten extrahiert (paralleles Issue), QB darauf reagieren

## Acceptance
- Alle pending Karten haben Verdict (mindestens N=10 wenn moeglich)
- APPROVED-Liste committed nach processes/strategy_cards/g1_approved_<date>.md oder analog
- Comment mit Verdict-Tabelle auf diesem Issue + Status PATCH zu in_review

## Pfade
- processes/qb_reputable_source_criteria.md
- framework/EAs/<ID>/REVIEW_INPUT.json - typische Karte
"""

BODY_C = """## Aufgabe
QM5_1003 P3 FAIL Hypothesen-Test: H2 (P2 baseline zu marginal). PHASE_STATE.md und QUA-902 listen 4 Hypothesen, H2 ist die testbare ohne neue Backtests:
- AUDCHF.DWX P2 PF=0.65
- EURNZD.DWX P2 PF=0.35

Wenn P2 baseline geometrisch nicht-profitabel ist, kann kein Sweep-Parameter es retten. Verdict: kill EA, gib Phase 3 frei fuer naechste Karte.

## Was zu tun
1. Lies D:/QM/reports/pipeline/QM5_1003/P2/report.csv - extrahiere PF, Sharpe, MaxDD, gross_pl pro Symbol
2. Lies D:/QM/reports/pipeline/QM5_1003/P3/report.csv und ggf. summary.json - verifiziere 0/82 Quote
3. Berechne: hat irgendein Sweep-Parameter PF >1.0 erreicht? Sharpe-Distribution? Statistische Power?
4. Verdict:
   - H2 dominant = P2 baseline durchweg negativ-erwartungswert -> kill QM5_1003, blockedByIssueIds setzen + naechste Card aktivieren
   - H1/H3 dominant = Sweep-Grid zu eng oder Timeframe-Mismatch -> re-spec recommendation an CTO
   - H4 = Datenqualitaet -> eskalation an QB/Data-Integrity
5. Output: docs/ops/QUA-902_H2_VERDICT_2026-05-09.md mit Daten, Methodik, Verdict

## Acceptance
- Verdict-Dokument committed
- Comment auf QUA-902 + dieses Issue mit Tabelle (PF/Sharpe pro Symbol pro Sweep-Slice) + Verdict
- Status PATCH zu done (oder in_review wenn Verdict OWNER-Eskalation braucht)

## Pfade
- D:/QM/reports/pipeline/QM5_1003/ - komplette Run-Daten
- framework/scripts/dl054_gates.py - gate library wiederverwendbar
- paperclip/governance/PHASE_STATE.md fuer Hypothesen H1-H4 Beschreibung
"""

BODY_D = """## Aufgabe
Drei neue Patterns aus dem QUA-1024 Sprint sind operational eingepraegt aber nicht in Vault/Notion gespiegelt. Plus weitere Doku-Schulden aus den letzten 2 Stunden.

## Was zu tun
1. Lessons-Learned Doc: docs/ops/LESSONS_LEARNED_QUA-1024_SPRINT_2026-05-09.md mit:
   - Continuation-runaway pattern - heartbeat.ts:3155+ Bug, Fix in QUA-1031, throttle alleine wirkt nicht (Memory feedback_continuation_runaway_only_patchable)
   - Subscription billing model - spentMonthlyCents=0 ist Design (heartbeat.ts:1038-1039); echte Quelle ist /api/companies/.../costs/quota-windows
   - /budgets/policies vs Quota-Windows - Hard-caps in Cents feuern bei Subscription nie
   - DL-046 enforcement - QUA-671 hatte 2069 WAIT_GUARD-JSONs, Sprint hat das gestoppt
2. DL-046 Update: wenn noetig decisions/DL-046_meta_work_purge_qua641.md mit konkreten Code-Hooks erweitern
3. EA-source-hygiene Policy: docs/ops/EA_SOURCE_DIR_HYGIENE.md (fuer QUA-1027) - framework/EAs/*/QUA-* darf nicht; .gitignore-Snippet, lint-Hook-Vorschlag
4. Vault/Notion mirror: wenn Doc-KM Routine aktiv ist, neue DLs propagieren

## Acceptance
- Drei neue Docs committed
- Comment auf diesem Issue mit Liste der neuen + updated Files
- Status PATCH zu in_review (CEO/Board-Advisor ratifizieren)

## Pfade
- Memory: feedback_continuation_runaway_only_patchable, feedback_subscription_billing_zero_cents_by_design, reference_paperclip_quota_windows_api
- Sprint: QUA-1024 (done)
- DLs: DL-046, DL-053, DL-055, DL-057
"""

BODY_E = """## Aufgabe
Zwei strategische Themen waehrend Codex throttled ist:

### Teil 1: Phase 4 Vorbereitung
Phase 4 (V5 Portfolio Build) ist next laut PHASE_STATE.md. Sobald Phase 3 schliesst, starten wir Phase 4.

Plan zu liefern:
- Welche 5+ EAs fuer ersten Portfolio-Basket? Kriterien: niedrige Korrelation, verschiedene Lanes (Trend/MR/Carry), DL-054 PASS auf P2-P5
- Magic-Number-Strategie fuer Portfolio (Memory: ea_id*10000+slot)
- Risiko-Allokation pro EA im Basket
- T6 Demo-Sequenz vor LiveOps Phase 5

### Teil 2: Subscription-Guardian-Spec ratifizieren
Board Advisor hat 2026-05-09T07:51Z CTOs urspruenglichen /budgets/policies Ansatz rejected (greift bei subscription_included nicht), Redirect-Spec auf QUA-1032 gepostet. CTO baut neu wenn Codex zurueck.

Aufgabe fuer CEO:
- Spec auf QUA-1032 (Comment 07:53Z + 08:19Z) durchlesen
- Threshold-Tabelle ratifizieren oder anpassen (Codex 5h: 75/85/95, weekly: 75/80/90 mit Reset-Awareness, Anthropic Subscription-Week: 80/90/95)
- Approve oder modifizieren via Comment auf QUA-1032

## Acceptance
- Phase 4 Plan committed nach decisions/PHASE_4_PORTFOLIO_PLAN_2026-05-09.md
- Subscription-Guardian-Spec ratified via Comment auf QUA-1032
- Status PATCH zu in_review fuer OWNER-Acceptance auf Plan

## Pfade
- paperclip/governance/PHASE_STATE.md - current phase pointer
- QUA-1032 - Subscription-Guardian-Spec
- Memory: reference_paperclip_quota_windows_api
"""

BODY_F = """## Aufgabe
Drei Phase-Runner sind nach wie vor seriell trotz QUA-901 / QUA-1026 Doctrine. Bei der naechsten Phase-3-Card und in Phase 4 ist das ein 5x-Slowdown.

## Was zu tun
1. framework/scripts/p5_stress_driver.py:64,121-147 - aktuell subprocess.run (blocking, 1200s timeout) fuer clean+stress smoke. Migrate auf Popen-Pool wie p2_matrix_launcher.py:130-139.
2. framework/scripts/p6_multiseed_driver.py:110-126 - aktuell for seed in seeds: subprocess.run(...). Migrate auf parallel Popen ueber T1..T5 mit Round-Robin.
3. framework/scripts/p2_baseline.py:35,435-447 - from concurrent.futures import ThreadPoolExecutor (dead import) + for symbol in symbols: serial loop. Entweder ThreadPoolExecutor aktivieren oder analog matrix_launcher refactoring.

## Pattern (Vorlage)
Aus p2_matrix_launcher.py:130-139 (funktioniert):
- running = {} dict tracking active subprocess per terminal
- for terminal in cycle(['T1','T2','T3','T4','T5'])
- if len(running) >= max_per_terminal: poll for free slot
- proc = subprocess.Popen([...], creationflags=DETACHED_PROCESS)
- running[terminal] = proc

Plus: --max-parallel N CLI-Flag wie in p3_param_sweep.py.

## Acceptance
- Drei drivers haben --max-parallel Flag (default 5)
- Smoke-Test: jeder driver laeuft auf 1 EA x 5 Symbolen mit timing-spread <60s zwischen Subprocess-Starts
- Doctrine-Doc updated falls vorhanden, .claude/commands/p5-*.md und p6-*.md korrigiert
- PR/commit + Comment auf diesem Issue mit timing-evidence

## Constraints (DL-054 / Anti-theater)
- Bestehende DL-054 gates muessen funktionieren (dl054_gate_runner.py:106-115)
- Run-Output identisch zu serial (deterministisch); Parallelitaet darf Resultate nicht aendern

## Pfade
- framework/scripts/p2_matrix_launcher.py:130-139 - funktionierender Vorbild
- framework/scripts/p3_param_sweep.py - QUA-1026 Pattern mit Dispatcher-Key
- framework/scripts/run_smoke.ps1:125-133 - bereits gefixt fuer Dispatch-Phase/-Version Override
- Wartet auf Codex-Verfuegbarkeit (weekly bei 90%, Reset 2026-05-14)
"""

# Dispatch all 6 issues
results = []
for label, title, short, agent, body, prio in [
    ('A_Research',  'Research G0 expansion: extract 10-15 new Strategy Cards (Anthropic-only)',
        'OWNER 2026-05-09: Codex throttled until 5/14, use Anthropic Subscription headroom. Continue SRC04 Chan queue (QUA-352) + new SRC chains. Full body in first comment.',
        AGENTS['Research'], BODY_A, 'high'),
    ('B_QB',        'QB G1 verdicts on pending Strategy Cards (Anthropic-only)',
        'Quality-Business: Verdicts auf alle noch offenen G0-Karten (R1-R4 Reputable-Source-Check). Backlog soll vor naechstem Codex-Cycle abgearbeitet sein.',
        AGENTS['QB'], BODY_B, 'high'),
    ('C_QT',        'QT P3 FAIL Triage: Hypothese H2 pruefen (P2 baseline zu marginal QM5_1003)',
        'Quality-Tech: Phase 3 haengt seit Tagen auf QM5_1003 P3 FAIL. H2 = P2 baseline zu marginal. Pure Number-Crunching auf bestehender report.csv. Verdict: kill QM5_1003 oder re-spec.',
        AGENTS['QT'], BODY_C, 'high'),
    ('D_DocKM',     'Doc-KM: QUA-1024 Sprint Lessons-Learned + DL-046/process docs update',
        'Drei neue durable Patterns aus dem Sprint: continuation-runaway, subscription quota windows, P3-dispatch-key-mismatch. Plus DL-046 Update + EA-source-hygiene policy.',
        AGENTS['DocKM'], BODY_D, 'high'),
    ('E_CEO',       'CEO Phase 4 Vorbereitung + Subscription-Guardian-Spec-Ratifikation',
        'Phase 3 in Limbo, Phase 4 muss vorbereitet werden. Plus: CEO ratifiziert die Subscription-Guardian-Spec aus QUA-1032 (Board Advisor hat /budgets-Ansatz rejected).',
        AGENTS['CEO'], BODY_E, 'high'),
    ('F_CTO_par',   'Backtests-Parallelisierung: P5_stress + P6_multiseed + P2_baseline auf Dispatcher-Pattern',
        'QUA-1026 hat P3 parallel gemacht. P5/P6/P2_baseline weiterhin serial (blocking subprocess.run). Same Pattern wie p2_matrix_launcher.py:130-139. Wartet auf Codex.',
        AGENTS['CTO'], BODY_F, 'high'),
]:
    ident, err = make_issue(title, short, agent, body, prio)
    print(f'  {label}: {ident or err}')
    results.append((label, ident, err))

# === Gmail-Monitor activation ===
print()
print('=== Gmail-Monitor activation ===')
patch_data, err = patch(f'/agents/{GMAIL_ID}', {
    'runtimeConfig': {'heartbeat': {'enabled': True, 'wakeOnDemand': True, 'intervalSec': 7200}}
})
if err:
    print(f'  Gmail PATCH error: {err}')
else:
    rc = (patch_data.get('runtimeConfig') or {}).get('heartbeat') or {}
    print(f'  Gmail-Monitor PATCH: enabled={rc.get("enabled")} interval={rc.get("intervalSec")}')

# === Daily 23:00 Vienna routine ===
print()
print('=== Daily Status Mail Routine ===')
routine_desc = """Daily status email to fabian.grabner@gmail.com at 23:00 Europe/Vienna.

Body should include:
- Phase 3 status (QM5_1003 progress + alternative cards)
- Token-burn snapshot (Codex weekly + Anthropic week from /api/companies/{id}/costs/quota-windows)
- Active sprints + blockers (top 3-5 issues with status)
- Next-day plan (today's wins + tomorrow's goals)

Constraints:
- Mail recipient: fabian.grabner@gmail.com (OWNER)
- Email tone: factual, no marketing-speak
- Length: 200-400 words
- Subject format: QuantMechanica Status YYYY-MM-DD
- DEPENDENCY: QUA-807 (Gmail OAuth re-auth) must be unblocked before this routine actually sends. Until then it'll fail gracefully and log to docs/ops/gmail_send_failures_<date>.json

If MCP/OAuth not available: log error and post Class-2 escalation comment on QUA-807. Don't loop-spam.
"""
routine_body = {
    'name': 'Daily Status Mail to OWNER (23:00 Vienna)',
    'description': routine_desc,
    'cron': '0 23 * * *',
    'timezone': 'Europe/Vienna',
    'assigneeAgentId': GMAIL_ID,
    'priority': 'medium',
    'concurrencyPolicy': 'coalesce_if_active',
    'goalId': GOAL,
}
data, err = post(f'/companies/{COMPANY}/routines', routine_body)
if err:
    print(f'  Routine create error: {err}')
else:
    print(f'  Routine created: id={data.get("id")} name={data.get("name")}')

# === QUA-807 escalation comment ===
print()
print('=== QUA-807 escalation comment ===')
url = f'{API}/companies/{COMPANY}/issues?limit=600'
issues = json.load(urllib.request.urlopen(url))
issues = issues if isinstance(issues, list) else issues.get('data', [])
qua807 = next((i for i in issues if i.get('identifier') == 'QUA-807'), None)
if qua807:
    body807 = """## Escalation: Gmail-Monitor activated, daily 23:00 routine scheduled - OAuth re-auth blocking actual sending

OWNER 2026-05-09 has explicitly requested daily 23:00 Vienna status mail to fabian.grabner@gmail.com. Gmail-Monitor (6dcf0a42) PATCHed to runtimeConfig.heartbeat.enabled=true (assignment-wakeable) and a routine "Daily Status Mail to OWNER" was created.

**Blocker:** QUA-807 OAuth re-auth requires interactive browser consent flow on info@quantmechanica.com (or alternative sender account). CTO cannot complete autonomously - needs OWNER click-through.

Until OAuth lands, the routine fires daily at 23:00 Vienna, attempts MCP send, fails gracefully, logs to docs/ops/gmail_send_failures_<date>.json. No infinite-loop or comment-spam.

**OWNER unblock action - simpler alternative:** Gmail App Password (Option A from Board Advisor message 2026-05-09):
1. https://myaccount.google.com/security
2. 2-Step-Verification on (prerequisite)
3. App passwords -> Other -> Paperclip -> generate
4. Token to Board Advisor -> Board Advisor sets in MCP config

OR full OAuth on info@quantmechanica.com (Option B from same message).

Once auth lands, mark this issue done; daily mail starts working with next 23:00 trigger.

Reference: routine + Gmail-Monitor activation 2026-05-09 by Board Advisor (local-board) per OWNER directive.
"""
    cdata, cerr = post(f'/issues/{qua807["id"]}/comments', {'body': body807})
    print(f'  QUA-807 escalation comment: {cdata.get("id") if cdata else cerr}')

print()
print('=== SUMMARY ===')
for label, ident, err in results:
    print(f'  {label}: {ident if ident else "ERROR " + (err or "")}')
print(f'  Gmail PATCH: {"ok" if not err else "ERROR"}')
