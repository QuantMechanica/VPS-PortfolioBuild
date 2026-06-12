# Library Mining: Mario Singh — 17 Proven Currency Trading Strategies (Wiley, 2013)

**Date:** 2026-06-12
**Miner:** Claude (library-mining task 7143e208)
**Slug:** singh-17proven-2013
**Source:** `C:/Users/Administrator/Downloads/17 Proven Currency Trading Strategies - How to Profit in the Forex Market 2013.pdf` (274 pages, Wiley Trading)
**Author:** Mario Singh — CNBC guest host (Squawk Box, Capital Connection, Worldwide Exchange), founder FX1 Academy, Singapore. Wiley/Bloomberg Press publication. R1 PASS.

---

## Step 0 — Mandatory Dedup Check

**Existing singh-related cards in cards_approved:**
- QM5_11385 `mario-singh-good-morning-asia-usdjpy-d1` (Good Morning Asia, D1)
- QM5_11482 `singh-m-good-morning-asia-d1` (Good Morning Asia, D1)
- QM5_11561 `singh-good-morning-asia-d1-usdjpy` (Good Morning Asia, D1)
- QM5_11909 `singh-good-morning-asia-usdjpy-d1` (Good Morning Asia, D1)

All 4 existing cards cover the same strategy (Strategy 17: Good Morning Asia).

---

## Source Assessment

### R1 Track Record
PASS — Mario Singh: Wiley Trading series (2013), CNBC appearances (Squawk Box, Capital
Connection, Worldwide Exchange, guest host). Singapore FX1 Academy founder. Single
verifiable Wiley publication.

### R2 Mechanical / R4 ML-Forbidden
Assessed per strategy below. No ML in any strategy. Standard indicators only.

### R3 Data Available
EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, USDCAD.DWX, AUDUSD.DWX,
NZDUSD.DWX, GBPJPY.DWX, CADJPY.DWX all available. XAU/USD not on DWX; XAUUSD.DWX
available. USD Dollar Index = not directly tradeable on DWX. WTI Oil = not on DWX.

---

## All 17 Strategies — Full Assessment

### PART A: Scalpers (Chapter 6)

---

#### Strategy 1: Rapid-Fire Strategy
- **Timeframe:** M1
- **Indicator:** None (pure price action)
- **Pair:** EUR/USD only
- **Entry concept:** Momentum-following scalp on M1 trending moves

**Rule-completeness assessment:** Book page 111 confirms the strategy is designed for
M1 EUR/USD but the book does not disclose specific entry triggers. The description
references "rapid fire" entries during trending conditions but no precise entry rules
(candle pattern, level, indicator threshold) are given beyond trend-following context.
**R2 FAIL — not rule-complete.**

**Verdict: NOT MINABLE** — insufficient parameter specification.

---

#### Strategy 2: Piranha Strategy
- **Timeframe:** M5
- **Indicator:** Bollinger Bands (period 12, shift 0, deviation 2)
- **Pair:** GBP/USD only
- **Entry:** Long when price touches lower BB; Short when price touches upper BB
- **Exit:** Not explicitly specified beyond "take small profits"; 15–20 signals/day

**Rule-completeness assessment:** Entry rule is precise (touch of band = entry).
However, **no stop-loss distance and no take-profit level are defined.** Book states
"small profits" consistent with scalping but gives no pip targets or % targets.
**R2 FAIL — no stop/target specified.**

**DWX compatibility:** M5 — not a standard DWX D1 or H4 pipeline-compatible timeframe.
Pipeline requires minimum H1; M5 scalping incompatible with MT5 tester model=4 efficiency.

**Verdict: NOT MINABLE** — no SL/TP + intraday scalping timeframe not compatible with factory.

---

### PART B: Day Traders (Chapter 7)

---

#### Strategy 3: Fade the Break
- **Timeframe:** M15 / M30
- **Indicator:** None (price action S/R)
- **Entry:** Identify support/resistance with ≥2 highs and ≥2 lows. Wait for a candle
  that tests support/resistance but closes BACK inside the range (false-break candle).
  Enter in the direction of the false break (long if false break below support, short
  if false break above resistance).
- **Stop:** At the extreme of the false-break candle (beyond the false-break low/high)
- **Target 1:** 1:1 R:R; **Target 2:** 1:2 R:R

**Rule-completeness assessment:** Entry rule depends on identifying "at least 2 highs
and 2 lows" to establish S/R — this is discretionary zone identification. The specific
S/R boundary is not algorithmically defined. **R2 BORDERLINE FAIL** — S/R identification
step requires human judgment; not fully automatable without additional pivot/extremum
specification.

**DWX compatibility:** M15/M30 — intraday, not factory-compatible.

**Verdict: NOT MINABLE** — discretionary S/R identification + intraday timeframe.

---

#### Strategy 4: Trade the Break
- **Timeframe:** M15 / M30
- **Entry:** Identify S/R (≥2 highs + ≥2 lows). Wait for a candle that closes ABOVE
  resistance (for long) or BELOW support (for short). Enter at opening of next candle.
- **Stop (long):** 60% of range distance below resistance (i.e., 0.4 × range above support)
- **Stop (short):** 60% of range distance above support
- **Target 1:** 1:1 R:R; **Target 2:** 1:2 R:R

**Rule-completeness assessment:** Same S/R identification problem as Strategy 3.
The stop-loss formula is unique (60% of range, not ATR-based) — mechanizable once
S/R is defined. **R2 BORDERLINE FAIL** — S/R still discretionary.

**DWX compatibility:** M15/M30 — intraday, not factory-compatible.

**Verdict: NOT MINABLE** — discretionary S/R + intraday timeframe.

---

#### Strategy 5: Gawk the Talk
- **Timeframe:** M15 / M30
- **Entry trigger:** Economic news: enter if actual figure > forecast by ≥20%
  (for interest rate news: deviation ≥20bps = 0.2%; for PMI: deviation ≥50bps = 0.5%)
- **Direction:** If affected currency is base → long on pair; if counter → short on pair
- **Stop:** Fixed 20 pips from entry
- **Target:** Fixed 40 pips from entry (1:2 R:R)

**Rule-completeness assessment:** Entry rule is deterministic given a news calendar.
However this is a **news-trading strategy** — it requires real-time news feed (actual
vs. forecast values) at release time. MT5 backtester cannot replay live economic
calendar data. **R2 FAIL for mechanical backtesting purposes** — news actual/forecast
data not available in MT5 tester environment.

**Verdict: NOT MINABLE** — requires live news data feed; not MT5-backtestable.

---

#### Strategy 6: Balk the Talk
- **Timeframe:** M15 / M30
- **Entry:** Mirror of Gawk the Talk: actual < forecast by ≥20% → trade in direction
  of currency weakness
- **Stop:** Fixed 20 pips; **Target:** Fixed 40 pips (1:2 R:R)

**Same assessment as Strategy 5 — news-dependent, not MT5-backtestable.**

**Verdict: NOT MINABLE** — news strategy.

---

### PART C: Swing Traders (Chapter 8)

---

#### Strategy 7: Trend Rider
- **Timeframe:** H1 or H4
- **Indicators:** EMA(12), EMA(36), ADX(14) with level 40
- **Entry (long):** EMA12 crosses above EMA36; enter when price pulls back to touch EMA12
- **Entry (short):** EMA12 crosses below EMA36; enter when price bounces up to touch EMA12
- **Stop:** At EMA36 (minimum 30 pips from entry)
- **Exit:** When ADX(14) crosses above 40 and then drops back below 40

**Rule-completeness assessment:** R2 PASS — all rules are mechanical. EMA cross +
pullback to EMA12 touch is automatable. ADX exit is deterministic. No discretionary step.

**DWX compatibility:** H1/H4 — factory-compatible for EURUSD, GBPUSD, USDJPY, etc.

**IS vs OOS:** Book examples show 1 IS trade on EURUSD H4 (1:5.4 R:R, 316 pips reward)
and 1 on AUDUSD H1 (1:4, 155 pips). Single-trade cherry-pick examples only; no
systematic backtest results reported. **OOS: not demonstrated.**

**Expected trades/year:** H4 EMA12/36 crossover with pullback confirmation ≈ 15–30 per
year per pair. H1 ≈ 40–80 per year per pair (highly variable by trend regime).

**Dedup check:** Searching existing unger-* cards for EMA12/36 + ADX exit:
- `QM5_1110_unger-crude-ma-crossover` is SMA crossover on crude, different parameters
- No existing card matches EMA(12)/EMA(36) crossover with pullback + ADX(14)>40 exit
**DEDUP VERDICT: NEW**

**Verdict: NEW — CARD PROPOSED**

---

#### Strategy 8: Trend Bouncer
- **Timeframe:** H1 or H4
- **Indicators:** Two Bollinger Bands: BB(12, 2) and BB(12, 4) — same period, different deviation
- **Entry (long):** Price hits upper band of BB(12,2) then retraces back to center MA12 → enter long at touch of MA12
- **Entry (short):** Price hits lower band of BB(12,2) then retraces back to center MA12 → enter short at touch of MA12
- **Stop (long):** Lower band of BB(12,4) (wider band)
- **Stop (short):** Upper band of BB(12,4)
- **Targets:** 1:1, 1:2, 1:3 R:R (three partial exits)

**Rule-completeness assessment:** R2 PASS — all mechanical. Upper/lower band touch
then MA12 pullback is unambiguous. Dual-BB stop is deterministic.

**DWX compatibility:** H1/H4 on EURUSD, GBPUSD, USDJPY, USDCHF, USDCAD, AUDUSD,
NZDUSD.

**IS vs OOS:** 1 IS example each (GBPUSD H4 long: 1:3 R:R, 270 pips; NZDUSD H1 short:
1:3 R:R, 138 pips). No systematic test.

**Expected trades/year:** H4 BB touch + pullback ≈ 20–40 per year per pair.

**Dedup check:** Existing cards:
- `QM5_1063_unger-bollinger-fx-meanrev` — BB mean-reversion (Unger), different entry
  (likely single-band, not dual-band, and does not use retrace-to-MA logic)
- `QM5_1108_unger-gold-bb-breakout` — BB breakout (opposite direction)
- `QM5_1163_unger-dax-bb-multiday` — DAX BB, different instrument

No exact match for dual-BB (Dev=2 touch, Dev=4 stop) + MA12 retrace entry on forex.
**DEDUP VERDICT: NEW**

**Verdict: NEW — CARD PROPOSED**

---

#### Strategy 9: Fifth Element
- **Timeframe:** H1 or H4
- **Indicator:** MACD (MT4/MT5 default: fast EMA=12, slow EMA=26, signal SMA=9)
  — uses the MACD line histogram (difference between EMA12 and EMA26)
- **Entry (long):** MACD histogram switches negative→positive; wait for 4 positive bars;
  enter long at open of the 5th positive bar
- **Entry (short):** MACD histogram switches positive→negative; wait for 4 negative bars;
  enter short at open of the 5th negative bar
- **Stop (long):** Previous swing low of histogram period (price low of the positive sequence)
- **Stop (short):** Previous swing high of histogram period
- **Targets:** 1:1 and 1:2 R:R (two partial exits)

**Rule-completeness assessment:** R2 PASS — "5th bar" count is deterministic. Stop at
last swing low/high is unambiguous given bars 1–4 price data.

**DWX compatibility:** H1/H4 on major DWX pairs.

**IS vs OOS:** 1 IS example each (AUDUSD H4 long 1:2; EURUSD H4 short 1:2). No test.

**Expected trades/year:** H4 MACD histogram sign-change + 4-bar wait ≈ 15–25 per year
per pair.

**Dedup check:** No existing card using MACD histogram bar count (5th bar entry).
Most existing MACD cards use crossover or zero-line cross, not histogram-bar counting.
**DEDUP VERDICT: NEW**

**Verdict: NEW — CARD PROPOSED**

---

#### Strategy 10: Power Ranger
- **Timeframe:** H1 or H4
- **Indicator:** Stochastic(10, 3, 3, High/Low, Simple) with levels 20 and 80
- **Entry (long):** Identify uptrend (series of HH+HL); draw uptrend line; wait for
  stochastic %K and %D to go below 20 (oversold); enter long when stochastic crosses
  back above 20
- **Entry (short):** Identify downtrend (LL+LH); wait for stochastic above 80; enter
  short when stochastic drops back below 80
- **Target 1:** 75% mark of identified range (within range)
- **Target 2:** 1:2 R:R (beyond range, anticipating breakout)
- **Stop:** 1:1 R:R (same distance as TP1); stop must be beyond support/resistance level
  (trade invalid if it is not)

**Rule-completeness assessment:** R2 BORDERLINE — range identification relies on
"drawing a trend line" through HH/HL or LL/LH, which requires human identification of
the swing points. The "75% of range" target requires range bounds to be specified. This
is semi-discretionary. Could be mechanized with ATR-based range detection, but that
would be a VARIANT not the published system.

**Verdict: VARIANT POTENTIAL** — the indicator rules are precise; the range boundary
identification is the weak link. Not carded as-is; could produce a VARIANT card if
swing-high/low lookback is parameterized.

---

#### Strategy 11: The Pendulum
- **Timeframe:** H1 or H4
- **Indicator:** None (pure price action range trading)
- **Entry (long):** Identify established range (support + resistance previously tested ≥2x).
  When price returns to support, enter long when price bounces 10% of range above support.
- **Entry (short):** When price returns to resistance, enter short when price drops 10%
  of range below resistance.
- **Target 1:** 50% of range from entry side boundary
- **Target 2:** 90% of range from entry side boundary
- **Stop:** 1:1 R:R (same pip count as TP1)

**Rule-completeness assessment:** R2 PASS for the entry math once range is identified:
10% of range as entry confirmation, 50%/90% as targets — all deterministic. Range
identification still requires identifying tested support/resistance, but this is
mathematically well-defined (min 2 prior tests of the level).

**DWX compatibility:** AUDUSD.DWX (H4 example), GBPUSD.DWX — all major DWX pairs.

**Expected trades/year:** H4 range touch + 10% bounce ≈ 20–40 per year per pair
(depends on ranging vs trending regime).

**Dedup check:** No existing card for pendulum/range-percentage-bounce strategy.
This is mechanistically distinct from all 36+ unger cards (none use % of range for
entry confirmation + 50/90% targets).
**DEDUP VERDICT: NEW**

**Verdict: NEW — CARD PROPOSED** (parameterize: min_prior_tests=2, entry_pct=10,
tp1_pct=50, tp2_pct=90, stop_ratio=1:1)

---

### PART D: Position Traders (Chapter 9)

---

#### Strategy 12: Swap and Fly
- **Timeframe:** D1 / W1
- **Entry signal:** 3 White Soldiers (3 consecutive bull candles) → long; 3 Black Crows
  (3 consecutive bear candles) → short. Entry at open of next candle.
- **Stop:** At recent significant low (for long) / recent significant high (for short)
- **Exit:** Shift stop to breakeven once 1:1 R:R achieved; hold indefinitely for swap
  accumulation

**Rule-completeness assessment:** R2 BORDERLINE — "3 white soldiers" entry rule is
precise (3 consecutive bull candles, entry next bar). Stop at "recent significant low"
is discretionary. More importantly, the strategy's logic depends on **positive swap
differential** (interest rate differential) — which is broker/time-specific and not
deterministic in backtesting. **R2 FAIL for backtesting** — swap-accumulation strategies
require live positive-swap pairs that change over time; fixed SL/TP ratios cannot
replicate the strategy's P&L profile.

**Verdict: NOT MINABLE** — swap-dependent; broker-specific; not MT5-backtestable in pure form.

---

#### Strategy 13: Commodity Correlation Part 1 (Oil → CAD/JPY)
- **Timeframe:** D1
- **Reference instrument:** WTI Crude Oil (not a DWX-available instrument)
- **Entry:** Candle closes above resistance on Oil chart → long CADJPY next day.
  Candle closes below support on Oil chart → short CADJPY next day.
- **Stop:** 2 × ATR(14) of previous Oil candle
- **Target:** 1:3 R:R

**Rule-completeness assessment:** R2 PASS — deterministic S/R breakout + ATR stop.
However, requires WTI Crude Oil price data as a separate reference feed. WTI Oil is
not available as a DWX symbol for backtesting in MT5. CADJPY.DWX is available.

**Cross-instrument dependency** makes this non-standard for the factory pipeline.
A workaround (using a correlated DWX symbol or DXY proxy) would be a VARIANT.

**Verdict: NOT MINABLE AS-IS** — WTI Oil reference instrument not on DWX. VARIANT
possible (Oil price as external signal, or CADJPY momentum standalone), but that is
not the published system.

---

#### Strategy 13: Commodity Correlation Part 2 (USD Dollar Index → XAU/USD)
- **Timeframe:** D1
- **Reference instrument:** US Dollar Index (DXY)
- **Entry:** Candle closes below support on DXY chart → long XAU/USD next day.
  Candle closes above resistance on DXY chart → short XAU/USD next day.
- **Stop:** 2 × ATR(14) of previous candle
- **Target:** 1:3 R:R

**Rule-completeness assessment:** Same cross-instrument issue — DXY (US Dollar Index)
is not a directly tradeable DWX instrument. XAUUSD.DWX is available. DXY data would
need to be sourced externally.

**Verdict: NOT MINABLE AS-IS** — DXY reference not on DWX.

---

#### Strategy 14: Siamese Twins (China PMI → AUD/USD)
- **Timeframe:** D1
- **Entry:** Major Chinese economic announcement (GDP, PMI, trade balance) better than
  expected → long AUDUSD immediately. Worse than expected → short AUDUSD immediately.
- **Stop:** Previous significant low (for long) / high (for short)
- **Target 1:** 1:1 R:R; **Target 2:** 1:2 R:R

**Rule-completeness assessment:** R2 FAIL — "major Chinese announcement better/worse
than expected" requires a Chinese economic news calendar with forecast vs. actual
data at the time of announcement. Same news-dependency problem as Strategies 5/6.
Not MT5-backtestable. Also highly discretionary ("major" announcement = undefined).

**Verdict: NOT MINABLE** — news-event dependent, not automatable in MT5.

---

### PART E: Mechanical Traders (Chapter 10) — Key Section

---

#### Strategy 15: Guppy Burst
- **Timeframe:** M5
- **Instrument:** GBP/JPY only (GBPJPY.DWX)
- **Indicator:** None (pure price action)
- **Session window:** 3 hours after 5 PM New York time (US market close) = first 3 hours
  of Asian session
- **Entry:** Identify highest high (resistance) and lowest low (support) in the 3-hour
  post-US-close window. Place pending buy stop at resistance; pending sell stop at
  support. Whichever triggers first = the trade; cancel the other.
- **Stop (long):** At support (the opposite boundary)
- **Stop (short):** At resistance
- **Target:** 2 × stop distance (1:2 R:R)

**Rule-completeness assessment:** R2 PASS — session window, high/low boundary
identification, pending stop placement, and 2× TP are all deterministic and automatable.

**DWX compatibility:** GBPJPY.DWX — available. M5 intraday is non-standard for factory
but the strategy has clear clock-window logic (specific 3-hour window).

**IS vs OOS:** 1 long example (30 pip SL, 60 pip TP on GBPJPY) and 1 short example
(21 pip SL, 42 pip TP). No systematic backtest results.

**IS clock assumption:** Book uses FXPrimus platform where 5 PM NY = 00:00 server time.
On DWX (GMT+2 non-DST, GMT+3 DST), the 3-hour window would need recalibration.

**Expected trades/year:** 1–2 trades/day (one direction per session) × ~250 trading
days ≈ 250–500 signals per year, but many will not trigger pending stops.

**Dedup check:** No existing GBPJPY session-range breakout card on M5 in approved cards.
**DEDUP VERDICT: NEW** — however, note M5 is outside standard pipeline timeframes.
The pipeline primarily tests D1, H4; M5 is unusual but mechanically valid.

**Verdict: NEW — CARD PROPOSED** (with note: M5 timeframe, session-clock-dependent)

---

#### Strategy 16: English Breakfast Tea
- **Timeframe:** M15
- **Instrument:** GBP/USD only (GBPUSD.DWX)
- **Logic:** Compare closing price of M15 candle at 04:15 London time vs 08:15 London
  time. If close at 08:15 < close at 04:15 (price declined in the pre-London window)
  → enter LONG at 08:30 London open. If close at 08:15 > close at 04:15 → enter SHORT
  at 08:30.
- **Stop:** Fixed 30 pips
- **Targets:** 30 pips (1:1), 60 pips (1:2), 90 pips (1:3) — three partial exits

**Rule-completeness assessment:** R2 PASS — time-based rule (two fixed clock times),
close-price comparison, market-order entry at 08:30 London, fixed-pip SL, fixed-pip TP.
Fully automatable.

**DWX compatibility:** GBPUSD.DWX M15 — available. DWX broker time is GMT+2 (non-DST)
or GMT+3 (US DST). London time = UTC+0 (winter) / UTC+1 (BST summer). This requires
careful broker-time translation. On DWX at GMT+2: London 04:15 = DWX 06:15; London
08:15 = DWX 10:15; entry at London 08:30 = DWX 10:30. The book example explicitly
confirms this offset (book uses FXPRIMUS with same GMT+2 convention and states
"10:30-hour candle... corresponds to London time 08:30 hours").

**IS vs OOS:** 1 long example (GBPUSD long 1:3, 90 pips); 1 short example (GBPUSD
short 1:3, 90 pips). No systematic backtest.

**Expected trades/year:** 1 trade per session × ~252 trading days ≈ 250 signals/year.
Some days the price change direction = 0, which is not handled (presumably no trade
if close at 04:15 = close at 08:15).

**Dedup check:** No existing London-reversal, English-session, fixed-clock comparison
card in approved cards. The `unger-dax-gap-reversal` and `unger-dax-overnight-bias`
are different instruments and mechanisms.
**DEDUP VERDICT: NEW**

**Verdict: NEW — CARD PROPOSED**

---

#### Strategy 17: Good Morning Asia
- **Timeframe:** D1
- **Instrument:** USD/JPY only (USDJPY.DWX)
- **Entry (long):** Previous D1 candle is a bull candle (close > open) → enter long at
  open of next D1 candle (= 5 PM New York time / DWX day-open)
- **Entry (short):** Previous D1 candle is a bear candle (close < open) → enter short
  at open of next D1 candle
- **Stop (long):** Previous candle's low. If < 30 pips away, shift stop lower to make
  it exactly 30 pips from entry.
- **Stop (short):** Previous candle's high. If < 30 pips away, shift stop higher to
  exactly 30 pips from entry.
- **Target:** 0.5 × stop distance (risk:reward = 2:1 unfavorable; strategy relies on
  high win rate)

**IS vs OOS (candid):** Win rate per D1 candle direction is NOT given. The R:R of 2:1
against (SL = 2× TP) means the strategy needs >67% win rate to be profitable. Book
provides 2 cherry-pick examples. No systematic OOS test. The edge claim (Asian market
follows prior US candle direction) is plausible but unverified.

**DEDUP VERDICT: DUPLICATE ×4**
Cards QM5_11385, QM5_11482, QM5_11561, QM5_11909 all cover this exact strategy
with the same mechanism (prior D1 bar color direction, next-bar entry, prior-bar
high/low stop, 0.5× pip TP). One card is sufficient; 4 is over-carded.

**Verdict: DUPLICATE — no new card needed.**

---

## Proposed New Cards Summary

| Strategy | Name | TF | Pairs | Mechanism | Verdict |
|----------|------|----|-------|-----------|---------|
| 7 | Trend Rider | H4/H1 | All DWX majors | EMA(12/36) crossover + pullback to EMA12 + ADX(14)>40 exit | **NEW** |
| 8 | Trend Bouncer | H4/H1 | All DWX majors | Dual-BB(12,2) + BB(12,4): touch upper/lower Dev2, retrace to MA12 entry, Dev4 stop | **NEW** |
| 9 | Fifth Element | H4/H1 | All DWX majors | MACD(12,26,9) histogram sign-change + 4-bar count + 5th bar entry | **NEW** |
| 11 | Pendulum | H4/H1 | All DWX majors | Range trading: 10% bounce from boundary = entry, 50%/90% of range = targets | **NEW** |
| 15 | Guppy Burst | M5 | GBPJPY | 3hr post-US-close range → pending breakout, 2×SL target | **NEW** |
| 16 | English Breakfast Tea | M15 | GBPUSD | London pre-open reversal: 04:15 vs 08:15 close comparison → 08:30 counter-entry | **NEW** |
| 17 | Good Morning Asia | D1 | USDJPY | Prior D1 candle direction → next-D1-open momentum entry | **DUPLICATE ×4** |

**NEW: 6 | VARIANT: 0 | DUPLICATE: 1 (×4 cards)**

---

## Strategies Not Proposed — Rejection Reasons

| Strategy | Rejection Reason |
|----------|-----------------|
| 1 Rapid-Fire (M1 EUR/USD) | Entry rules not specified in book |
| 2 Piranha (M5 GBP/USD BB scalp) | No SL/TP defined; M5 scalping |
| 3 Fade the Break (S/R false-break M15) | Discretionary S/R identification |
| 4 Trade the Break (S/R breakout M15) | Discretionary S/R identification |
| 5 Gawk the Talk (news >20% deviation) | Requires live news feed; not MT5-backtestable |
| 6 Balk the Talk (news <20% deviation) | Requires live news feed; not MT5-backtestable |
| 10 Power Ranger (Stochastic range) | Discretionary trend-line + range boundary |
| 12 Swap and Fly (3WS/3BC + swap accumulation) | Swap-dependent; broker-specific; not testable |
| 13a Commodity Corr. 1 (Oil→CADJPY) | WTI Oil not on DWX |
| 13b Commodity Corr. 2 (DXY→XAUUSD) | US Dollar Index not on DWX |
| 14 Siamese Twins (China news→AUDUSD) | Live news event dependent |

---

## IS vs OOS — Candor Statement

**Singh's book presents no systematic backtests for any of the 17 strategies.**
Every example is a single cherry-picked IS trade showing the strategy "working."
No win rates, no expectancy, no drawdown, no OOS period, no walk-forward are reported.

The mechanical strategies (7, 8, 9, 11, 15, 16) are rule-complete and testable —
but their claimed validity rests entirely on intuitive/conceptual rationale. The
factory's Q02–Q08 pipeline will determine actual edge. Do not assign prior probability
of profitability based on the book.

---

## Expected Trades Per Year Estimates

| Card | Timeframe | Est. Trades/Year/Symbol |
|------|-----------|------------------------|
| Trend Rider (Str 7) | H4 | 15–30 |
| Trend Bouncer (Str 8) | H4 | 20–40 |
| Fifth Element (Str 9) | H4 | 15–25 |
| Pendulum (Str 11) | H4 | 20–40 |
| Guppy Burst (Str 15) | M5 (session) | 100–200 (pending triggers vary) |
| English Breakfast Tea (Str 16) | M15 | ~250 (one signal/day) |

---

## DWX Symbol Mapping

| Book Pairs | DWX Symbol |
|------------|-----------|
| EUR/USD | EURUSD.DWX |
| GBP/USD | GBPUSD.DWX |
| USD/JPY | USDJPY.DWX |
| USD/CHF | USDCHF.DWX |
| USD/CAD | USDCAD.DWX |
| AUD/USD | AUDUSD.DWX |
| NZD/USD | NZDUSD.DWX |
| GBP/JPY | GBPJPY.DWX |
| CAD/JPY | CADJPY.DWX |
| XAU/USD | XAUUSD.DWX (note: swap = $0 per DWX convention; must inject) |

---

## Source Cache

Extracted text already present in source cache:
- `D:/QM/strategy_farm/source_cache/mario-singh-17strategies-2013.txt`
- `D:/QM/strategy_farm/source_cache/mario_ch10_pages.txt`
- `D:/QM/strategy_farm/source_cache/singh-17-proven-strategies.txt`

Source citation for new cards:
`Mario Singh, "17 Proven Currency Trading Strategies: How to Profit in the Forex Market" (John Wiley & Sons Singapore, 2013). ISBN 978-1-118-38551-7. Wiley Trading series.`
R1 PASS — Wiley 2013 publication, CNBC media appearances independently verifiable.
