# Unconventional Forex: T-WIN / U.F.O. Basket Forex Strategy Analysis (Batch 08)

**Date:** 2026-06-30  
**Status:** RESEARCH REPORT (Batch 08 Analysis)  
**Target File:** `C:/QM/repo/docs/research/unconventional_forex/batch_08.md`  
**Orchestration Context:** Reverse-Engineering of 'UnconventionalForexTrading' YouTube Channel (Videos 29–32)  

---

## 1. Executive Summary & Overview

This report details a complete mathematical and structural reverse-engineering of the **T-WIN / U.F.O. Basket Forex Strategy** based on videos 29 through 32 from the "Unconventional Forex Trading" YouTube channel. 

The analyzed videos include:
1. **Video 29 ([KdlsVs918qA](https://www.youtube.com/watch?v=KdlsVs918qA)):** *Forex mathematical formula MT4 uUFO-EA tutorial - Market technical analysis without indicators 2/2.*
2. **Video 30 ([RRAeHxC855E](https://www.youtube.com/watch?v=RRAeHxC855E)):** *Forex mathematical formula MT4 uUFO-EA tutorial: Volumes and Currencies strength/weakness analysis.*
3. **Video 31 ([VlxW-fs_UHk](https://www.youtube.com/watch?v=VlxW-fs_UHk)):** *Forex mathematical trading software MT4 uUFO_EVO-EA : the overbought vs oversold analysis. 1/2*
4. **Video 32 ([XQY7ZcnZVWQ](https://www.youtube.com/watch?v=XQY7ZcnZVWQ)):** *Forex mathematical trading software MT4 uUFO_EVO-EA : the overbought vs oversold analysis. 2/2*

### Core Advancements in this Batch
* **The Volume Dot Subroutine:** Rather than analyzing volume using traditional vertical histograms at the bottom of the chart, this batch introduces a custom volume algorithm that paints **yellow dots** directly onto the candlesticks to indicate price levels with highly concentrated tick volume activity.
* **The uUFO_EVO-EA "Astra" Formulas:** The "EVO" version of the Expert Advisor introduces two new sets of formulas designed to identify absolute overbought/oversold states for the **8 major currencies** across all timeframes.
* **Retracement/Scalping Logic:** When a major news-driven currency spike (e.g., a CAD spike of 113 pips in 15 minutes) or a trend has already run its course in higher timeframes, the system shifts to lower timeframes (M30 down to M1) to scalp significant retracements back to calculated support/resistance barriers.
* **Temporal and Session Constraints:** Highly specific rules are detailed for handling Friday closes, Monday opens, and European midnight spread spikes.

---

## 2. Currency Pairs & Basket Composition

The strategy continues to analyze the **8 major currencies** (USD, EUR, GBP, AUD, JPY, CAD, CHF, NZD) across all **28 cross pairs** to determine absolute strength and weakness.

### Video-Specific Portfolio Selections

* **Video 29 (CAD Retracement Scalping - Friday Close):**
  * *Rationale:* A massive CAD spike occurred during the US session (approx. 15:30/3:30 PM). Higher timeframes had already completed the main move, so the trader focused on lower timeframes (M15, M30) where CAD strength was dropping (from a prior level down to 21, then 17, and then 12) while JPY and USD were showing strength.
  * *Traded Pairs:* **USD/CAD (Buy)** and **CAD/JPY (Sell)**. By choosing CAD as the common denominator and JPY/USD as opposite currencies, the trader hedged CAD exposure. Symmetrical trade structure offset risk. **AUD/CAD** was also monitored and reversed at a calculated barrier.
* **Video 30 (JPY Strength Basket - London Session):**
  * *Rationale:* Weekly and daily charts showed JPY was the dominant strong currency, while EUR, AUD, GBP, CAD, and NZD were weak.
  * *Traded Pairs:* The trader opened a basket of 5 JPY cross pairs, shorting all of them: **EUR/JPY (Short)**, **AUD/JPY (Short)**, **GBP/JPY (Short)**, **CAD/JPY (Short)**, and **NZD/JPY (Short)**.
* **Video 31 (uUFO_EVO-EA Monday Basket):**
  * *Rationale:* JPY was strong across Monthly, Weekly, and Daily timeframes. GBP was the weakest currency (score of **-450** on the weekly), and CAD was also weak (score of **-174**).
  * *Traded Pairs:* A basket of 6 trades (18 total active positions) was injected, focusing on:
    * **GBP/USD (Sell)**
    * **USD/CAD (Buy)**
    * **CAD/JPY (Sell)**
    * **GBP/JPY (Sell)**
* **Video 32 (uUFO_EVO-EA Wednesday Basket):**
  * *Rationale:* JPY was the leading strong currency, while GBP and AUD were weak and oversold.
  * *Traded Pairs:* Focused on shorting GBP, AUD, and CAD against JPY: **GBP/JPY (Sell)**, **AUD/JPY (Sell)**, and **CAD/JPY (Sell)**.

---

## 3. Entry & Exit Rules

### Entry Rules
1. **Multi-Timeframe Trend and Correction Alignment:** First, analyze the higher timeframes (Monthly, Weekly, Daily, H4) to establish bias. Then, use lower timeframes (H1, M30, M15, M5, M1) to identify short-term corrections. Entry is triggered when lower-timeframe corrections show exhaustions (e.g., strength score decay) aligning with higher-timeframe biases.
2. **Divergence of Astra strength Scores:** In the EVO-EA, look for extreme overbought/oversold levels of the currencies themselves (e.g., weekly GBP at -450 and JPY strong).
3. **No-Trade on Timeframe Contradiction:** If the strength values are contradicting or unbalanced across different timeframes (typically seen on Mondays and Tuesdays), do NOT trade (`[5:13]` in Video 32).
4. **Volume Dot Confirmation:** Wait for yellow dots to appear on the candlesticks (`[17:24]` in Video 30):
   * A yellow dot in the **lower part** of a candlestick indicates buying pressure (support).
   * A yellow dot in the **upper part** of a candlestick indicates selling pressure (resistance).
5. **Retracement near S/R Barriers:** If a major news-driven spike has already occurred (e.g., CAD moving 113 pips in 10–15 minutes), wait for strength to decay in lower timeframes and enter the retracement near the calculated support/resistance barriers.

### Exit Rules
1. **Manual Portfolio Management (No Hard Stop Loss):** The strategy rejects standard stop losses (`[11:32]` in Video 31). If strength values indicate that the currency is losing momentum, the trend is shifting, or if the market fails to react as predicted, the trader manually closes the trades. Symmetrical hedging limits the overall portfolio drawdown.
2. **Friday Weekend Close:** Close all active positions before the Friday session ends (around 23:30 broker time, `[14:40]` in Video 29). Never hold speculative trades over the weekend due to bank closures and gap risks.
3. **Broker Spread Widening Avoidance (Midnight Rule):** Spreads widen significantly around midnight European/Broker time as liquidity drops (`[13:08]` in Video 31). Avoid opening new trades or holding tight intraday positions during this hour.
4. **European Session Close:** The end of the European/London session (afternoon) is a key target window to exit trades and lock in profits before the thin liquidity of the late US session.

---

## 4. Hedging & Basket Recovery Logic

### Hedging Logic
* **Currency Pairing Symmetry:** Symmetrical exposure is constructed using a common currency against two opposing currencies. In Video 29, the trader hedged CAD weakness by buying USD/CAD and selling CAD/JPY. This structure balances the CAD exposure; if CAD moves violently, the profit on one pair buffers the loss on the other.
* **Correlation-Based Risk Distribution:** Instead of trading a single pair, risk is spread across a basket of JPY cross pairs (EUR/JPY, AUD/JPY, GBP/JPY, CAD/JPY, NZD/JPY). If one currency (like NZD) shows unexpected strength and retraces, the gains on the other four pairs ensure the basket closes in profit.

### Recovery Logic (Position Enforcement)
* **Grid Scaling on Retracements:** When a basket position draws down, the trader "enforces the position" by adding supplementary trades at key support/resistance barriers.
* **Averaging the Entry Price:** Adding trades during a drawdown averages the basket's entry price. This allows the entire portfolio to exit in profit on a minor retracement, rather than waiting for the price to return to the original entry point.

---

## 5. Position Sizing & Mathematical Analysis

### Key Mathematical Metrics & Formulas
1. **Previous Day Activity Barriers (Orange & Blue Lines):** The EA calculates support/resistance barriers based on the previous day's trading range.
   * If the price breaks a barrier, continuation probability increases.
   * If the price is rejected by a barrier, it represents an entry zone.
2. **Astra Overbought/Oversold Formulas:** Custom formulas running tick-by-tick in uUFO_EVO-EA to calculate currency overbought/oversold values.
3. **Strength Score Thresholds:** Evaluates currency strength. In Video 31, GBP at **-450** represented an extreme oversold condition, while CAD was at **-174**.
4. **Volume Dot Algorithm:** Measures tick volume activity at specific price levels. Yellow dots are painted at the top/bottom of candlesticks to denote buying/selling volume clusters.

### Sizing and Performance Metrics
* **Account Base:** 10,000 EUR.
* **Lot Sizing:** Sizing is executed in "units" (e.g. 0.1 to 0.2 lots depending on settings) to allow grid scaling. Sizing is kept small to avoid margin pressure.
* **Basket Sizing:** In Video 30, the trader entered "2 units per symbol", opening "10 trades in MT4 which in reality are 5 trades" (2 positions per pair across 5 pairs). In Video 31, the trader had 18 total trades open (3 positions per pair across 6 pairs).
* **Account Growth Shown:** 
  * In Video 31: Friday trades ended with CAD spike losses, but overall +1,600 EUR profit (+16%). Closed Monday morning trades brought profit to +2,200 to +2,300 EUR (+22-23%).
  * In Video 32: Equity grew to **16,600 EUR** (+66% profit on the 10,000 EUR base account) after closing 23 trades.

---

## 6. Timeframe & Session

* **Trend Filtration Timeframes:** Monthly, Weekly, Daily, H4, H1.
* **Scalping/Entry Timeframes:** M30, M15, M5, M1.
* **Core Trading Sessions:**
  * **London Session Open (8:00 - 8:30 AM Broker Time):** The primary session for establishing daily biases and injecting baskets (Video 30 trades were injected between 8:00 and 8:30 AM).
  * **American Session Afternoon (around 15:30 / 3:30 PM):** High volatility and news spikes (e.g., the CAD spike in Video 29). Retracement scalping trades are executed in the afternoon.
  * **European Session Close:** Main exit window for intraday baskets.
  * **Midnight (Broker Time):** High-risk spread widening. Avoid trading.

---

## 7. Expert Advisor (EA) Parameters & Settings

* **Indicator Engine:** `uUFO-EA` and its successor `uUFO_EVO-EA`.
* **Astra Dashboard:** Dynamic multi-timeframe dashboard showing currency strength and overbought/oversold levels.
* **Barrier Projections:** Automatically plots blue and orange support/resistance barrier lines based on previous day activity.
* **Volume Dots overlay:** Toggle setting to overlay yellow dots on candlestick bodies indicating high tick volume concentration.
* **Line of Close S/R:** Plots support/resistance using close prices rather than candle extremes.
* **CPU Optimization Setting:** To handle tick-by-tick computations on 28 pairs across all timeframes, the "EVO" version includes a setting to reduce visual support/resistance lines to only **5% of the original elements**, preventing MT4 lag or freezing (`[9:13]` in Video 32).

---

## 8. Compliance Verdict (QuantMechanica V5 Hard Rules)

> [!WARNING]
> **COMPLIANCE VERDICT: REJECTED**
> 
> The strategy presented in Videos 29–32 strictly violates several **QuantMechanica V5 Hard Rules**.
> 
> **Violations:**
> 1. **No Stop Loss:** The strategy rejects standard hard stop losses, relying on manual closure. This exposes the account to catastrophic drawdown during unexpected black-swan events.
> 2. **Grid Averaging (Scaling-In / Enforcing):** Adding positions to a losing basket ("enforcing the position") multiplies exposure in a losing direction, violating risk parameters.
> 3. **Counter-Trend Scalping:** Entering retracements against high-momentum spikes (like CAD's 113-pip move) based purely on lower timeframe strength decay increases tail-risk.
> 
> **V5-Compliant Implementation Roadmap:**
> * **Mandatory Hard Stop Loss:** Every position inside the basket must be protected by a hard stop loss at execution.
> * **Disable Grid Scaling:** Disable all averaging-down or supplementary entries on active baskets.
> * **Mathematical Edge Extraction:** Extract the **Currency Strength & Weakness Matrix** and the **Volume Yellow Dot S/R indicator** as positive-expectancy filters. Use them to execute single-contract momentum or reversion entries with fixed, risk-adjusted lot sizing.
