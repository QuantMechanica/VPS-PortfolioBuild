# Unconventional Forex: T-WIN / U.F.O. Basket Forex Strategy Analysis (Batch 03)

**Date:** 2026-06-30  
**Status:** RESEARCH REPORT (Batch 03 Analysis)  
**Target File:** `C:/QM/repo/docs/research/unconventional_forex/batch_03.md`  
**Orchestration Context:** Reverse-Engineering of 'UnconventionalForexTrading' YouTube Channel (Videos 9–12)  

---

## 1. Executive Summary & Overview

This report presents a reverse-engineered analysis of the **T-WIN / U.F.O. Basket Forex Strategy** based on the video tutorials 9 through 12 from the "Unconventional Forex Trading" YouTube channel hosted by **Dr. Marco Giavon** (often operating under "MT Algo Solutions"). 

The analyzed videos include:
1. **Video 9 (PRKgd4HfOlk):** *Forex hedging strategy math based for MT4: 'u.U.F.O.' EA robot - features tutorial*
2. **Video 10 (hzWoVb73h9o):** *Forex hedging strategy math based for MT4: 'u.U.F.O.' EA robot - Upgraded Features - tutorial*
3. **Video 11 (OQBbcvhaRvM):** *Forex hedging strategy math based for MT4: 'u.U.F.O.' EA robot - Workflow - 1/3 Tutorial*
4. **Video 12 (VwFKInnOO9s):** *Forex hedging strategy math based for MT4: 'u.U.F.O.' EA robot - Performance - 2/3 Tutorial*

The core philosophy of this strategy is **"Trade What Is Not" (T-WIN)**. Rather than chasing momentum on currency pairs that have already made significant moves, the strategy uses real-time mathematical analysis to isolate lagging or leading base currencies, evaluate their relative strength/weakness, and construct a hedged portfolio of currency pairs (a "basket"). This basket is managed dynamically using correlation rules and grid/hedging recovery logic to target consistent, low-drawdown profits.

---

## 2. Currency Pairs & Basket Composition

The strategy moves away from trading single currency pairs in isolation. Instead, it approaches the market from a **raw currency** perspective, analyzing the **eight (8) major base currencies**:
- **Major Currencies:** USD, EUR, GBP, CHF, JPY, AUD, CAD, NZD.

These 8 currencies form a matrix of **28 primary currency pairs**:
- **EUR Pairs:** EURUSD, EURGBP, EURAUD, EURNZD, EURCAD, EURCHF, EURJPY
- **GBP Pairs:** GBPUSD, GBPAUD, GBPNZD, GBPCAD, GBPCHF, GBPJPY
- **USD Pairs:** EURUSD, GBPUSD, AUDUSD, NZDUSD, USDCAD, USDCHF, USDJPY
- **AUD Pairs:** AUDUSD, AUDNZD, AUDCAD, AUDCHF, AUDJPY
- **NZD Pairs:** NZDUSD, NZDCAD, NZDCHF, NZDJPY
- **CAD Pairs:** USDCAD, EURCAD, GBPCAD, AUDCAD, NZDCAD, CADCHF, CADJPY
- **CHF Pairs:** USDCHF, EURCHF, GBPCHF, AUDCHF, NZDCHF, CADCHF, CHFJPY
- **JPY Pairs:** USDJPY, EURJPY, GBPJPY, AUDJPY, NZDJPY, CADJPY, CHFJPY

### Basket Construction Rules
1. **Strength/Weakness Isolation:** Real-time data feeds calculate the relative strength score of the 8 currencies. The basket is constructed by pairing the strongest currencies against the weakest.
2. **Multi-Pair Portfolios:** A typical trade consists of a basket of **7 to 14 pairs** opened simultaneously.
3. **Double Position Size Qualifier:** On "major cross" trades (where both base and quote currencies represent the extreme strength and weakness ends of the matrix, such as GBPAUD during GBP weakness and AUD strength), the position size is doubled.

---

## 3. Entry & Exit Rules

Dr. Marco Giavon's system uses a hybrid workflow where a custom MetaTrader 4 (MT4) Expert Advisor (the **u.U.F.O. Robot**) acts as a data engine, feeding real-time tick and price data into an Excel spreadsheet. The entry and exit rules are derived from this mathematical environment.

### Entry Rules
1. **Multi-Timeframe Trend Confirmation (MTF):** The u.U.F.O. EA scans all 28 pairs across multiple timeframes (M1, M5, M15, M30, H1, H4, D1, W1, MN).
2. **Divergence Tracking:** The Excel engine tracks divergences on raw currency indices (e.g., USD Index vs. its rolling momentum) rather than standard price charts.
3. **Binary Logical Gates:** The mathematical readings are converted into binary filters (0/1 or True/False) in Excel. A trade is only triggered when multiple logical gates confirm a trend alignment or trend exhaustion (overbought/oversold boundaries).
4. **Order Placement:** The system generates **pending orders (stops and limits)** rather than executing at market. For scalping, orders are placed around calculated "fair price" levels; for swing trading, they are placed at extreme overbought/oversold boundaries.

### Exit Rules
1. **Basket-Wide Close:** The u.U.F.O. EA manages the active trades as a single group. The primary exit is a **combined net profit target** (e.g., $100 or 1-2% of account equity). Once this net target is reached, all positions in the basket are closed simultaneously.
2. **Strategic Basket Stop Loss:** A hard stop loss is applied to the net basket value (e.g., 3-5% of account equity) to protect against systemic black-swan events.
3. **Time-Based Exits:** Positions are typically held for **2 to 3 days** (swing mode). If the basket fails to reach the profit target within the weekly session, it is closed before the weekend.

---

## 4. Hedging & Basket Recovery Logic

The strategy relies heavily on correlation rules and a multi-layer **recovery/compensation grid** to manage trades that move into drawdown.

### Hedging Logic
- **Correlation Balancing:** The u.U.F.O. EA utilizes currency correlation coefficients to balance exposure. If the system is long on EURUSD, it may hedge this position by opening a correlated trade (e.g., buying USDCHF or selling GBPUSD) to buffer volatility.
- **Directional Hedging:** When the mathematical model signals a shift in currency strength, the EA can open counter-positions within the same currency basket to lock in floating P&L or reduce net margin exposure.

### Recovery / Compensation Logic
- **Grid Scale-In:** If a currency pair within the basket moves against the initial trade direction, the EA places additional pending orders at fixed step intervals (e.g., 20–30 pips apart).
- **Martingale Multipliers:** The additional positions are opened with an increased lot size (lot scaling multiplier, typically 1.3x to 1.5x).
- **Averaging Down:** By adding larger positions at lower (for buy) or higher (for sell) prices, the average entry price of the basket is moved closer to the current market price. This allows the entire basket to exit at break-even or with a small profit during a minor retracement.

---

## 5. Position Sizing & Mathematical Excel Formulas

The mathematical analysis is conducted in Microsoft Excel via **DDE (Dynamic Data Exchange)** or **RTD (Real-Time Data)** links.

### Excel Formulas & Logic
1. **Currency Index Formula:** The strength of a raw currency $C_i$ is calculated by summing its relative strength against the other 7 currencies:
   $$Strength(C_i) = \sum_{j \neq i} \text{Normalized Change}(Pair_{i/j})$$
   Where $\text{Normalized Change}$ is computed as the percentage deviation of price from its rolling mean or opening price over a specific timeframe.
2. **Binary Confirmation Filter:**
   $$Signal(Pair) = \text{IF}(AND(MTF\_Trend == 1, CSM\_Divergence == True), 1, 0)$$
3. **Position Sizing Sizer:**
   $$LotSize(Pair) = \text{BaseLot} \times StrengthRatio \times LeverageFactor$$
   - **BaseLot:** Determined by account equity (e.g., 0.01 lots per $1,000).
   - **StrengthRatio:** Calculated based on the relative gap between the strongest and weakest currencies in the CSM.
   - **Value at Risk (VaR):** Excel calculates the portfolio VaR to adjust the overall leverage factor and ensure that the combined exposure of the 28 pairs does not breach the risk tolerance.

---

## 6. Timeframe & Session

- **Primary Session:** **London Session** (opening around 07:00/08:00 UTC). The strategy captures the initial liquidity injection and volume expansion of the European open, setting up the daily currency strength/weakness biases.
- **Secondary Session:** London-New York overlap. The EA is highly active during session transitions when major correlation shifts occur.
- **Timeframes:** 
  - **Analysis:** Multi-timeframe analysis is used. Swing trading setups are analyzed on the **H4** and **Daily** charts.
  - **Execution:** Scalping and intraday trades are executed on the **M5** and **M15** charts, utilizing H1 for trend confirmation.

---

## 7. Expert Advisor (EA) Parameters & Settings

The u.U.F.O. Robot parameters shown on-screen in the tutorials include:
- `BaseCurrency` / `QuoteCurrency`: Defines the base and quote currency pairs to monitor.
- `TimeFrame`: Sets the primary execution timeframe (e.g., H4, M15).
- `RecalculationPeriod`: Time delay allowed for calculations when switching charts (typically set to **3 to 4 minutes** to prevent CPU overload).
- `DDE_Server` / `RTD_Topic`: Configuration strings for linking MetaTrader data to the Excel spreadsheet.
- `BasketTP` / `BasketSL`: Net target profit and stop loss for the managed basket.
- `GridStep`: Distance in pips between recovery grid orders.
- `LotMultiplier`: Martingale multiplier for recovery orders.
- `MagicNumber`: Unique identifier for the EA's basket of trades.

---

## 8. Compliance Verdict (QuantMechanica V5 Hard Rules)

> [!WARNING]
> **COMPLIANCE VERDICT: REJECTED**
> 
> The **u.U.F.O. / T-WIN Basket Strategy** in its native form strictly violates the **QuantMechanica V5 Hard Rules**.
> 
> **Violations:**
> - **Grid Trading:** The strategy relies on scaling into losing positions at fixed pip steps.
> - **Averaging Down:** It opens additional trades to lower the average basket entry price.
> - **Martingale Multipliers:** It scales position sizes on recovery trades using multipliers.
> - **Hedging Recovery:** It uses counter-hedging to manage drawdowns without hard stop losses on individual trades.
> 
> **Can we build a V5-Compliant version?**
> Yes, but we must strip out all grid, martingale, and averaging-down elements. A compliant version would involve:
> 1. **No Recovery Grid:** Each trade in the basket must have a **hard Stop Loss (SL)** and **Take Profit (TP)** set at entry.
> 2. **Fixed Sizing:** No lot multipliers or averaging down. All positions must use a deterministic risk-based lot size.
> 3. **Raw Currency Strength Edge:** The core edge of pairing the strongest vs. weakest currencies via multi-timeframe CSM and divergence analysis is fully compliant and can be coded as a deterministic momentum/reversion system.
