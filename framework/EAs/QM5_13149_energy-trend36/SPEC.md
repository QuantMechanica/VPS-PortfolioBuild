# QM5_13149_energy-trend36 - Strategy Spec

**EA ID:** QM5_13149
**Slug:** `energy-trend36`
**Strategy ID:** HOLLSTEIN-3YR-2021_XTI_XNG_S01
**Source:** Hollstein, Prokopczuk, and Tharann (2021), *Quarterly Journal of Finance* 11(4)
**Last revised:** 2026-07-12

## 1. Strategy Logic

The EA runs one D1 logical basket from `XTIUSD.DWX`. On the first host bar of
each broker month it reconstructs 37 consecutive completed month-end closes
for XTI and XNG, calculates 36 simple monthly returns for each, and takes their
arithmetic averages. It buys the higher-average-return leg and shorts the
lower-average-return leg.

The source names the characteristic `3Y Reversal`, but its tested direction is
high-minus-low. This build transparently implements that direction as
36-month relative continuation. Fixed package risk is split equally, both legs
receive frozen ATR(20) times 3.5 hard stops, and the package closes at the next
month, after 40 days, or immediately on an orphan or invalid composition.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| strategy_return_window_months | 36 | locked | completed simple monthly returns |
| strategy_history_bars | 1200 | 1000-1400 | bounded D1 retrieval buffer |
| strategy_atr_period_d1 | 20 | 14-30 | D1 hard-stop ATR |
| strategy_atr_sl_mult | 3.5 | 2.5-5.0 | frozen stop multiple |
| strategy_max_hold_days | 40 | locked | stale package guard |
| strategy_xti_max_spread_pts | 1500 | 1000-2500 | XTI spread cap |
| strategy_xng_max_spread_pts | 3000 | 2000-4500 | XNG spread cap |
| strategy_deviation_points | 20 | 10-50 | basket order deviation |

The window, simple-return arithmetic mean, high-minus-low direction, monthly
cadence, equal half-risk carrier, and no same-month re-entry are locked.

## 3. Symbol Universe

- Logical symbol: `QM5_13149_XTI_XNG_TREND36_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1, magic `131490000`.
- Traded slot 1: `XNGUSD.DWX`, D1, magic `131490001`.
- No other symbol, timeframe, or standalone-leg test is authorized.

## 4. Timeframe

The host and both signal legs use D1 bars. A decision forms only on the first
tradable host bar of each broker month. Current D1 bars and the current month
are excluded from the 36-return formation window.

## 5. Expected Behaviour

- Approximately twelve completed packages/year after 37-month warm-up;
  retire below five packages/year.
- Typical hold is one broker month, bounded by a 40-day stale guard.
- Opposite-side equal fixed-risk execution reduces common direction but does
  not guarantee dollar, beta, volatility, factor, or realized neutrality.
- Source evidence is weak for two portfolios; Q02 is a low-prior falsification.

## 6. Source Citation And Evidence Boundary

Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021),
"Anomalies in Commodity Futures Markets," *Quarterly Journal of Finance*
11(4), 2150017. DOI https://doi.org/10.1142/S2010139221500178.

Institutional accepted manuscript:
https://centaur.reading.ac.uk/100920/1/SSRN-id3567629.pdf.
Approved-card and R1-R4 evidence:
`strategy-seeds/cards/energy-trend36_card.md`.

The source ranks at least six of 26 fully collateralized fixed-maturity
futures. The EA ranks two continuous CFDs and substitutes raw close-to-close
returns for futures excess returns. No source performance, significance,
drawdown, cost, or correlation result is imported.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Backtest Q02+ | RISK_FIXED | 1000 per package, split 50/50 |
| Live | not authorized | none |

The EA calls `QM_LotsForRisk` and applies the 0.5 package share after
framework sizing. It validates broker volume metadata and flattens a failed
two-leg entry. There is no TP, trail, break-even, partial close, scale-in,
grid, martingale, or pyramiding.

## 8. Four-Module Mapping

- No-Trade: exact host, locked window, bounded history, consecutive months,
  finite arithmetic, spread, ATR, lot, magic, package, and prior-attempt guards.
- Entry: monthly 36-return high-minus-low rank, paired orders, equal fixed-risk
  allocation, and frozen hard stops.
- Management: next-month close, 40-day time stop, deal-history same-month
  suppression, composition validation, and orphan cleanup.
- Close: `QM_TM_ClosePosition` for package exits plus broker hard stops.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, admission artifact, external runtime data, banned indicator, or
ML is authorized.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-07-12 | Initial build from approved card | mission-directed |
