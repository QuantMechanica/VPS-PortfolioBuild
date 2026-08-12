# QM5_20198_xng-tue-bear - Strategy Spec

**EA ID:** QM5_20198
**Slug:** `xng-tue-bear`
**Strategy ID:** `BOROWSKI-MOP-XNG-TUEBEAR-2026_S01`
**Source:** `BOROWSKI-MOP-XNG-TUEBEAR-2026`
**Author:** Codex
**Last revised:** 2026-08-01

## 1. Strategy Logic

On the first observed tick within five minutes of a genuine Tuesday D1 bar
immediately following a Monday D1 bar, the EA computes XNG's completed 252-D1
log return. It opens one long `XNGUSD.DWX` position only when that return is
strictly negative, testing the source-observed Tuesday direction as a
bear-regime bounce.

The package uses a frozen `3.0 * ATR(20)` hard stop, no profit target, and a
two-day stale repair. The first non-Tuesday D1 bar is the ordinary exit. The
broker week is consumed before fallible gates, so a non-qualifying state,
rejection, blocked gate, stop, or restart cannot retry the week.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 252 | locked | completed XNG return horizon |
| `strategy_min_abs_return_pct` | 0.0 | locked | strict negative sign; no deadband |
| `strategy_entry_grace_minutes` | 5 | locked | Tuesday-bar attachment limit |
| `strategy_atr_period` | 20 | locked | completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.0 | locked | frozen hard-stop distance |
| `strategy_max_hold_days` | 2 | locked | missed-next-bar stale repair |
| `strategy_max_spread_points` | 2500 | locked | maximum entry spread |

There is no Q02 parameter sweep.

## 3. Symbol Universe

- Designed only for registered `XNGUSD.DWX`, magic slot 0, magic `201980000`.
- Metals, equity indices, FX, WTI, Brent, and symbol substitution are outside
  this build.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Calendar gate | current broker bar Tuesday; prior completed bar Monday |
| Decision cadence | at most one consumed attempt per broker week |
| State | completed `ln(Close[1] / Close[253]) < 0` |
| Holding period | Tuesday session; maximum two calendar days |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades/year | approximately 12-30; retire below five/year on average |
| Direction | long-only in a negative 252-D1 return state |
| Drawdown profile | high: XNG gaps and persistent bear trends |
| Source strength | weak Tuesday-specific lead; Q02 is authoritative |
| Diversification | unproven until downstream portfolio evidence |

## 6. Source Citation

The bounded composite source packet is
`strategy-seeds/sources/BOROWSKI-MOP-XNG-TUEBEAR-2026/source.md`. Borowski
(2016) supplies the positive Tuesday natural-gas sample direction; Moskowitz,
Ooi, and Pedersen (2012) supply the completed own-return state. The
countertrend conjunction and all CFD execution choices are QM hypotheses.

## 7. Risk Model

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Friday close remains enabled at broker hour 21 as a fail-safe; all news axes
are OFF for the native-price baseline. The framework kill switch, frozen
broker stop, attempt marker, position/deal history, next-D1 exit, and stale
repair remain active.

No live setfile, AutoTrading, T_Live, deployment, certification, portfolio
admission, correlation waiver, portfolio-gate change, or live-manifest change
is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-01 | initial approved XNG Tuesday bear-regime carrier | Q01 PASS: strict compile and V5 build check, 0 errors/warnings |
