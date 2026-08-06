# QM5_20242_xng-rsm-window - Strategy Spec

**EA ID:** QM5_20242

**Slug:** `xng-rsm-window`

**Sources:** `SUENAGA-XNG-SEASVOL-2008` and `PAPAILIAS-RSM-2021`

**Author:** Research+Development

**Last revised:** 2026-08-06

## 1. Strategy Logic

On the first tradable `XNGUSD.DWX` D1 bar of each broker month, close the
prior package and persist the decision month before any fallible entry gate.
Remain flat in February-April and October. In May-September and
November-January, reconstruct thirteen consecutive completed month-end closes
and classify each of the twelve newer-versus-older changes as non-negative or
negative. Buy when the non-negative share is at least `0.40`; sell otherwise.

Use a frozen `3.5 * ATR(20,D1)` hard stop, no target, next-month rollover,
and a forty-calendar-day stale guard. Friday close is disabled because the
monthly package spans weekends. An invalid history or current signal closes
owned exposure and suppresses entry.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_lookback_months` | 12 | Completed binary monthly returns |
| `strategy_positive_threshold` | 0.40 | Long/short probability boundary |
| `strategy_summer_first_month` | 5 | First source-window month |
| `strategy_summer_last_month` | 9 | Last source-window month |
| `strategy_winter_first_month` | 11 | First wraparound winter month |
| `strategy_winter_last_month` | 1 | Last wraparound winter month |
| `strategy_history_bars` | 500 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 3000 | Maximum XNG entry spread |

Every value is locked for Q02. No baseline parameter sweep is authorized.

## 3. Symbol Universe

- Exact carrier: `XNGUSD.DWX`.
- Magic slot: 0 (`202420000`).
- No companion symbol, futures curve, weather, storage, EIA, conversion
  history, file, API, trained output, or portfolio-state input.

## 4. Timeframe

- Exact timeframe: D1.
- Decision clock: first processed D1 bar at a real broker-month transition.
- Formation: thirteen consecutive completed broker-month endpoints.
- Signal: `P = count(close[m] >= close[m-1]) / 12`; equality is positive.
- Eligible decision months: May-September and November-January.

## 5. Expected Behaviour

Maximum cadence is eight eligible decisions per full post-warm-up year. Q02
retires the candidate below five completed packages/year. Exposure normally
spans one broker month. Principal risks are natural-gas gaps and rolls,
futures-to-CFD basis, financing, persistent long bias from the `0.40`
threshold, source-window translation, endpoint quality, and correlation with
the existing XNG sleeve.

## 6. Source Citation

Suenaga, H., Smith, A., and Williams, J. C. (2008), "Volatility Dynamics of
NYMEX Natural Gas Futures Prices," *Journal of Futures Markets* 28(5),
438-463, DOI `10.1002/fut.20317`.

Papailias, F., Liu, J., and Thomakos, D. D. (2021), "Return Signal Momentum,"
*Journal of Banking & Finance* 124, 106063, DOI
`10.1016/j.jbankfin.2021.106063`.

The governed composite record is
`strategy-seeds/sources/SUENAGA-PAPAILIAS-XNG-SEASRSM-2026/source.md`; the
approved card is
`strategy-seeds/cards/approved/QM5_20242_xng-rsm-window_card.md`. The papers
do not test this exact intersection or a continuous natural-gas CFD.

## 7. Risk Model

Backtests use only `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes, stress rejection, and Friday close are
OFF. Every entry has a server-side ATR hard stop. There is no manual
backtest, live/demo/shadow setfile, live authorization, deploy manifest,
portfolio admission, or portfolio-gate change.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-06 | Initial build from approved G0 card | Q01 strict compile/build PASS; 0 errors, warnings, failures, or build warnings |
