# QM5_41021_wti-mdual-mom - Strategy Spec

**EA ID:** QM5_41021  
**Slug:** `wti-mdual-mom`  
**Strategy ID:** `MOP-WTI-MDUAL-MOM-2026_S01`  
**Source:** `MOP-WTI-MDUAL-MOM-2026`  
**Author:** Codex  
**Last revised:** 2026-08-16

## 1. Strategy Logic

On the first executable `XTIUSD.DWX` D1 tick of a new broker month, the EA
reconstructs the immediately completed broker-month return and that same
month's final five close-to-close intervals. It enters only when both return
signs strictly agree: long for two positive returns and short for two negative
returns. Disagreement or exact zero consumes the month flat.

The attempt is persisted before fallible gates. A position receives a frozen
`3.5 * ATR(20,D1)` hard stop, no target, and closes at the first tick of the
sixth D1 bar in the entry month. Friday close is disabled to preserve the
five-session hold.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_closing_intervals` | 5 | nested final prior-month intervals |
| `strategy_hold_bars` | 5 | completed entry-month bars before close |
| `strategy_entry_grace_minutes` | 5 | first-new-month attachment limit |
| `strategy_history_bars` | 80 | bounded two-month endpoint scan |
| `strategy_atr_period` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 12 | stale-position guard |
| `strategy_max_spread_points` | 1500 | entry spread ceiling |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- `XTIUSD.DWX` only.
- Magic slot 0, magic `410210000`.
- No secondary symbol, logical basket, or runtime symbol substitution.

## 4. Timeframe

- Host and signal timeframe: D1.
- Decision cadence: one consumed attempt per broker month.
- Formation: the complete prior broker month plus its final five completed
  close-to-close intervals.
- Hold: first five completed D1 bars of the entry broker month.

## 5. Expected Behaviour

- Approximately 6-10 positions per full post-warm-up year after strict sign
  agreement.
- Symmetric long/short direction; disagreement and exact zero remain flat.
- One fixed-risk backtest position at a time.
- Q02 retires below five completed positions per full year.

## 6. Source Citation

Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), "Time
Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The complete governed review is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the bounded translation is
`strategy-seeds/sources/MOP-WTI-MDUAL-MOM-2026/source.md`.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The hard stop is the only lot-sizing distance. Signal
magnitude never scales risk. Both news axes and framework Friday close are OFF
for the locked native-price five-session carrier; the kill switch and strategy
exits remain active.

No live setfile, AutoTrading, T_Live, deploy manifest, portfolio admission,
correlation waiver, portfolio-gate change, or live-manifest change is
authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-16 | initial approved build scaffold | G0 approved |
| v1-build | 2026-08-16 | deterministic implementation | magic/resolver verified; strict compile and build check PASS |
| v1-queue | 2026-08-16 | Q02 baseline enqueue | one fixed-risk XTIUSD.DWX D1 work item pending |
