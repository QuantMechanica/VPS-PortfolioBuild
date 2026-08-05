# QM5_20221_wti-win-signmom - Strategy Spec

**EA ID:** QM5_20221

**Slug:** `wti-win-signmom`

**Source:** `BURAKOV-PAPAILIAS-WTI-WINSIGN-2026`

**Author:** Research+Development

**Last revised:** 2026-08-05

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of each November-May broker month,
reconstruct thirteen consecutive completed month-end closes. Convert the
twelve monthly returns to binary signs, assigning one to non-negative returns,
and buy when their mean is at least 0.40; otherwise sell. June through October
is forced flat.

Close the prior package before each monthly renewal. Persist each eligible
month before fallible gates so a blocked, stopped, or failed attempt cannot
retry after restart. Use a frozen `3.5 * ATR(20,D1)` hard stop, no target, and
a forty-day stale guard. Friday close is disabled because the monthly source
hold spans weekends.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_first_active_month` | 11 | November regime start |
| `strategy_last_active_month` | 5 | May regime end |
| `strategy_lookback_months` | 12 | Binary monthly-return window |
| `strategy_positive_threshold` | 0.40 | Long/short threshold |
| `strategy_history_bars` | 500 | Bounded D1 reconstruction |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | Maximum WTI entry spread |

Every value is locked for Q02. No baseline parameter sweep is authorized.

## 3. Symbol Universe

- Exact carrier: `XTIUSD.DWX`.
- Magic slot: 0 (`202210000`).
- No companion symbol, conversion history, or external runtime input.

## 4. Timeframe

- Exact timeframe: D1.
- Decision clock: first processed D1 bar of each new broker month.
- Eligible clock: November through May only.
- Formation: thirteen consecutive completed broker-month endpoints.

## 5. Expected Behaviour

Maximum cadence is seven decisions per full post-warm-up year; Q02 retires
below five completed packages/year. Exposure normally spans one broker month
and is always flat June through October. Principal risks are interaction
decay, WTI gaps and rolls, futures-to-CFD basis, financing, stop-outs, the
source's adverse WTI drawdown, and realized book correlation.

## 6. Source Citation

Burakov, D., Freidin, M., and Solovyev, Y. (2018), "The Halloween Effect on
Energy Markets: An Empirical Study," *International Journal of Energy
Economics and Policy* 8(2), 121-126. Papailias, F., Liu, J., and Thomakos,
D. D. (2021), "Return Signal Momentum," *Journal of Banking & Finance* 124,
106063, DOI `10.1016/j.jbankfin.2021.106063`.

The governed composite is
`strategy-seeds/sources/BURAKOV-PAPAILIAS-WTI-WINSIGN-2026/source.md`; the
approved card is
`strategy-seeds/cards/approved/QM5_20221_wti-win-signmom_card.md`. The sources
supply the winter regime and return-sign statistic, not this interaction's
WTI CFD performance.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes and Friday close are OFF. Every trade has
a server-side ATR hard stop. There is no manual backtest, live/demo/shadow
setfile, live authorization, deploy manifest, portfolio admission, or
portfolio-gate change.

## Revision history

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-05 | Initial build from approved G0 card | Q01 strict build PASS; 0 compile errors/warnings and 0 build failures/warnings |
| v2 | 2026-08-05 | Paced Q02 handoff attempted | Not enqueued: eight running factory terminals exceeded the seven-terminal CPU ceiling |
