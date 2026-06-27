---
ea_id: QM5_9416
slug: qs-coint-bb
type: strategy
source_id: 842161b9-a728-55c7-97e8-33e33719b70c
sources:
  - "[[sources/quantstart-articles]]"
concepts:
  - "[[concepts/pairs-trading]]"
  - "[[concepts/cointegration]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/cointegration-test]]"
  - "[[indicators/bollinger-band]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; verifiable QuantStart URL with named institution QuantStart / QuarkGluon Ltd. provides clear lineage."
r2_mechanical: PASS
r2_reasoning: "CADF gate, fixed 15-bar spread Bollinger z-score thresholds (1.5 entry / 0.5 exit), and monthly hedge re-estimation are all deterministic."
r3_data_available: PASS
r3_reasoning: "ARNC/UNG pair concept ports to DWX index pairs (SP500.DWX/NDX.DWX, SP500.DWX/WS30.DWX) and FX crosses testable on D1."
r4_ml_forbidden: PASS
r4_reasoning: "Monthly OLS hedge-ratio re-estimation uses price history only, not PnL; no ML; two-leg execution uses explicit magic slot allocation per HR4."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 80
last_updated: 2026-05-19
g0_approval_reasoning: "R1 verifiable 2026 QuantStart URL; R2 deterministic D1 CADF/OLS spread Bollinger entry and mean-cross exit with ~80 trades/year; R3 ports to related DWX index/FX pairs with SP500 caveat; R4 no ML/martingale with explicit two-slot magic allocation."
---

# QuantStart Cointegrated Spread Bollinger Pair

## Quelle
- Source: [[sources/quantstart-articles]]
- Article: "Aluminum Smelting Cointegration Strategy in QSTrader"
- Institution: QuantStart / QuarkGluon Ltd.
- URL: https://www.quantstart.com/articles/aluminum-smelting-cointegration-strategy-in-qstrader/
- Source citation: 2026 QuantStart URL: https://www.quantstart.com/articles/aluminum-smelting-cointegration-strategy-in-qstrader/
- Location: article defines the ARNC/UNG spread, Bollinger/z-score entry and exit rules, hedge multiple 1.213, 15-bar lookback, entry threshold 1.5, and exit threshold 0.5.

## Mechanik

### Entry
- Source instruments: ARNC and UNG as an aluminum-smelting/natural-gas cost pair.
- QM port: test related DWX pairs such as `SP500.DWX`/`NDX.DWX`, `SP500.DWX`/`WS30.DWX`, and liquid FX cross-pair combinations selected by Development.
- Target period: D1.
- Pre-trade selection: only enable a configured pair when the in-sample Engle-Granger/CADF test on daily closes rejects non-cointegration at the configured threshold during the approved IS window.
- Compute hedge ratio from the in-sample relationship; the source example uses 1.213 shares of UNG per ARNC share.
- Compute spread `spread_t = y_t - beta * x_t`.
- Compute spread moving average and standard deviation over a fixed 15-bar lookback.
- Compute z-score of the latest spread.
- If `zscore < -1.5`, enter long spread: long y-leg, short beta-adjusted x-leg.
- If `zscore > +1.5`, enter short spread: short y-leg, long beta-adjusted x-leg.
- Use explicit slot allocation: y-leg uses `MAGIC_BASE + 0`; x-leg uses `MAGIC_BASE + 1`. No pyramiding per slot.

### Exit
- Close long spread when `zscore >= -0.5`.
- Close short spread when `zscore <= +0.5`.
- Close both legs if the pair fails a scheduled monthly cointegration re-check, if beta leaves `0.25 <= beta <= 4.0`, or if a leg is unavailable.

### Stop Loss
- Source does not specify a stop.
- Build default: pair-level fixed-risk stop at $1,000 P2 risk or spread stop at `abs(zscore) >= 4.0`.

### Position Sizing
- P2 baseline: total pair risk is fixed-risk $1,000 equivalent, split across two hedge-adjusted slots.
- Gross notional is capped by framework margin guard.

### Zusätzliche Filter
- Require 252 completed daily bars before initial cointegration test.
- Re-estimate hedge ratio monthly, not every trade, to keep parameter updates bounded and auditable.
- Standard spread and execution filters apply to both legs.

## Concepts
- [[concepts/pairs-trading]] -- primary
- [[concepts/cointegration]] -- secondary
- [[concepts/mean-reversion]] -- secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable QuantStart URL; named institution is QuantStart / QuarkGluon Ltd. |
| R2 Mechanical | PASS | CADF gate, fixed spread bands, hedge-ratio calculation, and mean-cross exit are deterministic. |
| R3 Data Available | PASS | Related DWX index or FX pairs can be tested after porting; SP500.DWX caveat applies where used. |
| R4 ML Forbidden | PASS | No ML or martingale; two simultaneous legs are separated into explicit magic slots. |

## R3
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9407_qs-pairs-z]] -- rolling z-score pair variant.
- [[strategies/QM5_9415_qs-kalman-pair]] -- Kalman forecast-error pair variant.

## Lessons Learned
- TBD after pipeline run.
