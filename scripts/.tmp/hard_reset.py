"""
Hard reset 2026-05-15: cancel all open Paperclip issues to give CEO a clean slate,
then post one master directive. Issues remain in DB (cancelled status) — searchable
if Research/CEO needs to revive specific work.
"""
import json, urllib.request

CID = "03d4dcc8-4cea-4133-9f68-90c0d99628fb"
API = "http://127.0.0.1:3100/api"
CEO = "7795b4b0-8ecd-46da-ab22-06def7c8fa2d"

def fetch(url):
    return json.loads(urllib.request.urlopen(url, timeout=30).read())

def post_comment(iid, body):
    req = urllib.request.Request(f"{API}/issues/{iid}/comments",
        data=json.dumps({"body":body}).encode("utf-8"),
        headers={"Content-Type":"application/json"}, method="POST")
    try: urllib.request.urlopen(req, timeout=15); return True
    except: return False

def patch(iid, body):
    req = urllib.request.Request(f"{API}/issues/{iid}",
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type":"application/json"}, method="PATCH")
    try:
        return True, json.loads(urllib.request.urlopen(req, timeout=15).read())
    except Exception as e:
        return False, str(e)

# 1. Collect ALL open issues
print("=== Step 1: collect open issues ===")
all_open = []
for st in ["backlog","todo","in_progress","in_review","blocked"]:
    r = fetch(f"{API}/companies/{CID}/issues?status={st}&limit=500")
    all_open.extend(r)
print(f"to cancel: {len(all_open)}")

# 2. Cancel all with uniform reason
CANCEL_REASON = (
    "Hard reset 2026-05-15T08:20Z (OWNER directive): company moves to single master "
    "CEO directive for continuous research-code-backtest pipeline operations. Any "
    "still-relevant work can be re-spawned as a child of the new directive if CEO "
    "deems it necessary; cancelled issues remain searchable in the DB."
)
print("\n=== Step 2: cancel all ===")
cancelled, failed = 0, 0
for i in all_open:
    iid = i['id']
    post_comment(iid, CANCEL_REASON)
    ok, _ = patch(iid, {"status":"cancelled"})
    if ok: cancelled += 1
    else: failed += 1
print(f"cancelled: {cancelled}, failed: {failed}")

# 3. Post master CEO directive
MASTER_TITLE = "MASTER DIRECTIVE: QM V5 continuous pipeline — research, code, backtest, review (rolling)"
MASTER_BODY = """## Aufgabe (Mission)

Operate the QuantMechanica V5 EA-building pipeline as a continuous loop:
**Research -> Development -> Backtest -> Review**.

Keep the loop saturated until at least one EA reaches P7 (live-eligible review).
Then keep going.

This is the **only** top-level company directive. All other work is a sub-issue
of this one, spawned by CEO as needed.

## How the loop works

1. **Research** (`7aef7a17`): continuously generates Strategy Cards from approved
   sources (Singh 2013, Davey 2014, Lien candles, OWNER-curated). Submits to G0 review.

2. **CEO** (`7795b4b0`) + **QB** (`0ab3d743`): G0/G1 ratification. CEO checks
   reputable-source criteria (`processes/qb_reputable_source_criteria.md`), QB
   checks compliance fit, approves or rejects.

3. **Development-Codex** (`ebefc3a6`): builds `.ex5` from approved cards.
   Deploys to T1-T5 via `framework/scripts/deploy_ea_to_all_terminals.ps1`.
   Dev-Claude (`6733e8d1`) is co-equal but verify cap availability first.

4. **Phase Orchestrator** (deterministic Python, hourly via Windows Task
   `QM_Phase_Orchestrator` S4U mode): dispatches P1 -> P2 -> P3 -> P3.5 -> P4 ->
   P5 -> P5b -> P5c -> P6 -> P7 in sequence. State at
   `D:/QM/reports/pipeline/dispatch_state.json`.

5. **Zero-Trades-Specialist** (`8ba981d2`): triages MIN_TRADES_NOT_MET /
   INVALID failures. Three verdicts: `RECALIBRATED` (new set file),
   `STRATEGY_DRIFT` (back to Research), `BASELINE_ACCURATE_FAILED` (drop EA
   to lessons-learned).

6. **CTO** (`241ccf3c`) + **HoP** (`46fc11e5`): monitor pipeline health,
   address infrastructure blockers, escalate platform bugs.

7. **CoS** (`38f933cd`): daily token-burn rollup, agent roster, weekly status
   to OWNER.

## Steady-state target

At any moment, the pipeline should have:
- >= 3 EAs in G0..P1
- >= 3 EAs in P2..P5
- >= 1 EA in P5b..P7
- New Strategy Card approved per week
- New `.ex5` built per week
- Watchdog `docs/ops/pipeline_health/latest.json` shows zero `severity=high` alarms

## Acceptance criteria (rolling, weekly review every Sunday)

This is a long-running tracker. CEO posts a weekly summary comment each Sunday
~20:00 UTC containing:
1. EAs currently in pipeline + their phase
2. EAs reached P7 cumulatively (target: 1 by end of week 4)
3. Top 3 blockers (with owning agent + ETA)
4. Token burn vs Anthropic monthly cap (from Token-Controller)
5. Hard-Rules audit: any near-misses this week?

## Hard Rules (DO NOT cross)

- **No T6 AutoTrading toggle** — OWNER + Board Advisor only (Hard Rule)
- **No ML libraries in V5 EAs** — `framework/scripts/build_check.ps1` enforces
- **RISK_FIXED $1000 for backtests, RISK_PERCENT for live** (DL-054)
- **No invented commission/swap/DST values** — cite `framework/registry/tester_defaults.json`
- **Evidence over claims** — CSV/report/log paths, not screenshots
- **No deletion of `bases/`** (Hard Rule)
- **No founder-comms work** (deferred per project_qm_comms_gmail_requirement memory)

## State snapshot at directive start (2026-05-15 ~08:20Z)

- **3 EAs blocked at P2** with strategy-drift verdict (QM5_1003, QM5_1004, QM5_1017,
  QM5_SRC04_S03 — see report.csv per EA under `D:/QM/reports/pipeline/<EA>/P2/`).
  Cancelled in hard reset; CEO decides whether to revive via new Research dispatch
  or drop those EAs to lessons-learned.
- **1 EA built today**: QM5_1002_davey-eu-night.ex5 (106220 bytes, deployed T1-T5
  matching hash 0999E40F). Phase Orchestrator will pick it up on next hourly fire.
- **Dev-Claude resumed** from Anthropic cap (OWNER Option A executed 2026-05-15
  06:55Z). Healthy, awaiting first post-recovery assignment.
- **Continuation-runaway bug** patched in `paperclip/app/server/src/services/recovery/service.ts`
  at line ~1568 (Board Advisor 2026-05-15). Server restarted PID 16868.
- **Gmail-Monitor wakeOnDemand=false** (workaround for separate self-comment-loop
  bug; daily 8am Vienna cron still fires).
- **Watchdog** as of 2026-05-15 07:00Z: 2 alarms remaining (sub_agents_unutilized,
  detector_b_dispatcher_down_30m). Both will self-clear as agents pick up new
  work and as dispatcher state writes resume.

## Wake-OWNER conditions (request_confirmation only when these trigger)

- An EA reaches P7 (live-eligible review)
- A Hard Rule is at risk of being crossed
- Anthropic monthly cap is < 4 days from exhaustion (per Token-Controller forecast)
- A Strategy Card is rejected at G0 for a reason needing OWNER strategic input
- More than 7 days pass without any EA advancing a phase

## Open OWNER decision (carried over from pre-reset)

**QUA-1527** ratification: `friday_close=false` waiver for `singh-swap-fly`
(SRC06_S12, EA 1039). CEO has ratified. Awaiting OWNER co-ratification on
request_confirmation `75d82f73-72a9-4bfc-841b-93671419c9cc`. This issue was
NOT cancelled in the hard reset and remains in OWNER inbox.

## Non-Goals

- No founder-comms / Gmail-Agent buildup (deferred)
- No new agent hires (OWNER-class)
- No T6 live trading (until OWNER + Board Advisor sign-off at P7 ratification)
- No retrospective revival of cancelled hard-reset issues unless still load-bearing
"""

print("\n=== Step 3: post master CEO directive ===")
req = urllib.request.Request(
    f"{API}/companies/{CID}/issues",
    data=json.dumps({
        "title": MASTER_TITLE,
        "description": "Continuous-loop master directive; full spec follows as first comment. CEO must treat this as a rolling tracker (no done status until OWNER closes it).",
        "priority": "critical",
        "assigneeAgentId": CEO,
        "rollingTracker": True,
    }).encode("utf-8"),
    headers={"Content-Type":"application/json"}, method="POST")
master = json.loads(urllib.request.urlopen(req, timeout=15).read())
master_id = master['id']
master_ident = master['identifier']
print(f"created {master_ident} ({master_id[:8]}); posting body as first comment ...")
post_comment(master_id, MASTER_BODY)
print(f"done — master directive at {master_ident}")

# 4. Final state
print("\n=== Step 4: final state ===")
final = []
for st in ["backlog","todo","in_progress","in_review","blocked"]:
    r = fetch(f"{API}/companies/{CID}/issues?status={st}&limit=500")
    final.extend(r)
print(f"open issues now: {len(final)}")
for i in final:
    title = (i.get('title') or '').encode('ascii','replace').decode()[:60]
    print(f"  {i.get('identifier','')} {i.get('status','')} asg={(i.get('assigneeAgentId') or '-')[:8]} {title}")
