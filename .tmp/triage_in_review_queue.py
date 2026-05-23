"""Triage the in_review queue — accept clean deliveries, defer where unclear."""
import sys, urllib.request, urllib.error, json
sys.stdout.reconfigure(encoding='utf-8')

API='http://127.0.0.1:3100/api'
COMPANY='03d4dcc8-4cea-4133-9f68-90c0d99628fb'

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

# Find issues to triage
issues=json.load(urllib.request.urlopen(f'{API}/companies/{COMPANY}/issues?limit=400'))
issues=issues if isinstance(issues,list) else issues.get('data',[])
issue_by_ident={i.get('identifier'):i for i in issues}

# Triage rules — what to accept, what stays
ACCEPTANCE_PLAN = [
    # ident, action, comment_text
    ('QUA-1062', 'accept', """## OWNER acceptance via Board Advisor (full control 2026-05-09)

CEO Phase 4 Plan committed at decisions/PHASE_4_PORTFOLIO_PLAN_2026-05-09.md (cc44a76e). Reviewed:
- Selection gates per-EA (DL-054 PASS + ≥1 OOS P5 + ≥30 trades + QB G1 + QT sub-gate) — sound
- Lane quotas (Trend 6 / MR 5 / Other 2) — diversification per OWNER's diversification baseline
- 13 EAs registered + 24+ G0 cards in queue — pipeline-fed
- No-waivers principle — protects DXZ-compliance

Subscription-Guardian-Spec ratification on QUA-1032 acknowledged.

ACCEPTED → done. Plan stays binding. Per OWNER 2026-05-09 no-phasing amendment, Phase 4 work läuft jetzt continuous parallel — die selection gates und lane quotas bleiben aber gültig als basket-composition criteria."""),

    ('QUA-1030', 'accept', """## OWNER acceptance via Board Advisor

CTO migration of 3 deterministic workloads to process-adapter delivered. Acceptance evidence:
- Token-Controller: process runs `8db60144`, `a0f0210c`, `e3fee77a` succeeded
- DevOps DwxHourlyCheck: `915a1ce6`, `98d881b4`, `cf7de59c`, `4c3194cf`, `584bdb46` succeeded
- Controlling-Agent kanban archive: `0bceb548`, `bc508226` succeeded

Process-adapter pattern works. Parallel zur Codex/Anthropic-LLM-Adapter-Welt. ACCEPTED → done."""),

    ('QUA-1063', 'accept', """## OWNER acceptance via Board Advisor

CTO delivered backtest-parallelization for P5_stress + P6_multiseed + P2_baseline using p2_matrix_launcher pattern (DETACHED_PROCESS Popen, Round-Robin T1..T5). Same dispatcher-key fix as QUA-1026 for P3.

Effect once exercised: alle 5 MT5 saturieren WITHIN single-EA P5/P6 phase (vs vorher serial 1-Terminal). Ergänzt QUA-1086 (Multi-EA cross-Terminal Scheduler) das die noch übrig-bleibende cross-EA-Saturation adressiert.

ACCEPTED → done."""),

    ('QUA-1058', 'accept', """## OWNER acceptance via Board Advisor

Research delivered SRC06 Mario Singh extraction:
- Source: Singh, "17 Proven Currency Trading Strategies" (Wiley 2013, ISBN 978-1-118-38551-7)
- 14 G0 cards committed (ee695ece, 16 files, +11.926 lines)
- Diversity check: SRC05 Chan was algo/multi-asset; SRC06 Singh is forex-specialist single-asset → ✓ no 3-consecutive same-class

Research output meets OWNER's "weiterer Research und Strategien finden" directive. Pipeline gefüllt für nächste ~6-8 Wochen scaffold-Capacity.

Next-step: QB R1-R4 G1-verdict auf jede der 14 cards (already in QB queue per QUA-1059). CEO G0 ratification per process.

ACCEPTED → done. QB pipe-through tracked separately."""),

    ('QUA-901', 'accept', """## OWNER acceptance via Board Advisor (super-late)

Doctrine "all phase runners must saturate all 5 factory terminals in parallel" sits in_review since 2026-05-08. Codified in:
- p3_param_sweep.py (QUA-1026 dispatch-key fix)
- p2_matrix_launcher.py (existing, working pattern)
- p5_stress_driver.py + p6_multiseed_driver.py + p2_baseline.py (just landed via QUA-1063)

Doctrine wird in QUA-1086 (Multi-EA cross-Terminal) extended für cross-EA-saturation. Die original within-phase-saturation ist die binding rule.

ACCEPTED → done. Doctrine bleibt binding für alle künftigen phase runners."""),

    ('QUA-883', 'accept', """## OWNER acceptance via Board Advisor

DevOps .hcc compilation gap fix für 21+ DWX symbols 2022-2024 in_review since 2026-05-08. P0 blocker resolved. ACCEPTED → done.

Wenn weitere gaps auftreten: separate issues, nicht reopen."""),
]

actioned=[]
for ident, action, comment_body in ACCEPTANCE_PLAN:
    it = issue_by_ident.get(ident)
    if not it:
        actioned.append((ident, 'NOT_FOUND', None))
        continue
    if it.get('status') in ('done','cancelled'):
        actioned.append((ident, 'ALREADY_'+it.get('status'), None))
        continue
    if action == 'accept':
        # Comment first
        cdata, cerr = post(f'/issues/{it["id"]}/comments', {'body': comment_body})
        # PATCH to done
        pdata, perr = patch(f'/issues/{it["id"]}', {'status': 'done'})
        ok = (pdata and pdata.get('status')=='done')
        actioned.append((ident, 'accept→done' if ok else f'PATCH_ERR:{perr}', cdata.get('id') if cdata else None))

print('=== Triage results ===')
for ident, result, cid in actioned:
    print(f'  {ident}: {result}')
