# QM5_1070 FX Relative Carry Q02 Repair

Date: 2026-07-09
Branch: `agents/board-advisor`
Agent: `codex:agents/board-advisor`

## Scope

- EA: `QM5_1070_carver-relative-carry`
- Card/source: approved Rob Carver relative-carry FX basket card.
- Instrument diversity: D1 FX carry basket (`AUDJPY.DWX`, `AUDUSD.DWX`,
  `GBPJPY.DWX`, `GBPUSD.DWX`, `NZDJPY.DWX`, `USDCAD.DWX` requeued).
- Reason for selecting: no feasible high-diversity approved backlog build was
  available; these diverse FX sleeves were latest-state Q02 `INFRA_FAIL` and
  had not already progressed to Q03/Q04.

## Repair

- Claimed the work in the farm DB with lease
  `manual:codex:agents/board-advisor:QM5_1070:q02-setfile-conformance-requeue`.
- Fixed the DWX zero-spread guard in `CurrentSpreadWithinCap()` so zero or
  missing tester spread data is tradeable, while genuinely wide positive spread
  still blocks entries.
- Verified all nine RISK_FIXED D1 setfiles explicitly pin the strategy inputs
  from the approved card/spec:
  `strategy_entry_forecast`, `strategy_vol_span_days`, `strategy_atr_period`,
  `strategy_atr_stop_mult`, `strategy_min_valid_symbols`,
  `strategy_max_positions`, `strategy_spread_median_days`,
  `strategy_spread_cap_mult`, `strategy_forecast_scalar`,
  `strategy_forecast_cap`, `strategy_swap_days_per_year`, and
  `strategy_rebalance_hour`.
- Recompiled the EA and refreshed setfile `build_hash` values.

## Q02 Requeue

Requeued these latest-state `INFRA_FAIL` Q02 work items to `pending`:

| Symbol | Work item |
|---|---|
| `AUDJPY.DWX` | `de97eaba-7895-4480-8c5a-d481ed488ea0` |
| `AUDUSD.DWX` | `582e7bc9-7700-4e59-8066-6b798ad242b3` |
| `GBPJPY.DWX` | `143432e3-589f-4567-9b55-1d0109297233` |
| `GBPUSD.DWX` | `f46cc363-e40e-4630-9ff3-826ac843cc0b` |
| `NZDJPY.DWX` | `2fc1db25-03aa-4ba2-8a77-9fcf908239c1` |
| `USDCAD.DWX` | `bfecb687-4de0-4d68-b764-d280b24020a5` |

Did not requeue:

- `EURUSD.DWX`: already reached Q03 PASS and Q04 FAIL.
- `NZDUSD.DWX`, `USDJPY.DWX`: latest Q02 result was strategy
  `MIN_TRADES_NOT_MET`, not infra.

## Verification

- `compile_one.ps1 -EAPath framework/EAs/QM5_1070_carver-relative-carry/QM5_1070_carver-relative-carry.mq5`
  - PASS, 0 errors, 0 warnings.
- `build_check.ps1 -EALabel QM5_1070_carver-relative-carry -Strict -SkipCompile`
  - PASS, 0 failures, 2 warnings.
  - Remaining warnings are the known swap-signal review advisories for this
    carry EA; the prior DWX zero-spread warning is gone.
- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_1070_carver-relative-carry`
  - PASS.
- Targeted setfile conformance check:
  - checked 9 setfiles.
  - failures: none.

## Guards

- No backtest was run in this repair turn.
- No `T_Live` files touched.
- No AutoTrading setting touched.
- No portfolio gate touched.
- No live manifest touched.
