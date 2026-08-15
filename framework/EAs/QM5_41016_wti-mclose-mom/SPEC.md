# QM5_41016_wti-mclose-mom - Strategy Spec

**EA ID:** QM5_41016  
**Slug:** `wti-mclose-mom`  
**Strategy ID:** `MOP-WTI-MCLOSE-MOM-2026_S01`  
**Source:** `MOP-WTI-MCLOSE-MOM-2026`  
**Author:** Codex  
**Last revised:** 2026-08-15

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 tick of a new broker month, the EA
requires the six immediately preceding completed bars to belong to the prior
broker month. It follows the sign of `log(Close[1] / Close[6])`, entering long
after a positive final-five-interval return and short after a negative return.

The month is consumed before fallible gates. The position receives a frozen
`3.5 * ATR(20,D1)` hard stop, no target, and closes at the first tick of the
sixth D1 bar in the entry month. Friday close is disabled to preserve the
five-session hold.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_formation_intervals` | 5 | final prior-month return intervals |
| `strategy_hold_bars` | 5 | completed entry-month bars before close |
| `strategy_entry_grace_minutes` | 5 | first-new-month attachment limit |
| `strategy_history_bars` | 40 | bounded D1 history scan |
| `strategy_atr_period` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 12 | stale-position guard |
| `strategy_max_spread_points` | 1500 | entry spread ceiling |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- `XTIUSD.DWX` only.
- Magic slot 0, magic `410160000`.
- No secondary symbol, logical basket, or runtime symbol substitution.

## 4. Timeframe

- Host and signal timeframe: D1.
- Decision cadence: one consumed attempt per broker month.
- Formation: final five completed close-to-close intervals of the immediately
  prior broker month.
- Hold: first five completed D1 bars of the entry broker month.

## 5. Expected Behaviour

- Approximately twelve positions per full post-warm-up year.
- Symmetric long/short direction from the formation return sign.
- One fixed-risk backtest position at a time.
- Q02 retires below five completed positions per full year.

## 6. Source Citation

Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), "Time
Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The complete governed review is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the bounded translation is
`strategy-seeds/sources/MOP-WTI-MCLOSE-MOM-2026/source.md`.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The hard stop is the only lot-sizing distance. Signal
magnitude never scales risk. Both news axes and framework Friday close are OFF
for the locked native-price five-session carrier; the kill switch and
strategy exits remain active.

No live setfile, AutoTrading, T_Live, deploy manifest, portfolio admission,
correlation waiver, portfolio-gate change, or live-manifest change is
authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-15 | initial approved build scaffold | G0 approved |
| v1-build | 2026-08-15 | deterministic implementation | magic/resolver verified; strict compile and build check PASS |
