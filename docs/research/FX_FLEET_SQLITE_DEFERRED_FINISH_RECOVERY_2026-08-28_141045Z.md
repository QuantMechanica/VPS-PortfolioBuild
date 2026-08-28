# FX fleet — completed-result recovery clears the basket lane

Date: 2026-08-28 UTC (`2026-08-28T14:10:45.8355382Z`); 2026-08-28
16:10 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `a3c14fb98e0c502ff86ec6fe0863676a751ca979`

Status: completed a non-duplicate runtime recovery and durable fleet fix. The
new FX fallback `QM5_41140` remains exactly once in the Q02 queue, pending the
normal paced selector. No tester was launched in this run.

## Frontier and preferred-anchor disposition

The frozen sign-aware 66-relationship FX cointegration frontier is already
fully covered. A fresh repository census found 706 approved Cards and zero
approved Cards without a matching EA directory. The preferred anchors also
do not need ONINIT or NO_HISTORY repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, then Q04 PASS and Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Creating another Card or EA from the same scan would therefore be duplicate
work. The Strategy Card extraction and EA-build skill gates correctly remained
closed.

The concrete existing-forex fallback is
`QM5_41140_NZDJPY_CARRY_UNWIND_CRISIS_MOMENTUM_D1`. Its G0-approved Card cites
Brunnermeier, Nagel and Pedersen (2009), *Carry Trades and Currency Crashes*,
NBER Macroeconomics Annual 23, DOI `10.1086/593088`. It is structural,
closed-D1, non-ML logic. Its basket manifest declares AUDJPY, NZDJPY, CADJPY,
and EURJPY as synchronized signal inputs and only NZDJPY as traded. The sealed
logical setfile keeps `RISK_FIXED=1000` and `RISK_PERCENT=0`.

The fallback already has COMPILE_EA `COMPILE_OK` and one Q02 row,
`381b2608-c3f1-4493-88f8-9ed119e61d69`, pending with attempt count zero. No
duplicate enqueue or priority mutation was made.

## Deterministic blocker recovery

The multisymbol admission lane was occupied by
`QM5_41083_XAU_XAG_WLEGDIV_RV_D1`, work item
`5beefa38-44e0-4c60-89d0-0f487fb47ba7`, recorded active on T1. Read-only
inspection found that its test had actually completed hours earlier:

- identity-bound summary timestamp: `2026-08-28T09:08:26.5730333Z`;
- summary SHA-256:
  `8ff3d84702c9a5bf81385b72c0936ec1cb983fe329f20de6b8189188279e6e9d`;
- result: PASS, 62 trades, reason class `OK`, no ONINIT failure;
- no T1 terminal process remained;
- the resident worker log recorded
  `reason=sqlite_locked_finish_deferred` for this exact item.

The worker had published complete evidence but lost the final SQLite status
write under contention. Its next loop then saw its own still-live worker PID
and declined forever as `terminal_worker_busy`.

Using the worker's normal `_finish_work_item` classifier against that existing
summary recovered the row to canonical `done/PASS`, cleared `claimed_by`, and
bound the summary as its evidence path. No rerun, attempt increment, terminal
launch, or manufactured verdict occurred. This removed the stale logical
multisymbol gate without bypassing a live test.

## Durable fleet fix

`terminal_worker.claim_atomic` now checks for this narrow state before taking
another claim. It will recover only when:

- the active row belongs to the same terminal;
- the recorded child process is no longer alive; and
- the summary passes the existing claim-time and execution-evidence freshness
  checks.

Missing summaries, stale summaries, live children, and SQLite contention stay
fail-closed. After a successful recovery, the same ordinary claim cycle may
select the next eligible work item. This prevents future completed results
from wedging a terminal and the globally serialized basket lane.

Verification:

- `python -m py_compile` on the worker and regression test: PASS.
- `git diff --check`: PASS.
- `python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q --tb=short`:
  71 passed in 44.82 seconds.

The regression constructs a claim-fresh completed row plus a second pending
row and proves that the first becomes `done/PASS` before the second is claimed.

## Capacity and handoff

The initial five-sample CPU window averaged `75.084103%` and peaked at
`87.211981%`. The final window averaged `87.357322%` and peaked at
`96.505099%`. Both measures stayed strictly below the governed 97% ceiling.

QM5_41140 remained pending at the final snapshot because ordinary fleet SQLite
and mutation-lock contention had not yet yielded a paced claim. That is not
authority to bypass the selector. Leave its existing Q02 row in place; the
resident fleet may claim it after its normal CPU, memory, commit, lock, and
multisymbol checks pass.

No portfolio gate, `portfolio_admission`, `_kpi`, `_q08_contribution`, T_Live
manifest or terminal, AutoTrading state, live/deploy artifact, EA, Card,
registry, magic row, setfile, basket manifest, queue priority, or extra Q02 row
was changed. Concurrent unrelated worktree changes were preserved and excluded
from this commit.

Machine-readable evidence is in
`artifacts/fx_fleet_sqlite_deferred_finish_recovery_20260828T141045Z_board_advisor.json`.
