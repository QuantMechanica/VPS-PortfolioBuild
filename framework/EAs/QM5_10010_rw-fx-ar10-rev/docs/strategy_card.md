---
ea_id: QM5_10010
slug: rw-fx-ar10-rev
type: strategy
source_id: dcbac84f-6ecf-5d21-9630-50faa69306ec
source_citation: "Kris Longmore, Robot Wealth, 'Trading FX using Autoregressive Models', 2020-11-24, https://robotwealth.com/trading-fx-using-autoregressive-models/"
sources:
  - "[[sources/robot-wealth-blog]]"
concepts:
  - "[[concepts/short-term-reversal]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/autoregressive-model]]"
  - "[[indicators/atr]]"
target_symbols: [AUDUSD.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX]
period: M10
expected_trade_frequency: "M10 prediction-threshold reversal system; volatility and prediction thresholds reduce raw bar frequency. Conservative estimate 80 trades/year/symbol."
expected_trades_per_year_per_symbol: 80
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL cited; R2 mechanical AR10 threshold/time-exit rules with ~80 trades/year/symbol; R3 major FX DWX-testable; R4 fixed in-sample coefficients, no ML/online adaptation/martingale."
---

# Robot Wealth FX AR10 Reversal

## Quelle
- Source: [[sources/robot-wealth-blog]]
- Citation: Kris Longmore, "Trading FX using Autoregressive Models", Robot Wealth, 2020-11-24, https://robotwealth.com/trading-fx-using-autoregressive-models/
- Source location: sections "Ernie's AR Model", "Is there something we can trade here?", and "Conclusion".
- Author claim: The article finds negative autocorrelation in short-horizon FX returns, tests an AR(10) model on ten-minute AUDUSD data, and says the effect is marginal after costs. This card preserves that risk warning and uses thresholds/volatility filters to reduce churn.

## Mechanik

### Entry
- Work on M10 bars built from broker M1 data.
- At each completed M10 bar, compute a fixed AR(10) one-step-ahead forecast using coefficients fit once on the P2 in-sample window.
- Convert forecast to predicted return: `pred_ret = forecast_price / close - 1`.
- Enter long if `pred_ret >= +0.15 * ATR(14,M10) / close` and current realized volatility percentile over 60 M10 bars is above 50%.
- Enter short if `pred_ret <= -0.15 * ATR(14,M10) / close` and volatility filter passes.
- One position per magic-symbol; do not reverse on the same bar.

### Exit
- Exit on opposite forecast threshold.
- Exit after 6 M10 bars if no opposite signal.
- Exit at end of New York session to avoid overnight carry/noise.

### Stop Loss
- Initial SL = 1.2 * ATR(14,M10).
- Optional TP for P3 sweep = 0.8 to 1.5 * ATR(14,M10); baseline uses forecast/time exit only.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Skip if spread > 20% of ATR(14,M10).
- Skip first and last 10 minutes of the trading week.
- Skip high-impact USD and target-currency news windows.

## Concepts
- [[concepts/short-term-reversal]] - primary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Robot Wealth URL, named author Kris Longmore, article title and date. |
| R2 Mechanical | PASS | Article gives AR(10) on ten-minute AUDUSD and short-term reversal thesis; thresholds/time exits are deterministic implementation defaults. |
| R3 DWX-testbar | PASS | AUDUSD and other major FX pairs are available as DWX instruments. |
| R4 No ML | PASS | Fixed linear AR coefficients from in-sample calibration; no neural net, online learning, PnL-adaptive params, grid, or martingale. |

## R3
Primary P2 basket: AUDUSD.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX. Not SP500-specific.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10009_rw-fx-cointeg-bb]] - same source family, slower mean-reversion implementation.

## Lessons Learned
- TBD during pipeline run.

