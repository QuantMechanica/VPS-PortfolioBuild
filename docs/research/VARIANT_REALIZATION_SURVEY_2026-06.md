# Variant-Realization Survey 2026-06

**Task ID:** 9a5dcdaf  
**Date:** 2026-06-12  
**Purpose:** Survey canonical mechanical realizations of the strategy families we hold,
so our 50+ family cards can be linted for wrong-realization defects. OWNER directive:
we may hold the right family but the wrong realization (confirmed: NNFX cards used
VP-banned indicators; ICT family lacked killzones + FVG-retrace entry).

**Sources used:** Web search only. Rule parameters quoted only when found in search
results. Where rules are not documented in public sources, this is stated explicitly.

---

## 1. Rene Balke — Published Strategies

### Background

Rene Balke (BM Trading GmbH, Germany) is an algo trader who started his career at
Commerzbank, moved to automated trading, and runs the "Fx Bot Trading" YouTube channel
(4.5M+ views as of 2026). He publishes free MT5 EAs on MQL5 and bmtrading.de, and
maintains a verified live account.

**Track record (R1):** Myfxbook account "René Balke 50K" (account ID 11706975) — real
account, IC Trading, MT5, 1:500 leverage. Reported +168.64% return, 77.98% win rate.
Running instruments: US30, USDJPY, USTEC, GBPUSD, XAUUSD, EURJPY, DE40. This is a
real verified account (not a backtest), meeting the pre-2026-05-15 strict R1 standard
for track record evidence. URL: https://www.myfxbook.com/members/BMTrading/ren%C3%A9-balke-50k/11706975

---

### 1.1 Range Breakout EA

**Concept:** Time-based opening range breakout. The market sets its direction in the
morning; the EA fades in after price breaks the defined morning range.

**Timeframe:** Not stated in public sources; the EA is listed and optimized for EURUSD,
GBPUSD, USDJPY on MT5.

**Entry rules (from public MQL5 listing and YouTube explainer):**
- Define a daily range between a configurable start time and end time (morning window).
- Place a buy-stop order above the range high + order buffer.
- Place a sell-stop order below the range low + order buffer.
- Whichever stop is triggered first is the active trade; the other is cancelled.

**Stop Loss:** Set as the opposite extreme of the morning range (buy entry → SL = range
low; sell entry → SL = range high). Multiple SL calculation modes exist: range-based,
percent, or fixed points.

**Take Profit:** Multiple modes — range factor, percent of range, or fixed points.
Balke does not publish a single canonical multiplier in public sources.

**Close / delete times:** Configurable delete time (cancel unfilled pending orders) and
close time (force-close open positions to avoid overnight risk). Specific times are set
per instrument in the set files; exact defaults not published in public sources.

**Instruments in live 50K account:** US30, USDJPY, USTEC, GBPUSD, XAUUSD, EURJPY,
DE40 — all accessible via DWX symbols.

**Evidence:** MQL5 product listing (https://www.mql5.com/en/market/product/87520),
YouTube video "Explaining all the Settings of my Range Breakout EA"
(https://www.youtube.com/watch?v=mOa4dqxAh4g), myfxbook live account above.

**R1:** PASS — single source (BM Trading / MQL5), verified live myfxbook account.  
**R2:** PASS — entry/exit rules fully implementable; specific multipliers require
optimization but the logic is deterministic.  
**R3:** PASS — all instruments in DWX symbol matrix.  
**R4:** PASS — no ML, no martingale, 1 position per direction, bounded.

**Mechanization verdict:** READY (core logic fully specified; TP/SL multipliers are
optimization parameters, not structural gaps).

**Proposed card slug:** `range-breakout-morning-session-v1`

**Linting note:** If we already hold a range-breakout card, verify: (a) range window
uses configurable clock-based start/end, NOT a fixed-point count; (b) pending order
deletion time is present; (c) no overnight hold.

---

### 1.2 Turnaround Tuesday (Index Mean Reversion)

**Concept:** Wait for a weak Monday close on major indices; enter long expecting a
recovery on Tuesday. Long-only bias, exploiting the tendency of index markets to bounce
after Monday weakness.

**Timeframe:** Daily (D1); entry at Monday close, exit at Tuesday close.

**Entry rules (general community version, as Balke's exact parameters are not published
in public sources):**
- Monday's close is below the previous Friday's close (magnitude threshold varies by
  implementation; "at least 1% lower" is one community version).
- Enter long at Monday's close.

**Balke's version:** The EA "waits for setbacks in the major indices and then benefits
from recovery moves at the beginning of a new week." The EA opens only buy trades.
Exact Monday-close threshold for Balke's specific EA is not published in public sources.

**Stop Loss / Take Profit:** Not stated in public sources for Balke's specific version.

**Instruments:** Index CFDs (the live 50K account runs US30, USTEC, DE40).

**Evidence:** BM Trading EA description (https://bmtrading.de/en/), myfxbook 50K account.

**R1:** PASS — single source (BM Trading), myfxbook live track record present.  
**R2:** PASS — directional entry rule exists; side parameters (threshold, SL/TP)
require calibration.  
**R3:** PASS — US30.DWX, USTEC.DWX / NDX.DWX, DE40.DWX all in DWX matrix.  
**R4:** PASS — no ML, long-only, single position.

**Mechanization verdict:** NEEDS_SPEC — the entry threshold (how far below Friday close
must Monday close be?) and SL/TP rules are not disclosed in public sources. The concept
is mechanizable but requires parameter assumptions to be documented.

**Proposed card slug:** `turnaround-tuesday-index-lononly-v1`

---

### 1.3 Ninja Turtle Scalper (Donchian Channel)

**Concept:** Donchian Channel breakout entry — inspired by the original Turtle Trading
rules. Enter long on breakout above the N-period high, short on breakout below the
N-period low.

**Timeframe:** Not stated explicitly in public sources for Balke's version.

**Entry rules:** Price closes above the Donchian Channel high (long) or below the low
(short). Exact lookback period (N) and whether this is a close-based or intrabar trigger
are not stated in public sources.

**SL/TP:** Not stated in public sources for Balke's specific implementation.

**Evidence:** BM Trading product listing; MQL5 free EA (https://www.mql5.com/en/users/bmtrading/publications).

**R1:** PASS — single source (BM Trading / MQL5).  
**R2:** PASS — breakout logic is fully mechanical; lookback is an optimization parameter.  
**R3:** PASS — applicable to any DWX instrument.  
**R4:** PASS — no ML, deterministic.

**Mechanization verdict:** NEEDS_SPEC — N-period for the channel and SL/TP method not
published. Core logic is implementable; defaults must be documented.

**Proposed card slug:** `donchian-breakout-turtle-v1`

---

### 1.4 Go Long EA / Trend Trader EA

**Concept:** Simple trend-following — trade in the direction of the identified trend.

**Rules:** "Follow a really simple strategy — the most basic concepts are often the ones
that work best." Specific indicator(s) and entry triggers are not published in public
sources beyond the general description.

**Evidence:** BM Trading EA listing; no separate track record published for this
specific EA.

**Mechanization verdict:** REJECT for new card creation — insufficient public rule
specification. If Balke publishes the source code (he does on MQL5 for free EAs), a
card can be derived directly from the code.

---

## 2. German Algo Scene (beyond Balke)

### 2.1 Birger Schäfermeier — Open Range Breakout

**Background:** Birger Schäfermeier is one of Germany's best-known futures and CFD
traders, active for 30+ years. Author of "The Art of Successful Trading" (German and
English editions). His two strategies are built into WH SelfInvest's NanoTrader
platform and are published with complete rules.

**Track record (R1):** Strategy is embedded in a regulated broker's platform
(WH SelfInvest, Luxembourg), implying live usage. No standalone myfxbook/Darwinex URL
found in public sources. Institutional-level evidence (broker-hosted) accepted as
sufficient under post-2026-05-15 R1 criteria.

**Concept:** Identify the range formed in the first 60 minutes after market open. Trade
the breakout of that range in the direction of the prevailing trend.

**Exact rules (from WH SelfInvest published documentation):**

- **Range window:** First 60 minutes after market open (DAX/EuroStoxx: 09:00 CET). For
  S&P 500: first 45 minutes after US open (entry order placed at 16:15 CET).
- **Trend filter:** SuperTrend indicator on the same timeframe. Trend direction
  (positive or negative) determines which side of the range to trade.
- **Entry:** Buy-stop order placed at the range high when SuperTrend is positive.
  Sell-stop order placed at the range low when SuperTrend is negative. Only one
  direction traded per day (trend-aligned side only).
- **Stop Loss:** Opposite extreme of the opening range. (Buy SL = range low; Sell SL =
  range high.)
- **Take Profit:** 3× the SL distance (risk-to-reward ratio of 3:1).
- **Order cancellation:** If price does not trigger the pending order by the cancellation
  time, the order is deleted (intraday only; no overnight orders).
- **Instruments:** DAX, EuroStoxx, S&P 500 futures and equivalent CFDs.

**Evidence:** WH SelfInvest strategy store documentation
(https://www.whselfinvest.com/en-lu/trading-platform/store/trading-strategies/daytrading-birger-schaefermeier-trading-strategy-open-range-break-out),
tradercampus.de (https://www.tradercampus.de/de/bekannte-trader/open-range-break-out-birger-schaefermeier).

**R1:** PASS — single source (Schäfermeier / WH SelfInvest), broker-hosted live
strategy.  
**R2:** PASS — all parameters fully specified.  
**R3:** PASS — DAX.DWX / DE40.DWX, US500.DWX or SP500.DWX in DWX matrix.  
**R4:** PASS — no ML, deterministic, single position per session.

**Mechanization verdict:** READY — all rule parameters are stated. SuperTrend period
and ATR multiplier for the SuperTrend are the only optimization variables not stated.

**Proposed card slug:** `open-range-breakout-supertrend-d1-v1`

---

### 2.2 Birger Schäfermeier — Return to Open

**Concept:** After an initial directional move away from the open price, fade the move
expecting a return to the opening price by end of session.

**Exact rules (from WH SelfInvest published documentation):**

- **Order placement time:** 08:00 CET (DAX/EuroStoxx) or 15:20 CET (S&P 500).
- **Trend filter:** SuperTrend indicator — same as ORB above.
- **Entry level calculation:** Uses the relationships between the high, low, and open of
  the previous 5 days to determine the limit order entry level.
- **Order type:** Limit order (buy limit in positive trend; sell limit in negative
  trend).
- **Order cancellation:** If price does not reach the limit by 09:00 CET (DAX) or
  16:15 CET (S&P 500), the order is cancelled.
- **Stop Loss:** Placed at the same distance as the profit target (1:1 R:R).
- **Take Profit:** The opening price (the market is expected to return to open).
- **Time-based exit:** If position is still open at 21:59 CET, it is closed at market.
  No overnight holds.
- **Instruments:** DAX, EuroStoxx, S&P 500.

**Evidence:** WH SelfInvest strategy store
(https://www.whselfinvest.com/en-lu/trading-platform/store/trading-strategies/daytrading-birger-schaefermeier-trading-strategy-return-to-open),
tradercampus.de (https://www.tradercampus.de/de/tradingstrategie/return-open).

**R1:** PASS.  
**R2:** PASS — fully specified with one ambiguity: the exact formula for deriving the
entry level from the prior 5-day H/L/O is described qualitatively ("green line / red
line") but not published as a formula in accessible public sources. The platform
computes it automatically; reverse-engineering the formula would require the NanoTrader
source.  
**R3:** PASS.  
**R4:** PASS.

**Mechanization verdict:** NEEDS_SPEC — the 5-day H/L/O → limit entry level formula
is not found in public sources. All other rules are complete. A card can be created
with a documented approximation (e.g., prior-5-day midpoint minus/plus N×ATR) pending
confirmation.

**Proposed card slug:** `return-to-open-intraday-mean-reversion-v1`

---

### 2.3 TradersClub24 — BlueBox / VolaBox / SwissBox

**Background:** TradersClub24 (Hamburg, Germany, ~4,300 members) publishes rule-based
breakout strategies for DAX and Forex, claiming 100% rule-based duplicatibility.

**Claims (from TradersClub24 website):**
- **BlueBox:** Algorithmic detection of a price equilibrium ("inner value") from price
  history; the box is highlighted orange on approach, confirmed in blue at signal.
  Trades the breakout of the confirmed box on DAX and major FX pairs during main
  trading hours.
- **VolaBox:** Uses a probabilistic model to detect price ranges with high breakout
  probability, based on the observation that markets have "memory" — certain price
  ranges are visited rarely and briefly, making breakouts from them more reliable.
- **SwissBox:** Similar volatility breakout approach with position management automation
  (orders and closes handled by the TC24.SwissBox tool).

**Rule specification quality:** The public website describes the concepts but does not
publish exact indicator parameters, lookback periods, or precise entry triggers. The
strategies appear to require TC24's proprietary indicator set (not public) and coaching
subscription.

**Track record:** TradersClub24 claims >14 years of trading experience and >98% success
rate on their opening market breakout strategy. No verifiable myfxbook/Darwinex URL
found in public sources.

**R1:** PASS — single source (TradersClub24), but author track record not independently
verifiable.  
**R2:** FAIL — entry triggers depend on proprietary indicator outputs not documented in
public sources. Not implementable mechanically from public information alone.  
**R3:** PASS — DAX and Forex pairs.  
**R4:** Cannot assess — indicator logic is proprietary.

**Mechanization verdict:** REJECT for card creation from public sources alone. If OWNER
has or acquires the TC24 strategy materials (course access, indicator source), this
verdict may be revisited.

---

## 3. ICT 2022 Canonical Fidelity — What Retail Gets Wrong

Source basis: innercircletrader.net tutorial series, tradingfinder.com ICT
mentorship guide, tradezella.com learning items, crypoptionhub.com ICT mentorship
2022 guide.

The ICT 2022 model is an algorithmic intraday framework treating price as an
institutional delivery mechanism through time windows. Its three structural pillars are:
(1) higher-timeframe daily bias; (2) session liquidity sweep; (3) lower-timeframe entry
trigger off a PD Array (FVG, OB, or Breaker).

---

### Item 1 — Daily Bias Timeframe

**Rule name:** Higher-timeframe daily bias determination  
**Canonical definition:** Daily bias must be derived from HTF context — the Daily chart
and 4H chart establish the directional macro context before any intraday setup is
evaluated. The bias determines which side of the market to trade (buy below old lows in
bullish bias; sell above old highs in bearish bias).  
**Common wrong version:** Retail implementations read bias from the 1H or 15-minute
chart, producing conflicting signals every time intraday volatility appears. Trading
without any HTF bias at all is also common.  
**Impact on mechanical EA:** Any ICT EA that derives directional bias from the trading
timeframe or lower is structurally mis-wired. The HTF bias filter must reference the D1
or H4 close, not the execution chart.  
**Source:** innercircletrader.net 2022 model tutorial; crypoptionhub.com ICT mentorship 2022.

---

### Item 2 — Liquidity Sweep Is Not Itself the Entry Signal

**Rule name:** Market Structure Shift (MSS) confirmation requirement  
**Canonical definition:** A liquidity sweep (price running above a prior high / below a
prior low) is a necessary precondition, not sufficient. A lower-timeframe market
structure shift (MSS) — a break of the most recent counter-trend swing — must confirm
before entering. The sweep + MSS together form the inflection.  
**Common wrong version:** Entering immediately on the sweep candle, or entering when
price touches a PD Array without waiting for MSS confirmation. This produces entries
that trade against the post-sweep continuation.  
**Impact on mechanical EA:** An ICT EA that triggers on the sweep without requiring an
MSS confirmation is trading a different (non-canonical) model.  
**Source:** crypoptionhub.com ICT mentorship 2022; innercircletrader.net 2022 model.

---

### Item 3 — Killzone Time Windows (Exact)

**Rule name:** Session killzones — exact times  
**Canonical definition (2022 mentorship basis, from ictkillzonetimes.com and
tradingrage.com):**
- Asian Killzone: 20:00–00:00 EST (consolidation / range-building phase)
- London Open Killzone: 02:00–05:00 EST (highest probability for Forex)
- New York Killzone: 07:00–10:00 EST for Forex; 08:30–11:00 EST for indices
- London Close Killzone: ~10:00–12:00 EST (London session close)

Setups are ONLY taken during the relevant killzone. Trading outside killzone hours is
explicitly not part of the 2022 model.  
**Common wrong version:** Taking setups at any time of day whenever a PD Array is
touched or a sweep occurs. This removes the time-based filter entirely.  
**Impact on mechanical EA:** An ICT EA without a hardcoded session filter running only
during killzone hours is not the canonical model.  
**Source:** ictkillzonetimes.com; tradingrage.com ICT killzone guide 2026;
innercircletrader.net killzone tutorial.

---

### Item 4 — FVG Entry Placement (Retracement Required)

**Rule name:** FVG entry is a retracement entry, not a breakout entry  
**Canonical definition:** After the MSS, price retraces back into the FVG (the
3-candle imbalance between sweep low and subsequent displacement). The entry is placed
inside the FVG, not at the FVG boundary. Stop loss is placed above the sweep high
(bearish setup) or below the sweep low (bullish setup).  
**Common wrong version:** (a) Entering at the FVG boundary on initial touch rather than
inside it; (b) using the FVG as a breakout signal (entering when price initially prints
the FVG, not on retracement back into it); (c) confusing a wick-based FVG with the
valid 3-candle body-separation pattern.  
**Additional canonical detail:** A "weak FVG" forms entirely inside the range of a prior
large candle (wick-within-wick); a "strong FVG" has clean separation. Implied FVGs
(IFVG) are a distinct sub-type where wicks overlap — these require different handling.  
**Impact on mechanical EA:** An ICT EA that triggers on FVG creation (breakout) rather
than FVG retracement is a category-error implementation.  
**Source:** innercircletrader.net FVG tutorials; tradingfinder.com ICT mentorship 2022.

---

### Item 5 — Optimal Trade Entry (OTE) — Fibonacci 62–79%

**Rule name:** OTE retracement zone  
**Canonical definition:** The Optimal Trade Entry zone is the 62%–79% Fibonacci
retracement of the swing from the sweep low to the MSS high (for bullish setups).
Entries within this zone, aligned with a PD Array (FVG or OB), are the canonical
precision entry. The 70.5% level is often cited as the highest-probability sub-level.  
**Common wrong version:** Using the 50% retracement (the common "halfway" level),
or using any Fibonacci retracement at all independently of PD Array alignment (FVG /
order block confluence is required, not just the 62–79% zone in isolation).  
**Impact on mechanical EA:** An ICT EA using a 50% fib or no fib-based entry zone at
all is deviating from the canonical precision entry definition.  
**Source:** innercircletrader.net 2022 model tutorial; tradezella.com ICT Model 4
learning item.

---

## 4. NNFX Canonical Fidelity — What Retail Gets Wrong

Source basis: nononsenseforex.com; nononsensetrader.com NNFX Flow Charts PDF;
nnfxalgotester.com documentation; backtestd-doc GitHub; frzsoftware.com NNFX summary;
fxdreema.com forum; 4xpip.com NNFX overview.

NNFX (No Nonsense Forex) is VP's system published from ~2018 onward. Core structure:
D1 only; one moving-average Baseline; C1 confirmation; C2 second confirmation; Volume
indicator; Exit indicator; ATR-based position sizing and stops.

---

### Item 1 — Timeframe: D1 Only (VP's Original; H4 is Community Extension)

**Rule name:** Chart timeframe  
**Canonical definition:** VP's original NNFX system operates exclusively on the Daily
(D1) chart. Candle closes are evaluated once per day, 20 minutes before the daily
close.  
**Common wrong version:** Implementing NNFX on H4 or H1, citing the NNFX Algo Tester's
support for multiple timeframes. The Algo Tester allows H4 for more signals but this is
a community extension, not VP's stated method. Running the algorithm on intraday charts
with the same indicator settings invalidates the backtested edge.  
**Impact on EA:** A card marked as NNFX but coded on H4 with D1-calibrated indicators
is neither NNFX nor a properly calibrated H4 system.  
**Source:** nnfxalgotester.com help ("NNFX recommends the D1 and H4 charts, although
it will work on any timeframe" — H4 is an accommodation, not the canonical model).

---

### Item 2 — The "Dirty Dozen" — Banned Indicators

**Rule name:** Prohibited indicator categories  
**Canonical definition:** VP explicitly banned 12 indicator types from use as C1/C2/
Baseline/Exit in the NNFX system. The list as documented in the "Dirty Dozen" video
series on nononsenseforex.com:
1. ADX (Average Directional Index)
2. Trend lines
3. Stochastics
4. Price levels
5. CCI (Commodity Channel Index)
6. Support & resistance lines
7. Japanese candlestick patterns
8. Chart patterns (double top, H&S, harmonics, etc.)
9. Bollinger Bands
10. Fibonacci
11. RSI (Relative Strength Index)
12. Moving average crossovers

MACD was addressed separately — VP concluded only the histogram component has any
value; using the full MACD signal/line crossover is treated as equivalent to a banned MA
crossover. VP has never disclosed his own live indicator set.  
**Common wrong version:** Using RSI, Stochastic, or Bollinger Bands as C1/C2 because
they are familiar indicators. These are explicitly on the banned list.  
**Impact on EA:** Any NNFX-family card using RSI, Stochastic, CCI, or Bollinger as C1
or C2 is in direct violation of the source's stated rules. This is the confirmed defect
in our existing NNFX cards.  
**Source:** nononsenseforex.com "Dirty Dozen" category; frzsoftware.com NNFX summary.

---

### Item 3 — Baseline Entry: 1 ATR Proximity Requirement

**Rule name:** Baseline cross entry — price-to-baseline distance gate  
**Canonical definition:** A baseline cross signal is only valid if price is within 1×
ATR of the baseline at the time of the signal candle's close. If price is more than
1× ATR away from the baseline, the signal is skipped (the move has already occurred;
chasing is explicitly forbidden).  
**Common wrong version:** Taking any baseline cross at any distance from the baseline,
regardless of how extended price is. This produces entries that chase extended moves and
blow out the ATR-based stop immediately.  
**Impact on EA:** Omitting the 1 ATR proximity check is one of the most commonly
reported errors in community-built NNFX EAs.  
**Source:** 4xpip.com NNFX overview; nnfxalgotester.com baseline documentation;
frzsoftware.com NNFX summary.

---

### Item 4 — ATR-Based Money Management (Exact)

**Rule name:** Stop loss and position sizing  
**Canonical definition:**
- ATR period: 14 (last closed candle value)
- Stop loss: 1.5× ATR from entry
- Take profit (trade 1 of 2): 1× ATR from entry; close half at this level, move
  remaining stop to breakeven
- Trailing stop: activate only after price has moved 2× ATR from entry
- Risk per trade: ≤2% of account equity (sized from the 1.5× ATR stop distance)  
**Common wrong version:** (a) Using a fixed pip stop instead of ATR-scaled stop,
invalidating the money management entirely; (b) using a 1× ATR stop (too tight —
normal volatility triggers it); (c) omitting the half-close and breakeven-move logic,
turning the system into a single-position TP system.  
**Impact on EA:** An NNFX EA with a fixed stop or a 1× ATR stop is not implementing
the canonical money management. This is a structural deviation.  
**Source:** 4xpip.com NNFX overview; nononsensetrader.com NNFX Flow Charts PDF;
nnfxalgotester.com documentation.

---

### Item 5 — One Candle Rule and Baseline Cross Window

**Rule name:** One Candle Rule for delayed confirmation; 7-candle baseline cross window  
**Canonical definition:**
- **One Candle Rule:** If C1 signals but C2 (or Volume) do not agree on the same
  candle, check again on the very next candle. If C2/Volume agree then, the trade is
  still valid. This one-candle delay is the maximum wait — if still not aligned after
  one candle, the signal is abandoned.
- **Baseline cross window:** If the baseline crosses and C1 agrees within 7 candles
  of the cross, the trade is valid (provided price is still within 1× ATR of the
  baseline). Beyond 7 candles, the baseline cross signal is stale and must be ignored.  
**Common wrong version:** (a) Waiting more than 1 candle for C2 alignment (turning a
filter into a lookahead bias); (b) taking baseline-cross trades 10–20 candles after the
cross, when price has already extended.  
**Source:** fxdreema.com forum thread "One candle rule, No Nonsense Forex";
nnfxalgotester.com operation modes documentation; backtestd-doc GitHub NNFX Algorithm
Rules.org.

---

## 5. Freqtrade / Open-Source Live Track Records

**Assessment:** This section represents the weakest evidence tier in this survey.
Freqtrade is a crypto trading framework (not Forex/CFD), and verified multi-year live
track records matching the R1 standard for NNFX/ICT-comparable strategies are not
found in public search results as of 2026-06. What follows is the best available from
searches.

---

### 5.1 Freqtrade strategies GitHub repository

**Repository:** https://github.com/freqtrade/freqtrade-strategies  
**Description:** Official collection of free strategies contributed by the community
for educational purposes.  
**Rule summary:** Strategies include trend-following, RSI mean-reversion, EMA crosses,
and Bollinger Band breakouts. Each strategy is a Python class with explicit
`populate_indicators`, `populate_entry_trend`, and `populate_exit_trend` methods —
fully mechanized and deterministic.  
**Evidence quality:** BACKTEST-ONLY or DRY-RUN. The repository explicitly states
"These strategies are for educational purposes only." No audited live P&L is published
alongside the strategies. R1 FAIL by pre-2026-05-15 strict criteria; PASS under
relaxed criteria (source link exists).  
**R3 / R4:** All strategies are crypto-native; porting to Forex CFDs requires symbol
remapping. Most strategies are ML-free and deterministic. Some use ML (`FreqAI`
module) — those would be R4 REJECT.

---

### 5.2 myfxbook Verified EA Strategies (MT5)

The myfxbook Forex Strategies section
(https://www.myfxbook.com/strategies) hosts EA-backed accounts with live verification.
Examples found in search results that meet basic criteria:

**5.2a — René Balke 50K (covered in Section 1)**  
Already documented above. This is the strongest publicly-verifiable multi-EA live
account found in the German/MQL5 space. Running 4+ EAs across 7 instruments.

**5.2b — Rule-based MT5 EAs on myfxbook (generic)**  
The myfxbook strategies section lists many EAs with 2+ year live records, but most
provide no public rule disclosure. Searching for rule-disclosed + verified accounts
yields thin results — most vendors sell the EA without disclosing rules, which
prevents card creation.

**Evidence gap:** No open-source GitHub strategy with a publicly audited Forex live
account of 2+ years was found in public search results. This is a known gap in the
community — most serious live-track-record traders do not open-source their exact rules.

---

### 5.3 TheoBrigitte/freqtrade (GitHub)

**Repository:** https://github.com/TheoBrigitte/freqtrade  
**Description:** Personal Freqtrade strategies, configurations, and dry-runs.
Includes backtests and dry-run records for crypto pairs.  
**Evidence quality:** Dry-run (paper trading) only, crypto only. Not live-audited,
not Forex.  
**Verdict:** R3 fail (crypto-only dry-run; no DWX porting evidence).

---

**Summary finding for Section 5:** No open-source strategy with a verified 2+year live
Forex/CFD track record (myfxbook or Darwinex-audited) was found in public search
results. The Rene Balke 50K myfxbook account is the strongest publicly accessible
live-audited evidence found for this survey. Open-source crypto backtests (Freqtrade)
exist in volume but lack both live verification and Forex/CFD applicability.

---

## 6. Linting Implications

Based on the survey findings, the following card-family audits are highest priority:

### Priority 1 — NNFX Family Cards (CONFIRMED DEFECT — AUDIT IMMEDIATELY)

**Defect confirmed:** OWNER directive states our NNFX cards used VP-banned indicators
(RSI, Stochastic, Bollinger, CCI, or MA crossovers as C1/C2) and were on the wrong
timeframe. This survey confirms the exact banned list.

**Lint checklist for every NNFX family card:**
- [ ] Chart timeframe = D1 (not H4, not H1)
- [ ] C1 indicator is NOT in the Dirty Dozen (not RSI, Stochastic, CCI, BB, MA-cross,
      Fibonacci, ADX, CCI, trend lines, candlestick patterns, chart patterns)
- [ ] C2 indicator is NOT in the Dirty Dozen
- [ ] Baseline = a single moving-average-type indicator (not a Dirty Dozen member)
- [ ] Stop loss = 1.5× ATR(14), NOT fixed pips
- [ ] Entry has 1× ATR proximity gate from baseline
- [ ] One Candle Rule implemented (C2 can lag by max 1 candle)
- [ ] Baseline cross window ≤7 candles
- [ ] Two-position structure: close half at 1× ATR, move to breakeven

---

### Priority 2 — ICT Family Cards (CONFIRMED DEFECT — AUDIT IMMEDIATELY)

**Defect confirmed:** OWNER directive states our ICT family cards lacked killzones and
FVG-retrace entry. This survey confirms the canonical rules.

**Lint checklist for every ICT family card:**
- [ ] Daily bias derived from D1 or H4, NOT from the execution timeframe
- [ ] Session time filter present — execution only within killzone hours (London Open
      02:00–05:00 EST, or NY 07:00–10:00 EST for Forex; 08:30–11:00 EST for indices)
- [ ] Entry trigger requires: (a) liquidity sweep, then (b) MSS confirmation — not
      sweep alone
- [ ] FVG entry is a RETRACEMENT entry back into the gap — NOT a breakout entry on
      FVG formation
- [ ] OTE zone check: entry should be within 62–79% Fibonacci retracement of the
      sweep-to-MSS swing, or at a PD Array within that zone
- [ ] Stop loss placed above sweep high (bearish) or below sweep low (bullish)

---

### Priority 3 — Range Breakout Family Cards

**Lint checklist:**
- [ ] Morning range defined by clock-based start/end times, NOT a fixed bar count
- [ ] Pending order deletion time present (intraday only; no overnight positions)
- [ ] SL placed at opposite range extreme (not a fixed pip value)
- [ ] Verify: no overnight hold logic

---

### Priority 4 — Mean Reversion / Open-Return Family Cards

**Reference:** Schäfermeier Return to Open (Section 2.2)

**Lint checklist:**
- [ ] Entry is a limit order (retracement), not a stop order (breakout)
- [ ] Entry price derived from prior N-day H/L/O structure, not a fixed level
- [ ] Time-based exit present (no overnight holds)
- [ ] 1:1 R:R documented (TP = distance to open price, SL = same distance away)

---

### Priority 5 — Index Mean Reversion / Calendar Anomaly Cards

**Reference:** Balke Turnaround Tuesday (Section 1.2)

**Lint checklist:**
- [ ] Long-only bias verified (not symmetric)
- [ ] Entry threshold documented (% or absolute close gap from prior Friday)
- [ ] Entry and exit timing specified (close-of-Monday entry, close-of-Tuesday exit, or
      alternative documented)
- [ ] Instruments restricted to major indices with multi-year uptrend bias

---

*Survey complete. All rule parameters above are derived from web-accessible public
sources as of 2026-06-12. Parameters described as "not found in public sources" require
either OWNER input, direct source access, or a documented engineering assumption.*
