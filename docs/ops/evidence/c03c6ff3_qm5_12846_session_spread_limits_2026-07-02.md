# QM5_12846 Session/Spread/Symmetric-Limit Fix Evidence

Task: `c03c6ff3-b9e2-4bd2-8e8d-30b807fcdef4`
EA: `QM5_12846_euro-night-mr-eurusd`
Date: 2026-07-02

## Changes

- Corrected Davey overnight session mapping under DXZ ET+7:
  - `strategy_entry_start_hour=1` for 18:00 ET.
  - `strategy_entry_end_hour=8` for 01:00 ET.
  - `strategy_exit_hour=14` for 07:00 ET.
- Added `strategy_max_spread_points=50` and skip new paired-limit placement when current spread exceeds the cap.
- Replaced the one-sided limit selection path with paired buy/sell limit placement via `QM12846_OpenSymmetricLimits()`.
- Added partial-abort cleanup if either side of the pair fails to place, and OCO cleanup when a position exists with a remaining pending order.
- Reordered `OnTick` so Friday close, management, and time-exit handling run before the news blackout gates new entries.
- Updated `SPEC.md`, approved runtime card, and regenerated the EURUSD Q02 set.

## Verification

- Compile: `python tools/strategy_farm/compile_ea.py --ea-label QM5_12846_euro-night-mr-eurusd --force --json`
  - Verdict: `COMPILED`
  - Errors: `0`
  - Warnings: `0`
  - Ex5: `C:\QM\repo\framework\EAs\QM5_12846_euro-night-mr-eurusd\QM5_12846_euro-night-mr-eurusd.ex5`
  - Compile log: `C:\QM\repo\framework\build\compile\20260702_054313\QM5_12846_euro-night-mr-eurusd.compile.log`
- Guardrails: `PASS`
  - `qm_news_stale_max_hours=336`
  - Backtest set uses `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Setfile:
  - `qm_ea_id=12846`
  - `card_defaults_source=D:\QM\strategy_farm\artifacts\cards_approved\QM5_12846_euro-night-mr-eurusd.md`
  - `strategy_entry_start_hour=1`
  - `strategy_entry_end_hour=8`
  - `strategy_exit_hour=14`
  - `strategy_max_spread_points=50`

Q02 had not run for this EA, so no invalidation was required.
