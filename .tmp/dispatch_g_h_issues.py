"""File DXZ-Compliance-Gate + Cross-EA-Scheduler issues."""
import sys, urllib.request, urllib.error, json
sys.stdout.reconfigure(encoding='utf-8')

API='http://127.0.0.1:3100/api'
COMPANY='03d4dcc8-4cea-4133-9f68-90c0d99628fb'
GOAL='4662e91e-8e9b-458e-9383-b1f67751965b'
CTO='241ccf3c-ab68-40d6-b8eb-e03917795878'

def post(path, body):
    req=urllib.request.Request(API+path, data=json.dumps(body).encode('utf-8'),
        headers={'Content-Type':'application/json'}, method='POST')
    try: return json.loads(urllib.request.urlopen(req).read()), None
    except urllib.error.HTTPError as e: return None, f'HTTP {e.status}: {e.read().decode()[:200]}'

def patch(path, body):
    req=urllib.request.Request(API+path, data=json.dumps(body).encode('utf-8'),
        headers={'Content-Type':'application/json'}, method='PATCH')
    try: return json.loads(urllib.request.urlopen(req).read()), None
    except urllib.error.HTTPError as e: return None, f'HTTP {e.status}: {e.read().decode()[:200]}'

def make_issue(title, short, assignee, body, prio='high'):
    data, err=post(f'/companies/{COMPANY}/issues', {
        'title':title,'description':short,'priority':prio,
        'assigneeAgentId':assignee,'goalId':GOAL,'createdByUserId':'local-board'})
    if err: return None, err
    iid=data['id']; ident=data['identifier']
    patch(f'/issues/{iid}', {'status':'todo'})
    cdata, cerr=post(f'/issues/{iid}/comments', {'body':body})
    return ident, cerr

BODY_G = """## Aufgabe — Mission-Critical Gap

Per OWNER mission baseline 2026-05-09 (memory project_qm_mission_baseline_2026-05-09):
- T6 Live Account: DarwinexZero EUR 100k
- DXZ Risk Rules: Daily DD >5% = account killed. Total DD >20% = account killed.
- Performance target: >=20% p.a. growth

DL-054 anti-theater gates schuetzen vor falsch-positiven PASS-Verdicten. Sie pruefen aber NICHT die DXZ-Risk-Compliance. Aktuell kann ein EA P0..P8 PASSen, aber bei Live-Deployment am ersten Tag den 5% Daily DD reissen -> Account dead.

## Was zu bauen

framework/scripts/dxz_compliance_gate.py - gate library:

- Function: check_dxz_compliance(report_csv_path, equity_curve_path)
- Reconstruct daily PnL from trade list
- For each trading day: compute peak-to-trough loss
- Check: max(daily_loss) > 5% of starting day equity? -> FAIL_DAILY_DD
- Check: equity ever drop > 20% from all-time high? -> FAIL_TOTAL_DD
- Both PASS -> verdict DXZ_PASS
- Either FAIL -> verdict DXZ_FAIL with reason
- Output: dict with verdict, max_daily_dd_pct, max_total_dd_pct, violation_dates, evidence_path

## Wo wird geprueft

1. P5 stress (p5_stress_driver.py): nach jedem stress-scenario - bei Stress-Spike darf 5%/20% nicht reissen
2. P5b noise (p5b_noise_driver.py): pro Monte-Carlo-Pfad - wenn 5% der Pfade DXZ-fail haben, EA = INVALID
3. P6 multiseed (p6_multiseed_driver.py): jeder Seed muss DXZ-pass
4. Pre-T6 promotion gate (NEW): vor jeder T6-Aktivierung MUST DXZ_PASS auf historischen P5+P5b+P6 runs

## Constants

- daily_dd_threshold_pct = 5.0
- total_dd_threshold_pct = 20.0
- These move to framework/registry/tester_defaults.json under "dxz_rules" block
- T6-Promotion-Gate ist OWNER-Class - wenn DXZ_FAIL, Promotion blocked unless OWNER-override

## Acceptance

1. dxz_compliance_gate.py exists, unit-tested
2. Integrated into p5/p5b/p6 driver outputs (additional column in report.csv: dxz_verdict)
3. tester_defaults.json has dxz_rules block with daily_dd: 0.05, total_dd: 0.20
4. Existing 4 EAs re-evaluated retroactively (where data permits) - Comment with verdict per EA

## Pfade

- framework/scripts/dl054_gates.py (existing template; DXZ-gate parallel daneben)
- framework/registry/tester_defaults.json (constants)
- decisions/DL-XXX_dxz_compliance_gate.md (NEW DL fuer die Doctrine)
- Memory: project_qm_mission_baseline_2026-05-09 for risk parameters

## Constraints

- Codex weekly aktuell 92%, resettet 5/14. Patch-Implementation kann warten ~10 Tage wenn nicht akut. Aber KEINE T6-Promotion ohne DXZ-Gate.
- Wenn ein EA pre-DXZ-gate "PASS" markiert wurde, muss er retroaktiv mit DXZ-Gate validiert werden bevor er T6 sieht.
- Anti-theater per DL-054 bleibt orthogonal - DXZ-Gate ergaenzt, ersetzt nicht.

Prio: HIGH weil der erste Heureka (1 EA live auf T6) ohne dies unsicher ist.
"""

BODY_H = """## Aufgabe - Phase 4 Prerequisite

Per OWNER mission baseline 2026-05-09: die 5 MT5 Terminals sollen permanent saturiert sein.

Aktuelle Architektur saturiert nur innerhalb eines EAs (z.B. p3_param_sweep.py: 5 Terminals x 5 Symbole eines EAs gleichzeitig). In P0/P1-Phasen (single-symbol prep, compile) ist nur 1/5 Terminal aktiv. Phase 4 will 5+ EAs parallel durch die Pipeline jagen - der Single-EA-orchestrator macht das sequenziell, was 5x langsamer ist als noetig.

## Was zu bauen

framework/scripts/multi_ea_scheduler.py - cross-EA work queue:

- job_queue = list of (ea_id, phase, symbol, config_hash) tuples
- auto-populated from: APPROVED cards waiting for P0; EAs with phase X PASS waiting for X+1 dispatch; reattempts on FAIL with explicit re-spec
- terminals = ['T1','T2','T3','T4','T5']
- running = dict terminal -> (job, popen, started_at)
- Loop: reap finished jobs, dispatch new from queue to free terminals via run_smoke.ps1 / pipeline_dispatcher.py, alarm if queue empty (= Mission failure signal per memory)

Preserves QUA-901 doctrine (5-terminal parallel WITHIN phase) but adds cross-EA layer above it. When QM5_1014 is in P0 (single-symbol), the other 4 terminals can run QM5_1017 P2 baseline in parallel etc.

## Trigger Path

- Replaces phase_orchestrator.py at the top level (the disabled hourly cron)
- phase_orchestrator becomes the "next-job-decider" called per-EA when current phase completes
- multi_ea_scheduler is the long-running terminal-saturator

## Voraussetzungen

- DXZ-compliance gate (vorgehende Issue) muss da sein bevor scheduler EAs bis P5+ jagt
- QUA-1063 (P5/P6 parallelization) sollte gelandet sein
- Each phase runner needs --terminal explicit flag (vorhanden in p2_matrix_launcher; check p3_param_sweep)

## Acceptance

1. multi_ea_scheduler.py exists, runs as Windows Task Scheduler (or process-adapter)
2. Demo: dispatch 3 different EAs in different phases simultaneously, all 5 terminals stay >50% CPU/MT5 backtest-active for >5 min
3. Idle-alarm: if queue empty for 10+ min, post Class-2 escalation to Board-Advisor (OWNER-style)
4. PHASE_STATE.md add KPI line "MT5 saturation last 24h: X% avg active"

## Prio

MEDIUM, NOT URGENT. Phase 3 (1 EA at a time) doesn't suffer; Phase 4 (5+ EAs) needs this. Land before first card hits P8 and is ready for portfolio addition.

Codex weekly 92% / 5/14 reset - kann warten. CTO load: parallel mit DXZ-gate plus QUA-1063 (P5/P6 parallel).

## Pfade

- framework/scripts/p2_matrix_launcher.py:130-139 - funktionierende within-EA pattern
- framework/scripts/phase_orchestrator.py - currently single-EA; refactor to next-job-decider
- D:/QM/Reports/pipeline/dispatch_state.json - already has dedup machinery, reuse
- Memory: project_qm_mission_baseline_2026-05-09 for MT5-saturation = success metric
"""

ident_g, err = make_issue(
    'DXZ-Compliance Gate: Daily 5% / Total 20% DD enforcement before T6 promotion',
    'Mission-critical gap per OWNER baseline 2026-05-09: DL-054 deckt anti-theater, aber kein DXZ-Risk-Check. EA kann P0..P8 PASSen und am ersten T6-Tag account killen. Bauen + retroaktiv validieren.',
    CTO, BODY_G, 'high')
print(f'G DXZ-Gate: {ident_g or err}')

ident_h, err = make_issue(
    'Multi-EA Cross-Terminal Scheduler (Phase 4 prerequisite)',
    'OWNER mission baseline: 5 MT5 sollen permanent saturiert sein. Aktuell nur within-EA-parallel. Phase 4 (5+ EAs gleichzeitig) braucht cross-EA-scheduler. Build for Phase 4 prep.',
    CTO, BODY_H, 'medium')
print(f'H Multi-EA-Scheduler: {ident_h or err}')
