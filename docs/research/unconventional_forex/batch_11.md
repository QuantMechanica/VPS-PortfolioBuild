# Unconventional Forex: T-WIN / U.F.O. Basket Forex Strategy Analysis (Batch 11)

**Date:** 2026-06-30  
**Status:** RESEARCH REPORT (Batch 11 Analysis)  
**Target File:** `C:/QM/repo/docs/research/unconventional_forex/batch_11.md`  
**Orchestration Context:** Reverse-Engineering of 'UnconventionalForexTrading' YouTube Channel (Videos 41–44)  

---

## 1. Executive Summary & Overview

This report details a complete mathematical, structural, and procedural reverse-engineering of the **T-WIN / U.F.O. Basket Forex Strategy** based on the webinar videos 41 through 44 from the "Unconventional Forex Trading" channel hosted by **Dr. Marco Giavon** (MT Algo Solutions).

The analyzed videos include:
1. **Video 41 ([aSqlMMFhGEs](https://www.youtube.com/watch?v=aSqlMMFhGEs)):** *FREE WEBINAR: Forex trade WIN strategy - A currency trading example from Excel analysis. 1/3* (Published June 8, 2019)
2. **Video 42 ([gPAXkVrB1Y0](https://www.youtube.com/watch?v=gPAXkVrB1Y0)):** *FREE WEBINAR: Forex trade WIN strategy - A currency trading example from Excel analysis. 3/3* (Published June 26, 2019)
3. **Video 43 ([30FF3yyCQ2k](https://www.youtube.com/watch?v=30FF3yyCQ2k)):** *FREE WEBINAR: Forex profitable strategy: math analysis and risk management. 1/2* (Published October 18, 2019)
4. **Video 44 ([fjJ0yagmoDU](https://www.youtube.com/watch?v=fjJ0yagmoDU)):** *FREE WEBINAR: Forex profitable strategy: currency strength meter for manual trading. 2/2* (Published October 26, 2019)

### Core Strategy Evolution in Batch 11
* **Concept of "Trade WIN":** The strategy is stylized as "Trade What Is Not" (`[35:44]` in Video 41, `[26:53]` in Video 42). It focuses on identifying and trading currency index divergences—such as laggard and leading currencies—that are invisible on standard pair charts.
* **The Excel-to-MT4 Pipeline:** Raw market tick feeds (all 28 pairs across multiple timeframes) are exported by an MT4 Expert Advisor (uUFO) to a local Windows folder. A custom Windows background process/macro reads and updates these files into an Excel strength matrix every **2 to 3 minutes** (`[6:15]` / `[19:32]` in Video 41).
* **Intraday vs. Swing Execution:** The strategy is strictly intraday day trading (representing 95% of the author's activity, `[10:22]` in Video 43). Positions are opened in the morning and closed by the evening. Weekend holds and overnight exposure are avoided to eliminate broker swap costs and gap risks (`[11:36]` in Video 43, `[25:30]` in Video 44).
* **Automated vs. Manual Paradigm:** The author argues that full automation is dangerous because network delays, broker spread updates, and Windows OS updates interrupt automated execution (`[38:22]` in Video 41). Instead, the system uses u.U.F.O. as a **75% analytical filter** to define the raw biases, leaving the final **25% decision** to manual chart entry analysis (identifying key support/resistance barriers and entry timings) (`[12:31]` in Video 44).

---

## 2. Currency Pairs & Basket Composition

The strategy measures the relative strength of the **8 major currencies** (USD, EUR, GBP, AUD, JPY, CAD, CHF, NZD) across all **28 cross pairs** to build multi-pair baskets that trade raw strength against raw weakness.

### Video-Specific Portfolio Selections & Basket Compositions

* **Video 42 (NZD Strength & JPY Weakness Baskets):**
  * **Day 1 Basket (25th June 2019):** **NZD Strength.** The matrix identified NZD as the absolute strongest currency (`[6:43]`). A basket of **7 NZD-related pairs** was traded to buy NZD strength against all other currencies (e.g., buying NZD/USD, NZD/JPY, NZD/CAD, NZD/CHF, and selling EUR/NZD, GBP/NZD, AUD/NZD).
  * **Day 2 Basket (26th June 2019):** **JPY Weakness.** The matrix identified JPY as the absolute weakest currency (`[8:54]`). Symmetrical JPY long cross positions (meaning shorting JPY) were injected across multiple pairs between 06:37 and 07:00 AM server time (`[9:55]`):
    1. **GBP/JPY (Long)**
    2. **EUR/JPY (Long)**
    3. **AUD/JPY (Long)**
    4. **NZD/JPY (Long)**
    5. **CAD/JPY (Long)**
    6. **USD/JPY (Long)**
    * *Basket Retracement:* GBP/JPY experienced a significant retracement. Symmetrical exposure from the other JPY cross pairs offset the drawdown, keeping the net portfolio equity curve moving upward (`[9:55]`, `[14:23]`).

* **Video 44 (GBP Weakness Basket):**
  * **Friday Basket (25th October 2019):** **GBP Weakness.** The matrix identified GBP as weak against all other major currencies (`[32:14]`). A diversified basket selling GBP was injected between 09:30 AM and 10:00 AM server time. A specific trade highlighted was:
    * **GBP/USD (Sell)** at **1.2857 – 1.2860** (`[21:39]`, `[23:15]`), which was closed for a **+45 pip** gain.

---

## 3. Entry & Exit Rules

### Entry Rules
1. **Divergence of Currency Clusters:** The primary trigger is an extreme gap between the strongest and weakest currencies in the 8x8 Excel matrix.
2. **Coherence Filter:** Confirm that the strength ranking of the target currency is supported across multiple timeframes (e.g., JPY weak on H1 and Daily).
3. **Session Timing:** Baskets are injected during the morning of the **London Open** (between 06:30 AM and 08:30 AM server time, `[9:55]` in Video 42) or during the **London-New York overlap** (around 09:30 AM to 10:00 AM, `[32:14]` in Video 44).
4. **Pullback and Ranging Phase Entry:** Chasing trends is rejected (`[37:29]` in Video 43). Once the strongest/weakest currencies are identified, check the lower timeframes (M1, M5, M15) and wait for a consolidation range or a clear pullback before placing orders.
5. **Session Interruption Filter:** Do not trade if major markets are closed for holidays (e.g., Tokyo session closed on Monday, `[5:03]` in Video 44). Holiday ranging of a single currency (like JPY) freezes correlations and prevents trend development across all pairs.

### Exit Rules
1. **Divergence Ranking Decay:** Baskets are closed immediately when the strength matrix rankings shift (e.g., a new currency replaces the previous strong/weak one), regardless of individual pair profits (`[25:29]` in Video 43).
2. **Zero-Sum Portfolio Target Profit:** Baskets are closed as a group once the combined floating profit reaches a target threshold (e.g., 2,000 to 5,000 units on a 50k account, `[10:27]` in Video 42).
3. **Intraday Temporal Close:** All trades must be closed before the US session ends (European evening). No trades should be left open overnight, keeping swap costs at 0% for 90% of trades (`[41:01]` in Video 43).
4. **Friday Weekend Exit:** All active trades are manually exited before the Friday market close (around 22:55 server time, `[41:01]` in Video 44) to eliminate weekend gap risks.

---

## 4. Hedging & Basket Recovery Logic

### Hedging Logic
* **Synthetic Portfolio Buffer:** Rather than trading a single currency pair, the strategy spreads risk across multiple pairs of the same currency cluster (e.g., buying NZD against USD, CAD, JPY, EUR, GBP, CHF).
* **Correlation Drawdown Offset:** Individual pair drawdowns (e.g., GBP/JPY retracing heavily on Day 2 in Video 42) are neutralized and offset by the positive performance of other pairs in the basket, creating a smoother equity curve (`[9:55]`, `[14:23]` in Video 42).

### Recovery Logic (Position Enforcement)
* **Averaging In (Enforcements):** When a strong/weak bias is confirmed (e.g., JPY weakness at 92-96% probability) but a pair retraces, the trader scales in with additional positions at support/resistance levels.
* **Lot Scaling:** The trader increases position sizes on these supplementary "enforcements" to shift the net break-even price closer to current market levels, facilitating a quick exit on minor pullbacks (`[9:55]` in Video 42).

---

## 5. Position Sizing & Mathematical Analysis

### Mathematical & Excel Formula Framework
The core strategy is built on the **Zero-Sum Theory** of the currency matrix:
$$\sum \text{Normalized Price Changes} = 0$$
$$\text{Relative Change} = \text{Close} - \text{Open}$$

* **Raw Data Processing:** MetaTrader feeds raw pair data to a local file. The Excel sheet parses the data and sums relative price returns for each raw currency across all 28 pairs:
$$\text{Strength}(C_i) = \sum \text{Perf}(\text{Base } C_i) - \sum \text{Perf}(\text{Quote } C_i)$$
* **Currency Oscillators:** Dr. Giavon computes custom oscillators in Excel based on raw currencies (rather than pair charts).
* **Boolean Threshold Matrix:** Strength values are converted into binary outputs (zeros and ones, True/False) based on custom deviation thresholds (`[22:38]` in Video 43):
$$\text{Threshold Condition} = \text{IF}(\text{Strength}(C_i) > \text{Threshold}, 1, 0)$$
* **Color-Coded Memory Tracker:** Color-coded tabs (e.g., shifting from red to blue) store historical currency biases. A color shift triggers manual basket exits.

### Sizing and Performance Metrics

* **Demonstration Account Size (Videos 41 & 42):** 
  * Initial Balance: 50,000 units.
  * Sizing: 1.0 standard lot flat per trade.
  * *Results:*
    * Day 1: 7 trades, 100% win rate, +2,100 units.
    * Day 2: JPY weakness basket. Floating profit milestones: +1,500 (10:00 AM) -> +4,000 (11:12 AM) -> +5,400 (1:00 PM).
    * Total 2-Day Return: +7,700 units (approx. +15.4% return).
* **Demo Test Account Size (Videos 43 & 44):** 
  * Test Period: 8 October 2019 to 25 October 2019 (approx. 2 weeks / 10-12 trading days).
  * Initial Balance: 10,000 units.
  * Sizing: 1.0 standard lot flat per trade.
  * Total Trades: 191 trades.
  * Swap Profile: 90% of trades had zero swaps. Only 9 of 191 trades were held overnight (`[41:01]` in Video 43).
  * Final Balance: 52,812 units (approx. +42,812 units profit, ~428% return).
* **Money Management Sizing Rules (Real Accounts):**
  * For a 10,000 EUR real account, the lot size must be scaled down to **0.10 lots** per trade (`[43:46]` in Video 43). This yields a realistic +4,000 EUR profit (+40% return) over two weeks with significantly lower risk.
  * For small retail accounts (e.g., 500 EUR), traders must use micro-lots (**0.01 lots**) (`[26:20]` in Video 42).

---

## 6. Timeframe & Session

* **Analysis Timeframes:** Primary trend and matrix strength calculations are performed on the **Daily** charts.
* **Execution Timeframes:** Intraday entries, pullbacks, and S/R analysis are executed on **M1, M5, and M15** charts (`[34:43]` in Video 43, `[20:30]` in Video 44).
* **Core Sessions:**
  * **London session morning open:** 06:30 AM to 08:30 AM server time. Primary basket entry window.
  * **London-New York session overlap:** 09:30 AM to 10:00 AM server time. Active trend execution window.
  * **European evening US session end:** Basket liquidation window.
  * **Holiday Sessions:** Strictly avoid trading when major sessions are closed (e.g. Tokyo bank holidays).

---

## 7. Expert Advisor (EA) Parameters & Settings

* **u.U.F.O. EA Engine:** Loaded on a **single chart** (EUR/USD, Daily timeframe, `[20:30]` in Video 44) to display strength rankings for all 8 currencies.
* **DDE/RTD File Export:** The EA writes tick updates into local files inside the MetaTrader directory.
* **Excel Subroutine Macro:** A Windows background script grabs raw files and refreshes the Excel matrix every **2 to 3 minutes**.
* **Analytical Ratio Split:** The uUFO EA functions as a **75% filter** (determining currency direction and bias). The remaining **25%** consists of manual chart analysis of S/R levels, volumes, and price action.

---

## 8. Compliance Verdict (QuantMechanica V5 Hard Rules)

> [!WARNING]
> **COMPLIANCE VERDICT: REJECTED**
> 
> The **T-WIN / U.F.O. Basket Strategy** analyzed in Videos 41–44 violates the **QuantMechanica V5 Hard Rules** in its native configuration.
> 
> **Violations:**
> 1. **No Hard Stop Losses:** The strategy rejects standard hard stop losses, relying on a global soft stop loss (manually exiting the entire portfolio when drawdown exceeds 2% to 3% of the account balance). This exposes the account to catastrophic broker execution slips and black-swan gaps (`[25:29]` in Video 43).
> 2. **Grid Scaling & Averaging Down (Enforcements):** The system scales into losing trades (adding "enforcements" with larger lot sizes) to shift the break-even price closer to current market levels (`[9:55]` in Video 42). This dramatically increases margin exposure in a losing direction.
> 
> **V5-Compliant Implementation Roadmap:**
> To extract the mathematical edge of this strategy while satisfying V5 compliance:
> * **Mandatory Hard Stop Loss:** Every trade in the basket must have a hard stop loss set at execution (calculated using a fixed ATR multiplier).
> * **Disable Grid Scaling:** Disable all averaging-down entries or lot-size multipliers on active positions.
> * **Index Momentum Filtration:** Utilize the 8-currency Excel strength index purely as a momentum or mean-reversion filter. Pair the strongest and weakest currencies, and trade a single contract with a fixed risk percentage (e.g., 0.5% or 1% of equity per trade) and a hard take profit (TP) at calculated S/R channels.

---

## 9. Video Details and Key Metrics Summary

| Video ID | Title / Topic | Key Metrics shown | Traded Baskets | Core Takeaway |
| :--- | :--- | :--- | :--- | :--- |
| **aSqlMMFhGEs** (V41) | Trade WIN Intro 1/3 | 2–3 Minute Updates, 8x8 Excel matrix | Conceptual overview | T-WIN stands for "Trade What Is Not". Raw data is parsed in Excel; automated EAs are vulnerable to network interruptions. |
| **gPAXkVrB1Y0** (V42) | Day Trading Example 3/3 | 50k balance, 7,700 units profit (15.4% return) | NZD Strength Basket, JPY Weakness Basket | Symmetrical exposure in baskets buffers individual pair retracements; intraday trades closed at US session end. |
| **30FF3yyCQ2k** (V43) | Math & Risk Management 1/2 | 191 trades, 10k to 50k units (428% return) | Basket of 1 lot flat trades (various pairs) | 90% of trades are zero-swap intraday; global soft SL set at 2-3% of account balance. |
| **fjJ0yagmoDU** (V44) | Strength Meter Manual 2/2 | 45-pip gain on GBP/USD | GBP Weakness Basket, GBP/USD Sell | Manual trading is superior to automation. UFO is loaded on a single Daily EUR/USD chart; avoid trading on bank holidays. |
