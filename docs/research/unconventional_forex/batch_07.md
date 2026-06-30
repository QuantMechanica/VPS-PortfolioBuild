# Unconventional Forex: T-WIN / U.F.O. Basket Forex Strategy Analysis (Batch 07)

**Date:** 2026-06-30  
**Status:** RESEARCH REPORT (Batch 07 Analysis)  
**Target File:** `C:/QM/repo/docs/research/unconventional_forex/batch_07.md`  
**Orchestration Context:** Reverse-Engineering of 'UnconventionalForexTrading' YouTube Channel (Videos 25–28)  

---

## 1. Executive Summary & Overview

This report details the mathematical, logical, and structural reverse-engineering of the **T-WIN / U.F.O. Basket Forex Strategy** based on the video tutorials 25 through 28 from the "Unconventional Forex Trading" channel hosted by **Dr. Marco Giavon** (MT Algo Solutions). 

The analyzed videos include:
1. **Video 25 (QXCjf_EC6fQ):** *Forex mathematical formula - MT4 uUFO-EA real time Forex LIVE TRADING EXAMPLE - 2/3*
2. **Video 26 (4b2B4P-z95U):** *Forex mathematical formula - MT4 uUFO-EA real time Forex LIVE TRADING EXAMPLE - 3/3*
3. **Video 27 (BDgZsQ3qyFM):** *Forex mathematical formula - MT4 uUFO-EA - hedging on currencies weakness and strength.*
4. **Video 28 (RyY8bcFtKi8):** *Forex mathematical formula MT4 uUFO-EA tutorial - Market technical analysis without indicators 1/2.*

This research batch covers the continuation of the live trading series (Videos 25 & 26), a core breakdown of the hedging logic applied to currency strength/weakness divergences (Video 27), and a technical tutorial demonstrating indicator-free market analysis using Excel and custom Expert Advisor (EA) channel projections (Video 28). The strategy rejects retail chart indicators (RSI, MACD) in favor of **raw currency matrix indexing, multi-pair correlation hedging, and mathematical fair price channels.**

---

## 2. Currency Pairs & Basket Composition

The strategy operates by calculating the relative strength of the **8 major currencies** (USD, EUR, GBP, AUD, JPY, CAD, CHF, NZD) across the **28 cross pairs** to construct multi-pair baskets that isolate currency divergences.

### Video-Specific Portfolio Selections & Basket Compositions

*   **Videos 25 & 26 (GBP Strength vs. Commodity Weakness - Live Trading Example):**
    *   *Trade Concept:* GBP strength was paired against weak commodity currencies (AUD, NZD, CAD) and JPY.
    *   *Basket Composition:* The trader opened positions in **GBPNZD (Long)**, **GBPAUD (Long)**, **GBPCAD (Long)**, and **GBPJPY (Long)**.
    *   *Sizing/Positioning:* He doubled the position size on GBP/AUD and GBP/JPY due to strong daily/weekly alignment, while keeping a standard size on GBP/NZD (which he considered a slightly higher risk due to a weak weekly score, `[2:58]` in Video 26).
    *   *Compensating Correlation:* When GBP/NZD experienced a major retracement, the losses were completely offset and compensated by gains in GBP/AUD and GBP/JPY (`[5:36]` in Video 26).

*   **Video 27 (AUD Strength vs. Europe/Japan/Canada Weakness):**
    *   *Trade Concept:* AUD was identified as strong while GBP, CHF, CAD, and JPY were extremely weak. 
    *   *Basket Composition:* Symmetrical hedge trades were opened to sell the weak quote currencies against AUD:
        1.  **AUD/CHF (Long)** (`[8:23]` - spoken as "osseous frank")
        2.  **AUD/JPY (Long)** (`[8:23]` - spoken as "jose yen")
        3.  **GBP/AUD (Short)** (`[8:23]`)
        4.  **AUD/CAD (Long)** (`[8:23]`)

*   **Video 28 (NZD & AUD Strength vs. Yen & USD Weakness):**
    *   *Trade Concept:* First week of January 2018 (`[4:01]`). AUD and NZD were identified as strong, while Yen and USD were the weakest currencies. Euro was left untouched due to neutrality.
    *   *Basket Composition:* 
        1.  **AUD/JPY (Long)** (`[7:44]` - "longer on Aussie Yen")
        2.  **NZD/JPY (Long)** (`[9:46]`)
        3.  **NZD/USD (Long)** (`[5:37]`)
        4.  **GBP/AUD (Short)** (`[4:31]` - M5 range scalp)
        5.  **GBP/NZD (Short)** (`[11:21]`)

---

## 3. Entry & Exit Rules

Dr. Giavon's system operates on a hybrid model where the custom MT4 u.U.F.O. EA acts as the data engine feeding real-time price changes into an Excel matrix, and the trader executes entries/exits based on mathematical divergence.

### Entry Rules
1.  **Extreme Matrix Divergence:** Trades are only entered when there is a significant strength score gap. For example, in Video 28, NZD had a score of **+500** and JPY had a score of **-400** on the daily chart (`[28:23]`).
2.  **Multi-Timeframe Coherence:** Biases are filtered across H4, Daily, Weekly, and Monthly charts. Entry is executed when lower timeframe (M5/M15) pullbacks align with the higher timeframe direction.
3.  **Support/Resistance Channel Triggers:** Pending buy limit or sell limit orders are placed at key levels calculated by the EA. In Video 27, the trader missed the initial Monday open run on NZD and placed **buy limit pending orders** to catch a pullback (`[0:54]`). If the trend continues without a pullback, pending orders are cancelled to avoid late entries.
4.  **Overlap Session Injections:** The highest probability entries occur during the **London/US overlap** when institutional volume drives major currency trends (`[5:07]` in Video 28).

### Exit Rules
1.  **No Hard Stop Losses:** Dr. Giavon rejects standard stop losses as arbitrary barriers that brokers exploit (`[5:41]` in Video 27). Instead, the system uses **soft manual exits** based on mathematical index decay.
2.  **Divergence Decay Exit:** If the strength matrix shows that the strong currency is losing score (e.g. AUD strength decaying against NZD, `[8:54]` in Video 27) or if the weak currency begins to gain momentum on H1/M30 charts, the entire basket is closed.
3.  **Zero-Sum Target Profit:** Baskets are managed as a single portfolio. Positions are closed as a group when the combined net profit reaches a target threshold (e.g., 300 to 500 EUR on a 10k account) or when price hits a calculated resistance channel boundary (`[7:08]` in Video 26).
4.  **Temporal Session Exit:** All trades are closed on **Friday afternoon** before the market close to avoid broker swap fees and weekend gap risk (`[8:09]` in Video 26).

---

## 4. Hedging & Basket Recovery Logic

The strategy relies on currency correlation and grid-style position scaling to manage risk.

### Hedging Logic
*   **Correlation Buffering:** Rather than placing a single large position on one pair, the risk is distributed across 4 to 6 correlated pairs in a basket (`[14:08]` in Video 27). For example, buying NZD/USD, NZD/JPY, and selling GBP/NZD simultaneously. Symmetrical exposures neutralize intermediate currency spikes.
*   **Drawdown Compensation:** As seen in Video 26 (`[5:36]`), if one pair within the basket (GBP/NZD) retraces heavily, the other pairs (GBP/AUD and GBP/JPY) compensate for the temporary loss. The net equity curve remains smooth due to correlation.

### Recovery Logic (Position Enforcement)
*   **Averaging In (Over-Trading):** When a trade moves into a minor drawdown or ranges, the trader scales in with **multiple additional positions** at calculated support levels to average down the entry price (`[12:24]` in Video 28). This is referred to as "enhancing the effectiveness" or "enforcing" the trade.
*   **Martingale/Lot Scaling:** Position sizes are increased on subsequent grid entries to shift the break-even level closer to the current price, allowing a quick exit on minor pullbacks.
*   **Speculative Swing Holding:** Baskets are typically held for **36 to 40 hours** (Video 27, `[20:55]`) or overnight. The trader accepts overnight drawdown (reaches minus 300 EUR in Video 26, `[4:31]`) as long as the higher-timeframe index rankings remain coherent.

---

## 5. Position Sizing & Mathematical Excel Formulas

The core decision engine of the T-WIN/U.F.O. strategy is rooted in **Excel-based matrix calculations** linked to MT4 via RTD (Real-Time Data).

### Zero-Sum Theory
Dr. Giavon outlines the mathematical framework of the Forex market as a closed zero-sum system:
$$\text{Forex} = \text{One Big Number}$$
$$\text{Individual Cross Pairs} = \text{Fractions of the Big Number}$$
The sum of all currency movements across the 28 cross pairs must theoretically equal zero:
$$\sum \text{Normalized Price Changes} = 0$$
By analyzing all 28 pairs simultaneously, the Excel engine isolates the absolute strength/weakness of raw currencies relative to this zero-sum boundary (`[16:17]`–`[16:47]` in Video 27).

### Currency Strength Index Calculation
The strength score of a raw currency $C_i$ (e.g., JPY) is derived by summing its percentage price change from the daily open (midnight broker time) across all pairs in which it is traded. Negative signs are applied when the currency is the quote asset:
$$\text{Strength}(C_i) = \sum \text{Perf}(\text{Base } C_i) - \sum \text{Perf}(\text{Quote } C_i)$$
*   **Threshold Metrics:** Strength scores are scaled from $-500$ to $+500$.
*   A score of **$+350$ to $+500$** represents extreme strength, while **$-350$ to $-500$** represents extreme weakness.
*   **Positive Kurtosis Filter:** The Excel sheet computes the kurtosis of price returns over a rolling window. Trades are filtered to align with positive kurtosis, identifying statistical price extensions ready to reverse or trend (`[9:46]` in Video 28).

### Position Sizing Parameters
*   **Base Account size:** 10,000 EUR.
*   **Leverage:** 1:500.
*   **Position Sizing:** Micro-lots of **0.01 to 0.1 lots** are scaled in. Standard risk distribution is 0.01 lots per trade for testing/scaling, and 0.05 to 0.1 lots for primary pairs.
*   **Ratios:** Ratios of strength/weakness (e.g. +500 vs. -400) dictate whether standard sizing or doubled sizing is used. Double sizes are used on the absolute strongest vs. weakest pairing.

---

## 6. Timeframe & Session

*   **Primary Analysis Timeframes:** Multi-timeframe analysis. Swing trading calculations are performed on the **Daily**, **Weekly**, and **Monthly** charts (`[5:11]` in Video 27).
*   **Execution Timeframes:** Entries are timed and managed on the **M5** and **M15** timeframes (`[4:31]` in Video 28) using H1 for intermediate direction.
*   **Core Trading Sessions:**
    *   **London Open (8:00 AM - 9:00 AM Broker Time):** Crucial session for observing initial daily volume injections and setting daily biases (`[13:38]` in Video 27).
    *   **London-New York Overlap (1:00 PM - 4:00 PM Broker Time):** Highly active period for entries and trend validation (`[5:07]` in Video 28).
    *   **Asian Open (Monday 1:00 AM / 3:00 AM Broker Time):** Missed opportunities often occur here if there is a gap. Baskets are rarely entered during early Monday liquidity gaps unless pending orders were pre-set.

---

## 7. Expert Advisor (EA) Parameters & Settings

The custom **u.U.F.O. Expert Advisor** displays several visual indicators on-screen:
*   **Nine Timeframe Matrix:** Displays real-time currency strength matrix rankings tick-by-tick across M1 to MN.
*   **Line of Close Projections:** Draws support and resistance channels using the line of close (close prices) rather than candle wicks to filter noise (`[25:02]` in Video 28).
    *   *Long-Period Channel:* Blue lines representing long-term S/R.
    *   *Medium-Period Channel:* Gray lines on the chart (`[11:33]` in Video 25).
    *   *Lower-Timeframe Channel:* Dark magenta lines representing short-term S/R (`[11:33]` in Video 25).
*   **Fair Price Recalculation:** The fair price calculation updates every **30 minutes** (`[26:25]` in batch 6 and Video 25).
*   **Yellow Spread Bar:** A single yellow bar on the right side of the chart visually represents the spread, eliminating the clutter of bid/ask lines (`[12:37]` in batch 6 and Video 27).
*   **3-Day Chart Projection:** Projections of the fair price channel extending 3 days into the future (`[3:44]` in Video 25).

---

## 8. Compliance Verdict (QuantMechanica V5 Hard Rules)

> [!WARNING]
> **COMPLIANCE VERDICT: REJECTED**
> 
> The **T-WIN / u.U.F.O. Basket Strategy** strictly violates the **QuantMechanica V5 Hard Rules** in its native implementation.
> 
> **Violations:**
> 1.  **No Hard Stop Losses:** Relying on manual observation and "intuition" to close losing trades exposes the portfolio to catastrophic drawdowns during black-swan events (`[5:41]` in Video 27).
> 2.  **Grid scaling / Averaging down:** The system actively scales into losing positions (referred to as "position enforcement") to lower the average entry price of the basket (`[12:24]` in Video 28).
> 3.  **Martingale Multipliers:** Lot sizes are increased on subsequent grid entries to shift the break-even point.
> 
> **V5-Compliant Implementation Roadmap:**
> To adapt the mathematically sound edges of the T-WIN strategy while remaining V5-compliant:
> *   **Enforced Stop Losses:** Every trade must have a hard stop loss placed at execution, calculated using a fixed ATR multiplier (e.g., $1.5 \times ATR$).
> *   **Single Contract Execution:** Disable all grid scaling, lot multipliers, and averaging-down logic.
> *   **Matrix Momentum Edge:** Retain the raw currency index calculation (Divergence tracking of the 8 major currencies). Pair the strongest and weakest currencies to generate buy/sell signals. Trade a single contract with a fixed risk percentage (e.g., 0.5% or 1% of equity per trade) with a deterministic take profit (TP) set at the 30-minute Fair Price boundary.

---

### **Video Details and Key Metrics Summary**

| Video ID | Topic | Key Metrics shown | Traded Baskets | Core Takeaway |
| :--- | :--- | :--- | :--- | :--- |
| **QXCjf_EC6fQ** (V25) | Live Trading 2/3 | 30-min Recalculation, 9 Timeframes | GBPNZD, GBPAUD, GBPCAD, GBPJPY (Longs) | S/R lines projected via "Line of Close"; overnight drawdown is acceptable. |
| **4b2B4P-z95U** (V26) | Live Trading 3/3 | 10 Hours Trade, 14k EUR Balance | Closed: GBPNZD, GBPAUD, GBPJPY, GBPCAD | Basket correlation offsets individual pair retracements; manual close on Friday. |
| **BDgZsQ3qyFM** (V27) | Hedging Strength | 36–40 Hours Trade, Monday missed | AUDCHF, AUDJPY (Long), GBPAUD (Short) | Forex is a zero-sum game; Stop Loss is rejected; exit on divergence decay. |
| **RyY8bcFtKi8** (V28) | TA No Indicators 1/2 | 19 Trades, +500 / -400 Scores | AUDJPY, NZDJPY, NZDUSD (Long), GBPNZD (Short) | Currencies are traded like commodities; multiple positions are added to "enforce" direction. |
