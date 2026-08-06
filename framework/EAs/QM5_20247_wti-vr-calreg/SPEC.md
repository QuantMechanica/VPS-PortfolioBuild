# QM5_20247_wti-vr-calreg - Strategy Spec

**EA ID:** QM5_20247

**Slug:** `wti-vr-calreg`

**Source:** `BURAKOV-MEHLITZ-WTI-VRCAL-2026`

**Author:** Research+Development

**Last revised:** 2026-08-06

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of every broker month, reconstruct
thirty-three consecutive completed broker-month closes and form thirty-two
chronological log returns. Estimate the published `q=2`
heteroskedasticity-robust variance-ratio z-statistic over all thirty-two
returns. Independently map the current broker month to the source-defined
physical-season state: November-May long and June-October short.

Trade only when the memory statistic is significant at the fixed two-sided
10% boundary. A positive z follows the calendar direction; a negative z
reverses it. Insignificant memory or invalid history consumes the month flat.
Close the prior package before each monthly decision. Persist every attempted
month before fallible gates so a blocked, stopped, failed, or flat attempt
cannot retry after restart. Use a frozen `3.0 * ATR(20,D1)` hard stop, no
target, and a forty-day stale guard. Friday close is disabled for the monthly
hold.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_vr_window_months` | 32 | Robust variance-ratio sample |
| `strategy_vr_q` | 2 | Published short-memory order |
| `strategy_significance_z` | 1.64485362695147 | Two-sided 10% critical value |
| `strategy_winter_start_month` | 11 | First alternative-two winter month |
| `strategy_winter_end_month` | 5 | Last alternative-two winter month |
| `strategy_history_bars` | 1200 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.0 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | Maximum WTI entry spread |

Every strategy value is locked for Q02. No baseline parameter sweep is
authorized.

## 3. Symbol Universe

- Exact carrier: `XTIUSD.DWX`.
- Magic slot: 0 (`202470000`).
- No companion symbol, futures curve, inventory release, or external input.

## 4. Timeframe

- Exact timeframe: D1.
- Decision clock: first processed D1 bar of every new broker month.
- Formation: thirty-three consecutive completed broker-month endpoints.
- Memory state: robust `q=2` z-statistic across thirty-two chronological
  returns.
- Calendar state: November-May long; June-October short.

## 5. Expected Behaviour

Maximum cadence is twelve consumed decisions per full post-warm-up year. The
predeclared expectation is 6-10 completed packages/year; Q02 retires below
five per full post-warm-up year. Exposure normally spans one broker month.
Principal risks are WTI gaps and rolls, futures-to-CFD basis, financing, sparse
memory significance, anti-persistent reversals, seasonal decay, stop-outs, and
realized book correlation.

This is not unconditional WTI seasonality, the existing one-month-sign
variance-ratio rule, the twelve-sign variance-ratio rule, or any cumulative
trend/calendar concordance sleeve. Its load-bearing information object is the
application of a statistically significant serial-dependence regime to the
alternative-two physical-season direction.

## 6. Source Citation

Burakov, D., Freidin, M., and Solovyev, Y. (2018), "The Halloween Effect on
Energy Markets: An Empirical Study," *International Journal of Energy
Economics and Policy* 8(2), 121-126.

Mehlitz, J. S., and Auer, B. R. (2024), "Memory-enhanced momentum in commodity
futures markets," *The European Journal of Finance* 30(8), 773-802, DOI
`10.1080/1351847X.2023.2220118`.

The governed composite record is
`strategy-seeds/sources/BURAKOV-MEHLITZ-WTI-VRCAL-2026/source.md`; the approved
card is `strategy-seeds/cards/approved/QM5_20247_wti-vr-calreg_card.md`. The
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
  contract, month boundary, attempt state, history, arithmetic, significance,
  spread, quote, ATR, and stop guards.
- **Trade entry:** thirty-three endpoint reconstruction, robust memory test,
  physical-season state, follow/reverse mapping, registered magic, V5
  fixed-risk sizing, and frozen hard stop.
- **Trade management:** next-month and forty-day stale closes before
  entry-only gates.
- **Trade close:** framework close helper, broker hard stop, and kill switch.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-06 | Initial build from approved G0 card | strict compile/build PASS; zero errors, warnings, failures, or build warnings |
| v1.1 | 2026-08-06 | Paced Q02 handoff | Not enqueued at binding 10/7 factory-terminal CPU ceiling; no tester run |
