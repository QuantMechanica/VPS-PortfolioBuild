# Variant-Realization Research: Balke + German Algo Scene + ICT/NNFX Fidelity Survey

**Task:** 9a5dcdaf  
**Date:** 2026-06-12  
**Researcher:** Claude (interactive)  
**Context:** OWNER directive: "right family, wrong realization." QM5_12534 (NNFX rebuild) and QM5_12535 (ICT MSS/sweep rebuild) are canonical variants. This survey is the data layer to lint other cards against.  
**Sources:** web research 2026-06-12 + existing repo EA audit  
**Reputable-source criteria R1-R4 applied** (processes/qb_reputable_source_criteria.md)

---

## 1. Rene Balke — Published Mechanical Strategies

### Background

René Balke, founder of BM Trading GmbH (Berlin), active prop trader (FTMO-certified), MT5 educator with ~29k YouTube subscribers. Former asset management trader. Published strategies available on MQL5 market and bmtrading.de.

Source: [MQL5 Profile](https://www.mql5.com/en/users/bmtrading) | [BM Trading](https://en.bmtrading.de/free-expert-advisor/) | [StrategyQuant interview](https://strategyquant.com/blog/interview-with-trader-rene-balke-about-prop-trading/)

**Track record:** Verifiable FTMO challenge completions (prop firm documented, not independent audit). No myfxbook/Darwinex live track record found.

---

### Strategy 1: Range Breakout EA

**Source:** [MQL5 product page](https://www.mql5.com/en/market/product/87520) | [BM Trading EA page](https://bmtrading.de/en/expert-advisors/range-breakout/)  
**R1 assessment:** Public product with documented rules — passes R1 (published author). No academic review (R2 N/A for EA products). Mechanically specified (R3). No independent multi-year OOS study found (R4 partial).

**Rules:**
- **Concept:** Time-range breakout. Identify highest/lowest price during a configurable window (default: London open ~08:00-09:00 broker). Place pending stop orders above/below the range.
- **Entry:** Price breaks above range high → pending BUY STOP triggered. Price breaks below range low → pending SELL STOP triggered. Optional "Order Buffer" (small offset above/below).
- **Stop Loss:** Configurable — factor × range size, fixed points, or percentage.
- **Take Profit:** Configurable — same options as SL.
- **Exit by time:** Pending orders deleted at configurable "Delete Time"; open positions closed at configurable "Close Time" (avoids overnight hold).
- **Timeframe:** Flexible. XAUUSD M30 documented as one use case.
- **Instruments:** Any instrument with a distinct session open. Primarily gold, index CFDs.

**Dedup verdict:** VARIANT vs existing session-open breakout cards. Our QM5_10069 (mql5-hs-rev, which is currently modified per git status) is a session-reversion strategy, not the same. The ORB (Opening Range Breakout) mechanism is the same family as our Edge Lab `QM5_10893_el-d4-t12-ls-ob-micro` and intraday breakout cards — check those for duplicate. The *Balke Range Breakout* uses a parameterized time window which gives it flexibility over hardcoded session EAs. **Recommendation: NEEDS_SPEC** — the exact parameter set (start/end time, SL/TP factor) that Balke published as his own is not public; the EA is a framework, not a single system.

**Expected trades/year:** Depends heavily on parameter set and symbol. For a 1h morning-session range on XAUUSD, expect ~200+ signals/year before filtering.

---

### Strategy 2: Turnaround Tuesday

**Source:** [BM Trading products](https://en.bmtrading.de/) | [BM Trading EA description] | [QuantifiedStrategies reference](https://www.quantifiedstrategies.com/turnaround-tuesday-strategy/)  
**R1/R4:** Published in accessible form; original concept pre-dates Balke (Connors-era; documented in academic/quantitative literature with long track records).

**Rules (Balke's version as described):**
- **Concept:** Long major indices on Tuesday after Monday weakness.
- **Entry:** Monday close < Monday open AND IBS (Internal Bar Strength = (Close − Low) / (High − Low)) < 0.20 → Enter at Monday close (or early Tuesday open).
- **Exit:** Exit at Tuesday close.
- **Instruments:** S&P 500, NASDAQ, DAX (NDX.DWX, WS30.DWX, GDAXI.DWX).
- **Timeframe:** D1 (daily bar logic, entry/exit at close).
- **Stop Loss:** Not specified in public descriptions — time-based exit (Tuesday close) is the primary risk control.
- **Direction:** Long only.

**Track record:** Stivers-Sun (2010) documented the Monday effect underlying this. Many quantitative confirmations 2000-2015. Post-2015 decay in some literature (our OPEX study shows related patterns are mixed 2018-2026).

**Dedup verdict:** Check existing Connors cards (QM5_10061/10062) and our "sell-in-may" family. Search for "tuesday" and "turnaround" in cards_approved. If no exact match: **VARIANT vs Connors RSI strategies** (different mechanism — Connors uses RSI2 pullback; Turnaround Tuesday uses IBS filter on Monday). Potentially a new card targeting D1 NDX/WS30. **Mechanization-readiness: READY** — rules are complete and D1 bars available.

**Expected trades/year:** ~10-20 (requires weak Monday ~25-30% of weeks; some of those pass IBS filter).

---

### Strategy 3: Ninja Turtle Scalper (Donchian Channel)

**Source:** MQL5/BM Trading product descriptions  
**Rules:** Entry on Donchian Channel (N-period, typically 20) breakout. Long when price exceeds N-day high, Short when price breaks N-day low. SL = channel opposite side. Scalping variant implies tight profit target.

**Dedup verdict:** We have 36 turtle/raschke cards. The Balke "Ninja Turtle" is a Donchian breakout variant — likely DUPLICATE vs existing turtle cards. **DUPLICATE — skip**, verify against turtle card pool before any proposal.

---

## 2. German Algo Scene Beyond Balke

### Birger Schäfermeier

**Source:** [tradAc profile](https://tradac.info/birger-schaefermeier/) | [WH SelfInvest strategies](https://www.whselfinvest.com/en-de/trading-platform/store/trading-strategies/) | [Open Range Breakout page](https://www.whselfinvest.com/en/Store_Birger_Schaefermeier_Trading_Strategy_Return_To_Open.php)  
**Background:** >20 years trading, founder of tradAc (European Trading Academy #1 in Europe), DAX futures specialist.

**Strategy A: Open Range Break-out (ORB)**
- **Rules:** Entry when price breaks above/below the high/low of the first 60 minutes of the session. For S&P 500: first 45 minutes. Orders placed as pending stop orders.
- **Instruments:** DAX, Eurostoxx50, S&P 500.
- **Timeframe:** Intraday (60-min / 45-min range, then intraday hold).
- **Built into NanoTrader** — mechanically specified.
- **Dedup verdict:** Same family as Balke Range Breakout and many of our intraday breakout EAs. Check for GDAXI.DWX 60-min ORB cards. Likely VARIANT (shorter fixed window vs Balke's configurable). **NEEDS_SPEC** on exact SL/TP for Schäfermeier's version.

**Strategy B: Return to Open**
- **Rules:** Mean reversion to the daily open price. When price deviates from the open, enter a position targeting a return to the open. Morning sessions for DAX/Eurostoxx, afternoon for S&P.
- **Direction:** Both (long if below open, short if above open).
- **Target:** Daily open price.
- **Instruments:** GDAXI.DWX, WS30.DWX (Eurostoxx not available as .DWX).
- **Dedup verdict:** Distinct mechanism from our existing cards. No "return to open" card found in current card pool review. **READY** — straightforward mechanization: entry on H1 deviation from D1 open > X×ATR, exit at D1 open or end of session.
- **Expected trades/year:** ~200+ (multiple entries per day possible).
- **Risk note:** Trending days are killers for this strategy. Must include trend filter (e.g., wide open-to-close range as filter-out condition).

### Other German Scene Findings

No other German algo traders with fully-specified published mechanical systems with track records found. The German community centers on:
- Discretionary traders (Philipp Kahler — mostly discretionary with some systematic elements)
- TradersClub24: educational/discretionary focus, no published mechanical rule sets found
- German prop trading community: FTMO challengers (Balke is the main systematic public voice)

**Gap:** The German algo community is underrepresented in English-language published mechanical systems. Schäfermeier and Balke are the main published sources.

---

## 3. ICT 2022 Model — Canonical Fidelity Audit

**Sources:** [innercircletrader.net OTE tutorial](https://innercircletrader.net/tutorials/ict-optimal-trade-entry-ote-pattern/) | [ICT 2022 mentorship model](https://tradingfinder.com/education/forex/ict-mentorship-2022-model/) | [ICT Killzones guide](https://innercircletrader.net/tutorials/master-ict-kill-zones/)

### Top 5 Community-Verified Misimplementations

**1. Killzone timing (most commonly wrong)**

Correct killzone times are ALL in **New York (Eastern) Time**, NOT UTC or broker time:
- Asian Killzone: **20:00–00:00 ET** (midnight ET, = 01:00–05:00 UTC)
- London Killzone: **02:00–05:00 AM ET** (= 07:00–10:00 UTC)
- New York Killzone — forex: **07:00–10:00 AM ET** (= 12:00–15:00 UTC)
- New York Killzone — indices: **08:30–11:00 AM ET** (= 13:30–16:00 UTC)
- London Close Killzone: **10:00–12:00 PM ET** (= 15:00–17:00 UTC)

**Common retail error:** Using broker time (GMT+2/+3) directly. For our Darwinex broker (NY-close, GMT+2 non-DST / GMT+3 DST):
- London KZ: 02:00 ET = **broker 09:00** (non-DST) / **broker 10:00** (DST). NOT "broker 07:00."
- NY KZ (forex): 07:00 ET = **broker 14:00** (non-DST) / **broker 15:00** (DST).

**Lint target:** QM5_12535 ICT MSS card must use ET-anchored killzones. Verify the hardcoded broker times account for DST shifts correctly.

**2. FVG entry placement**

- FVG = 3-candle imbalance: gap between candle 1's high and candle 3's low (bullish) or candle 1's low and candle 3's high (bearish).
- CE (Consequent Encroachment) = 50% of the FVG body. This is where institutional re-entry is expected.
- **Common error:** Drawing Fibonacci OTE on "any visible FVG" rather than specifically the **displacement FVG following the MSS** (Market Structure Shift). Must sequence: 1) identify MSS, 2) identify the displacement move that caused it, 3) the FVG WITHIN that displacement is the valid entry FVG.
- **Common error 2:** Entering at any touch of the FVG zone rather than waiting for price to reach the CE (50% of FVG). ICT uses the CE as the optimal entry point, not the full FVG range.

**Lint target:** QM5_12535 — verify FVG search is anchored to post-MSS displacement, not pre-MSS price action.

**3. OTE Fibonacci levels**

Correct OTE zone = **0.62, 0.705, 0.79** retracement (not 0.618 alone).
- Must be drawn from **swing low to swing high** for bullish setups (after MSS from bearish → bullish).
- **Common error:** Using 0.618 only (standard Fibonacci) and calling it OTE. The 0.705 level is ICT-specific and not in standard Fibonacci sets.
- **Common error 2:** Drawing from the wrong swing points — must use the *most recent* confirmed swing, not arbitrary highs/lows.

**4. News avoidance (ICT mandates this as non-negotiable)**

ICT requires avoiding entries during "high-impact news events" (NFP, FOMC, CPI, PMI, BOE/ECB rate decisions) within a blackout window (typically ±30 min around release).
- **Common error:** Skipping the news filter entirely.
- **Relevance for QM:** Our QM_Common.mqh news calendar is the correct implementation. Any ICT EA MUST use our news guard.

**5. MSS confirmation before OTE entry**

Entry in the OTE zone is only valid AFTER a confirmed MSS (a higher-high in a downtrend, signaling a potential reversal). 
- **Common error:** Entering at OTE on a swing retracement without waiting for the MSS to confirm the directional change.
- The MSS is the "permission" to look for an OTE entry. Without it, the OTE is a continuation entry into a potentially continuing trend.

**Lint target:** QM5_12535 must require MSS detection before OTE entry logic fires.

---

## 4. NNFX (No Nonsense Forex by VP) — Canonical Fidelity Audit

**Sources:** [NNFX Flow Charts PDF](https://nononsensetrader.com/wp-content/uploads/2021/02/No-Nonsense-FOREX-Flow-Charts.pdf) | [NNFX Algo Tester](https://nnfxalgotester.com/help/c1-c2-volume-exit-cont/) | [FRZ Software summary](https://www.frzsoftware.com/product/no-nonsense-forex-strategy-nnfx/)

### Full NNFX System Architecture

| Component | Role | Official Rule |
|-----------|------|---------------|
| Baseline | Trend direction filter | Price must be within 1×ATR(14) of baseline at entry |
| C1 (Main Confirmation) | Primary entry signal | Must signal within 7 candles of entry (7-candle rule) |
| C2 (Second Confirmation) | Entry filter | Must agree with C1 direction |
| V1 (Volume) | Trade quality filter | Must confirm (e.g., above-average volume indicator) |
| ATR | Stop sizing | SL = 1.5×ATR(14). TP = 1.0×ATR(14) for first target |
| Exit Indicator | Active exit | Signals when to close before SL/TP |

### Top 5 Misimplementations

**1. ATR period and SL multiple**

Canonical: **ATR(14), SL = 1.5×ATR, TP = 1.0×ATR**.
- **Common error:** Using ATR(20) or ATR(21) (MetaTrader default) for SL — this produces a ~50% larger stop.
- **Common error 2:** Using 2.0×ATR stop "to be safe" — VP's system is built around 1.5×ATR; changing it breaks the edge.

**Lint target:** QM5_12534 and all NNFX-family cards must verify ATR period = 14 and SL multiple = 1.5.

**2. Banned indicators used as C1/C2 ("Dirty Dozen")**

VP's Dirty Dozen (indicators that retail commonly misuse and VP explicitly warns against):
1. RSI (lagging, mean-reverting in trending markets)
2. Stochastics (same issues as RSI)
3. CCI (similar pattern)
4. ADX (measures trend strength, not direction — wrong as a standalone C1)
5. Moving Average crossovers (severe lag)
6. Bollinger Bands (not a directional signal, volatility measure)
7. Fibonacci retracements (subjective, discretionary)
8. Support/Resistance (discretionary)
9. Trend lines (discretionary)
10. Chart patterns (discretionary, not mechanical)
11. Japanese candlestick patterns (confirmation bias, unreliable mechanically)
12. Price levels (round numbers — discretionary)

**Common error (directly affecting QM5_12534):** The original NNFX-v2 card that triggered the rebuild used a VP-banned indicator. Per OWNER note 2026-06-12: "nnfx-v2 cards used VP-banned indicators on wrong timeframe." Must verify QM5_12534 uses only VP-approved indicator families for C1/C2.

**Approved C1/C2 indicator families (VP-sanctioned):** Vortex Indicator, Coppock Curve, Waddah Attar Explosion, ASHma Indicator, B3 Fibonacci, TEMA, McGinley Dynamic, Schaff Trend Cycle (STC), DEMA. These are trend-continuation momentum indicators. NOT simple MAs, NOT oscillators (RSI/Stoch/CCI).

**3. 7-Candle Rule ignored**

C1 signal must have been generated within the last 7 candles. If C1 signaled 10 candles ago and C2 is now confirming, that is a stale signal — no trade.
- **Common error:** Using the most recent state of C1 (above/below zero line) rather than the timestamp of the last crossover.

**4. Baseline filter not applied**

Entry only when price is within 1×ATR(14) of the baseline. If price is 1.5×ATR away, the entry is "late" and should be skipped — wait for pullback.
- **Common error:** Entering immediately on C1/C2 agreement regardless of baseline distance.

**5. C1 and C2 from the same indicator family**

C1 and C2 must be from **different indicator families** to provide genuine confirmation (not just echo). Using two momentum oscillators (e.g., Vortex + Coppock) is acceptable because they are different. Using two period variants of the same indicator (e.g., MACD(12,26) and MACD(5,13)) is NOT — they are correlated and provide false confirmation.
- **Common error:** Picking two visually different but mathematically correlated indicators.

---

## 5. Python/Open-Source Track Records

**Sources:** [freqtrade-strategies GitHub](https://github.com/freqtrade/freqtrade-strategies) | [freqtrade Strategy Ninja](https://strat.ninja/)

**Honest finding:** No freqtrade/open-source forex/index strategies with published, independently verified multi-year live track records were found.

- freqtrade is a **crypto-focused** bot. The published strategies are for crypto pairs, not FX or index CFDs. These are NOT mappable to .DWX symbols.
- "Strategy Ninja" tests published freqtrade strategies monthly on backtests, not live trading.
- The few "live" records found (myfxbook links in search results) are for discretionary or non-mechanical systems, not freqtrade-specific strategies.

**Verdict for QM:** The freqtrade/open-source ecosystem is not a source of .DWX-compatible strategies with live track records. Not applicable for our pipeline. **No cards proposed from this source.**

---

## Card Proposals Summary

| Proposed System | Mechanization-Readiness | Dedup Verdict | Priority |
|----------------|------------------------|---------------|----------|
| Balke Range Breakout (Balke-specific params) | NEEDS_SPEC | VARIANT vs ORB family | Low — params unclear |
| Balke Turnaround Tuesday | READY | VARIANT vs Connors (different mechanism) | HIGH — check for gaps in coverage |
| Schäfermeier Return to Open (DAX/S&P) | READY (with trend filter) | LIKELY NEW | HIGH |
| Schäfermeier ORB (60-min, DAX) | NEEDS_SPEC (exact SL/TP) | VARIANT vs ORB cards | Medium |
| Ninja Turtle Scalper | DUPLICATE | DUPLICATE vs turtle cards | SKIP |
| freqtrade open-source | REJECT | N/A (crypto only, not .DWX) | SKIP |

**Concrete next step:** Before writing any proposal cards, run dedup search:
1. `grep -ri "turnaround tuesday\|tuesday.*monday\|monday.*weak" D:/QM/strategy_farm/artifacts/cards_approved/`
2. `grep -ri "return.*open\|open.*return\|schaefer" D:/QM/strategy_farm/artifacts/cards_approved/`
3. `grep -ri "open range\|range breakout\|ORB" D:/QM/strategy_farm/artifacts/cards_approved/`

Then propose only if dedup confirms NEW or justified VARIANT.

---

## ICT/NNFX Fidelity Matrix (for linting QM5_12534, QM5_12535, and related cards)

| Rule | ICT 2022 | NNFX |
|------|----------|------|
| Killzone timing | ET-based (NOT broker/UTC direct) | N/A |
| FVG anchor | Post-MSS displacement FVG only | N/A |
| OTE levels | 0.62, 0.705, 0.79 (not just 0.618) | N/A |
| Stop loss | News blackout mandatory | 1.5×ATR(14) mandatory |
| Confirmation indicator family | MSS + OTE + FVG sequence | C1/C2 from different non-banned families |
| ATR period | N/A | 14 (NOT 20 or 21) |
| Entry distance from baseline | N/A | ≤ 1×ATR |
| Stale signal rule | N/A | 7-candle rule |
| News filter | Mandatory blackout | Not explicitly specified by VP |
