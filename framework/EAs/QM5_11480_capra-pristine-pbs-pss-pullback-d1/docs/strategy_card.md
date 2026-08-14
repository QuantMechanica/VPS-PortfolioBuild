---
ea_id: QM5_11480
slug: capra-pristine-pbs-pss-pullback-d1
type: strategy
source_id: 60dd4b99-251b-5bb7-95d3-aca347a243ca
sources:
  - "[[sources/capra-greg-pristine-trading-method]]"
concepts:
  - "[[concepts/pullback-in-trend]]"
  - "[[concepts/consecutive-bar-pattern]]"
  - "[[concepts/stop-order-entry]]"
  - "[[concepts/trend-filter]]"
indicators:
  - "[[indicators/ema]]"
period: D1
source_citation: "Greg Capra & Oliver Velez, Trading the Pristine Method (Pristine Capital Holdings / Wiley 2001). R1 PASS — Wiley authors, Pristine Capital Holdings founders. PBS = Pristine Buy Setup; PSS = Pristine Sell Setup."
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
expected_trades_per_year_per_symbol: 30
g0_approval_reasoning: "R1 single Capra/Velez source_id/citation; R2 mechanical EMA trend, pullback stop-entry, SL/TP/time exits with plausible D1 cadence >2/year/symbol; R3 testable on DWX FX D1; R4 deterministic non-ML one-position rules."
---

# QM5_11480 Capra — Pristine Buy/Sell Setup Pullback (D1)

## Quelle
- Source: Greg Capra & Oliver Velez, "Trading the Pristine Method" (Wiley, 2001; also seminar workbook editions)
- R1: PASS — Greg Capra is co-author of "Trading the Pristine Method" (Wiley, 2001) and "Techniques of Tape Reading" (McGraw-Hill, 2003). Oliver Velez authored multiple Wiley books. Named Wiley/McGraw-Hill authors.

## Mechanik

**Concept**: The Pristine Buy Setup (PBS) captures pullbacks within uptrends. In a macro Stage 2 uptrend (price above rising 20MA), a pullback of 3+ consecutive lower highs (or 3+ bearish candles) represents a temporary correction against the trend. When price breaks above the last pullback bar's high, the trend resumes and offers a low-risk entry with stop just below the pullback low. The PSS mirrors this for downtrends.

**Trend Context**: Pristine uses Stage 2 (uptrend) and Stage 4 (downtrend) as the filter. For FX mechanization: Stage 2 = Close[1] > EMA20[1] AND EMA20[1] > EMA20[6] (rising EMA20 slope over 5 bars). Stage 4 = inverse.

### Indicators
- `EMA20 = iMA(NULL, PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE)` — trend filter

### Entry

**LONG — Pristine Buy Setup (PBS):**
1. Trend: `iClose(D1,1) > EMA20[1]` AND `EMA20[1] > EMA20[6]` (Stage 2 uptrend)
2. Pullback: 3+ consecutive lower highs: `High[1] < High[2]` AND `High[2] < High[3]` AND `High[3] < High[4]`
   - OR 3+ consecutive bearish bars: `Close[1] < Open[1]` AND `Close[2] < Open[2]` AND `Close[3] < Open[3]`
3. Entry: BUYSTOP at `High[1] + 1pip`; valid for 1 bar; cancel at close of bar[0] if not filled
4. SL = `min(Low[1], Low[0])` when filled — below pullback bar's low

**SHORT — Pristine Sell Setup (PSS):**
1. Trend: `iClose(D1,1) < EMA20[1]` AND `EMA20[1] < EMA20[6]` (Stage 4 downtrend)
2. Rally: 3+ consecutive higher lows: `Low[1] > Low[2]` AND `Low[2] > Low[3]` AND `Low[3] > Low[4]`
   - OR 3+ consecutive bullish bars: `Close[1] > Open[1]` AND `Close[2] > Open[2]` AND `Close[3] > Open[3]`
3. Entry: SELLSTOP at `Low[1] - 1pip`; cancel at close of bar[0] if not filled
4. SL = `max(High[1], High[0])` when filled — above rally bar's high

### Exit
- **TP**: Prior swing pivot in trade direction — for long: `iHighest(D1, MODE_HIGH, 10, 2)` as proxy for nearest prior pivot high
- **Trail**: After 2 bars in trade direction, trail stop below each subsequent bar's low (long) / above each high (short)
- **SL**: Opposite extreme of pullback/rally (as above)
- **Time stop**: exit after 5 D1 bars if neither TP nor SL hit

### Stop Loss
- Below pullback low (long) / above rally high (short)
- P2 cap: 80 pips (skip if SL > 80 pips)

### Position Sizing
- `RISK_FIXED = $1000` for P2.
- `RISK_PERCENT = 0.5%` for live.

### Zusätzliche Filter
- Timeframe: D1
- Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX
- Spread cap: 25 pips
- No Friday entry
- EMA20 trend filter required (do not trade counter-trend)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Greg Capra (Wiley 2001, McGraw-Hill 2003), Oliver Velez (multiple Wiley books). Named published authors. |
| R2 Mechanical | PASS | 3 consecutive lower highs: OHLC comparison. EMA20 slope: iMA difference over 5 bars. BUYSTOP at High[1]: arithmetic. All MT5-native. |
| R3 Data Available | PASS | D1 DWX FX. iMA/iHigh/iLow/iClose/iOpen MT5-native. |
| R4 No ML | PASS | Fixed count (3 bars), fixed EMA period (20), fixed slope lookback (5 bars). No ML. |

G0 APPROVE — R1 PASS (Capra/Velez, Wiley authors).

## Pipeline-Verlauf
- G0: 2026-05-23 — drafted from Greg Capra & Oliver Velez, Trading the Pristine Method (Wiley 2001 / seminar)

## Implementation Notes for Codex (P1)
- EMA20: `h_ema = iMA(NULL,PERIOD_D1,20,0,MODE_EMA,PRICE_CLOSE)`; read buffer 0 into ema_array; trend check: `ema_array[1] > ema_array[6]` for uptrend
- Consecutive lower highs: `iHigh(NULL,PERIOD_D1,1) < iHigh(NULL,PERIOD_D1,2) && iHigh(NULL,PERIOD_D1,2) < iHigh(NULL,PERIOD_D1,3) && iHigh(NULL,PERIOD_D1,3) < iHigh(NULL,PERIOD_D1,4)`
- Bearish bar check (alternative condition): `iClose(NULL,PERIOD_D1,1) < iOpen(NULL,PERIOD_D1,1)` etc.
- BUYSTOP: `iHigh(NULL,PERIOD_D1,1) + pip_offset`; 1-bar validity
- SL at entry: use pending-order SL = `MathMin(iLow(D1,1), iLow(D1,2)) - pip_offset`
- TP proxy: use ATR(14)[1] × 2.0 from entry as fixed target if swing-high detection complex
- P3 sweeps: pullback bar count (2/3/4), trend filter (EMA20/EMA50/off), pullback mode (lower-highs/red-bars/both), SL ref (bar1-low/bar2-low), TP method (ATR-2x/swing-pivot/trail-only), time-stop (3/5/7 bars)

## Verwandte Strategien
- Related: QM5_11461 (goodwin-j-outside-bar-daily-reversion-d1) — also D1 bar-count pattern; outside bar vs. consecutive pullback bars
- Related: QM5_11437 (carter-t-ema18-adx-pullback-h1) — also pullback-in-trend; H1 EMA touch vs D1 consecutive bar pullback

## Lessons Learned
- *(populated as pipeline progresses)*
