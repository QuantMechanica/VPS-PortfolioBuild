---
ea_id: QM5_12482
slug: gh-oil-nok
type: strategy
source_id: af7930c8-6c65-52d1-9c01-040490b5ad39
source_citation: "je-suis-tm, quant-trading Oil Money Trading backtest.py, https://github.com/je-suis-tm/quant-trading/blob/master/Oil%20Money%20project/Oil%20Money%20Trading%20backtest.py"
sources:
  - "[[sources/github-quant-finance-python]]"
concepts:
  - "[[concepts/petrocurrency]]"
  - "[[concepts/regression-residual]]"
indicators:
  - "[[indicators/rolling-ols]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 10
r1_track_record: PASS
r1_reasoning: "Single source_id present (GitHub script URL + named author je-suis-tm); lineage intact."
r2_mechanical: PASS
r2_reasoning: "Rolling OLS length, R-squared gate, two-sigma entry thresholds, and time/price exits are deterministic and implementable."
r3_data_available: PASS
r3_reasoning: "DWX has XBRUSD/XTIUSD oil CFDs and USDJPY FX; strategy is testable on at least one oil-sensitive DWX instrument pair."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic rolling OLS on price history only; no ML, adaptive PnL parameters, grid, martingale, or multi-position."
pipeline_phase: G0
last_updated: 2026-05-26
strategy_type_flags: [n-period-min-reversion, signal-reversal-exit, time-stop, symmetric-long-short, atr-hard-stop]
target_symbols: [USDNOK.DWX, USDJPY.DWX, XBRUSD.DWX, XTIUSD.DWX]
g0_approval_reasoning: "R1 single GitHub script source_id/URL; R2 rolling OLS residual entries/exits are mechanical with plausible multi-trade annual cadence; R3 oil/FX relationship can port to DWX oil and FX symbols; R4 deterministic OLS, no ML/grid/martingale."
---

# QM5_12482 GitHub Oil-NOK Residual Reversion

## Quelle
- Accessed 2026-05-26.
- Source: [[sources/github-quant-finance-python]]
- Primary URL: https://github.com/je-suis-tm/quant-trading/blob/master/Oil%20Money%20project/Oil%20Money%20Trading%20backtest.py
- Author / institution: GitHub user `je-suis-tm`.
- Location: `Oil Money project/Oil Money Trading backtest.py`, function `signal_generation`.

## Mechanik

Rolling OLS residual mean-reversion between Brent crude and NOK price series. The source fits a 50-bar regression of NOK against Brent, requires `R^2 > 0.7`, enters when the NOK price exits the fitted two-sigma residual band, and exits on a fixed holding period or fixed price move.

Target symbols: USDNOK.DWX, USDJPY.DWX, XBRUSD.DWX, XTIUSD.DWX.

### Entry
- Evaluate once per completed D1 bar.
- Let `x = brent` and `y = nok` in the source.
- If no model is active, fit OLS over the latest `train_len = 50` bars:
  - `y = a + b * x + residual`.
- Accept the model only when `R^2 > 0.7`.
- Compute residual sigma on the training window.
- Forecast `y_hat = a + b * x`.
- Enter long `y` when `y < y_hat - 2 * sigma`.
- Enter short `y` when `y > y_hat + 2 * sigma`.

### Exit
- Close when holding period exceeds `10` bars.
- Close when absolute move in `y` from entry exceeds source stop/profit threshold `0.5` price points.
- Refit only after a position is closed or the model is inactive.

### Stop Loss
- Source uses symmetric absolute price move `0.5` as profit/loss exit.
- V5 port also caps emergency loss at `2.5 * ATR(20)` on the traded leg.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25`.
- One open position per symbol/magic on the traded NOK leg.
- Brent/oil series is a signal input only unless CTO later approves a hedged two-leg variant.

### Zusaetzliche Filter
- Only trade when both oil and FX bars are present for the same completed date.
- Skip new entries when OLS slope sign flips versus the prior accepted model.
- Skip entries when spread exceeds `2 * MedianSpread(60D)` on the traded leg.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Source-Link | PASS | Single source_id with public GitHub script URL and named GitHub author `je-suis-tm`. |
| R2 Mechanical | PASS | Rolling OLS length, R-squared gate, two-sigma entries, and exits are explicit. |
| R3 DWX-testbar | UNKNOWN | Likely portable if DWX has a usable oil CFD input plus NOK FX symbol; otherwise reviewer may retarget to oil-sensitive FX proxies. |
| R4 No ML | PASS | Deterministic rolling OLS on price history; no ML model, online PnL adaptation, grid, martingale, or multi-position requirement. |

## R3
Preferred port is Brent or WTI CFD as signal input and a NOK FX symbol as the traded leg. If Darwinex symbol availability lacks NOK or oil history on the target terminals, G0 should either reject R3 or retarget to available oil-sensitive FX proxies before build.

## Author Claims
- The source comments describe the idea as running regression on NOK and Brent over the past 50 data points.
- The source states the model is valid when R-squared exceeds `0.7` by default.
- The source states `+/- two sigma` residual thresholds trigger trading signals and positions clear after 10 days or a `0.5` point stop/profit move.

## Parameters To Test
- Train length: `30`, `50`, `75`, `100` bars.
- R-squared threshold: `0.6`, `0.7`, `0.8`.
- Residual threshold: `1.5`, `2.0`, `2.5` sigma.
- Holding period: `5`, `10`, `15` bars.
- Stop: source-scaled `0.25`, `0.5`, `0.75` price points or `2.5 * ATR(20)`.

## Initial Risk Profile
Cross-market statistical relationship can break abruptly. This card treats oil as a signal input and trades only one FX leg to remain compatible with one-position-per-magic; that leaves basis risk versus the original pair-style thesis.

## Pipeline-Verlauf
- G0: 2026-05-26 - drafted from GitHub topic quantitative-finance Python source, PENDING.
