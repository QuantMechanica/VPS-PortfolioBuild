# QM5_20248_xng-vr-window - Strategy Spec

**EA ID:** QM5_20248

**Slug:** `xng-vr-window`

**Source:** `SUENAGA-MEHLITZ-XNG-VRWIN-2026`

**Author:** Research+Development

**Last revised:** 2026-08-06

## 1. Strategy Logic

On the first tradable `XNGUSD.DWX` D1 bar of each eligible broker month,
reconstruct thirty-three consecutive completed broker-month closes and form
thirty-two chronological log returns. Estimate the published `q=2`
heteroskedasticity-robust variance-ratio z-statistic. The eligible physical-
volatility windows are May-September and November-January; all other months
remain flat.

Trade only when the memory statistic is significant at the fixed two-sided
10% boundary and the latest completed monthly return is nonzero. A positive z
follows that latest-return direction; a negative z reverses it. Insignificant
memory or invalid history consumes the eligible month flat. Close the prior
package before each monthly decision. Persist every eligible attempted month
before fallible gates so a blocked, stopped, failed, or flat attempt cannot
retry after restart. Use a frozen `3.0 * ATR(20,D1)` hard stop, no target, and
a forty-day stale guard. Friday close is disabled for the monthly hold.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_vr_window_months` | 32 | Robust variance-ratio sample |
| `strategy_vr_q` | 2 | Published short-memory order |
| `strategy_significance_z` | 1.64485362695147 | Two-sided 10% critical value |
| `strategy_summer_start_month` | 5 | First summer-window proxy month |
| `strategy_summer_end_month` | 9 | Last summer-window proxy month |
| `strategy_winter_start_month` | 11 | First winter-window proxy month |
| `strategy_winter_end_month` | 1 | Last winter-window proxy month |
| `strategy_history_bars` | 1200 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.0 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | Maximum XNG entry spread |

Every strategy value is locked for Q02. No baseline parameter sweep is
authorized.

## 3. Symbol Universe

- Exact carrier: `XNGUSD.DWX`.
- Magic slot: 0 (`202480000`).
- No companion symbol, futures curve, storage release, weather input, or
  external runtime input.

## 4. Timeframe

- Exact timeframe: D1.
- Decision clock: first processed D1 bar of each new broker month.
- Eligible months: May-September and November-January.
- Formation: thirty-three consecutive completed broker-month endpoints.
- Direction: latest completed return sign multiplied by the significant
  robust `q=2` memory-state sign.

## 5. Expected Behaviour

Maximum cadence is eight eligible consumed decisions per full post-warm-up
year. The predeclared expectation is 5-7 completed packages/year; Q02 retires
below five per full post-warm-up year. Exposure normally spans one broker
month. Principal risks are XNG gaps and rolls, futures-to-CFD basis, financing,
weather shocks, sparse memory significance, the coarse full-month window
translation, anti-persistent reversals, stop-outs, and realized book
correlation.

This is not `QM5_12567`'s two-day long-only cumulative-RSI pullback or
`QM5_20242`'s twelve-sign probability rule. Its load-bearing information
object is a statistically significant serial-dependence state applied to the
latest monthly return only inside the physical-volatility windows.

## 6. Source Citation

Suenaga, H., Smith, A., and Williams, J. C. (2008), "Volatility Dynamics of
NYMEX Natural Gas Futures Prices," *Journal of Futures Markets* 28(5),
438-463, DOI `10.1002/fut.20317`.

Mehlitz, J. S., and Auer, B. R. (2024), "Memory-enhanced momentum in commodity
futures markets," *The European Journal of Finance* 30(8), 773-802, DOI
`10.1080/1351847X.2023.2220118`.

The governed composite record is
`strategy-seeds/sources/SUENAGA-MEHLITZ-XNG-VRWIN-2026/source.md`; the approved
card is `strategy-seeds/cards/approved/QM5_20248_xng-vr-window_card.md`. The
papers supply the parent states, not this conjunction's CFD performance,
drawdown, costs, density, or portfolio correlation.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes and Friday close are OFF. Every trade has
a server-side ATR hard stop. There is no manual backtest, live/demo/shadow
setfile, live authorization, deploy manifest, portfolio admission, or
portfolio-gate change.

## 8. Framework Alignment

- **No trade:** exact host/timeframe/ID/slot, locked inputs, news/Friday
  contract, month boundary, physical-window gate, attempt state, history,
  arithmetic, significance, spread, quote, ATR, and stop guards.
- **Trade entry:** thirty-three endpoint reconstruction, robust memory test,
  latest-return direction, follow/reverse mapping, registered magic, V5
  fixed-risk sizing, and frozen hard stop.
- **Trade management:** prior-month, off-window, and forty-day stale closes
  before entry-only gates.
- **Trade close:** framework close helper, broker hard stop, and kill switch.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-06 | Initial build from approved G0 card | strict compile/build PASS; zero errors, warnings, failures, or build warnings |
| v1.1 | 2026-08-06 | Paced Q02 handoff | one priority Q02 work item pending; no manual tester or dispatch |
