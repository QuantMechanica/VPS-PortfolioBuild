---
ea_id: QM5_11422
slug: williams-18ma-outside-bar-entry-d1
type: strategy
source_id: bb9e26af-ebd1-5a26-b1a8-cc4d78835f03
sources:
  - "[[sources/williams-inner-circle-workshop-trading-method]]"
concepts:
  - "[[concepts/moving-average-filter]]"
  - "[[concepts/outside-bar]]"
  - "[[concepts/stop-order-entry]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/sma]]"
period: D1
source_citation: "Larry Williams, Inner Circle Workshop Trading Method, local PDF: C:\\Users\\Administrator\\Dropbox\\Finanzen\\Forex\\###  Forex to read\\Inner Circle Workshop Trading Method. (Larry Williams) (Z-Library).pdf"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 20
g0_approval_reasoning: "R1 single source_id and Williams local PDF attribution; R2 deterministic MA/outside-bar D1 stop-entry plus exit/SL with plausible >2/year/symbol cadence; R3 DWX FX D1 testable; R4 deterministic no ML/HR14 issue."
---

# QM5_11422 Williams — 18-Bar MA Two-Outside-Bar Entry (D1)

## Quelle
- Source: "Inner Circle Workshop Trading Method" by Larry Williams
- File: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\Inner Circle Workshop Trading Method. (Larry Williams) (Z-Library).pdf`
- Source Citation: 2026 local PDF URL/path attribution captured in `source_citation` frontmatter.
- R1: PASS — Larry Williams, World Cup Trading Championship winner, 37 years experience.

## Mechanik

**Concept**: The 18-period MA divides the market into bullish and bearish regimes. When two consecutive D1 bars have their lows entirely above the 18-bar MA (and neither bar is an inside bar), market structure confirms the uptrend on the lowest extreme. The entry is a BUYSTOP at the highest high of those two bars — a breakout confirmation rather than a close-only signal.

The inside-bar exclusion is critical: inside bars indicate indecision/noise and would produce false signals if included.

### Definitions
- **Inside bar**: `High[i] < High[i-1] && Low[i] > Low[i-1]` — both high and low are within prior bar's range.
- **Outside bar (or normal bar)**: not inside.

### MA Setup
- `MA18 = iMA(NULL, PERIOD_D1, 18, 0, MODE_SMA, PRICE_CLOSE, i)` (Williams uses "18-bar MA of closes" — SMA implied)

### Entry

**LONG** (two non-inside-bar days with lows above MA18):
1. `Low[1] > MA18[1]` — yesterday's low above MA18.
2. `Low[2] > MA18[2]` — day before yesterday's low above MA18.
3. `!(High[1] < High[2] && Low[1] > Low[2])` — bar[1] is NOT an inside bar vs bar[2].
4. `!(High[2] < High[3] && Low[2] > Low[3])` — bar[2] is NOT an inside bar vs bar[3].
5. Place **BUYSTOP** at `max(High[1], High[2]) + 1 pip` — the highest high of the two qualifying bars.

**SHORT** (two non-inside-bar days with highs below MA18):
1. `High[1] < MA18[1]` AND `High[2] < MA18[2]`.
2. Neither bar[1] nor bar[2] is an inside bar.
3. Place **SELLSTOP** at `min(Low[1], Low[2]) - 1 pip`.

### Exit
- TP: 2× ATR(14) from entry.
- Williams' preferred exit: 3-bar trailing stop (lowest true low of 3 non-inside-day bars from most favorable close).
- P2 default: fixed 2× risk TP.

### Stop Loss
- LONG: `min(Low[1], Low[2]) - 1 pip` — low of the lowest of the two setup bars.
- SHORT: `max(High[1], High[2]) + 1 pip`.
- P2 cap: 80 pips.

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: D1
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX
- Williams tested: Copper, GBP, Gold, JPY, Coffee, Soybeans, Sugar, T-Bonds — forex pairs are appropriate
- Spread cap: 25 pips
- Cancel pending stop order if a new MA18 setup forms in the opposite direction

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Larry Williams, World Cup Trading Championship winner, 37 years. |
| R2 Mechanical | PASS | MA comparison, inside-bar test, two-bar lookback, highest high calculation — all arithmetic. Stop order entry fully defined. |
| R3 Data Available | PASS | D1 DWX FX. SMA18 MT5-native. |
| R4 No ML | PASS | Fixed period (18). |

G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Williams Inner Circle Workshop

## Implementation Notes for Codex (P1)
- `ma18[i] = iMA(NULL, PERIOD_D1, 18, 0, MODE_SMA, PRICE_CLOSE, i)` for i=1,2,3
- Inside bar check for bar[1]: `High[1] < High[2] && Low[1] > Low[2]` → if true, NOT a valid setup bar
- Long setup: `Low[1] > ma18[1] && Low[2] > ma18[2] && !inside_bar[1] && !inside_bar[2]`
- BUYSTOP = `MathMax(High[1], High[2]) + Point`; SL = `MathMin(Low[1], Low[2]) - Point`
- Cancel pending order on each new bar; re-check setup daily
- P3 sweeps: MA period (12/18/25), MA type (SMA/EMA), inside-bar inclusion (with/without filter)

## Verwandte Strategien
- Related: QM5_11406 (carter-tf16-ema7-21-pullback) — also uses stop order entry at recent high; Carter uses EMA cross confirmation instead of two-bar low position
- Differentiator: Williams' two-outside-bar lows-above-MA requirement is a structural strength confirmation without using any crossover indicator — pure price position relative to one MA.

## Lessons Learned
- *(populated as pipeline progresses)*
