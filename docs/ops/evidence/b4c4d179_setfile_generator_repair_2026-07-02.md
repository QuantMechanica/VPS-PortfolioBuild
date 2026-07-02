# Setfile Generator Repair Evidence

Task: `b4c4d179-b4a0-4533-952b-7331c6f3dc06`
Date: 2026-07-02

## Scope

The live generator at `C:\QM\repo\framework\scripts\gen_setfile.ps1` already contains the required repaired behavior in the current worktree state:

- Searches approved/runtime card roots, including `D:\QM\strategy_farm\artifacts\cards_approved`.
- Resolves exact approved card filenames such as `QM5_12836_turnaround-tuesday-ws30.md`.
- Emits `qm_ea_id=<id>`.
- Omits the dead `qm_filter_*` block.
- Appends card/default strategy inputs that match EA inputs.

I regenerated the standard `QM5_12846` Q02 set through that generator and cleaned special non-standard set names that the standard generator cannot produce.

## Setfile Fixes

- Regenerated:
  - `QM5_12846_euro-night-mr-eurusd_EURUSD.DWX_H1_backtest.set`
- Cleaned special setfiles without changing strategy or risk values:
  - `QM5_12567_cum-rsi2-commodity_XAUUSD.DWX_D1_prop_ftmo_scale8_equiv_backtest.set`
  - `QM5_12567_cum-rsi2-commodity_XNGUSD.DWX_D1_prop_ftmo_scale8_equiv_backtest.set`
  - `QM5_12821_twin-csm-basket_FX8_TWIN_CSM_BASKET_H1_H1_backtest.set`
- Verified already-clean affected standard sets for:
  - `QM5_12836`
  - `QM5_12847`
  - `QM5_12567`
  - `QM5_12845`
  - `QM5_12821`

## Verification

Focused setfile scan across `QM5_12836`, `QM5_12847`, `QM5_12567`, `QM5_12845`, `QM5_12821`, and `QM5_12846`:

- No `qm_filter_*` dead keys.
- No `card_defaults_source=not_found`.
- Every `*backtest.set` has `qm_ea_id=...`.
- Every checked backtest set has `RISK_FIXED > 0` and `RISK_PERCENT = 0`.

Guardrails:

- `python tools/strategy_farm/validate_build_guardrails.py` on modified EA directories returned `PASS`.

Generator smoke:

- `& C:\QM\repo\framework\scripts\gen_setfile.ps1 -EaSlug QM5_12846_euro-night-mr-eurusd -Symbol EURUSD.DWX -TF H1 -Env backtest -RiskFixed 1000 -RiskPercent 0 -PortfolioWeight 1.0`
- Result: `status=ok`, card path resolved to `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12846_euro-night-mr-eurusd.md`.
