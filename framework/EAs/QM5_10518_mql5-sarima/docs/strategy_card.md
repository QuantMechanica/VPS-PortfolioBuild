---
ea_id: QM5_10518
slug: mql5-sarima
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Cronex / Sergey Kazachenko idea, Vladimir Karputov / barabashkakvn code, SAR trading v2.0, MQL5 CodeBase, published 2018-01-22, updated 2018-02-28, https://www.mql5.com/en/code/19608"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/indicator-confirmation]]"
indicators: [iMA, iSAR]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "MA plus Parabolic SAR trend comparison on zero/new bars; conservative estimate is 40-100 trades/year/symbol on H1."
expected_trades_per_year_per_symbol: 60
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL/title/date; R2 PASS MA+SAR trend entries and opposite-state/stopped exits with ~60 trades/year/symbol; R3 PASS iMA/iSAR testable on DWX symbols; R4 PASS no ML/grid/martingale, one-position explicit."
---

# MQL5 SAR MA Trend Confirm

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Cronex / Sergey Kazachenko idea, "SAR trading v2.0", MQL5 CodeBase, published 2018-01-22, updated 2018-02-28, URL https://www.mql5.com/en/code/19608.
- Source location: page states "Trading signals are generated based on a comparison of two trend indicators: iMA (Moving Average, MA) and iSAR (Parabolic SAR)." It also states the EA works on the zero bar, only one position can be open, and trailing stop is used. The page shows EURUSD H1 Every Tick testing.

## Mechanik

### Entry
- Evaluate on H1 bars using iMA and iSAR.
- Long: price is in bullish relation to iMA and iSAR confirms bullish trend state.
- Short: price is in bearish relation to iMA and iSAR confirms bearish trend state.
- Open only one position per symbol/magic.
- Build review should confirm the exact zero-bar comparison from the downloadable mq5 source; P2 baseline may shift evaluation to closed bars for deterministic replay.

### Exit
- Source supports fixed Stop Loss, fixed Take Profit, Trailing Stop, and Trailing Step.
- P2 baseline: close on opposite MA/SAR state, SL = 1.5 * ATR(14), TP = 1.5R, optional SAR/ATR trailing disabled for first baseline.

### Stop Loss
- Source has pip Stop Loss input; V5 baseline uses ATR-normalized hard stop unless source defaults are selected during build.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One-position-per-magic is source-aligned.
- Disable source trailing for initial P2; sweep fixed trailing as later variant.
- V5 news/spread/Friday-close defaults apply.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL with title, idea author, code author, and publish/update dates. |
| R2 Mechanical | PASS | MA and SAR trend comparison plus fixed SL/TP/trailing and one-position gating are deterministic. |
| R3 DWX-testbar | PASS | iMA, iSAR, OHLC, and tick data are available on DWX symbols. |
| R4 No ML | PASS | No ML, grid, martingale, or adaptive online parameter logic; one active position is explicit. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10508_mql5-sar-tm]] - SAR-only timed holding variant.
- [[strategies/QM5_10516_mql5-sar-rsi]] - SAR plus RSI confirmation variant.

## Lessons Learned
- TBD during pipeline run.
