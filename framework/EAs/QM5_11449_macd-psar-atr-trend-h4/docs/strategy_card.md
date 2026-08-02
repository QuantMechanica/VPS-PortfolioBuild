---
ea_id: QM5_11449
slug: macd-psar-atr-trend-h4
type: strategy
source_id: f66dfd8d-c60a-59be-b542-a70b8b41c17a
sources:
  - "[[sources/macd-trender-anonymous]]"
concepts:
  - "[[concepts/macd-zero-cross]]"
  - "[[concepts/parabolic-sar]]"
  - "[[concepts/atr-partial-exits]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/macd]]"
  - "[[indicators/isar]]"
  - "[[indicators/atr]]"
period: H4
source_citation: "Anonymous, MACD Trender System (online source, unknown author). R1 FAIL — no named individual author."
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; anonymous PDF sources are explicitly accepted per 2026-05-23 updated R1 criteria — author track record not required.
r2_mechanical: PASS
r2_reasoning: MACD histogram/signal arithmetic, PSAR confirmation, and ATR-based partial exits are all MT5-native and fully deterministic.
r3_data_available: PASS
r3_reasoning: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX on H4 are DWX instruments with adequate history.
r4_ml_forbidden: PASS
r4_reasoning: Fixed MACD(12,26,9), PSAR(0.02,0.2), ATR(14); partial exits are explicitly bounded percentage slices of one position — no ML.
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 35
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "R1 PASS single source_id; R2 PASS mechanical MACD/PSAR/ATR rules with plausible H4 trend cadence >2 trades/year/symbol; R3 PASS DWX FX H4; R4 PASS deterministic no ML and partial exits are bounded single-position management."
---

# QM5_11449 MACD + PSAR + ATR Partial Exits (H4)

## Quelle
- Source: Anonymous, 2026 source note, URL/local PDF: `640322690-MACD-Trender-Forex-Trading-Strategy.pdf` (4 pages).
- R1: FAIL — no named individual author. Edge must be demonstrated entirely by Q02+ backtest data.

## Mechanik

**Concept**: MACD histogram zero-cross identifies momentum direction shift. The MACD signal line entering the histogram (histogram and signal converging) provides the precise entry timing. Parabolic SAR confirms the directional bias. ATR-based partial exits (1×, 2×, 3× ATR) lock in profit progressively while allowing the trend to run.

**Note**: R1 FAIL means this strategy must prove edge entirely through pipeline results. The logic itself is coherent and mechanical.

### Indicators
- `MACD(12,26,9)` — histogram and signal line
- `PSAR(0.02, 0.2)` — step 0.02, max 0.2
- `ATR(14)`

### Entry

**LONG:**
1. `MACD_histogram[1] > 0` — histogram is above zero (positive momentum)
2. `MACD_histogram[2] <= 0` — histogram crossed zero this bar (momentum shift up)
   OR `MACD_signal[1] < MACD_histogram[1] AND MACD_signal[2] >= MACD_histogram[2]` — signal enters histogram from below (acceleration)
3. `PSAR[1] < Low[1]` — PSAR dot below price (bullish confirmation)
4. Enter BUY at open of bar[0]

**SHORT:**
1. `MACD_histogram[1] < 0` — below zero
2. `MACD_histogram[2] >= 0` — just crossed zero downward
   OR signal exits histogram from above
3. `PSAR[1] > High[1]` — PSAR dot above price
4. Enter SELL at open of bar[0]

### Exit (ATR-based partial exits)
- **TP1**: entry + ATR(14)[1] × 1.0 — take 33% of position
- **TP2**: entry + ATR(14)[1] × 2.0 — take 33% of position
- **TP3**: entry + ATR(14)[1] × 3.0 — take final 34% of position
- **Trail remaining**: move SL to PSAR dot after TP1 fills

### Stop Loss
- Initial: `PSAR[1]` level at entry (PSAR dot)
- P2 cap: 100 pips
- P2 simplification: use fixed ATR(14) × 1.5 SL for P2 (single unit, no partial exits)

### Position Sizing
- `RISK_FIXED = $1000` for P2 (single unit).
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: H4
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX
- Spread cap: 20 pips

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | FAIL | Anonymous source; no named author, no credentials. Edge must be proven by pipeline. |
| R2 Mechanical | PASS | MACD histogram/signal arithmetic, PSAR — all MT5-native. |
| R3 Data Available | PASS | H4 DWX FX. iMACD, iSAR, iATR MT5-native. |
| R4 No ML | PASS | Fixed periods (12/26/9, PSAR 0.02/0.2, ATR 14). |

G0 APPROVE with FAIL R1 note. Must pass Q02 backtesting to proceed past G1.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from anonymous MACD Trender System

## Implementation Notes for Codex (P1)
- MACD: `iMACD(NULL,PERIOD_H4,12,26,9,PRICE_CLOSE,MODE_MAIN,1)` — histogram; `MODE_SIGNAL,1` — signal
- Histogram cross: `hist[1]>0 && hist[2]<=0`
- PSAR: `iSAR(NULL,PERIOD_H4,0.02,0.2,1)`
- P2 single-unit: ATR SL only; TP = ATR × 2.0; no partial exits (simplify for backtesting)
- P3 sweeps: MACD (8/12/19, 17/26/39, 9), PSAR step (0.01/0.02/0.03), ATR TP (1.5/2.0/3.0)

## Verwandte Strategien
- Related: QM5_11439 (pivot9level-macd-ema-m5) — also MACD-based entry; M5 pivot context vs. H4 standalone
- Related: QM5_11434 (carter-t-sma32hl-psar-sma200-h1) — also uses PSAR confirmation; H1 trend-channel vs. H4 MACD

## Lessons Learned
- R1 FAIL — purely pipeline-driven validation required.
