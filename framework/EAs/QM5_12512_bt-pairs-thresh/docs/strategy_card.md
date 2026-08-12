---
ea_id: QM5_12512
slug: bt-pairs-thresh
type: strategy
source_id: 2d7aaa5f-321c-524b-99ce-bc921cddfc60
source_citation: "Philippe Morissette, bt - Flexible Backtesting for Python, GitHub repository, https://github.com/pmorissette/bt; examples/pairs_trading.py, PairsStrategy demo, commit 2630651f212c025f0cec351d6319ad81d587ad6e"
sources:
  - "[[sources/pmorissette-bt]]"
concepts:
  - "[[concepts/pairs-trading]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/spread-threshold]]"
indicators:
  - "[[indicators/spread]]"
  - "[[indicators/z-score]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDUSD.DWX, NZDUSD.DWX]
period: H1
expected_trade_frequency: "Threshold pair spread mean-reversion with 5-bar max hold; conservative estimate 20-60 trades/year/configured pair."
expected_trades_per_year_per_symbol: 30
g0_status: APPROVED
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-23
strategy_type_flags: [mean-reversion, pairs-trading, spread-threshold, time-stop, symmetric-long-short]
card_body_incomplete: false
card_body_missing: ""
g0_rejection_reason: "SUPERSEDED: source-only rejection recovered under OWNER R1 policy on 2026-07-23; original retained in cards_rejected."
status: APPROVED
r1_reasoning: "Existing attribution retained; R1 is informational and non-gating under OWNER policy 2026-07-23."
legacy_contract_repair: false
g0_recovery_reason: "Source-only rejection recovered; audited card body documents R2-R4 PASS."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_12512_bt-pairs-thresh.md"
g0_approval_reasoning: "OWNER 2026-07-23 retroactive source-only recovery; body audit documents R2-R4 PASS and original rejection is retained."
---

# bt Pair Spread Threshold Reversion

## Quelle
- Source: [[sources/pmorissette-bt]]
- Primary URL: https://github.com/pmorissette/bt
- Source location: `examples/pairs_trading.py`, `PairsSignal`, `WeighPair`, `PriceCompare`, and `RunAfterDays` logic.
- Author / institution: Philippe Morissette project; public GitHub repository.
- Snapshot used: commit `2630651f212c025f0cec351d6319ad81d587ad6e`.

## Mechanik

The bt pair demo identifies pairs where the difference between two indicator values exceeds a threshold, sells the rich leg, buys the cheap leg, and exits when the pair strategy price crosses a lower/upper threshold or after five days. MT5 port uses one configured pair per magic slot to preserve V5 one-position discipline.

### Entry
- Evaluate on each completed H1 bar.
- For each configured pair, compute log-price spread: `spread = log(price_A) - beta * log(price_B)`.
- Default `beta = 1.0`; P3 may test rolling OLS beta, but beta must be computed from price history only and frozen at entry.
- Compute spread z-score over 240 H1 bars: `(spread - SMA(spread,240)) / StdDev(spread,240)`.
- If `zscore >= +2.0`, sell A and buy B at next bar open.
- If `zscore <= -2.0`, buy A and sell B at next bar open.
- Open only one active pair trade per configured pair/magic.

### Exit
- Close both legs when `abs(zscore) <= 0.25`.
- Close both legs after 5 H1 bars if mean reversion has not occurred.
- Close both legs immediately if either leg hits its emergency stop.

### Stop Loss
- Pair stop: close both legs if `abs(zscore) >= 3.5`.
- Per-leg emergency stop: `2.0 * ATR(20, H1)` from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` total pair risk, split 50/50 across legs.
- Live default if approved: `RISK_PERCENT = 0.25` total pair risk.
- Use explicit slot allocation: each configured pair gets its own magic number; no multiple pair trades under one magic.

### Zusaetzliche Filter
- Trade only pairs listed in the EA parameters; do not dynamically create unlimited pairs.
- Require both legs to have valid H1 bars and spread history.
- Skip if either leg spread exceeds `2 * MedianSpread(60D)`.
- Skip entries during the first and last H1 bar of Friday trading.

## Concepts
- [[concepts/pairs-trading]] - primary
- [[concepts/mean-reversion]] - primary
- [[concepts/spread-threshold]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Source-Link | PASS | Single source_id and public GitHub URL with named project owner are cited. |
| R2 Mechanical | PASS | Source provides threshold pair selection, long/short pair weighting, price-threshold exits, and fixed time exit; card fixes spread normalization for MT5. |
| R3 DWX-testbar | PASS | FX pair spreads are testable from DWX H1 OHLC series. |
| R4 No ML | PASS | Deterministic z-score thresholds and bounded one-pair-per-magic slot allocation; no ML, grid, martingale, or unbounded dynamic pair book. |

## R3
Primary P2 configured pairs: EURUSD.DWX/GBPUSD.DWX, EURJPY.DWX/GBPJPY.DWX, AUDUSD.DWX/NZDUSD.DWX.

## Author Claims
- The source comments describe identifying pairs whose indicator exceeds a threshold.
- The source trade setup buys one leg and sells the other with equal absolute weights.
- The source exit stack closes trades on lower/upper price thresholds or after a fixed five-day holding period.

## Parameters To Test
- Entry z-score: `1.5`, `2.0`, `2.5`.
- Exit z-score: `0.0`, `0.25`, `0.5`.
- Spread lookback: `120`, `240`, `480` H1 bars.
- Max hold: `5`, `12`, `24` H1 bars.
- Pair stop z-score: `3.0`, `3.5`, `4.0`.

## Initial Risk Profile
Two-leg execution and correlation breakdown risk. This is acceptable only with explicit pair-slot allocation and both legs flattened together on every exit path.

## Pipeline-Verlauf
- G0: 2026-05-26 - drafted from bt pairs_trading.py example, PENDING.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
