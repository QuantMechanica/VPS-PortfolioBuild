---
ea_id: QM5_1505
slug: connors-cumulative-rsi-h4
expected_trades_per_year_per_symbol: 100
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/cumulative-oscillator-extreme]]"
  - "[[concepts/pullback-in-trend]]"
indicators:
  - "[[indicators/rsi-2]]"
  - "[[indicators/cumulative-rsi-2-3]]"
  - "[[indicators/sma-200]]"
  - "[[indicators/sma-5]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; body cites FF cluster URL plus Connors/Alvarez Short Term Trading Strategies That Work (ISBN 978-0-9819239-0-1) ch. 5, satisfying the one-source-per-card rule.
r2_mechanical: PASS
r2_reasoning: Five closed-form arithmetic gates over RSI(2) 3-bar cumulative sum, SMA(200), D1 SMA(50), ATR floor, and bar-count cooldown; direction is unambiguous.
r3_data_available: PASS
r3_reasoning: Pure closing-price RSI and SMA inputs are testable on every DWX instrument; SP500.DWX backtest-only with T6 live-promotion gate flagged in card body.
r4_ml_forbidden: PASS
r4_reasoning: Fixed thresholds (CumRSI < 30 / > 270), fixed lookbacks (RSI period 2, sum window 3, SMA 200), explicit ATR-bounded SL added per HR14; no ML or adaptive PnL logic, single position per magic.
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS: Connors/Alvarez book and research-note attribution; R2 PASS: explicit CumRSI/SMA/ATR entry-exit rules; R3 PASS: testable on DWX symbols with SP500.DWX T6 caveat noted; R4 PASS: no ML/adaptive/grid, bounded SL, 1-pos-per-magic."
---

# Connors Cumulative RSI Pullback (H4)

## Quelle
- Source: [[sources/forexfactory-trading-systems]]
- Page / Timestamp: ForexFactory Trading Systems subforum
  cluster "Connors Cumulative RSI EA" / "RSI-2 3-day sum MT4"
  / "Connors CRSI detector" threads (2009-2024). Laurence A.
  Connors + Cesar Alvarez, *Short Term Trading Strategies That
  Work* (TradingMarkets Publishing 2008, ISBN
  978-0-9819239-0-1), ch. 5 ("The Cumulative RSI Strategy").
  Subsequent treatment in Connors + Alvarez, *High Probability
  ETF Trading: 7 Professional Strategies to Improve Your ETF
  Trading* (Trading Markets Analytics 2009, ISBN
  978-0-9819239-1-8), ch. 4. Connors Research Trading Strategy
  Series, "The Cumulative RSI Strategy", 2009 research note.
  Continuation of the Connors cluster opened in Batch 25
  (QM5_1450 Connors RSI-2 single-bar pullback) and Batch 29
  (QM5_1492 Connors VIX-Stretch port). This card adds the
  **sum-over-N-bars aggregation** topology — distinct from the
  single-bar RSI-2 extreme (1450) and distinct from the vol-
  spike trigger (1492). It is the most-cited Connors primitive
  in the *Short Term Trading Strategies That Work* book.

## Mechanik

The Cumulative RSI primitive sums the RSI(2) values over a
rolling 3-bar window to dampen single-bar noise. Connors' rule
in the original 2008 book is:

> Enter long when the 2-day Cumulative RSI(2) is below 35 and
> price is above the 200-day SMA. Exit when the 2-day RSI(2)
> closes above 65, or when price closes above the 5-day SMA.

The original rule is daily-bar — this card ports the same
topology to H4 bars, with bar-counts adjusted to preserve the
equivalent calendar lookback (Connors' 200-day SMA becomes
H4 SMA(200) over 200 H4 bars = ~33 trading days, which retains
the same "intermediate-term trend" semantics on the H4
timeframe per the standard Connors H4 port treatment in the
FF cluster).

Definitions:
- **RSI(2)**: standard 2-bar Wilder RSI.
- **CumRSI(2, 3)[t]**: sum over the last 3 H4 bars =
  RSI(2)[t] + RSI(2)[t-1] + RSI(2)[t-2]. The "3-day sum"
  becomes the "3-bar sum" in the H4 port.

### Entry (long on bullish pullback — short mirror)

All five gates must PASS on bar t:

1. **Cumulative-RSI-extreme gate**: CumRSI(2, 3)[t] < 30 for
   longs / > 270 (= 3 * 90, the equivalent extreme on the upper
   tail) for shorts. Connors' original threshold of 35 (long)
   in *Short Term Trading Strategies* is the asymmetric long-
   side bias; the symmetric extreme 30 = 3 * 10 is the H4-port
   tightening to keep the entry rare (the H4 RSI(2) is more
   volatile per bar than the daily RSI(2), so a tightening of
   the threshold maintains the per-trade frequency).
2. **Trend-bias gate**: close[t] > SMA(200)[t] for longs /
   close[t] < SMA(200)[t] for shorts. The 200-bar SMA on H4
   (~33 trading days) is the H4 port of Connors' 200-day SMA
   filter — defines the medium-term trend.
3. **D1 macro-bias gate**: D1 close > D1 SMA(50) AND D1
   SMA(50)[t] > D1 SMA(50)[t-5] for longs (mirror for shorts).
   Added daily-trend confirmation — Connors' original daily-bar
   strategy didn't need a separate D1 gate because it WAS the
   daily strategy; the H4 port adds D1 SMA(50) to retain
   daily-trend filtering.
4. **ATR floor gate**: ATR(14)[t] > 0.6 * SMA(ATR(14), 200)[t].
   In compressed-vol regimes the RSI(2) extreme can occur on
   nearly-flat bars with no tradable range; ATR floor filters
   these out.
5. **No-recent-entry gate**: no prior Cumulative-RSI entry
   within the last 16 H4 bars. Cumulative RSI can stay extreme
   across 2-3 sequential bars; 16-bar cooldown prevents
   re-entry on the same pullback cluster.

Direction: long on lower-tail extreme + uptrend / short on
upper-tail extreme + downtrend. Order: market on H4 close of
bar t.

### Exit

- **TP1**: 1.5 * ATR(14)[t] from entry — close 60% of
  position. (Connors' original exit-on-RSI(2)>65 is replaced
  by a measurable ATR-based partial because the per-trade
  R-multiple is more controllable.)
- **TP2**: close > SMA(5)[t'] for longs / close < SMA(5)[t']
  for shorts (Connors' alternate exit). Close remaining 40%.
  This preserves Connors' original "exit on 5-day SMA cross"
  rule as the secondary exit.
- **Time-stop**: 20 H4 bars elapsed without TP1 → close at
  market. (Connors' original holding-time per the book is
  typically 1-4 days = 6-24 H4 bars.)

### Stop Loss

Hard SL at 2.0 * ATR(14)[t_entry] from entry. Fixed at fill,
never trailed. **Note**: Connors' original 2008 book strategy
had no stop loss (relying on the 200-day SMA filter + RSI-65
exit as the bounded risk control). The H4 port adds an explicit
ATR-based SL per HR14 worst-case-bounded mechanic — Connors'
no-SL version is incompatible with the QM HR14 bounded
worst-case requirement.

### Position Sizing

P2 baseline: RISK_FIXED = $1000 per trade per HR4. Live:
RISK_PERCENT = 0.5%.

### Zusätzliche Filter

- News-blackout: 60 min around NFP / ECB / FOMC.
- Spread filter: spread <= 1.5 * 20-bar median.
- Warm-up filter: require >= 350 H4 bars of history before
  the first entry (200-bar SMA + D1 SMA(50) warm-up + 200-bar
  ATR baseline + Cumulative RSI 3-bar sum + RSI(2) 2-bar
  warm-up).

### Target symbols

Cumulative RSI(2) + SMA-trend filters work on every DWX
instrument with clean closing-price series. Initial P2 baseline
scope: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX,
USDCAD.DWX (FX majors), NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX
(index CFDs — Connors' original 2008 book examples were S&P
500 and equity ETFs, indices port naturally; SP500.DWX backtest-
only — T6 live-promotion gate flagged below), XAUUSD.DWX,
XTIUSD.DWX (commodities). H4 timeframe.

**SP500.DWX live-promotion T6 gate**: SP500.DWX is a Custom
Symbol (OWNER-imported ticks 2018-07→2026-05, backtest-only
since 2026-05-16). If P2-P9 pass on SP500.DWX, T6 AutoTrading
enable requires parallel-validation on NDX.DWX or WS30.DWX
before live promotion — Board Advisor T6-gate enforcement per
`processes/qb_reputable_source_criteria.md`.

## Concepts (was ist das für eine Strategie)
- [[concepts/cumulative-oscillator-extreme]] — primary (sum
  over N bars dampens single-bar noise so the extreme reading
  reflects sustained pullback, not a single-bar spike — the
  Connors 2008 contribution)
- [[concepts/pullback-in-trend]] — secondary (entry is a
  bullish pullback in an uptrend / bearish pullback in
  downtrend — continuation primitive, not reversal)

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PENDING | FF Trading Systems cluster URL + Connors + Alvarez *Short Term Trading Strategies That Work* TradingMarkets 2008 ch. 5 (ISBN-cited, named-author book) + Connors + Alvarez *High Probability ETF Trading* TradingMarkets 2009 ch. 4 (ISBN-cited follow-up) + Connors Research 2009 research note. Larry Connors is a publicly-identifiable trader (TradingMarkets founder, multiple books, Connors Research). R1 PASS expected under relaxed 2026-05-15 criteria. |
| R2 Mechanical | PENDING | All five gates are closed-form arithmetic over RSI(2) sum + SMA(200) + D1 SMA(50) + ATR + bar-count cooldown. Direction is unambiguous (extreme + trend-direction). Connors' verbal rule reduces directly to numeric inequalities. R2 PASS expected. |
| R3 Data Available | PENDING | Pure closing-price input + RSI + SMA + ATR — testable on every DWX symbol. R3 PASS expected (with SP500.DWX T6 gate flag for SP500-specific extension). |
| R4 ML Forbidden | PENDING | No ML, no adaptive parameters, fixed thresholds (CumRSI(2,3) < 30 / > 270 from H4 port of Connors 2008 ch. 5), fixed lookbacks (RSI period 2, sum window 3, SMA(200), SMA(5), 16-bar cooldown), fixed exit multiples (1.5 ATR TP1, 2.0 ATR SL). The H4 port explicitly adds an ATR-bounded SL where Connors' original used none — required for HR14 bounded worst-case. Single position per magic per HR14. R4 PASS expected. |

## Pipeline-Verlauf
- G0: PENDING

## Verwandte Strategien
- [[strategies/QM5_1450_connors-rsi-2-pullback-h4]] — sibling
  (Connors RSI-2 single-bar extreme pullback; this card uses
  the 3-bar sum CumRSI(2,3) primitive. Topologically distinct
  — single-bar trigger vs. sum-over-3-bars aggregation — same
  Connors-2008 book.)
- [[strategies/QM5_1492_connors-vix-spike-reversal-h4]] —
  distinguished (Connors VIX-Stretch port = vol-spike trigger,
  reversal primitive; this card = oscillator-extreme pullback,
  continuation primitive. Different trigger topology and trade
  direction logic.)
- [[strategies/QM5_1117_hopwood-rsi-pullback-h1]] —
  distinguished (Hopwood RSI(14) pullback in trend on H1 with
  single-bar RSI extreme; this card is RSI(2) Cumulative sum on
  H4. Different RSI period + sum aggregation + timeframe.)

## Lessons Learned (während Pipeline-Lauf)
- <Datum>: <Erkenntnis> — siehe `docs/ops/LESSONS_LEARNED_<YYYY-MM>.md`

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
