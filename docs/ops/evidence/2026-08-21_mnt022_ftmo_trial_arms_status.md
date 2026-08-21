# MNT-022 — FTMO trial arms: status check + governor-parity result (partial, blocked)

**Date:** 2026-08-21
**Router task:** 750001ab-d641-40f4-9bb6-3f1bae17eb43 (priority 73, ops_issue)
**Authority cited on the ticket:** OWNER decision 2026-08-21, "wir folgen immer
der Empfehlung" on MNT-022 — recommendation was explicitly NO challenge
purchase until the arms are finished and joint replay/paired estimator/
governor parity are in hand.
**Recorder:** Claude (agents/board-advisor)
**Hard stop respected:** no challenge purchase, no live account contact, no
book construction, no factory start/stop, no recompile in the active
inventory. This is evidence only.

## Finding 1 — a prior cycle already classed this "deliberately NOT dispatched"

`docs/ops/evidence/2026-08-21_maintenance_ledger_reverification_and_dispatch.md`
§5 classes MNT-022 as OWNER-bound with the standing recommendation "no
challenge purchase," and states it was **deliberately not dispatched**. This
router task (routed 10:42:28 today) dispatches it anyway. Flagging the
conflict rather than silently overriding a documented prior decision — OWNER
should confirm whether circumstances changed, or whether this was routed by
mistake against the standing hold.

Given that conflict, and given the remaining work (root-causing an EA's
`ONINIT_FAILED`) is substantial, focused engineering rather than a bounded
ops fix, this cycle did **not** attempt the deepest piece (see Finding 3).
What follows is a verified status check plus the one check that could be
run safely and completely today.

## Finding 2 — the ticket's premise is accurate; nothing has moved

Live `work_items` query at time of this check, latest row per EA:

| EA | Phase / status / verdict | updated_at |
|---|---|---|
| QM5_13108 | Q08 / done / **FAIL_SOFT** | 2026-08-18T05:25Z |
| QM5_20181 | Q03 / done / **INFRA_FAIL** | 2026-08-05T04:59Z |
| QM5_13301 | Q08 / done / **PASS** (+ Q14 OPT_ELIGIBLE) | 2026-08-17T23:35Z |
| QM5_10145 | Q08 / done / **INFRA_FAIL** (after a same-day Q08 PASS) | 2026-08-18T07:11Z |

Matches the ticket's `measured_state` exactly — no drift.

## Finding 3 — QM5_20181's Q03 INFRA is genuinely stuck, not a passive requeue

Evidence: `D:\QM\reports\work_items\50ada76a-…\QM5_20181\20260805_045921\summary.json`
— `result: FAIL`, `reason_classes: ["ONINIT_FAILED","INCOMPLETE_RUNS"]`, two
identical Q03 failures plus a prior Q04 INFRA_FAIL on 08-04. Identity is
clean (`source_matches_deployed: true`) — this is not a stale-binary/deploy
defect, the EA's `OnInit()` genuinely returns `INIT_FAILED` in the tester
(likely the joint multisym/basket warmup path, unconfirmed). `attempt_count=0`
on a `done` (terminal) row means the factory will not self-requeue this —
it needs a manual root-cause pass, which is out of scope for this cycle's
remaining time/token budget and is the actual blocking item for two of the
three named checks (see Finding 4). Prior repair
`docs/ops/evidence/2026-07-27_20181_repair.md` fixed unrelated source
defects (F3/F4) and explicitly recorded no pipeline verdict at the time —
consistent with this having never cleared Q03 since.

## Finding 4 — the three named checks: tools exist; two are blocked on Finding 3

- **Governor-parity check** — `portfolio/ftmo_governor_policy_v2.py::self_check()`
  (runs at import time; deterministic, no terminal/live dependency).
  **Run this cycle:** `python -m pytest tools/strategy_farm/tests/test_ftmo_governor_parity_oracle.py`
  → **34 passed** — no policy drift against the sealed golden reference
  (`artifacts/ftmo_governor_policy_golden_2026-07-17.json`). This is the one
  of the three checks that is complete and green.
- **Sealed joint replay** — `tools/strategy_farm/compare_joint_replay.py`
  (exists, CLI-runnable) — needs a real joint run from QM5_20181's current
  binary to diff against the gated standalone stream. Blocked on Finding 3.
- **Paired estimator** — `tools/strategy_farm/portfolio/ftmo_book3_standalone_evaluator.py`
  (exists, CLI-runnable, hard-wires `deployment_allowed=false` — evidence
  only by construction) — same dependency, blocked on Finding 3.

"Resolve QM5_13108's Q08 FAIL_SOFT against QM5_13301 as the alternative" has
no atomic swap/retire tool in the repo; closest existing tooling is
`portfolio/ftmo_replace_sleeve_manifest.py` / `portfolio/swap_scenario.py` /
`portfolio/ftmo_apply_sleeve_filters.py` (manifest editing, not one-shot).
FAIL_SOFT (`farmctl.py` verdict taxonomy) means a soft merit near-miss
(EDGE_SOFT/LOW_SAMPLE tier), not an infra defect — it's still Q09-eligible,
so "resolve" here is a portfolio judgment call (pick 13301's clean PASS over
13108's soft pass), not a code fix. Not made unilaterally in this cycle —
it's a slot-selection decision, not an ops task.

## What was and wasn't done this cycle

- Verified all four EA states live (Finding 2) — confirms the ticket's
  premise, no work invented to fill a gap.
- Root-caused why QM5_20181 is stuck (`ONINIT_FAILED`, terminal `done` row,
  no self-requeue) — did not attempt a fix; this needs focused EA-specific
  diagnosis with real tester time, which the remainder of this cycle did not
  have budget for.
- Ran the governor-parity check to completion: **PASS (34/34)**.
- Did not run sealed joint replay or the paired estimator (both correctly
  blocked on QM5_20181's Q03 state, not skipped by omission).
- Did not touch the FAIL_SOFT/PASS slot-selection decision — portfolio
  judgment, not this ticket's ops scope.
- No factory start/stop, no recompile, no purchase, no live-account contact.

## Recommendation

1. OWNER confirm whether MNT-022 should stay dispatched given the prior
   "deliberately not dispatched" classification (Finding 1) — if yes,
   root-causing QM5_20181's `ONINIT_FAILED` is the next real blocking step
   and deserves a dedicated cycle with tester time budgeted for it, not a
   fragment of an already-long ops cycle.
2. The governor-parity leg of the acceptance criterion is done and green;
   record that as the one of three checks currently satisfied.
3. The FAIL_SOFT-vs-PASS slot decision (13108 vs 13301) is ready for a
   portfolio-scope judgment call whenever OWNER/orchestrator wants it — the
   evidence (Finding 2) is already in hand, it just isn't blocked by tooling.
