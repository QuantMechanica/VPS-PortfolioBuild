# QM5_13010_xti-cadjpy-rspr - Strategy Spec

**EA ID:** QM5_13010
**Slug:** `xti-cadjpy-rspr`
**Source:** `EIA-BOC-BOJ-XTI-CADJPY-2026`
**Card:** `strategy-seeds/cards/xti-cadjpy-rspr_card.md`
**Period:** D1
**Runtime feed:** Darwinex MT5 OHLC only

## Strategy

Two-leg D1 return-spread reversion basket on `XTIUSD.DWX` and `CADJPY.DWX`.
On each new D1 host bar the EA computes:

`log(XTI[t] / XTI[t-L]) - beta_cadjpy * log(CADJPY[t] / CADJPY[t-L])`

A high positive z-score means WTI has outperformed CADJPY over the fixed return
window, so the basket sells WTI and buys CADJPY. A high negative z-score buys
WTI and sells CADJPY. The package exits when the z-score reverts inside the
exit band, the max-hold guard fires, Friday close fires, or a broken basket is
detected.

This differs from `QM5_1040_singh-cmd-corr`, which trades CADJPY from oil
support/resistance breakouts and does not trade WTI as a paired basket leg. It
also differs from WTI/USDCAD, WTI/USDJPY, WTI/NZD, XTI/XNG, Brent/WTI, oil/gold,
oil/silver, XAU/XAG, XNG, and index sleeves.

## Parameters

| Input | Default | Role |
|---|---:|---|
| `strategy_return_lookback_d1` | 20 | Return window for both legs |
| `strategy_z_lookback_d1` | 120 | Rolling normalization window |
| `strategy_beta_cadjpy` | 0.65 | CADJPY return multiplier and risk-weight proxy |
| `strategy_entry_z` | 1.9 | Absolute z-score entry threshold |
| `strategy_exit_z` | 0.4 | Mean-reversion exit band |
| `strategy_atr_period_d1` | 20 | ATR stop lookback |
| `strategy_atr_sl_mult` | 3.0 | Per-leg hard stop distance |
| `strategy_max_hold_days` | 30 | Stale package timeout |
| `strategy_xti_max_spread_pts` | 1000 | WTI spread cap |
| `strategy_cadjpy_max_spread_pts` | 120 | CADJPY spread cap |

## Framework Mapping

- No-trade: host chart guard, D1 guard, parameter guard, spread caps, news,
  Friday close, and symbol guard.
- Entry: two-leg basket entry through `QM_BasketOrder` when the return spread
  z-score crosses the entry threshold.
- Management: broken-package repair and max-hold tracking.
- Close: z-score mean exit, max-hold exit, Friday close, and ATR hard stops.

## Risk And Queue

- Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Logical basket setfile: `QM5_13010_XTI_CADJPY_RSPREAD_D1`.
- Slot 0: `XTIUSD.DWX`.
- Slot 1: `CADJPY.DWX`.
- No live setfile, `T_Live` manifest, AutoTrading action, portfolio gate, or
  portfolio admission code is touched by this build.
