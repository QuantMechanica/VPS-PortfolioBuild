# QM5_20251_wti-cal-rsm - Strategy Spec

**EA ID:** QM5_20251

**Slug:** `wti-cal-rsm`

**Sources:** `KELOHARJU-RETSEAS-2016` and `PAPAILIAS-RSM-2021`

**Author:** Research+Development

**Last revised:** 2026-08-06

## 1. Strategy Logic

At the first processed `XTIUSD.DWX` D1 bar of each broker month, consume that
month's only attempt. Estimate the current calendar month's seasonal direction
from the arithmetic mean of the same month's completed log return in up to ten
prior years, with at least five valid observations. Independently reconstruct
the latest thirteen consecutive completed month-end closes, encode the twelve
monthly returns as nonnegative or negative, and classify their positive-sign
probability at the source-fixed `0.40` threshold.

Enter only when both non-zero states agree: buy when both are positive and sell
when both are negative. Disagreement or invalid history stays flat for the
consumed month. Close before renewal at the next month boundary or after 40
calendar days. Each entry has a `3.5 * ATR(20,D1)` broker hard stop and no
target. Friday close is disabled because the structural holding period spans
weekends.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_history_years` | 10 | Maximum prior same-calendar observations |
| `strategy_min_history_years` | 5 | Minimum valid same-calendar observations |
| `strategy_lookback_months` | 12 | Completed return-sign window |
| `strategy_positive_threshold` | 0.40 | Long/short return-sign boundary |
| `strategy_history_bars` | 3000 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period` | 20 | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | Frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | WTI entry spread ceiling |

All values are locked for Q02. No baseline parameter sweep is authorized.

## 3. Symbol Universe

- Exact carrier: `XTIUSD.DWX`.
- Slot 0 magic: `202510000`.
- Single direct WTI position only; no hedge, scale-in, or second symbol.

## 4. Timeframe And Lifecycle

- Exact chart timeframe: D1.
- Signal endpoints: completed D1 bars and completed calendar months only.
- Decision cadence: one persisted attempt per broker month.
- Maximum lifecycle: next month boundary or 40 calendar days.

## 5. Expected Behaviour

Estimated cadence is six to nine completed packages per full post-warm-up year.
Q02 retires the edge below five trades per full year per symbol. Principal
risks are sparse seasonal samples, WTI CFD-to-futures basis and roll effects,
gaps and financing, threshold instability, source decay, and realized overlap
with XNG or risk assets.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`.

Papailias, Liu, and Thomakos (2021), "Return Signal Momentum," *Journal of
Banking & Finance* 124, 106063, DOI `10.1016/j.jbankfin.2021.106063`.

The governed composite packet is
`strategy-seeds/sources/KELOHARJU-PAPAILIAS-WTI-CALRSM-2026/source.md`; the
approved card is
`strategy-seeds/cards/approved/QM5_20251_wti-cal-rsm_card.md`. Neither source
tests this exact WTI concordance rule or guarantees profitability or portfolio
decorrelation.

## 7. Risk And Safety Boundary

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes and stress rejection are OFF. There is no
manual backtest, live/demo/shadow setfile, AutoTrading action, `T_Live` access,
deploy manifest, portfolio admission, portfolio-gate edit, or correlation
waiver.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-06 | Initial build from approved G0 card | Q01 strict compile PASS; 0 errors and 0 warnings; build check 0 failures and 0 warnings |
