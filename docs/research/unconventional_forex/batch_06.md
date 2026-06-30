# Unconventional Forex: T-WIN / U.F.O. Basket Forex Strategy Analysis (Batch 06)

**Date:** 2026-06-30  
**Status:** RESEARCH REPORT (Batch 06 Analysis)  
**Target File:** `C:/QM/repo/docs/research/unconventional_forex/batch_06.md`  
**Orchestration Context:** Reverse-Engineering of 'UnconventionalForexTrading' YouTube Channel (Videos 21–24)  

---

## 1. Executive Summary & Overview

This report details a complete mathematical and structural reverse-engineering of the **T-WIN / U.F.O. Basket Forex Strategy** based on the video tutorials 21 through 24 from the "Unconventional Forex Trading" YouTube channel. 

The analyzed videos include:
1. **Video 21 (_LlxWfaAQ88):** *Forex mathematical formula - MT4 uUFO-EA: hedging real time forex charts scalping strategy*
2. **Video 22 (hH6nhec_M1A):** *Forex mathematical formula - MT4 uUFO-EA: hedging real time charts scalping to intraweek trading*
3. **Video 23 (Fn4zL3YHl3Y):** *Forex mathematical formula - MT4 uUFO-EA: real time currency strength and weakness analysis.*
4. **Video 24 (kz9RLZi2qLU):** *Forex mathematical formula - MT4 uUFO-EA real time Forex LIVE TRADING EXAMPLE - 1/3*

The core philosophy of the strategy remains **"Trade What Is Not" (T-WIN)**, utilizing a custom MetaTrader 4 (MT4) Expert Advisor (**u.U.F.O. Robot**) that computes currency strength/weakness tick-by-tick across 28 pairs and 9 timeframes. This batch focuses heavily on **scalping and intraweek position scaling (weekend holding)**, the **mechanics of the EA's graphical module (fair price channel and support/resistance lines)**, and the **temporal divergence** between Monday's open and mid-week trends.

---

## 2. Currency Pairs & Basket Composition

The strategy operates on a raw base currency perspective, evaluating the relative strength of the **8 major currencies** (USD, EUR, GBP, AUD, JPY, CAD, CHF, NZD) and executing trades across the **28 major cross pairs**.

### Video-Specific Portfolio Selections

*   **Video 21 (GBP/NZD Long Setup):** 
    *   *Currency Selection Rationale:* The weekly chart showed GBP was positive and strong, while NZD was the absolute weakest currency (`[6:54]`). On the monthly chart, both GBP and NZD were in negative territory, but GBP had "bumped up" to a better level. The daily Euro was weak, leaving GBP as the primary vehicle to pair against NZD.
    *   *Traded Pairs:* Primary focus on **GBPNZD** (Long) and EURAUD / EURNZD (earlier in the week).
*   **Video 22 (AUD/JPY Short Setup - Ranging and Weekend Holding):**
    *   *Currency Selection Rationale:* The monthly chart indicated a highly negative AUD and a strong positive JPY (`[2:39]`).
    *   *Traded Pairs:* Traded **GBPAUD** and **AUDUSD** at the start of the week. Then shifted to **AUDJPY** (Short) due to AUD weakness and JPY strength.
*   **Video 23 (GBPJPY Day Trading & Pullbacks):**
    *   *Currency Selection Rationale:* Daily charts showed GBP was extremely strong (score of **350 to 375**) and JPY was negative (`[5:39]`).
    *   *Traded Pairs:* Focus shifted to **GBPJPY** (Sell on pullback). Later, JPY turned positive and NZD went weak, prompting a shift to **GBPNZD** and **GBPCHF** (`[7:50]`).
*   **Video 24 (Live Trading Portfolio):**
    *   *Traded Pairs:* Primarily **GBPNZD** (Long), along with **GBPAUD** and **GBPCHF** based on GBP strength vs. AUD/NZD weakness.

---

## 3. Entry & Exit Rules

The entry and exit rules are derived from real-time currency strength calculations and the EA's graphical channels.

### Entry Rules
1.  **Strength/Weakness Divergence:** Identify when a currency pair consists of a base currency and quote currency at opposite extremes of the strength index (e.g., GBP strength score at 375 and NZD at negative extremes).
2.  **Pullback Execution:** Avoid chasing momentum. In Video 23 (`[6:09]`), the trader waited for a massive down-move to exhaust itself during the London/US overlap, entering long positions near the calculated support bounds.
3.  **Timeframe Confirmation (9 Timeframes):** The system monitors M1, M5, M15, M30, H1, H4, Daily, Weekly, and Monthly. Entry is initiated when lower-timeframe corrections align with higher-timeframe biases.
4.  **Monday/Tuesday Divergence Setup:** 
    *   *Monday Bias:* Weekly and Daily index calculations are identical on Monday morning (`[18:20]`). This creates initial uncertainty.
    *   *Tuesday Biases:* From Tuesday onward, Daily and Weekly indices diverge. Daily corrections against the weekly trend are used as high-probability entry points.

### Exit Rules
1.  **Manual Trend Shift Exit (No Hard SL):** The strategy rejects standard stop losses (`[16:29]`). If the strength values signal that a currency is losing momentum or shifting direction (e.g., JPY turning strong and GBP weakening on H1/M30 charts), positions are manually closed.
2.  **Ranging Exits:** If JPY, NZD, and AUD are ranging/exchanging, the system exits active trades and stays out of the market due to "high uncertainty" (`[13:50]`).
3.  **Friday Session Close:** The trader recommends closing all trades before the Friday weekend close (`[14:20]`) to avoid broker swap costs and weekend gap risk.

---

## 4. Hedging & Basket Recovery Logic

The strategy manages risk as a portfolio group rather than treating individual pairs in isolation.

### Hedging Logic
*   **Correlative Offsetting:** Positions are taken in correlated pairs (e.g., trading GBP/NZD alongside EUR/AUD) to buffer volatility. Symmetrical legs hedge against sudden localized spikes in intermediate currencies.
*   **Weekend Carry Hedging:** In Video 22, the trader held AUDJPY positions over the weekend. Because the higher-timeframe (monthly) bias was JPY strong/AUD weak, the trader accepted the short-term risk of weekend gap exposure, which paid off on Monday morning at 3:00 AM when JPY spiked.

### Recovery Logic (Position Enforcement)
*   **Grid Scaling in Ranges:** When a pair is stuck in a tight range (e.g., AUDJPY ranging within a **15-pip** band, `[0:58]`), the trader adds multiple positions at key support/resistance levels. This is termed "enforcing the position."
*   **Averaging Entry Price:** By adding additional positions during retracements, the trader averages down (or up) the entry price of the basket, allowing the entire group to exit in profit on a minor retracement.

---

## 5. Position Sizing & Mathematical Analysis

The mathematical decision engine runs on MT4 and is linked to Excel via RTD/DDE.

### Key Mathematical Metrics & Formulas
1.  **Fair Price Channel:** The EA calculates a "fair price" for each of the 28 pairs based on daily highs and lows. This is updated and recalculated every **half hour (30 minutes)** (`[26:25]`).
2.  **Support/Resistance Channels:**
    *   *Long-Period Channel:* Projections of fair price over a longer period.
    *   *Medium-Period Channel:* Rendered as gray lines on the chart.
    *   *Lower-Timeframe Channel:* Rendered as dark magenta lines (`[11:33]`), calculating immediate support/resistance.
3.  **Line of Close:** The EA plots support/resistance using the line of close rather than candlesticks or bars to reduce noise and increase reading accuracy (`[24:47]`).
4.  **Spread Visualizer (Yellow Bar):** Instead of drawing multiple bid/ask lines, the EA uses a single yellow bar representing the spread to keep the charts clean (`[12:37]`).
5.  **Tick Volume:** Used as the primary volume indicator to measure market activity (`[24:16]`).
6.  **Currency strength scores:** Base strength metrics are scaled between -400 and +400. In Video 23, the trader highlights a GBP strength of **350 to 375** as a highly significant trend threshold.

### Sizing and Performance Metrics (Video 21 & 22)
*   **Account Base:** 10,000 EUR.
*   **Leverage:** 1:500.
*   **Position Sizing:** Micro-lots of **0.01 lots** to **0.1 lots** are scaled in. The trader notes a mistake where they accidentally traded 0.01 lots instead of their target sizing (`[7:58]`).
*   **Profit Milestones Shown (Video 21):**
    *   *Stage 1:* 1,700 EUR profit.
    *   *Stage 2:* 3,000 EUR profit.
    *   *Stage 3:* 5,600 EUR profit (representing a **+56%** return on the 10,000 EUR base account).

---

## 6. Timeframe & Session

*   **Primary Execution Timeframes:** The trader executes scalping entries on the **M5** and **M15** charts (`[22:09]`), while using the **H1**, **H4**, **Daily**, **Weekly**, and **Monthly** charts for trend/strength filters.
*   **Core Sessions:**
    *   **London Session:** The primary session for establishing daily biases. Entries are typically taken around **8:00 AM broker time** (`[5:20]`).
    *   **London-New York Overlap:** Used for observing correlation shifts and executing pullback entries (`[6:09]`).
    *   **Asian Open:** Monday morning at **3:00 AM** and **1:00 AM** broker time are highlighted as crucial times for closing intraweek trades and taking profits from weekend moves (`[1:08]`, `[1:26]`).

---

## 7. Expert Advisor (EA) Parameters & Settings

The u.U.F.O. Robot parameters and interface features visible in this batch include:
*   `Nine Timeframe Matrix`: Real-time strength display for the 8 base currencies.
*   `Fair Price Channels`: Automatically draws long-period, medium-period (gray), and lower-timeframe (magenta) support/resistance lines.
*   `Recalculation Interval`: Set to **30 minutes** for the main fair price channel.
*   `Ask/Bid Spread Bar (Yellow Bar)`: Visual bar on the right side of the chart showing bid/ask spread.
*   `Tick Volume Module`: Visual overlay displaying tick activity.
*   `3-Day Chart Projection`: Projections of the fair price channel extending 3 days into the future (`[3:44]`).

---

## 8. Compliance Verdict (QuantMechanica V5 Hard Rules)

> [!WARNING]
> **COMPLIANCE VERDICT: REJECTED**
> 
> The strategy presented in Videos 21–24 strictly violates several **QuantMechanica V5 Hard Rules**.
> 
> **Violations:**
> 1.  **No Stop Loss:** The strategy relies entirely on manual observation of currency strength values to close losing positions (`[16:29]`). This exposes the account to catastrophic drawdown during sudden black-swan events.
> 2.  **Grid Averaging (Enforcing Positions):** The trader scales into multiple positions at fixed steps during ranging markets (`[4:52]`, `[5:53]`) to lower the average entry price.
> 3.  **Weekend Holding (Intraweek Trading):** Holding speculative, unhedged/under-hedged positions over the weekend (`[0:58]`) violates risk limits.
> 
> **V5-Compliant Implementation Roadmap:**
> To implement the viable edge of this strategy under V5 rules, we must:
> *   **Hard Stop Loss:** Force a hard SL on every single trade at execution.
> *   **No Grid Scaling:** Disable all averaging-down and lot-multiplication features.
> *   **Strength Momentum/Reversion Edge:** Extract the real-time currency strength matrix (pairing the strongest vs. weakest currencies) and use it as a filter for single-contract momentum or reversion entries with fixed risk-adjusted lot sizing.
