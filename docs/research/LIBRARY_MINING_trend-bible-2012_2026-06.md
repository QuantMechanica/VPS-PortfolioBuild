# Library Mining: The Trend Following Bible (2012)
**Slug:** trend-bible-2012  
**Date:** 2026-06-12  
**Miner:** Claude (claude-sonnet-4-6)  
**File:** `C:/Users/Administrator/Downloads/The Trend Following Bible - How Professional Traders Compound Wealth and Manage Risk 2012.pdf`  
**Author:** Andrew Abraham, John Wiley & Sons 2013 (copyright 2013)  
**Exclusion check:** USABLE — appears in USABLE section of `downloads_library_triage_2026-06-12.txt` (line 311)  
**PDF quality:** 210 pages, 440,682 chars extracted. Fully readable.  
**Source cache:** `D:/QM/strategy_farm/source_cache/trendbible_extracted.txt`

---

## DEDUP VERDICT — MANDATORY STEP 0

Searched `D:/QM/strategy_farm/artifacts/cards_approved/` (2,693 cards) for:
- Author: `abraham` — 0 direct matches in card filenames
- Mechanism keywords: `trend-follow`, `breakout`, `atr.*trail`, `macd.*zero`, `channel-breakout`, `donchian`, `turtle`
- Concept tags: cross-reference to momentum breakout + MACD filter + ATR trailing stop combination

**Key finding:** No existing card attributes Andrew Abraham or the *Trend Following Bible*. The book presents one complete mechanical trading system (Abraham's own system) plus illustrative examples of other trend-following traders' approaches (Mulvaney, Marcus, Seykota, Dennis — not proprietary systems). The Abraham system itself is partially codified in the text.

| Component | Existing Cards | Status |
|---|---|---|
| X-day channel breakout + MACD filter + ATR trail | None with this tri-component combination | NEW |
| Breakout + MACD zero-line filter alone | QM5_11202 (ft-adxmom), QM5_10407 (et-macd-zero) — no channel breakout + ATR trail | VARIANT |
| ATR trailing stop alone | Many (QM5_9908, QM5_10794, etc.) | DUPLICATE (component only) |
| Smoothed ROC strength-ranking universe selection | 0 cards | NEW (component; not standalone) |
| Hard stop = Y-day low / ATR switch | No exact match | NEW |

---

## Abraham System Rules Extracted

From `trendbible_extracted.txt` pages 101–121, Chapter 6–7:

### Abraham's Complete 7-Criterion Trading System

Andrew Abraham presents a systematic checklist-based entry system. Unlike Turtle, this is **not** an always-in-the-market reversal — it is a filtered trend-following breakout with position management.

**Step 0 — Universe Selection:**
- For equities: Use IBD50 as base universe; rank by **smoothed rate of change (ROC)**. Trade only the strongest (long) and weakest (short) instruments.
- For futures/forex: Monitor **52-week new highs and new lows** daily; rank by smoothed ROC. This is the candidate pool.
- Abraham applies this to stocks and futures. For FX: equivalent = rank DWX pairs by 20-day or 90-day ROC; trade only top-N long candidates and bottom-N short candidates.

**Step 1 — Breakout Entry Signal:**
- LONG: Market makes a **new X-day high** breakout (Abraham leaves the period as "X days"; his Turtle-era reference suggests 20–55 days; his own MACD-based system implies daily bars).
- SHORT: Market makes a **new X-day low** breakout.
- **MACD filter:** Enter only if MACD is **above zero** for longs (below zero for shorts). This is the primary trend-direction confirmation layer.
- Entry execution: Market order or limit order at breakout price.

**Step 2 — Pre-Trade Risk Checklist (must pass all 7):**
1. Strongest/weakest universe member (per smoothed ROC ranking).
2. Breakout risk ≤ 1% of total account size (entry price − Y-day hard stop ≤ 1% × account).
3. MACD above zero (long) or below zero (short).
4. No more than 10 longs + 10 shorts active simultaneously.
5. Dollar risk per contract ≤ $2,500 (Abraham's futures cap; for FX, equivalent = stop distance ≤ position-adjusted pip value capped at $2,500/position).
6. Sector allocation ≤ 5% of account (per currency pair family or correlated group).
7. Open trade equity ≤ 20% of core account (avoid riding an open P&L cliff).

**Initial Hard Stop (Y-day Low/High):**
- LONG: stop = lowest low of prior Y days (Abraham uses Y = 10 as example; "the 10-day low").
- SHORT: stop = highest high of prior Y days.
- Stop is set on entry and is NOT moved until the ATR trailing stop takes over.

**Trailing Stop — ATR (39-period):**
- Once the trade moves favorably (away from the initial hard stop), switch to a **39-period ATR trailing stop**.
- Long ATR trail: `Stop = EMA_of_Close − multiplier × ATR(39)`. Abraham does not specify the multiplier explicitly, but references standard ATR-stop tools in MetaStock/Tradingblox. Typical value: 3.0× ATR.
- The ATR stop only moves in the trade's favor (ratchet); it never widens.
- The ATR trailing stop replaces the Y-day hard stop once price has moved 1 ATR in favor of the trade.

**Take Profit:**
- No fixed TP. Hold the trade until the ATR trailing stop is hit.
- Abraham explicitly states: "Giving back part of your profits is reality." The system is designed to hold for rare large winners.
- Optional: tighten ATR multiplier or cap open trade equity at 20% of core account.

**Position Sizing:**
- Risk-based: size so that entry − stop ≤ 1% of account per trade.
- Formula: `Units = (Account × 0.01) / (Entry − Hard_Stop) / pip_value`

### DWX Symbol Mapping

Abraham trades US stocks (IBD50) and commodity futures. For QM FX/CFD application:

| Abraham Universe | DWX Equivalent |
|---|---|
| Strongest FX pairs by ROC | GBPJPY.DWX, AUDUSD.DWX, NZDUSD.DWX (high beta; top ROC) |
| Weakest FX pairs by ROC | USDCHF.DWX, USDJPY.DWX (safe havens; low ROC bearish) |
| Gold | XAUUSD.DWX |
| Crude oil | XTIUSD.DWX |
| S&P 500 equivalent | NDX.DWX, WS30.DWX |

**Note:** Forex market has no "sector cap" equivalent to stock sectors. The sector rule (Step 6) maps to: no more than 2 correlated DWX pairs from the same currency family (e.g., EURUSD + GBPUSD = both USD-long; limit to 1 position per USD-direction). This is a tractable MT5 constraint.

---

## NEW PROPOSALS

### Proposal 1: Abraham Trend-Bible — Breakout + MACD Zero + ATR Trail (D1)

**Dedup verdict: NEW** — No existing approved card implements this tri-component combination (channel breakout + MACD zero-line filter + ATR-trailing stop) attributed to a named primary-source author. The nearest cards (QM5_10407 et-macd-zero uses MACD+SMA crossover without channel; QM5_9727 bandy-atr-ratio-compression-breakout uses ATR compression without MACD) are partial overlaps.

**Mechanism:**

**Universe selection (pre-trade):** Rank DWX instruments by 90-day simple ROC. Qualify the top 6 long candidates and bottom 6 short candidates for trade consideration each day.

**Entry (D1):**
1. MACD(12, 26, 9) must be **above zero** for longs (close[1] MACD histogram or MACD line > 0).
2. D1 bar closes above the **highest high of the previous 20 bars** → long entry signal.
3. OR D1 bar closes below the **lowest low of the previous 20 bars** → short entry signal.
4. Pre-trade checklist: risk ≤ 1% account, no more than 10 directional positions, correlated pair cap.
5. Execute at open of next D1 bar.

**Initial stop:** Y-day low/high where Y = 10. Stop = `iLow(NULL, PERIOD_D1, 11)` for longs (lowest low of prior 10 bars at entry time).

**Trailing stop transition:** Once price moves ≥ 1× ATR(39) in trade's favor, switch to ATR(39) trailing stop with multiplier = 3.0. `Trail_Stop = highest_close_since_entry − 3 × ATR(39)` for longs (ratchet only upward).

**Position sizing:** `lot = (account × 0.01) / (entry − initial_stop) / pip_value_per_lot`

**Exit:** ATR trailing stop hit; no fixed TP.

**DWX symbols:** GBPUSD.DWX, EURUSD.DWX, USDJPY.DWX, AUDUSD.DWX, XAUUSD.DWX, XTIUSD.DWX, NDX.DWX, WS30.DWX  
**Period:** D1  
**Expected trades/year/symbol:** 6–12 (20-day breakouts occur ~1/month; MACD filter eliminates ~30–50% of signals, especially in ranging conditions → ~8/year/symbol estimate)

**R1–R4:**
| Criterion | Status | Reasoning |
|---|---|---|
| R1 Track Record | PASS | Andrew Abraham, named author, *The Trend Following Bible* (Wiley, 2013, ISBN 978-1-118-41732-5); active CTA/fund manager; Wiley publication provides institutional credibility |
| R2 Mechanical | PASS | 20-day HHV/LLV breakout, MACD(12,26,9) zero-line filter, 10-day initial hard stop, 39-period ATR trail at 3× multiplier, ROC ranking for universe — all arithmetic, no discretion |
| R3 Data Available | PASS | D1 DWX FX + metals + indices; MACD and ATR are MT5-native |
| R4 No ML | PASS | Fixed periods (20/10/39/3.0); no ML; no martingale; 1 position per magic |

**Slug:** `abraham-trend-bible-breakout-macd-atr-d1`

**Notes for Codex (P1):**
- Universe ranking: compute 90-day ROC = `(Close[1] − Close[91]) / Close[91]` daily; qualify as long-candidate if ROC > 0 and MACD > 0.
- MT5 implementation: MACD via `iMACD(NULL, PERIOD_D1, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 1)` > 0.
- 20-day channel: `iHighest(NULL, PERIOD_D1, MODE_HIGH, 20, 1)` and `iLowest(NULL, PERIOD_D1, MODE_LOW, 20, 1)`.
- ATR trail switch: track `favorable_movement = Close[1] − entry` (long); switch to ATR trail when `favorable_movement >= iATR(NULL,PERIOD_D1,39,1)`.
- ATR trail: `trail_stop = max(trail_stop_prev, iClose(NULL,PERIOD_D1,1) − 3.0 × iATR(NULL,PERIOD_D1,39,1))`.
- P3 sweeps: channel period (15/20/25/55), MACD params (12-26-9 / 8-21-5), ATR period (20/39/55), ATR multiplier (2.0/3.0/4.0).

**Regime note:** ~8 trades/year/symbol on D1. Qualifies for Q08 swing/low-freq track (DL-070). System is designed for rare large winners; expected PF depends heavily on ATR multiplier tuning.

---

### Proposal 2: Abraham Trend-Bible — Retracement Entry Variant (D1)

**Dedup verdict: VARIANT** — Abraham explicitly describes a retracement (pullback) entry alternative for traders who miss the breakout or want to pyramid. This is mechanically distinct: instead of entering at the breakout level, wait for price to retrace to the 20-day channel boundary after a confirmed breakout.

**Mechanism:**
1. 20-day breakout occurs (as in Proposal 1).
2. MACD above zero (long) / below zero (short).
3. **Do NOT enter at breakout bar.** Wait for price to pull back to the 20-day channel level (the old breakout level now becomes support/resistance).
4. Enter LIMIT at the 20-day boundary (highest high from before the breakout, for longs).
5. Hard stop: 10-day low at time of limit entry.
6. Trail: same ATR(39) × 3.0 trail once trade moves favorably.

**Expected trades/year/symbol:** 4–8 (fewer fills than breakout entry due to retracement requirement)  
**Slug:** `abraham-trend-bible-retracement-d1`

**R1–R4:** Same as Proposal 1. PASS on all criteria.

**Differentiation from Proposal 1:** Entry location (limit at prior breakout level vs. market at new high). This is explicitly described in Chapter 6 as an alternative and is worth testing as a distinct EA to determine whether limit/retracement entries improve fill quality and expectancy on DWX instruments.

---

## What the Book Does NOT Contain (Important Negative Findings)

The Trend Following Bible is primarily an **inspirational/educational** text. It documents Abraham's system but does not provide complete quantitative specification for:
- The exact "X-day" breakout period (only "20-day high and 10-day low" mentioned as example; Abraham says parameters are subjective).
- The exact ATR multiplier (references standard ATR-stop tools without specifying 3×; derived from standard practice).
- How Mulvaney's program works beyond "channel breakout + long holding period" — this is not a mechanical spec.
- The ROC ranking algorithm (smoothed rate of change is mentioned but not defined precisely).

These gaps are identified. Proposal 1 fills them with standard industry-accepted parameters (20/10/39/3.0) which are testable in P3 sweep.

---

## Summary

| Category | Count |
|---|---|
| Systems found in book | 1 primary (Abraham system) + 1 retracement variant |
| DUPLICATE | 0 (no Abraham-attributed card exists) |
| NEW proposals | 1 (Abraham breakout + MACD + ATR trail) |
| VARIANT proposals | 1 (retracement entry version) |

**Recommended slugs:**
- NEW: `abraham-trend-bible-breakout-macd-atr-d1`
- VARIANT: `abraham-trend-bible-retracement-d1`
