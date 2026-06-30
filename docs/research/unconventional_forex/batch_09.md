# Unconventional Forex: T-WIN / U.F.O. Basket Forex Strategy Analysis (Batch 09)

**Date:** 2026-06-30  
**Status:** RESEARCH REPORT (Batch 09 Analysis)  
**Target File:** `C:/QM/repo/docs/research/unconventional_forex/batch_09.md`  
**Orchestration Context:** Reverse-Engineering of 'UnconventionalForexTrading' YouTube Channel (Videos 33–36)  

---

## 1. Executive Summary & Overview

This report presents a thorough reverse-engineering of the **T-WIN / U.F.O. Basket Forex Strategy** based on the detailed analysis of the following four videos from the "Unconventional Forex Trading" YouTube channel:
1. **Video 33 ([`https://www.youtube.com/watch?v=-q6T5osorZs`](file:///C:/QM/repo/docs/research/unconventional_forex/batch_09_video_33_transcript.txt)):** *Forex mathematical trading software MT4 EA uUFO_EVO : swing trading the overbought vs oversold.*
2. **Video 34 ([`https://www.youtube.com/watch?v=WJsjaFx9Nfg`](file:///C:/QM/repo/docs/research/unconventional_forex/batch_09_video_34_transcript.txt)):** *Forex mathematical trading software MT4 uUFO_EVO-EA: day-trading the overbought vs oversold.*
3. **Video 35 ([`https://www.youtube.com/watch?v=gIEoYQ8NvY8`](file:///C:/QM/repo/docs/research/unconventional_forex/batch_09_video_35_transcript.txt)):** *Forex mathematical trading software MT4 uUFO_EVO-EA : math-based trend analysis on all pairs.*
4. **Video 36 ([`https://www.youtube.com/watch?v=YUUWgK9nl-U`](file:///C:/QM/repo/docs/research/unconventional_forex/batch_09_video_36_transcript.txt)):** *FREE WEBINAR: real time mathematical trading workflow w/ uUFO_EVO-EA: trend analysis on all pairs.*

### Core Advancements in this Batch
* **Transition from Day Trading to Weekly Swing Trading:** Video 33 introduces a swing trading approach that targets long-term monthly overbought/oversold levels, holding trades over multiple days (Tuesday through Friday afternoon).
* **The Four-Currency Hedging Square:** Videos 34 and 36 detail the mathematical structure of a closed-loop hedging square where the net exposure to the reference currencies (EUR and USD) is completely canceled out, leaving only the synthetic exposure of the strongest vs. weakest currencies.
* **The Multi-Temporal Cross Analyzer Module:** Video 35 demonstrates a new, separately developed MT4 trend analysis module that visualizes horizontal and vertical strength/weakness vectors across nine timeframes and historical periods (up to two months back).
* **Connection to Excel Spreadsheets:** The uUFO_EVO EA links to external Excel files via MT4's DDE or CSV data output to calculate synthetic pricing, correlation matrices, and win probabilities for the hedged baskets.

---

## 2. Currency Pairs & Basket Composition

The strategy continues to evaluate the **8 major currencies** (USD, EUR, GBP, AUD, JPY, CAD, CHF, NZD) across all **28 cross pairs** to determine absolute strength and weakness.

### Video-Specific Portfolio Selections

* **Video 33 (Swing Trading Basket):**
  * *Rationale:* The Monthly chart showed that the JPY was extremely strong and oversold (ready to go long), while AUD, GBP, and CAD were extremely weak and overbought (ready to go short). USD was also weak on Tuesday. Swiss Franc (CHF) and New Zealand Dollar (NZD) were excluded because NZD was strong on the Monthly (+1700) and CHF had narrow ranges.
  * *Pairs Traded:* **AUD/JPY (Short)**, **GBP/JPY (Short)**, **CAD/JPY (Short)**, and **USD/JPY (Short)**.
* **Video 34 (4-Currency Day Trading Hedging Square):**
  * *Rationale:* Euro (EUR) and JPY were strong, while USD and CAD were weak.
  * *Pairs Traded:* A closed square basket of 4 pairs:
    * **EUR/USD (Buy)** (Long EUR, Short USD)
    * **EUR/CAD (Buy)** (Long EUR, Short CAD)
    * **USD/JPY (Sell)** (Short USD, Long JPY)
    * **CAD/JPY (Sell)** (Short CAD, Long JPY)
  * *Net Exposure:* Long 2 units EUR, Long 2 units JPY, Short 2 units USD, Short 2 units CAD. EUR/USD and EUR/CAD hedge USD and CAD exposure, while the JPY legs capture JPY strength.
* **Video 35 (Cross Analyzer Trend Basket):**
  * *Rationale:* GBP and JPY were strong, while NZD, AUD, CHF, and CAD were weak.
  * *Pairs Traded:*
    * **NZD/JPY (Sell)** (Short NZD, Long JPY)
    * **GBP/AUD (Buy)** (Long GBP, Short AUD)
    * **GBP/CHF (Buy)** (Long GBP, Short CHF)
    * **AUD/JPY (Sell)** (Short AUD, Long JPY)
    * **NZD/CAD (Sell)** (Short NZD, Long CAD) - *Note: The trader admits NZD/CAD Sell was a small mistake because CAD was weak as well, resulting in a flat ranging phase.*
* **Video 36 (Webinar 4-Currency Synthetic Hedged Square):**
  * *Rationale:* AUD was the weakest currency on the daily timeframe, and JPY was the strongest. EUR and USD were used as reference/hedging parameters.
  * *Pairs Traded:*
    * **EUR/AUD (Buy)** (Long EUR, Short AUD)
    * **USD/JPY (Sell)** (Short USD, Long JPY)
    * **EUR/JPY (Sell)** (Short EUR, Long JPY)
    * **AUD/USD (Sell)** (Short AUD, Long USD)
  * *Net Exposure:*
    * EUR: +1 (EUR/AUD) - 1 (EUR/JPY) = **0**
    * USD: -1 (USD/JPY) + 1 (AUD/USD) = **0**
    * AUD: -1 (EUR/AUD) - 1 (AUD/USD) = **-2**
    * JPY: +1 (USD/JPY) + 1 (EUR/JPY) = **+2**
    * *Result:* The net EUR and USD exposures are completely neutralized (Net 0), leaving a synthetic position of **Long 2 units JPY and Short 2 units AUD** (equivalent to shorting 2 units of AUD/JPY).

---

## 3. Entry & Exit Rules

### Entry Rules
1. **Multi-Timeframe Trend and Overbought/Oversold Divergence:** First, analyze higher timeframes (Monthly/Weekly/Daily) using the uUFO_EVO EA's strength scores to identify overbought/oversold currencies. Then, use lower timeframes (H1 down to M5) to enter on short-term pullbacks aligning with the primary trend.
2. **Early Morning Day Trading Injections:** For day-trading baskets, positions are opened very early in the day, typically 1 hour after midnight (`[1:57]` in Video 34), around 1:00 AM broker time, to capture the daily expansion before the London session open.
3. **Weekly Swing Trading Entry:** Swing trading positions are injected early in the week (usually Tuesday, `[1:54]` in Video 33) based on Monthly trend filtration, allowing the positions to ride the weekly swing.
4. **Weak/Strong Divergence Thresholds:** Wait for currencies to reach extreme scores. JPY being strong and AUD/GBP/CAD being weak/overbought triggers the JPY-buying basket.

### Exit Rules
1. **No Stop Loss Policy:** The strategy explicitly rejects traditional hard stop losses (`[2:24]` in Video 33, `[16:31]` in Video 34, `[1:36]` in Video 35). Positions are managed collectively, relying on correlation and offsetting trades to contain risk.
2. **Friday Afternoon Close:** All speculative swing and day trades must be closed on Friday afternoon (near the end of the American session, around broker market close, `[10:40]` in Video 33, `[4:38]` in Video 34) to avoid weekend gap risk, broker spread spikes, and bank closure risks.
3. **Relative Strength Shift (Equation Invalidation):** If the weak currency starts showing strength (e.g. USD or CAD rising on the Daily matrix) or if the elements of the basket equation $A+B+C+D$ change, the trader closes all positions immediately because the group's net return could turn negative (`[26:56]` in Video 34).
4. **Intraday Target Profit:** Close the entire basket once the collective profit reaches the target (e.g., +2,200 to +2,600 EUR on the test account).
5. **Time Horizon Limits:** The trader notes that holding retail positions longer than 1–2 days is dangerous because Forex is a zero-sum game with central banks manipulating prices, making prolonged positions easily targetable (`[28:52]` in Video 35).

---

## 4. Hedging & Basket Recovery Logic

### Hedging Logic
* **Closed-Loop Symmetrical Hedging:** By trading a loop of four pairs (e.g., EUR/AUD, USD/JPY, EUR/JPY, AUD/USD), exposure to the reference currencies (EUR and USD) is completely neutralized. If EUR or USD spikes due to unexpected news, the positive move on one pair offsets the negative move on the other, leaving the basket exposed only to the core trend (JPY strength vs. AUD weakness).
* **Correlation-Based Risk Containment:** Risk is spread across multiple cross pairs (e.g., buying JPY against AUD, GBP, CAD, and USD). Drawdown in a single pair (like GBP/JPY when GBP temporarily retraces up) is buffered by profits in the other JPY legs (AUD/JPY, CAD/JPY, USD/JPY), keeping the equity curve smooth (`[8:00]` in Video 33, `[23:02]` in Video 34).

### Recovery Logic
* **Grid Scaling (Position Sizing Split):** Rather than entering a single large lot size, the trader splits the position size into multiple price levels (`[24:12]` in Video 34). This allows the EA to scale into positions at better prices during pullbacks, averaging down the entry price.
* **Mean Reversion Expectation:** The strategy assumes that currencies returning from extreme overbought/oversold levels will mean-revert, allowing the averaged basket to exit in profit on minor pullbacks.

---

## 5. Position Sizing & Mathematical Analysis

### Key Mathematical Metrics & Formulas
1. **The Basket Equation:** 
   $$\text{Portfolio Return} = A + B + C + D > 0$$
   where $A, B, C, D$ represent the individual positions. The target is to close the basket when the sum is positive.
2. **The 4-Pair Neutralization Matrix:**
   $$\text{EUR/AUD (Buy)} + \text{USD/JPY (Sell)} + \text{EUR/JPY (Sell)} + \text{AUD/USD (Sell)} \implies \text{Net } 0\text{ EUR}, \text{ Net } 0\text{ USD}, \text{ Long } 2\text{ JPY}, \text{ Short } 2\text{ AUD}$$
3. **Cross Analyzer Multi-Temporal Matrix:**
   Analyzes strength/weakness tick-by-tick across a grid of 9 timeframes (5m, 15m, 30m, 60m, 240m, Day, Week, Month) and historical intervals (5m, 15m, 30m, 1h, 2h, 4h, 1d, 2d, 1w, 2w, 1m, 2m ago) to identify trend decay or continuation (`[21:23]` in Video 35).
4. **Excel Connection:**
   The EA exports real-time DDE or CSV data to an external Excel spreadsheet to analyze the basket's synthetic instrument pricing and overall win probabilities (`[8:57]` in Video 36).

### Account Performance Metrics (Shown on Screen)
* **Base Account:** 10,000 EUR test account.
* **Video 33 Profit (in Pips):**
  * AUD/JPY: **+104 pips**
  * GBP/JPY: **+105 pips**
  * USD/JPY: **+200 pips**
  * CAD/JPY: **+144 pips**
  * Total profit resulted in approximately **+16%** account growth.
* **Video 34 Profit (in Pips):**
  * EUR/USD: **+100 pips**
  * EUR/CAD: **+150 pips**
  * USD/JPY: **+50 pips**
  * CAD/JPY: **+67 pips**
  * Net profit grew by **+400 EUR** in the final 30 minutes of the video, closing all 8 positions in profit.
* **Video 35/36 Profit:**
  * Displays account profit scaling up to **+2,200 to +2,600 EUR** (+22% to +26% on the 10,000 EUR base).

---

## 6. Timeframe & Session

* **Trend Filtration Timeframes:** Monthly, Weekly, Daily, H4.
* **Intraday & Entry Timeframes:** H1, M30, M15, M5, M1.
* **Trading Sessions & Windows:**
  * **Day Trading Entry (Midnight window):** Baskets are injected 1 hour after midnight (1:00 AM broker time) to capture the early daily trend.
  * **London Session Open (8:00 AM - 9:00 AM Broker time):** Key window for trend analysis and monitoring the basket's daily acceleration (`[10:12]` in Video 35).
  * **American Session Close (Friday afternoon close):** All positions are manually liquidated before the weekend (around 15:30 - 16:00 US time / 23:00 broker time) to consolidate profits.
  * **Maximum Holding Time:** Typically 18 hours for day trading, and up to 3–4 days (Tuesday to Friday) for weekly swing trading.

---

## 7. Expert Advisor (EA) Parameters & Settings

* **uUFO_EVO EA Dashboard:** 
  * Volatility index panel.
  * Permutations panel (calculates most probable currency pairs).
  * Dynamic multi-timeframe Strength & Weakness matrix (covering 8 currencies across 9 timeframes).
  * Overbought vs. Oversold indicators.
* **Cross Analyzer (Single Pair Trend Module):**
  * Evaluates individual pairs across horizontal/vertical time grids.
  * Displays history columns (up to 2 months prior) to scan historical strength.
* **CPU Optimization Setting:**
  * A crucial parameter to disable visual elements and graphical indicators, reducing CPU load to prevent MT4 from freezing during real-time tick calculations across all 28 pairs (`[5:53]` in Video 35).
* **Excel Data Link (DDE/CSV):**
  * Links real-time feed to spreadsheets for synthetic pricing calculation.

---

## 8. Compliance Verdict (QuantMechanica V5 Hard Rules)

> [!WARNING]
> **COMPLIANCE VERDICT: REJECTED**
> 
> The strategy analyzed in Videos 33–36 strictly violates several core **QuantMechanica V5 Hard Rules**.
> 
> **Violations:**
> 1. **No Stop Loss Policy:** The strategy relies entirely on manual exits and currency correlation to manage risk, leaving the account open to catastrophic losses during black-swan events or extreme news announcements.
> 2. **Grid Averaging (Scaling-In):** Entering trades at multiple price levels to average down entry prices in drawdowns violates the requirement for fixed, risk-adjusted sizing.
> 3. **Uncapped Basket Exposure:** While $A+B+C+D > 0$ provides a mathematical target, the strategy lacks a hard stop-loss trigger for the basket itself.
> 
> **V5-Compliant Implementation Roadmap:**
> * **Forced Hard Stop Loss:** Every trade in the basket must have a hard stop loss defined at execution.
> * **Eliminate Grid Averaging:** Disable scaling-in or adding positions during drawdowns. Positions must be opened with a single, risk-adjusted lot size.
> * **Extract the Symmetrical Matrix:** The **EUR-USD 4-Pair Hedging Square** is a highly valuable, positive-expectancy filter. Implement this structure as a V5-compliant arbitrage strategy: trade the synthetic AUD/JPY exposure via the four pairs, but protect each leg with a tight, non-discretionary stop loss and a basket-wide trailing target.

---

*Report compiled by Antigravity.*
