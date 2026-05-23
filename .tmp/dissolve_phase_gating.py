"""Dispatch the no-phasing structural correction + promote Multi-EA-Scheduler."""
import sys, urllib.request, urllib.error, json
sys.stdout.reconfigure(encoding='utf-8')

API='http://127.0.0.1:3100/api'
COMPANY='03d4dcc8-4cea-4133-9f68-90c0d99628fb'
GOAL='4662e91e-8e9b-458e-9383-b1f67751965b'
CEO='7795b4b0-8ecd-46da-ab22-06def7c8fa2d'
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

# ===== 1. CEO issue: dissolve company-phase gating =====

CEO_BODY = """## Aufgabe — Structural correction (OWNER 2026-05-09)

OWNER hat klargestellt: **Die Firma soll in der Endausbaustufe sein, voll umfaenglich laufend. Phase 1/2/3/4/5/6/Final als sequenzielle Firmen-Phasen sind Konstrukt-Fehler. Auflösen.**

Memory project_qm_mission_baseline_2026-05-09 wurde entsprechend amendet.

## Was bleibt vs. was weg muss

**BLEIBT (real, sequenziell):**
- EA-level phases G0..P10: Lifecycle eines einzelnen EA. Cannot skip.
- Pre-T6-promotion: ein EA muss G0..P8 + Portfolio-DXZ-PASS haben bevor er live geht. Das ist EA-level, nicht firm-level.
- OWNER-class hard gates: T6-toggle, real-money-decisions.

**WEG (artifiziell):**
- "Phase 3 must complete before Phase 4 starts" — falsch. Portfolio-Composition-Infra (correlation, basket-composer, aggregate-DD-monitor) baut SOFORT.
- "Phase 5 LiveOps starts after Phase 4" — falsch. T6-deploy-manifest, T6-promotion-gate, live-monitoring-infra laufen jetzt aktiv.
- "Phase 6 Public Dashboard parallel-eligible" — falsch formuliert. Es laeuft, nicht "eligible".
- "Phase Final Founder-Comms DEFERRED" — laut OWNER baseline: YouTube/Newsletter sind Marketing fuer den DXZ-Fund, also aktiv (Background-Stream, low cadence ok aber AKTIV — nicht "deferred").

## Was du jetzt machst (CEO direct)

### 1. PHASE_STATE.md komplett umschreiben (delegate at Doc-KM 8c85f83f)
Frame-Wechsel:
- ALT: "Current phase / Closure criterion / Current blocker / ETA" -> sequenzielles Phasen-Modell
- NEU: "Active workstreams / Today's progress / Open blockers" -> kontinuierliches Operations-Modell

Active workstreams werden parallel gefuehrt:
1. **Strategy Pipeline (continuous)**: G0 extraction → QB G1 → Development scaffold → Compile → Pipeline Run G0..P8
2. **Portfolio Composition (continuous)**: correlation matrix infra, basket composer, aggregate-DD monitor — laeuft auch wenn 0 EAs heute basket-eligible sind
3. **LiveOps Readiness (continuous)**: T6 deploy manifest, promotion-gate library, live-monitoring infra
4. **Public Channels (continuous)**: Dashboard auf quantmechanica.com (QUA-889 unblock noetig), YouTube/Newsletter background
5. **Operations Infrastructure (continuous)**: token-burn governance, agent fleet hygiene, runbook integrity
6. **Heartbeat Sprint (current focus)**: aktueller Fokus-Sprint, kann variieren

Pro Workstream: Status (active/blocked/dormant), Today's progress (1 Zeile), Open blockers (max 3).

### 2. QUA-889 unblock (Public dashboard build, DevOps assigned)
Aktuell blocked seit ~5/6. Per OWNER no-phasing: Dashboard ist nicht Phase-6-prereq sondern continuous workstream. Triage was blockiert + dispatch DevOps. Pruefe ob blocker noch real ist oder Phasing-Artefakt.

### 3. QUA-1067 reframen (Phase 4 prep Lane B: next-candidate P3 queue stage)
Aktuell "Phase 4 prep". Sollte "Continuous next-card P3 queue staging" heissen — gleiche Arbeit, andere Sprache. Das Konzept "queue an APPROVED cards die als naechstes durch P3 gehen" ist continuous infrastructure.

### 4. QUA-884 reclassify (Mail-Agent MC0 founder-comms)
Aktuell "todo" mit deferred-Status. Per OWNER no-phasing + "YouTube/Newsletter ist Marketing fuer DXZ-Fund": founder-comms infra should be ACTIVE als low-cadence Background-Workstream. Reclassify, hire wenn nicht schon, low-prio cron (e.g., weekly content review).

### 5. QUA-1083 (Multi-EA-Scheduler) priority bump → HIGH
Board Advisor hat gerade auf HIGH gepatcht (parallel zu diesem Issue). Scope amend: nicht "Phase 4 prereq" sondern "current operational infrastructure". Build now als ordentliche Paperclip-routine (process-adapter, nicht standalone-script-workaround).

### 6. Re-prioritize backlog allgemein
Pruefe alle in_review/blocked/todo Issues mit "phase X prep" oder "deferred until phase X" Sprache. Reframe oder activate. Ziel: alle Workstreams haben einen klaren in_progress oder dormant-aktiv-monitoring State, kein "warten auf naechste Phase".

## Acceptance
- PHASE_STATE.md neu strukturiert (Doc-KM child issue)
- QUA-889 entweder unblocked oder mit echter Blocker-Reason (nicht Phasing-Artefakt)
- QUA-1067, QUA-884 reframed (comments + status)
- QUA-1083 Scope-Amendment notiert (Board Advisor macht den HIGH-PATCH, du als CEO bestaetigst)
- Comment auf diesem Issue mit Action-Log
- Status PATCH zu in_review wenn Plan steht

## Nicht zu tun (boundary)
- Keine T6-Aktionen (OWNER-class)
- Keine pause/unpause API (OWNER-class)
- Keine neuen Hires (OWNER-class) — wenn ein Workstream einen neuen Agent braucht: Class-2 escalation an OWNER
- Keine Code-Patches im framework/ ohne CTO

## Pfade
- Memory: project_qm_mission_baseline_2026-05-09.md (just amended with no-phasing section)
- paperclip/governance/PHASE_STATE.md (target rewrite)
- decisions/PHASE_4_PORTFOLIO_PLAN_2026-05-09.md (your existing plan; bleibt gueltig, nur umschreiben dass es continuous infra ist)
- QUA-889, QUA-1067, QUA-884, QUA-1083 (re-classify or unblock)

## Constraint
Codex weekly aktuell 92%, Anthropic week 55%. Du (CEO) kannst diesen Sprint Anthropic-only bewaeltigen. Doc-KM ist Sonnet (Anthropic). Codex-Issues (QUA-1083 build) warten auf 5/14 reset.

Prio: HIGH. Strukturelles Update vom OWNER, sollte heute oder morgen landen.
"""

data, err = post(f'/companies/{COMPANY}/issues', {
    'title': 'Dissolve Company-Phase Gating: rewrite PHASE_STATE + reframe Phase-4/5/6 work as continuous infrastructure',
    'description': 'OWNER 2026-05-09 directive: company-level Phase 1/2/3/4/5/6/Final ist Konstrukt-Fehler. Aufloesen. Endausbaustufe-Modus = alle Workstreams continuous parallel. EA-level G0..P10 bleibt. Reframe PHASE_STATE.md, QUA-889/1067/884/1083, backlog re-prio.',
    'priority': 'high',
    'assigneeAgentId': CEO, 'goalId': GOAL, 'createdByUserId':'local-board',
})
if err:
    print(f'CEO issue ERROR: {err}')
else:
    iid=data['id']; ident=data['identifier']
    patch(f'/issues/{iid}', {'status':'todo'})
    cdata, cerr = post(f'/issues/{iid}/comments', {'body': CEO_BODY})
    print(f'{ident}: filed | comment={cdata.get("id") if cdata else cerr}')

# ===== 2. PATCH QUA-1083 priority HIGH + amend scope =====

# Find QUA-1083
url=f'{API}/companies/{COMPANY}/issues?limit=600'
issues=json.load(urllib.request.urlopen(url))
issues=issues if isinstance(issues,list) else issues.get('data',[])
qua1083=next((i for i in issues if i.get('identifier')=='QUA-1083'), None)
if qua1083:
    pdata, perr = patch(f'/issues/{qua1083["id"]}', {'priority': 'high'})
    print(f'QUA-1083 priority: {pdata.get("priority") if pdata else perr}')

    AMEND="""## SCOPE AMENDMENT — current infrastructure, not Phase-4-prereq (OWNER 2026-05-09)

OWNER hat klargestellt: **die Firma laeuft bereits in Endausbaustufe.** "Phase 4 prereq" ist falsche Sprache. Multi-EA-Scheduler ist **continuous operational infrastructure**, nicht "Vorbereitung fuer einen kuenftigen Modus".

### Was bleibt
- Architektur (cross-EA work queue + 5-terminal saturator)
- Acceptance criteria
- Pfade

### Was sich aendert
- Prio MEDIUM → **HIGH** (Board Advisor PATCH gerade durchgegangen)
- Framing: "build before Phase 4" → "build now, this is wie die Firma jetzt operiert"
- Deployment: nicht standalone script, sondern **ordentlich in Paperclip integriert** als process-adapter routine
  - Eigener Agent oder Pipeline-Operator-extension
  - Status visibility via Paperclip dashboard (queue depth, terminal saturation, alarms)
  - Self-healing + idle-alarm direkt an CEO/Board-Advisor
- Test mit aktuellem state: SRC04_S08 (=QM5_1014) ist gerade dispatched, in P0/P1; andere EAs (1004, 1017, SRC04_S03) idle bei P2. Multi-EA-Scheduler wuerde diese 4 anderen EAs in andere Phasen weiter pushen waehrend QM5_1014 P0/P1 macht.

### Build-Prio
HIGH. Codex weekly 92% → Build wartet ggf. ~5 Tage bis 5/14 reset, aber DAS Pattern (idle MT5 waehrend EA in P0/P1) ist genau die Failure-Mode die OWNER stoppen will.

Wenn Codex zu eng: Anthropic-Adapter-Variante moeglich? Pipeline-Orchestrator (Haiku 4.5) koennte den scheduler-loop ausfuehren — Sonnet/Haiku reicht fuer subprocess.Popen + queue management. CTO bewerten.
"""
    cdata, cerr = post(f'/issues/{qua1083["id"]}/comments', {'body': AMEND})
    print(f'QUA-1083 scope-amendment: {cdata.get("id") if cdata else cerr}')
