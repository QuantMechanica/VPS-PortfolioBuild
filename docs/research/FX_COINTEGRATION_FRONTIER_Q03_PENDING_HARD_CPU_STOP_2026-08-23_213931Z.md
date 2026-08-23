# FX cointegration frontier: existing Q03 continuation / hard CPU stop

**Date:** 2026-08-23 UTC (`2026-08-23T21:39:31Z`), Europe/Berlin

**Branch:** `agents/board-advisor`

**Status:** frozen 66-pair frontier remains fully mechanized; one concrete
existing FX pair is already advanced to an exact v4 Q03 row; stopped at the
explicit backtest CPU ceiling

## Outcome

No new Strategy Card or EA was created. The durable sign-aware relationship
audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships produced by
`analyze_cross_asset_v3.py --include-negative-hedges`: 66 covered and zero
uncovered. A new scan-derived identity would duplicate governed work.

The preferred anchors do not need Q02 infrastructure repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.

Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

## One concrete existing-pair continuation

The strongest nonterminal scan relationship with an exact current successor
is rank 40, `USDJPY.DWX` / `NZDUSD.DWX`, implemented as
`QM5_20219_usdjpy-nzdusd`. Higher-ranked relationships are either terminal at
an economic gate or already represented by an open successor.

This sleeve remains within the requested contract:

- OWNER-approved, Tier-A Chan source lineage at
  `decisions/2026-08-05_usdjpy_nzdusd_cointegration_g0.md`;
- structural fixed-beta two-leg D1 logic with no ML or banned indicator;
- required `basket_manifest.json` for `USDJPY.DWX` and `NZDUSD.DWX`; and
- canonical backtest risk of `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

Fresh supported work-item evidence shows:

- Q02 `5eb61981-472e-4f08-82c0-53fbec77d6c8`: DONE/PASS.
- Q03 `4514a6c7-0a2e-4523-a756-b63a232dd8aa`: PENDING, unclaimed,
  `attempt_count=0`, v4, `priority_track=true`, and hash-bound to the current
  EX5/MQ5/fixed-risk setfile.
- Legacy Q04 `b721ce82-2d53-46db-b2d0-f20b561a1513`: PENDING, unclaimed,
  `attempt_count=0`.

The Q03 row was created at `2026-08-23T18:59:50Z`, after the preceding
frontier receipt selected now-terminal `QM5_20208`. It is already the exact
non-duplicate continuation, so no enqueue, requeue, priority restamp, or
second work item was valid.

## Binding capacity stop

The supported `farmctl mt5-slots` snapshot at `2026-08-23T21:39:19Z`
observed two governed factory terminals actively testing: T1 and T3. The
paced launch gate in `D:/QM/strategy_farm/state/launch_gate_max.txt` is `1`,
so launch capacity was already exceeded.

Five current whole-host CPU readings were `98.5041%`, `88.4139%`, `67.8828%`,
`57.8660%`, and `65.4909%`. Their average was `75.6315%`, but their maximum
was `98.5041%`. The explicit ceiling binds when either the average or maximum
is at least `97%`; the maximum therefore triggered the required stop.
`T_Live` and the unrelated FTMO terminal were observed only to exclude them
from the factory count; neither was controlled.

Per the mission stop condition, no queue mutation, dispatch tick, tester
launch, terminal reservation, terminal control, compile, or backtest followed.
Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_q03_pending_hard_cpu_stop_20260823T213931Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- No Card, EA, EX5, setfile, basket manifest, registry row, or magic row
  changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
