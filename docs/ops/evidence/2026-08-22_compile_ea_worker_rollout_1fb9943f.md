# COMPILE_EA worker rollout — bounded live-factory canary

Date: 2026-08-22  
Router task: `1fb9943f-1b87-4515-b2b4-f5ca3ffb56f8`  
Branch: `agents/board-advisor`  
Verdict: `SAFE_DEFER_CANARY_PENDING_CAPACITY` — rollout mechanism verified and one canary released; widening is not yet safe because every resident worker owns active Q-only work.

## Outcome

The existing governed `COMPILE_EA` worker remains the only execution path. A new bounded release
utility deactivates only `COMPILE_EA_WORKER_ROLLOUT_PENDING` holds after revalidating the exact
pending/unclaimed row and its enqueued MQ5 SHA-256. It does not claim, dispatch, compile, produce a
gate verdict, or launch/stop a terminal. The normal worker selector, terminal claim/lease,
ownership CAS, include-mirror mutex, compile evidence, and completion transition remain binding.

Live inventory at rollout start:

| Class | Count |
|---|---:|
| Held pending COMPILE_EA rows | 92 |
| Source-fresh | 90 |
| SHA-stale, retained under hold | 2 |
| Canary holds released | 1 |
| Canary compiled/failed | 0 / 0 |
| Wider-wave holds released | 0 |

The stale rows are `QM5_12946` (`ae9e93a6-4a77-4ac9-bd11-e9ec1363bc60`) and `QM5_41097`
(`d646713d-c8ba-41ef-98f4-9b544780e714`). They were not exposed to a worker. They require the
sanctioned supersede/cancel path and a fresh enqueue bound to the current source hash.

The released canary is `QM5_12932_wyckoff-phase-e-markdown-continuation-h4`, work item
`03cdfa65-e9e6-4673-8599-d4f6c5710991`. Its hold release is recorded in
`work_item_transition_ledger` and `events`; a pre-mutation SQLite backup was written to
`D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260822T041123Z_410b4813.sqlite`
with SHA-256 `3c793e7e2a8203575c9d7993469a9f1ff12c71c1e6ca1d25c31bdd9e06b5d681`.

## Live contention result

At the post-release check, T1–T9 each owned an active Q-only work item and T10 had no resident
worker. The factory was CPU-saturated and workers were correctly observing their CPU/commit
headroom pauses. The canary therefore stayed `pending`, unheld, unclaimed, with no EX5, no
setfiles, no evidence path, and no verdict. No active backtest, `terminal64.exe`, AutoTrading, or
T_Live process was interrupted.

This is a safe capacity defer, not a compile result. The acceptance requirement to show the
include mirror deferring busy terminals and then report compiled/failed outcomes cannot be
claimed until the canonical worker naturally acquires a quiescent slot. Widening before that
first evidence exists would defeat the bounded-canary requirement.

## Verification

Focused regression:

```text
python -m pytest tools/strategy_farm/tests/test_release_compile_wave.py \
  tools/strategy_farm/tests/test_compile_work_items.py \
  tools/strategy_farm/tests/test_include_mirror.py -q
11 passed in 3.43s

python -m py_compile tools/strategy_farm/release_compile_wave.py
PASS
```

The canary setfile/guardrail checks remain pending with its worker execution. The underlying
worker contract continues to generate `RISK_FIXED=1000`, `RISK_PERCENT=0` and invoke strict
`build_check.ps1 -EALabel <exact-label>`; no guardrail was weakened here.

Durable receipts:

- `docs/ops/evidence/2026-08-22_compile_ea_rollout_wave0_plan.json`
- `docs/ops/evidence/2026-08-22_compile_ea_rollout_wave1_apply.json`

## Required continuation

1. Wait for the released canary to reach `done/COMPILE_OK` or `failed/COMPILE_FAIL` through the
   canonical worker; do not start or stop terminals to accelerate it.
2. Verify its `compile_evidence.json` records the claimed terminal, busy-terminal deferrals,
   include-mirror mutex path, atomic replacement, strict build-check result, fixed-risk setfiles,
   and failure classes.
3. Only after that evidence, release the next source-fresh bounded wave and repeat. Keep the two
   stale rows held until their exact supersede/cancel and fresh enqueue are complete.

No pipeline or gate verdict is asserted by this artifact.
