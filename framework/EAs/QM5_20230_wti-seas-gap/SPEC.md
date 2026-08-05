# QM5_20230_wti-seas-gap - Strategy Spec

**EA ID:** QM5_20230

**Slug:** wti-seas-gap

**Source:** BURAKOV-CHAN-WTI-SEASGAP-2026

**Author:** Research+Development

**Last revised:** 2026-08-05

## 1. Strategy Logic

On a genuine broker-calendar Monday whose immediately preceding completed D1
bar is Friday, compare the Monday open with the completed Friday range plus a
lagged volatility buffer. Compute exactly 90 arithmetic close-to-close returns
from 91 completed D1 closes and their sample standard deviation.

- November through May: buy only when the Monday open is strictly above
  `FridayHigh * (1 + 0.10 * stdret90)`.
- June through October: sell only when the Monday open is strictly below
  `FridayLow * (1 - 0.10 * stdret90)`.
- Reject an in-band gap or any threshold break that opposes the fixed season.

Consume the Monday attempt before all fallible gates. Close on the first
following D1 bar, with a two-calendar-day stale guard. Freeze a 3.0 times
ATR(20,D1) hard stop, use no profit target, and retain framework Friday close
at broker hour 21.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| strategy_winter_first_month | 11 | Seasonal BUY interval start |
| strategy_winter_last_month | 5 | Seasonal BUY interval end |
| strategy_return_lookback_d1 | 90 | Completed arithmetic-return sample |
| strategy_entry_z | 0.10 | Prior-extreme volatility buffer |
| strategy_entry_grace_minutes | 5 | Monday-open attachment window |
| strategy_atr_period | 20 | Completed D1 ATR estimator |
| strategy_atr_sl_mult | 3.0 | Frozen hard-stop distance |
| strategy_max_hold_days | 2 | Stale lifecycle repair |
| strategy_max_spread_points | 2500 | Maximum WTI entry spread |

Every value is locked for Q02. No baseline parameter sweep, holiday shift,
opposing-season fallback, or post-result threshold adjustment is authorized.

## 3. Symbol Universe

- Exact carrier: XTIUSD.DWX.
- Magic slot: 0 (202300000).
- No companion symbol, synthetic basket, conversion history, or external
  runtime input.

## 4. Timeframe

- Exact timeframe: D1.
- Decision clock: first observed tick within five minutes of a genuine Monday
  D1 bar immediately following a completed Friday bar.
- Formation: Friday High[1]/Low[1] and completed Close[1] through Close[91].
- Lifecycle: first following D1 bar, with a two-day stale repair.

## 5. Expected Behaviour

At most one attempt occurs per genuine Monday. The season agreement gate is
expected to yield approximately 4-10 completed packages per full post-warm-up
year; Q02 retires the candidate below five per year on average.

The proposed return driver combines fixed WTI physical-season direction with
sparse weekend information diffusion and breakaway-gap continuation. It is a
direct crude-oil, weekly-reopen clock absent from the certified XAU, SP500,
NDX, and XNG book. Realized decorrelation is not assumed and remains a
downstream gate.

## 6. Source Citation

Burakov, Dmitry, Max Freidin, and Yuriy Solovyev (2018), "The Halloween
Effect on Energy Markets: An Empirical Study," *International Journal of
Energy Economics and Policy* 8(2), 121-126. Chan, Ernest P. (2013),
*Algorithmic Trading: Winning Strategies and Their Rationale*, Wiley,
Chapter 7, Example 7.1. Hoelscher, Seth A., Cedric Mbanga, and Walt A. Nelson
(2017), "TGIF? The Weekend Effect in Energy Commodities," *Journal of
Finance Issues* 16(1), 47-68, DOI 10.58886/jfi.v16i1.2264.

The governed composite is
`strategy-seeds/sources/BURAKOV-CHAN-WTI-SEASGAP-2026/source.md` and the
approved card is
`strategy-seeds/cards/approved/QM5_20230_wti-seas-gap_card.md`. The sources
provide separate season, gap, and target-market premises; none claims this
interaction's returns, frequency, CFD performance, or portfolio correlation.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes are OFF. Friday close remains enabled at
broker hour 21. Every entry has a server-side completed-ATR hard stop. There
is no live/demo/shadow setfile, live authorization, deploy manifest, portfolio
admission, or portfolio-gate change.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-05 | Initial build from approved G0 card | Q01 strict compile/build PASS; zero errors, warnings, failures, or build warnings |
