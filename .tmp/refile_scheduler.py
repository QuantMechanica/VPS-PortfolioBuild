"""Refile Multi-EA-Scheduler with correct scope (no Phase-4-prereq language)."""
import sys, urllib.request, urllib.error, json
sys.stdout.reconfigure(encoding='utf-8')

API='http://127.0.0.1:3100/api'
COMPANY='03d4dcc8-4cea-4133-9f68-90c0d99628fb'
GOAL='4662e91e-8e9b-458e-9383-b1f67751965b'
CTO='241ccf3c-ab68-40d6-b8eb-e03917795878'

BODY = """## Aufgabe — Continuous Operational Infrastructure

Per OWNER 2026-05-09: die Firma operiert in Endausbaustufe (memory project_qm_mission_baseline_2026-05-09 amendment 2). KEIN Phase-4-Prereq, sondern current state.

OWNER mission baseline: die 5 MT5 Terminals sollen permanent saturiert sein. Idle MT5 = Mission alarm.

**Aktuelle Architektur saturiert nur INNERHALB eines EAs** (z.B. p3_param_sweep.py: 5 Terminals × 5 Symbole eines EAs gleichzeitig). In P0/P1-Phasen (single-symbol prep, compile) ist nur 1/5 Terminal aktiv. Beobachtung 2026-05-09T10:0xZ: SRC04_S08 (QM5_1014) gerade dispatched, läuft P0/P1 → 1/5 Terminals saturiert, 4 idle.

**Was zu bauen — nicht standalone-script-workaround, sondern ordentlich in Paperclip integriert:**

### Architektur

`paperclip/tools/ops/multi_ea_scheduler.py` — cross-EA work queue als Paperclip-Process-Adapter-routine:

- **job_queue**: list of `(ea_id, phase, symbol, config_hash)` tuples
  - auto-populated from: APPROVED cards waiting for P0; EAs with phase X PASS waiting for X+1 dispatch; reattempts on FAIL with explicit re-spec
- **terminals**: `['T1','T2','T3','T4','T5']`
- **Loop**: reap finished jobs, dispatch new from queue to free terminals via `run_smoke.ps1` / `pipeline_dispatcher.py`, alarm if queue empty (= Mission failure signal)

Preserves QUA-901 doctrine (5-terminal parallel WITHIN phase) but adds cross-EA layer above it. When QM5_1014 in P0 (single-symbol), other 4 terminals run other EAs in P2/P3 parallel.

### Paperclip-Integration (NICHT standalone)

1. **Eigener Agent oder Pipeline-Operator-extension** mit `adapterType: "process"` (kein LLM)
2. **Cron-trigger**: alle 5 min via Paperclip-routine (deterministisch, kostenlos)
3. **Status visibility via Paperclip**:
   - Routine output: `{ queue_depth, active_terminals, idle_min_per_terminal, throughput_runs_per_h }`
   - Diese Metriken landen via API in einem rolling tracker issue (e.g., neue QUA-XXXX "MT5 Saturation Live Tracker")
   - Daily Mail (paperclip/tools/ops/daily_status_mail.py) zeigt diese Metriken
4. **Self-healing + idle-alarm**:
   - Wenn Queue empty UND keine EA in P9/P9b/P10 (manual gate) → comment auf rolling tracker mit "Queue dry, upstream gestaucht — investigate" + tag CEO
   - Wenn Terminal idle >10 min während Jobs in Queue → restart-attempt + alarm
5. **Replaces QM_Phase_Orchestrator Windows Task** (currently disabled per Board Advisor 2026-05-09): phase_orchestrator.py wird zu "next-job-decider per EA-completion", multi_ea_scheduler ist der long-running terminal-saturator
6. **Kompatibilität**: bestehende run_smoke.ps1 + pipeline_dispatcher.py + dispatch_state.json dedup machinery wird wiederverwendet, nicht ersetzt

### Voraussetzungen / Dependencies

- DXZ-portfolio-aggregate-gate (QUA-1082) muss da sein bevor scheduler EAs bis P5+ jagt
- QUA-1063 (P5/P6 parallelization) sollte gelandet sein damit auch P5/P6 die 5-terminal nutzen
- Each phase runner needs --terminal explicit flag (vorhanden in p2_matrix_launcher; check p3_param_sweep)
- QUA-1067 (next-candidate P3 queue stage) feeds into job_queue

### Acceptance

1. `multi_ea_scheduler.py` exists, läuft als Paperclip process-adapter routine cron */5
2. **Demo**: dispatch 3 different EAs in different phases simultaneously, all 5 terminals stay >50% mem (>500MB) for >5 min sustained
3. **Idle-alarm**: if queue empty for 10+ min → Class-2 escalation comment (auf rolling tracker)
4. **Saturation KPI**: rolling tracker issue updated alle 5 min mit `mt5_active_count, queue_depth, throughput_24h_runs`
5. **PHASE_STATE.md** (oder dessen continuous-ops-Nachfolger) zeigt MT5-saturation als KPI

### Prio: HIGH

Idle MT5 ist Mission-Failure-Signal per OWNER baseline. Build now, nicht warten auf hypothetische Phase-4.

Codex weekly aktuell 92% / 5/14 reset. Wenn build-implementation Codex-cycles braucht: kann ggf. ~5 Tage warten. ABER: Anthropic-Adapter-Variante moeglich? Pipeline-Orchestrator (Haiku 4.5) koennte den scheduler-loop selbst ausfuehren — Sonnet/Haiku reicht fuer subprocess.Popen + queue management, nicht für komplexe Reasoning. CTO bewerten: Codex-build pure performance vs Anthropic-build no-Codex-bottleneck.

### Pfade

- `framework/scripts/p2_matrix_launcher.py:130-139` — funktionierende within-EA pattern als Template
- `framework/scripts/phase_orchestrator.py` — currently single-EA + disabled; refactor zu "next-job-decider"
- `D:/QM/Reports/pipeline/dispatch_state.json` — already has dedup machinery, reuse
- Memory: `project_qm_mission_baseline_2026-05-09` — MT5-saturation = success metric, no-phasing
- Daily mail: `paperclip/tools/ops/daily_status_mail.py:gather_mt5_status()` — already wired für saturation reporting

### Constraint

- KEINE OWNER-Klasse Aktionen
- Nicht mit QUA-901 doctrine (within-phase 5-terminal saturation) konfligieren — komplementär nicht ersetzend
- Anti-theater: scheduler darf KEINE FAIL-Loops machen (per QM_Phase_Orchestrator-Lehre 2026-05-09 morgen — der hat genau das gemacht und Board Advisor musste disablen)
- Idempotenz: dispatch_state.json dedup respektieren
"""

req=urllib.request.Request(f'{API}/companies/{COMPANY}/issues',
    data=json.dumps({
        'title': 'Multi-EA Cross-Terminal Scheduler — continuous operational infrastructure (NOT phase-prereq)',
        'description': 'OWNER 2026-05-09: 5 MT5 sollen permanent saturiert sein. Aktuell nur within-EA-parallel; in P0/P1 sind 4/5 Terminals idle. Build cross-EA scheduler als Paperclip process-adapter routine, integriert mit dispatch_state + alarm + rolling tracker. NICHT standalone script.',
        'priority': 'high',
        'assigneeAgentId': CTO,
        'goalId': GOAL,
        'createdByUserId': 'local-board',
    }).encode('utf-8'),
    headers={'Content-Type':'application/json'}, method='POST')
try:
    resp=urllib.request.urlopen(req); d=json.loads(resp.read())
    iid=d['id']; ident=d['identifier']
    print(f'Issue created: {ident} | id={iid}')
    # PATCH to todo
    req2=urllib.request.Request(f'{API}/issues/{iid}',
        data=json.dumps({'status':'todo'}).encode('utf-8'),
        headers={'Content-Type':'application/json'}, method='PATCH')
    resp2=urllib.request.urlopen(req2)
    print(f'PATCH status->todo: {resp2.status}')
    # Post body as comment
    req3=urllib.request.Request(f'{API}/issues/{iid}/comments',
        data=json.dumps({'body':BODY}).encode('utf-8'),
        headers={'Content-Type':'application/json'}, method='POST')
    resp3=urllib.request.urlopen(req3); d3=json.loads(resp3.read())
    print(f'Comment posted: {resp3.status} | id={d3.get("id")}')
except urllib.error.HTTPError as e:
    print(f'ERR: {e.status} {e.read().decode()[:300]}')
