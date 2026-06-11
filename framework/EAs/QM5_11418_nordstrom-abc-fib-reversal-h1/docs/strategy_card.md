---
ea_id: QM5_11418
slug: nordstrom-abc-fib-reversal-h1
type: strategy
source_id: ce671b89-6c69-5b90-8af7-071cbd395e3c
sources:
  - "[[sources/nordstrom-tradingwalk-winning-strategy]]"
concepts:
  - "[[concepts/abc-pattern]]"
  - "[[concepts/fibonacci-extension]]"
  - "[[concepts/multi-timeframe]]"
  - "[[concepts/counter-trend-reversal]]"
  - "[[concepts/trend-following]]"
indicators: []
period: H1
source_citation: "Johan Nordstrom (TradingWalk), Winning Trading Strategy (2015), local PDF: C:\\Users\\Administrator\\Dropbox\\Finanzen\\Forex\\###  Forex to read\\313229969-WINNING-TRADING-STRATEGY-pdf.pdf"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 25
g0_approval_reasoning: "R1 source_id single Nordstrom local PDF source; R2 deterministic D1 trend plus H1 ABC Fib entry/SL/TP with plausible cadence; R3 FX DWX testable; R4 deterministic no ML."
---

# QM5_11418 Nordstrom — ABC Fibonacci Reversal in Macro Trend (H1)

## Quelle
- Source: "Winning Trading Strategy" by Johan Nordstrom (TradingWalk, 2015)
- Citation: 2015 local PDF archive; URL: local file path below.
- File: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\313229969-WINNING-TRADING-STRATEGY-pdf.pdf`
- R1: PASS — Johan Nordstrom, named individual author, TradingWalk.

## Mechanik

**Concept**: Multi-timeframe counter-trend reversal in the direction of the macro trend. On the macro timeframe (D1), identify the dominant trend direction by counting candle bodies (more red = downtrend, more green = uptrend). On the entry timeframe (H1/H4), wait for an ABC corrective structure to complete at the Fibonacci extension zone of the correction. Enter in the direction of the macro trend against the local micro-trend.

### Macro Trend Definition (D1)
- Scan last N bars (N=20): count bars where `Close[i] < Open[i]` (red) vs. `Close[i] > Open[i]` (green).
- If `red_count > green_count` → downtrend.
- If `green_count > red_count` → uptrend.
- Threshold: require majority of ≥60% in one direction.

### ABC Pattern Identification (H1)
Uses swing point detection: HIP (High Point) and LOP (Low Point) as in Wilder's definitions:
- `LOP[i]`: bar where `Low[i] < Low[i-1] && Low[i] < Low[i+1]`
- `HIP[i]`: bar where `High[i] > High[i-1] && High[i] > High[i+1]`

**Short setup (in D1 downtrend):**
1. Identify most recent HIP on H1 as point **B** (top of corrective rally).
2. Identify the prior LOP before B as point **A** (bottom before the rally).
3. Price continues rallying above B, creating a new HIP → that new high is point **C**.
4. The AB leg defines the Fibonacci extension: `AB_size = HIP_B − LOP_A`.
5. Fibonacci extension zone from A:
   - Entry zone low: `LOP_A + AB_size × 1.279`
   - Entry zone high: `LOP_A + AB_size × 1.618`
6. **Signal**: C-move high (`HIP_C`) falls within or above this zone.

**Long setup (in D1 uptrend):** mirror — find descending ABC, enter long when C-low is in Fibonacci extension zone below A.

### Entry

**SHORT** (macro downtrend, C-move exhausted in Fib zone):
1. D1 candle count confirms downtrend.
2. ABC pattern on H1: `HIP_C` is in range `[LOP_A + 1.279 × AB, LOP_A + 1.618 × AB]` or beyond.
3. Find the first H1 bar with a green body (`Close > Open`) in the entry zone.
4. Place **SELLSTOP** at the Open of that candle (or enter SELL at close of the candle).
5. SL: above `HIP_C` and above the nearest round number (10-pip rounded) above `LOP_A + 1.618 × AB`.

**LONG**: mirror — first red-body candle in the extension zone during uptrend.

### Exit
- **TP**: Price level of the Open of the first red candle at the A-move low (`LOP_A` bar's open price).
  Rounded to nearest 10-pip level.
- Minimum R:R: 2:1.

### Stop Loss
- SHORT: `HIP_C + buffer` (buffer = 5 pips or round-number above 1.618 extension).
- LONG: `LOP_C - buffer`.
- P2 cap: 80 pips (H1 bars).

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Primary timeframe: H1 (entry); D1 (trend filter)
- Instruments: GBPUSD.DWX (Nordstrom's example pair); GBPJPY.DWX, EURUSD.DWX
- Spread cap: 20 pips
- Cancel setup if D1 trend count flips to opposite majority before entry

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Johan Nordstrom, named author, TradingWalk 2015. |
| R2 Mechanical | PASS | Candle-body trend count, swing HIP/LOP detection, Fibonacci extension arithmetic — all computable from OHLC. No discretion required. |
| R3 Data Available | PASS | H1 + D1 DWX FX data. No external indicators required. |
| R4 No ML | PASS | Fixed Fib levels (1.279, 1.618), fixed lookback for body count. |

G0 APPROVE eligible.

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Nordstrom Winning Trading Strategy PDF

## Implementation Notes for Codex (P1)
- D1 trend: count green/red bodies on last 20 D1 bars; require ≥12/20 (60%) in one direction
- H1 swing detection: ZigZag variant — scan for 3-bar LOP/HIP patterns with minimum swing size (5 pips) to avoid noise
- ABC identification: track last 3 confirmed swings; classify A=LOP, B=HIP, C=HIP (for short); verify C>B
- Fib zone: `zone_low = A + 1.279 * (B - A)`, `zone_high = A + 1.618 * (B - A)`; if C >= zone_low → signal active
- Entry candle: first candle whose body opens inside or above zone_low; SELLSTOP at Open + Point
- Round-number rounding: `round(price / 0.001) * 0.001` for 10-pip rounding on 5-decimal pairs
- TP = A_bar_open (open of the bar where LOP_A formed), rounded to nearest 0.001
- P3 sweeps: Fib levels (1.0/1.272/1.618 lower bound), D1 trend lookback (15/20/30 bars), swing min size (3/5/10 pips)

## Verwandte Strategien
- Related: QM5_11413 (wilder-directional-movement-di14-cross-d1) — also uses a trend filter before entry; Nordstrom uses candle-body count instead of DI indicator
- Differentiator: ABC structure combined with Fibonacci extension creates a specific price-structure entry that most trend-following EAs lack. The entry is at a structural exhaustion point, not a simple MA cross.

## Lessons Learned
- *(populated as pipeline progresses)*
