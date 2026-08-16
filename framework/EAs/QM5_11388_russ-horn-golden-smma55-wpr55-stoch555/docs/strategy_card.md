---
ea_id: QM5_11388
slug: russ-horn-golden-smma55-wpr55-stoch555
type: strategy
source_id: 8e980ec0-c92b-5163-a865-c3e451c5442b
sources:
  - "[[sources/dropbox-forex-pdf-archive]]"
concepts:
  - "[[concepts/channel-breakout]]"
  - "[[concepts/oscillator-trend-confirm]]"
  - "[[concepts/smma-channel]]"
indicators:
  - "[[indicators/smma]]"
  - "[[indicators/williams-percent-range]]"
  - "[[indicators/stochastic]]"
period: M5
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX]
source_citation: "Russ Horn, The Golden Strategy (RapidResultsMethod.com), local PDF: C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\pdfcoffee.com_golden-strategy-forex--pdf-free.pdf"
g0_status: APPROVED
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-27
expected_trades_per_year_per_symbol: 40
card_body_incomplete: true
card_body_missing: "legacy_contract_repair"
g0_rejection_reason: "SUPERSEDED: source-only rejection recovered under OWNER R1 policy on 2026-07-23; original retained in cards_rejected."
status: draft
r1_reasoning: "Existing attribution retained; R1 is informational and non-gating under OWNER policy 2026-07-23."
r2_reasoning: "Entry is fully deterministic (SMMA(55) channel close cross + WPR(55) level cross + Stoch %K/%D compare); exit is fixed ATR(14)x1.0 stop with 2R take-profit; no discretion."
r3_reasoning: "EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX all carry M5 DWX tick data for the full P2 pipeline."
r4_reasoning: "SMMA/WPR/Stochastic only, no ML/adaptive components, single-entry logic compatible with 1-position-per-magic."
legacy_contract_repair: true
g0_recovery_reason: "Source-only rejection recovered; fresh semantic R2-R4 G0 review required."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_11388_russ-horn-golden-smma55-wpr55-stoch555.md"
g0_approval_reasoning: "R1 lineage recorded; R2 deterministic SMMA/WPR/Stochastic entry with ATR stop and 2R exit, conservatively 40 trades/year/symbol; R3 testable on listed FX .DWX symbols; R4 deterministic, ML-free, one-position compatible."
expected_pf: 1.2
expected_dd_pct: 18.0
---

# QM5_11388 Russ Horn Golden Strategy — SMMA(55) Channel + WPR(55) + Stoch(5,5,5) (M5)

## Quelle

- Source: "The Golden Strategy" by Russ Horn — RapidResultsMethod.com
- File: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\pdfcoffee.com_golden-strategy-forex--pdf-free.pdf`
- Author: Russ Horn (named individual, RapidResultsMethod.com, forex educator). R1 PASS.

## Mechanik

Dual SMMA(55) channel (one on High, one on Low) creates a price-action band. A close
beyond the upper/lower SMMA band is required simultaneously with Williams %R(55)
confirming momentum and Stochastic(5,5,5) confirming %K above %D signal line.

### Indicators

- SMMA(55) applied to HIGH — upper channel line (green)
- SMMA(55) applied to LOW — lower channel line (red)
- Williams %R(55) with levels at -25 (overbought signal) and -75 (oversold signal)
- Stochastic(5,5,5) with standard 20/80 levels; compare %K vs %D signal line

### Entry

**LONG**:
1. Close of signal bar is **above** SMMA(55)[High].
2. Williams %R(55) crosses **above** -25 level: `wpr[1] <= -25 && wpr[0] > -25`.
3. Stochastic %K is **above** %D at signal bar.
4. Enter BUY at next bar open (Conservative entry; aggressive = enter at signal bar close).

**SHORT**:
1. Close of signal bar is **below** SMMA(55)[Low].
2. Williams %R(55) crosses **below** -75 level: `wpr[1] >= -75 && wpr[0] < -75`.
3. Stochastic %K is **below** %D.
4. Enter SELL at next bar open.

### Exit

- TP: 2× SL (fixed 2:1 risk-reward).
- SL: ATR(14) × 1.0 (mechanized replacement for "below last swing low" in source).
- No trailing stop by default; P3 variant with ATR trail.

### Stop Loss

- ATR(14) × 1.0 from entry price.
- P2 cap: 20 pips max.

### Position Sizing

- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter

- Timeframe: M5 primary (source shows M5 and M15 examples); H1 as P3 variant.
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX
- Spread cap: 15 pips
- News filter: off in P2

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Russ Horn, named individual, RapidResultsMethod.com forex educator. |
| R2 Mechanical | CONDITIONAL | SMMA(55) close cross and %R level cross are fully deterministic. Stoch %K vs %D comparison deterministic. SL in source = "below last swing low" (subjective) — replaced with ATR(14)×1.0. |
| R3 Data Available | PASS | M5 DWX data available. |
| R4 No ML | PASS | SMMA, WPR, Stochastic — no ML. |

G0 APPROVE eligible.

## Pipeline-Verlauf

- G0: 2026-05-23 — drafted from Russ Horn "The Golden Strategy" PDF (RapidResultsMethod.com)

## Implementation Notes for Codex (P1)

- Timeframe: M5
- DWX symbols: **EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX**
- SMMA(55) High: `iMA(NULL,0,55,0,MODE_SMMA,PRICE_HIGH,i)` — apply to High price
- SMMA(55) Low: `iMA(NULL,0,55,0,MODE_SMMA,PRICE_LOW,i)` — apply to Low price
- WPR(55): `iWPR(NULL,0,55,0)` — MT5 native, range [-100, 0]; -25 = overbought zone
- Stoch(5,5,5): `iStochastic(NULL,0,5,5,5,MODE_SMA,0,MODE_MAIN,0)` for %K,
  `MODE_SIGNAL` for %D. Compare %K[0] > %D[0] for bullish.
- LONG trigger: `Close[0] > smma55_high[0] && wpr[1] <= -25 && wpr[0] > -25 && stoch_k[0] > stoch_d[0]`
- SL: `iATR(NULL,0,14,0) * 1.0`; TP: SL * 2.0
- P3 sweeps: SMMA period (34 vs 55 vs 89), %R levels (-20/-80 vs -25/-75), Stoch settings (5,5,5 vs 14,3,3), TF M5 vs M15.

## Verwandte Strategien

- Related: QM5_11379 (144lwma-5smma-cross-m5) — also uses SMMA, but for crossover not channel
- Differentiator: Dual SMMA channel on High/Low creates a price band; %R(55) and Stoch(5,5,5) use same period (55) as SMMA for consistency; triple simultaneous confirmation.

## Lessons Learned

- *(populated as pipeline progresses)*
