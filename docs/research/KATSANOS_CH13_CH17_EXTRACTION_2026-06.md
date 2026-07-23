# Katsanos Book Mining: Ch.13 DAX & Ch.17 Forex Systems
**File Date:** 2026-07-23  
**Status:** DRAFT CARD PROPOSALS  
**Lead:** Gemini  
**Task Reference:** Katsanos Intermarket Trading Strategies (Wiley 2008) Extraction  

---

## 1. Overview & Operating Guidelines

As part of the **QuantMechanica Edge Lab Program**, this document contains the exact rules, parameters, intermarket partners, and MetaStock code blocks extracted from Markos Katsanos' *Intermarket Trading Strategies* (Wiley 2008) for:
- **Chapter 13:** Trading DAX Futures (book p. 201+)
- **Chapter 17:** Forex Trading Using Intermarket Analysis (book p. 261+, Yen & Euro systems)

All conventional (non-neural) systems described in these sections are analyzed. In accordance with the **Edge Lab Charter (2026-05-22)** and **Profitability Track (2026-05-21)**, neural network systems (such as those in Chapter 14 and Appendix B) are explicitly skipped, and any model proposed must fit our strict design box (news blackouts, risk controls, and mechanical execution).

### Crucial Operating Rules Applied:
- **No ML in EA:** These systems are strictly technical and intermarket-driven.
- **FTMO Compliance:** Systems must run with news blackouts, swing/scalping horizons, no martingales, and tight drawdown bounds ($\le 5\%$ daily, $\le 10\%$ total).
- **Available Symbols:** All `.DWX` FX pairs, `XAUUSD`, `XAGUSD`, `XTIUSD`, `XNGUSD`, `NDX`, `WS30`, `GDAXI` (DAX), `UK100` (FTSE), `SP500` (backtest-only).
- **Unavailable Symbols:** Bond yields (`TNX`/yields), VIX, miners indices, CRB index, Nikkei. Systems requiring these must be flagged as `R3_FAIL` unless a robust, deterministic proxy is proposed.

---

## 2. The Honest In-Sample Caveat

> [!WARNING]
> **In-Sample Optimization Bias (Katsanos, book p. 179 / PDFPAGE 197)**
> The author explicitly admits a significant methodological shortcut in the system development:
> *"Normally, when these type of systems are developed, two data sets should be used: one for optimization and the other for testing the optimized parameters on the new data. Since these tests were only carried out for comparison purposes, in order to simplify the process, optimization was carried out across the complete data set."*
>
> Because optimization was conducted over the entire data set, all reported performance figures (including win rates, drawdowns, and profit factors) are heavily subject to **in-sample curve-fitting bias**. Real-world performance is highly likely to be significantly degraded. Any system marked `PASS` must undergo strict out-of-sample forward tests prior to pipeline promotion.

---

## 3. The Trade Frequency Problem

> [!IMPORTANT]
> **Extremely Low Trade Frequency**
> Intermarket and divergence systems operating on daily charts generate very few trades. Katsanos notes that many systems trade only **2 to 4 times per year** (or 5 to 8 times per year for combined breakout models). 
> For FTMO-style prop evaluation with tight evaluation windows (e.g., 30-day limits or active trading requirements), such low frequency will fail to meet profit targets in time. Trade frequency must be estimated honestly and must be factored into any portfolio generation logic.

---

## 4. Chapter 13: DAX Futures Systems

### System 13.1: DAX Daily Disparity System
* **Asset Class:** Equity Index Futures (DAX / FDAX)
* **Intermarket Partner:** CAC 40 Futures (FCE)
* **Periodicity:** Daily
* **Parameters:**
  * Disparity Period ($D1$): 10 days
  * Congestion Index ($CI$): 39 days (uses 40-period HHV/LLV)
  * Divergence Momentum Oscillator ($IM$): 200 days (3-day SMA smoothing)
  * $IM$ Buy Threshold: 65 (reversal trigger)
  * $IM$ Exit Threshold: 5 (reversal trigger)
  * Fast Stochastic: 5 days (trigger)
  * Congestion Stochastic: 15 days (congestion entry filter)
  * Linear Regression Slope ($LRS20$): 20 days (congestion filter)
  * Linear Regression Slope ($LRS40$): 40 days (trend reversal filter)
  * Time Exit: 80 trading days
  * Volatility Stop: $1.6 \times ATR(8)$ of last 8 bars

* **Exact Entry/Exit Rules:**
  * **Long Entry (Buy next day at Open):**
    * *Divergence Condition:* $HHV(DIVERG, 2) > 0$ AND $IM > 65$ AND $IM < Ref(IM, -1)$ AND $Stoch(5,3) > MA(Stoch(5,3), 4, S)$ AND $ROC(CAC\_Futures, 6) > 0.4\%$ AND $ROC(DAX, 1) > 0$.
    * *OR Congestion Condition:* $ABS(CI) < 35$ AND $LRS20 < 0.2\%$ AND $LLV(Stoch(15,3), 4) < 30$ AND $Stoch(15,3) > 30$ AND $Stoch(5,3) > MA(Stoch(5,3), 4, S)$.
  * **Long Exit (Sell next day at Open):**
    * *Divergence Exit:* $DIVERG < 0$ AND $LLV(IM, 4) < 5$ AND $IM > Ref(IM, -1)$ AND $Stoch(5,3) < MA(Stoch(5,3), 3, S)$.
    * *OR Trend Reversal Exit:* $HHV(CI, 3) - CI > 40$ AND $DIV2 < 0$ AND $ROC(DAX, 3, \%) < -0.1\%$.
    * *OR Bear Market Downtrend:* $MA(DAX, 10) < MA(DAX, 150)$ AND $MACD()$ crosses below $EMA(MACD(), 7)$ AND $DIV2 < 0$.
    * *OR Intermarket Exit:* $DIVERG < -1$ AND $Stoch(5,3) < MA(Stoch(5,3), 3, S)$ AND $ROC(DAX, 2, \%) < -0.5\%$ AND $ROC(CAC\_Futures, 2, \%) < -0.6\%$.
  * **Short Entry (Sell Short next day at Open):**
    * *Trend Reversal:* $HHV(CI, 3) - CI > 50$ AND $LRS < 0$ AND $MACD() < EMA(MACD(), 7)$.
    * *OR Congestion:* $ABS(CI) < 30$ AND $LRS20 < 0.1\%$ AND $HHV(Stoch(25,3), 4) > 85$ AND $Stoch(25,3) < 70$ AND $Stoch(5,3) < MA(Stoch(5,3), 4, S)$.
  * **Short Exit (Buy to Cover next day at Open):**
    * *Divergence Cover:* $DIVERG > 0$ AND $HHV(IM, 4) > 60$ AND $IM < Ref(IM, -1)$ AND $Stoch(5,3) > MA(Stoch(5,3), 3, S)$.
    * *OR Trend Reversal Cover:* $LLV(CI, 3) - CI < -40$.
    * *OR Trend Cover:* $MA(DAX, 10) > MA(DAX, 150)$ AND $MACD()$ crosses above $EMA(MACD(), 7)$.
    * *OR Congestion Cover:* $ABS(CI) < 30$ AND $LLV(Stoch(25,3), 4) < 30$ AND $Stoch(25,3) > 40$ AND $Stoch(5,3) > MA(Stoch(5,3), 4, S)$.

* **Appendix A Code Block:**
  ```metastock
  { Long }
  SEC2:=Security("C:\Metastock Data\REUTERSFUTURES\@:FCEc1",C);
  CI:=ROC(C,39,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  D1:=10;
  DIS1:=((C-Mov(C,D1,S)) /Mov(C,D1,S))*100;
  DIS2:=((SEC2-Mov(SEC2,D1,S))/Mov(SEC2,D1,S))*100;DIV2:=DIS2-DIS1;
  DIVERG:=Mov(DIV2,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  LRS20:=LinRegSlope(C,20)/Abs(Ref(C,-19))*100;
  LRS:=LinRegSlope(C,40)/Abs(Ref(C,-39))*100;
  (HHV(DIVERG,2)>0 AND IM>65 AND IM<REF(IM,-1) AND Stoch(5,3)>Mov(Stoch(5,3),4,S) AND ROC(SEC2,6,%)>.4 AND ROC(C,1,%)>0)
  {Buy Condition 1 -DIVERGENCE}
  OR (ABS(CI)<35 AND LRS20< .2 AND LLV(STOCH(15,3),4)<30 AND STOCH(15,3)>30 AND STOCH(5,3)>MOV(STOCH(5,3),4,S))
  {Buy Condition 2 CONGESTION}

  { Sell }
  SEC2:=Security("C:\Metastock Data\REUTERSFUTURES\@:FCEc1",C);
  CI:=ROC(C,39,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  D1:=10;
  DIS1:=((C - Mov(C,D1,S)) / Mov(C,D1,S)) *100;
  DIS2:=((SEC2 - Mov(SEC2,D1,S)) / Mov(SEC2,D1,S)) * 100;DIV2:=DIS2-DIS1;
  DIVERG:=Mov(DIV2,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  (DIVERG<0 AND LLV(IM,4)<5 AND IM> REF(IM,-1) AND STOCH(5,3)<MOV(STOCH(5,3),3,S)) {Sell Condition 1: DIVERGENCE}
  OR (hhv(CI,3)-CI >40 AND DIV2<0 AND ROC(C,3,%)<-.1) {Sell Condition 2: Trend reversal}
  OR (MOV(C,10,S)<MOV(C,150,S) AND CROSS(MOV(MACD(),7,E),MACD()) AND DIV2<0) {Sell Condition 3- Bear Market downtrend}
  OR (DIVERG<-1 AND STOCH(5,3)<MOV(STOCH(5,3),3,S) AND ROC(C,2,%)<-.5 AND ROC(SEC2,2,%)<-.6) {Sell Condition 4: Intermarket}

  { Sell Short }
  SEC2:=Security("C:\Metastock Data\REUTERSFUTURES\@:FCEc1",C);
  CI:=ROC(C,39,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  LRS20:=LinRegSlope(C,20)/Abs(Ref(C,-19))*100;
  LRS:=LinRegSlope(C,40)/Abs(Ref(C,-39))*100;
  (hhv(CI,3)-CI>50 AND LRS<0 AND MACD()<MOV(MACD(),7,E)) {Short condition 1: Trend reversal} 
  OR (ABS(CI)<30 AND LRS20< .1 AND HHV(STOCH(25,3),4)>85 AND STOCH(25,3)<70 AND STOCH(5,3)<MOV(STOCH(5,3),4,S)) {Short condition 2: CONGESTION}

  { Buy to Cover }
  SEC2:=Security("C:\Metastock Data\REUTERSFUTURES\@:FCEc1",C);
  CI:=ROC(C,39,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  D1:=10;
  DIS1:=((C - Mov(C,D1,S)) / Mov(C,D1,S)) * 100;
  DIS2:=((SEC2 - Mov(SEC2,D1,S)) / Mov(SEC2,D1,S)) *100;DIV2:=DIS2-DIS1;
  DIVERG:=Mov(DIV2,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  (DIVERG>0 AND HHV(IM,4) >60 AND IM< REF(IM,-1) AND STOCH(5,3)>MOV(STOCH(5,3),3,S)) {Cover condition 1: Divergence}
  OR (LLV(CI,3)-CI<-40) {Cover condition 2: Trend reversal}
  OR (MOV(C,10,S)>MOV(C,150,S) AND CROSS(MACD(),MOV(MACD(),7,E))) {Cover condition 3: Trend}
  OR (ABS(CI)<30 AND LLV(STOCH(25,3),4)<30 AND STOCH(25,3)>40 AND STOCH(5,3)>MOV(STOCH(5,3),4,S)) {Cover condition 4: CONGESTION}
  ```

* **Universe Mapping & Proxy:**
  * Base: `GDAXI` (German DAX Index).
  * Intermarket Partner: CAC 40 Futures (`FCE` or `^FCHI`). *CAC 40 is not available.*
  * **Proxy Proposal:** Use `UK100` (FTSE 100 Index) or `SP500` (S&P 500) as the intermarket partner. Both are highly correlated stock indices.
* **R3 Verdict:** **PASS (With Proxy)**
  * The logic does not require interest rates or unavailable data. The proxy index `UK100` or `SP500` is fully tradeable/backtestable.
* **Proposed Card Slug:** `QM5_12543_katsanos-dax-disparity`
* **Expected Trades/Year:** **5.8** (extremely low frequency).

---

### System 13.2: DAX MACrossoverSystem (Standard)
* **Asset Class:** Equity Index Futures (DAX)
* **Intermarket Partner:** None (explores standard indicators with trend/congestion switching)
* **Periodicity:** Daily
* **Parameters:**
  * Fast MA ($MA1$): 15 days (Long), 10 days (Short)
  * Slow MA ($MA2$): 20 days (Long & Short)
  * Long-Term Trend Filter: 150 days
  * Congestion Index ($CI$): 39 days (40-period HHV/LLV)
  * Stochastic periods: 5 days (trigger), 40 days (congestion filter)

* **Exact Entry/Exit Rules:**
  * **Long Entry (Buy next day at Open):**
    * *Trending Condition:* $CI > 30$ AND $Stoch(5,3) > MA(Stoch(5,3), 3, S)$ AND $MA(DAX, 15) > MA(DAX, 20)$.
    * *OR Congestion Condition:* $ABS(CI) < 25$ AND $Stoch(5,3) > MA(Stoch(5,3), 3, S)$ AND $LLV(Stoch(40,3), 2) < 30$.
  * **Long Exit (Sell next day at Open):**
    * $HHV(CI, 3) - CI > 40$ OR ($ABS(CI) < 20$ AND $Stoch(5,3) < MA(Stoch(5,3), 3, S)$ AND $HHV(Stoch(40,3), 4) > 85$ AND $Stoch(40,3) < 75$).
  * **Short Entry (Sell Short next day at Open):**
    * *Trending Condition:* $CI < -30$ AND $ROC(CI, 3, \%) < 0$ AND $Stoch(5,3) < MA(Stoch(5,3), 3, S)$ AND $MA(DAX, 10) < MA(DAX, 20)$ AND $MA(DAX, 2) < MA(DAX, 150)$.
    * *OR Congestion Condition:* $ABS(CI) < 25$ AND $ROC(CI, 3, \%) < 0$ AND $Stoch(5,3) < MA(Stoch(5,3), 3, S)$ AND $HHV(Stoch(40,3), 2) > 70$.
  * **Short Exit (Buy to Cover next day at Open):**
    * $LLV(CI, 3) - CI < -40$ OR ($Cross(MACD(), EMA(MACD(), 7))$ AND $DAX > EMA(DAX, 7)$).

* **Appendix A Code Block:**
  ```metastock
  { Long }
  CI:=ROC(C,39,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  (CI>30 AND STOCH(5,3)>MOV(STOCH(5,3),3,S) AND MOV(C,15,S)>MOV(C,20,S)) OR (ABS(CI)<25 AND STOCH(5,3)>MOV(STOCH(5,3),3,S) AND LLV(STOCH(40,3),2)<30){CONGESTION}

  { Sell }
  CI:=ROC(C,39,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  (hhv(CI,3)-CI>40) OR (ABS(CI)<20 AND STOCH(5,3)<MOV(STOCH(5,3),3,S) AND HHV(STOCH(40,3),4) >85 AND STOCH(40,3)<75) {CONGESTION}

  { Sell Short }
  CI:=ROC(C,39,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  (CI<-30 AND ROC(CI,3,%)<0 AND STOCH(5,3)<MOV(STOCH(5,3),3,S) AND MOV(C,10,S)<MOV(C,20,S) AND MOV(C,2,S)<MOV(C,150,S)) OR (ABS(CI)<25 AND ROC(CI,3,%)<0 AND STOCH(5,3)<MOV(STOCH(5,3),3,S) AND HHV(STOCH(40,3),2)>70) {CONGESTION}

  { Buy to Cover }
  CI:=ROC(C,39,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  LLv(CI,3)-CI<-40 OR (CROSS(MACD(),MOV(MACD(),7,E)) AND C>MOV(C,7,E))
  ```

* **Universe Mapping & Proxy:**
  * Base: `GDAXI` (DAX).
  * Intermarket Partner: None.
* **R3 Verdict:** **PASS**
  * Straightforward moving average/stochastic system with no dependencies on external datasets.
* **Proposed Card Slug:** `QM5_12544_katsanos-dax-macross`
* **Expected Trades/Year:** **13.5** (higher frequency trend/congestion switcher).

---

### System 13.3: DAX Intermarket Enhanced MA Crossover System
* **Asset Class:** Equity Index Futures (DAX)
* **Intermarket Partner:** EuroStoxx 50 Futures (FESX)
* **Periodicity:** Daily
* **Parameters:** Same as System 13.2, plus:
  * Disparity Period ($D1$): 10 days
  * Divergence ($DIV2$): $DIS2 - DIS1$ (EuroStoxx Disparity - DAX Disparity)

* **Exact Entry/Exit Rules:**
  * Same rules as System 13.2, but adding intermarket filters ($DIV2 > 0$ and EuroStoxx ROC filters) to eliminate false breakout/congestion entries.
  * **Long Entry (Buy next day at Open):**
    * *Trending Condition:* $CI > 30$ AND $Stoch(5,3) > MA(Stoch(5,3), 3, S)$ AND $MA(DAX, 15) > MA(DAX, 20)$.
    * *OR Congestion Condition:* $ABS(CI) < 25$ AND $Stoch(5,3) > MA(Stoch(5,3), 3, S)$ AND $LLV(Stoch(40,3), 2) < 30$ AND $ROC(EuroStoxx, 1, \%) > 0$ AND $DIV2 > 0$.
  * **Long Exit (Sell next day at Open):**
    * $HHV(CI, 3) - CI > 40$ OR ($ABS(CI) < 20$ AND $Stoch(5,3) < MA(Stoch(5,3), 3, S)$ AND $HHV(Stoch(40,3), 4) > 85$ AND $Stoch(40,3) < 75$ AND $DIV2 < 0$).
  * **Short Entry (Sell Short next day at Open):**
    * *Trending Condition:* $CI < -30$ AND $ROC(CI, 3, \%) < 0$ AND $DIV2 < 0$ AND $ROC(EuroStoxx, 2, \%) < -0.5\%$ AND $Stoch(5,3) < MA(Stoch(5,3), 3, S)$ AND $MA(DAX, 10) < MA(DAX, 20)$ AND $MA(DAX, 2) < MA(DAX, 150)$.
    * *OR Congestion Condition:* $ABS(CI) < 25$ AND $ROC(CI, 3, \%) < 0$ AND $Stoch(5,3) < MA(Stoch(5,3), 3, S)$ AND $HHV(Stoch(40,3), 2) > 70$ AND $ROC(EuroStoxx, 1, \%) < 0$ AND $DIV2 < 0$ AND $MA(EuroStoxx, 10) < MA(EuroStoxx, 20)$.
  * **Short Exit (Buy to Cover next day at Open):** Same as System 13.2.

* **Appendix A Code Block:**
  ```metastock
  { Long }
  SEC2:=Security("C:\Metastock Data\REUTERSFUTURES\@:STXEc1",C);
  CI:=ROC(C,39,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  D1:=10;
  DIS1:=((C - Mov(C,D1,S)) / Mov(C,D1,S)) * 100;
  DIS2:=((SEC2 - Mov(SEC2,D1,S)) / Mov(SEC2,D1,S)) * 100;DIV2:=DIS2-DIS1;
  (CI>30 AND STOCH(5,3)>MOV(STOCH(5,3),3,S) AND MOV(C,15,S)>MOV(C,20,S)) OR (ABS(CI)<25 AND STOCH(5,3)>MOV(STOCH(5,3),3,S) AND LLV(STOCH(40,3),2)<30 AND ROC(SEC2,1,%) >0 AND DIV2>0) {CONGESTION}

  { Sell }
  SEC2:=Security("C:\Metastock Data\REUTERSFUTURES\@:STXEc1",C);
  CI:=ROC(C,39,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  D1:=10;
  DIS1:=((C - Mov(C,D1,S)) / Mov(C,D1,S)) * 100;
  DIS2:=((SEC2 - Mov(SEC2,D1,S)) / Mov(SEC2,D1,S)) * 100;DIV2:=DIS2-DIS1;
  (hhv(CI,3)-CI>40) OR (ABS(CI)<20 AND STOCH(5,3)<MOV(STOCH(5,3),3,S) AND HHV(STOCH(40,3),4)>85 AND STOCH(40,3)<75 AND DIV2<0) {CONGESTION}

  { Sell Short }
  SEC2:=Security("C:\Metastock Data\REUTERSFUTURES\@:STXEc1",C);
  CI:=ROC(C,39,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  D1:=10;
  DIS1:=((C - Mov(C,D1,S)) / Mov(C,D1,S)) * 100;
  DIS2:=((SEC2 - Mov(SEC2,D1,S)) / Mov(SEC2,D1,S)) * 100;DIV2:=DIS2-DIS1;
  (CI<-30 AND ROC(CI,3,%)<0 AND DIV2<0 AND ROC(SEC2,2,%)<-.5 AND STOCH(5,3)<MOV(STOCH(5,3),3,S) AND MOV(C,10,S)<MOV(C,20,S) AND MOV(C,2,S)<MOV(C,150,S)) OR (ABS(CI)<25 AND ROC(CI,3,%)<0 AND STOCH(5,3)<MOV(STOCH(5,3),3,S) AND HHV(STOCH(40,3),2)>70 AND ROC(SEC2,1,%) <0 AND DIV2<0 AND MOV(SEC2,10,S)<MOV(SEC2,20,S)) {CONGESTION}

  { Buy to Cover }
  SEC2:=Security("C:\Metastock Data\REUTERSFUTURES\@:STXEc1",C);
  CI:=ROC(C,39,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  D1:=10;
  DIS1:=((C - Mov(C,D1,S)) / Mov(C,D1,S)) * 100;
  DIS2:=((SEC2 - Mov(SEC2,D1,S)) / Mov(SEC2,D1,S)) * 100;DIV2:=DIS2-DIS1;
  LLv(CI,3)-CI<-40 OR (CROSS(MACD(),MOV(MACD(),7,E)) AND C >MOV(C,7,E))
  ```

* **Universe Mapping & Proxy:**
  * Base: `GDAXI` (DAX).
  * Intermarket Partner: EuroStoxx 50 Futures (`STXEc1` or `FESX`). *EuroStoxx is not available.*
  * **Proxy Proposal:** Use `UK100` or `SP500` as the intermarket partner.
* **R3 Verdict:** **PASS (With Proxy)**
  * The system is viable with `UK100` or `SP500` as a proxy intermarket partner.
* **Proposed Card Slug:** `QM5_12545_katsanos-dax-macross-enhanced`
* **Expected Trades/Year:** **6.9** (infrequent).

---

### System 13.4: DAX Component Stock Disparity System
* **Asset Class:** Equities (DAX Component Stocks)
* **Intermarket Partner:** CAC 40 Futures (FCE)
* **Periodicity:** Daily
* **Parameters:** Same as System 13.1 (Long only), plus:
  * Time Stop: 50 trading days
  * Trailing Stop: `STOP = HHV(C, 3) - 2.2 * ATR(10)`

* **Exact Entry/Exit Rules:**
  * **Long Entry:** Same as System 13.1 Long conditions.
  * **Long Exit:** Same as System 13.1 Sell conditions, OR if price hits Trailing Stop or 50-day Time Stop.

* **Appendix A Code Block:**
  ```metastock
  { Entry Trigger }
  SEC2:=Security("C:\Metastock Data\REUTERSFUTURES\@:FCEc1",C);
  CI:=ROC(C,39,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  D1:=10;STOP:=HHV(C,3)-2.2*ATR(10);
  DIS1:=((C-Mov(C,D1,S)) /Mov(C,D1,S))*100;
  DIS2:=((SEC2-Mov(SEC2,D1,S))/Mov(SEC2,D1,S))*100;DIV2:=DIS2-DIS1;
  DIVERG:=Mov(DIV2,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  LRS20:=LinRegSlope(C,20)/Abs(Ref(C,-19))*100;
  LRS:=LinRegSlope(C,40)/Abs(Ref(C,-39))*100;
  ENTRYTRIGGER:=(HHV(DIVERG,2)>0 AND IM>65 AND IM<Ref(IM,-1) AND Stoch(5,3)>Mov(Stoch(5,3),4,S) AND ROC(SEC2,6,%)>.4 AND ROC(C,1,%) >0) {DIVERGENCE}
  OR (Abs(CI)<35 AND LRS20< .2 AND LLV(Stoch(15,3),4)<30 AND Stoch(15,3)>30 AND Stoch(5,3)>Mov(Stoch(5,3),4,S)) {CONGESTION};

  { Exit Trigger }
  EXITTRIGGER:=(DIVERG<0 AND LLV(IM,4)<5 AND IM> Ref(IM,-1) AND Stoch(5,3)<Mov(Stoch(5,3),3,S))
  OR (HHV(CI,3)-CI>40 AND DIV2<0 AND ROC(C,3,%)<-.1)
  OR (Mov(C,10,S) <Mov(C,150,S) AND Cross(Mov(MACD(),7,E),MACD()) AND DIV2<0)
  OR (DIVERG<-1 AND Stoch(5,3)<Mov(Stoch(5,3),3,S) AND ROC(C,2,%)<-.5 AND ROC(SEC2,2,%)<-.6) 
  OR Cross(STOP,L);
  ExtFml("TradeSim.SetTimeStop",50);
  ```

* **Universe Mapping & Proxy:**
  * Base: Individual German Stocks (E.ON, Siemens, BASF, SAP, etc.). *Not available in our trading universe.*
  * Intermarket Partner: CAC 40 Futures (FCE). *Not available.*
* **R3 Verdict:** **R3_FAIL**
  * We hold no individual German equity stock symbols (only index `GDAXI` is available). Proposing this system is mathematically unviable for our execution pipeline.
* **Proposed Card Slug:** `QM5_12546_katsanos-dax-stocks-disparity`
* **Expected Trades/Year:** **29.4** across a 10-stock portfolio (~2.9 trades/year per stock).

---

## 5. Chapter 17: Forex Systems (Yen & Euro)

### System 17.1: Yen (USD/YEN) Daily Intermarket Volatility System
* **Asset Class:** Forex Spot (USD/JPY)
* **Intermarket Partners:** S&P 500 Index (SPX), 10-year Treasury Yield (TNX), US Dollar Index (DXY)
* **Periodicity:** Daily
* **Parameters:**
  * Regression Period ($D1$): 200 days
  * ROC Period ($D2$): 15 days
  * Volatility Period ($SDADX$): 15 days (Welles Wilder ADX)
  * Bollinger Bands: 20 period (std dev 1.8 for breakout entry), 10 period (std dev 2.5 for stop loss exit)
  * Disparity Period: 10 days (Exponential moving average)
  * Stochastic: 5 days (trigger)
  * Trailing Stop: lower 10-day Bollinger Band (long), upper 10-day BB (short)

* **Exact Entry/Exit Rules:**
  * **Long Entry (Buy next day at Close):**
    * *Regression Divergence Trigger:* $HHV(IM, 4) > 70$ AND $IM < HHV(IM, 4) - 4$ AND $MA(USDJPY, 2) > MA(USDJPY, 10)$ AND ($DIS > 0$ OR $ROC(SPX, 1, \%) > 2$) AND $USDJPY > Open$.
    * *OR Disparity Divergence Trigger:* $HHV(DIS, 4) > 4$ AND $DIS < HHV(DIS, 4)$ AND $Stoch(5,3)$ crosses above 20.
    * *OR Volatility Breakout Trigger:* $LLV(SDADX, 3) < 0.11$ AND $USDJPY$ crosses above Bollinger Band Top (20, 1.8) AND ($DIS > 0$ OR $DXY > MA(DXY, 20)$).
  * **Long Exit (Sell next day at Close):**
    * *Volatility Stop:* $USDJPY$ crosses below Bollinger Band Bottom (10, 2.5).
    * *OR Regression Divergence Exit:* $LLV(IM, 4) < 30$ AND $IM > LLV(IM, 4)$ AND $MACD() < EMA(MACD(), 7)$.
    * *OR Disparity Exit:* $LLV(DIS, 4) < -4$ AND $DIS > LLV(DIS, 4)$ AND $Stoch(5,3)$ crosses below 80.
  * **Short Entry (Sell Short next day at Close):**
    * *Regression Divergence Trigger:* $LLV(IM, 4) < 30$ AND $IM > LLV(IM, 4) + 4$ AND $MA(USDJPY, 2) < MA(USDJPY, 10)$ AND ($DIS < 0$ OR $ROC(SPX, 1, \%) < -2$) AND $USDJPY < Open$.
    * *OR Disparity Divergence Trigger:* $LLV(DIS, 4) < -4$ AND $DIS > LLV(DIS, 4)$ AND $Stoch(5,3)$ crosses below 80.
    * *OR Volatility Breakout Trigger:* $LLV(SDADX, 3) < 0.11$ AND $USDJPY$ crosses below Bollinger Band Bottom (20, 1.8) AND $DIS < 0$.
  * **Short Exit (Buy to Cover next day at Close):**
    * *Volatility Stop:* $USDJPY$ crosses above Bollinger Band Top (10, 2.5).
    * *OR Regression Divergence Cover:* $HHV(IM, 4) > 70$ AND $IM < HHV(IM, 4)$ AND $MACD() > EMA(MACD(), 9)$.
    * *OR Disparity Cover:* $HHV(DIS, 4) > 4$ AND $DIS < HHV(DIS, 4)$ AND (($USDJPY$ crosses above $MA(USDJPY, 10)$ AND $DXY > MA(DXY, 20)$) OR $Stoch(5,3)$ crosses above 20).

* **Appendix A Code Block:**
  ```metastock
  { Long }
  SEC1:=Security("C:\Metastock Data\REUTERSINDEX\.SPX",C);
  SEC3:=Security("C:\Metastock Data\REUTERSINDEX\.TNX",C);
  SEC2:=Security("C:\Metastock Data\REUTERSINDEX\.DXY",C);
  D1:=200; {REGRESSION DAYS}D2:=15;
  RS1:=ROC(C,D2,%);RS2:=ROC(SEC2,D2,%);
  b:=Correl(RS1,RS2,D1,0)*Stdev(RS1,D1)/(Stdev(RS2,D1)+.001);
  a:=mov(RS1,D1,S)-b*MOV(RS2,D1,S);
  pred:=b*RS2+a;DIVERG:=(PRED-RS1); DIVERG:=Mov(DIVERG,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  SDC:=Stdev(C,15)/Mov(C,15,S);SDADX:=SDC*ADX(15);
  DISY:=(C-Mov(C,10,E))/Mov(C,10,E)*100;
  DIS3:=(SEC3-Mov(SEC3,10,E))/Mov(SEC3,10,E)*100;
  DIS:=MOV((DIS3-DISY),3,E);
  (HHV(IM,4)>70 AND IM<HHV(IM,4)-4 AND MOV(C,2,S) >MOV(C,10,S) AND (DIS>0 OR ROC(SEC1,1,%)>2) AND C> O)
  OR (HHV(DIS,4)>4 and DIS <HHV(DIS,4) AND CROSS(STOCH(5,3),20))
  OR (LLV(SDADX,3)<0.11 AND CROSS(C, BBandTop(C,20,S,1.8)) AND (DIS>0 OR SEC2>MOV(SEC2,20,S)))

  { Sell }
  SEC2:=Security("C:\Metastock Data\REUTERSINDEX\.DXY",C);
  SEC3:=Security("C:\Metastock Data\REUTERSINDEX\.TNX",C);
  D1:=200; {REGRESSION DAYS}D2:=15; {ROC DAYS}
  RS1:=ROC(C,D2,%); RS2:=ROC(SEC2,D2,%);
  b:=Correl(RS1,RS2,D1,0)*Stdev(RS1,D1)/(Stdev(RS2,D1)+.001);
  a:=mov(RS1,D1,S)-b*MOV(RS2,D1,S);
  pred:=b*RS2+a;
  DIVERG1:=(PRED-RS1); DIVERG:=Mov(DIVERG1,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  SDC:=Stdev(C,15)/Mov(C,15,S);SDADX:=SDC*ADX(15);
  DISY:=(C-Mov(C,10,E))/Mov(C,10,E)*100;
  DIS3:=(SEC3-Mov(SEC3,10,E))/Mov(SEC3,10,E)*100;
  DIS:=MOV((DIS3-DISY),3,E);
  MA:=MOV(C,4,E)-MOV(C,4,E)*1.2/100;
  CROSS(BBandBOT(C,10,S,2.5),C)
  OR (LLV(IM,4)<30 and IM >LLV(IM,4) AND MACD()<MOV(MACD(),7,E))
  OR (LLV(DIS,4)<-4 and DIS >LLV(DIS,4) AND CROSS(80,STOCH(5,3))

  { Sell Short }
  SEC1:=Security("C:\Metastock Data\REUTERSINDEX\.SPX",C);
  SEC2:=Security("C:\Metastock Data\REUTERSINDEX\.DXY",C);
  SEC3:=Security("C:\Metastock Data\REUTERSINDEX\.TNX",C);
  D1:=200; D2:=15; RS1:=ROC(C,D2,%); RS2:=ROC(SEC2,D2,%);
  b:=Correl(RS1,RS2,D1,0)*Stdev(RS1,D1)/(Stdev(RS2,D1)+.001);
  a:=mov(RS1,D1,S)-b*MOV(RS2,D1,S);
  pred:=b*RS2+a; DIVERG1:=(PRED-RS1); DIVERG:=Mov(DIVERG1,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  SDC:=Stdev(C,15)/Mov(C,15,S);SDADX:=SDC*ADX(15);
  DISY:=(C-Mov(C,10,E))/Mov(C,10,E)*100;
  DIS3:=(SEC3-Mov(SEC3,10,E))/Mov(SEC3,10,E)*100;
  DIS:=MOV((DIS3-DISY),3,E);
  (LLV(IM,4)<30 and IM >LLV(IM,4)+4 AND MOV(C,2,S)<MOV(C,10,S) AND (DIS<0 OR ROC(SEC1,1,%)<-2) AND C<O)
  OR (LLV(DIS,4)<-4 and DIS >LLV(DIS,4) AND CROSS(80,STOCH(5,3))
  OR (LLV(SDADX,3)<.11 AND CROSS(BBandBOT(C,20,S,1.8),C) AND DIS<0)

  { Buy to Cover }
  SEC2:=Security("C:\Metastock Data\REUTERSINDEX\.DXY",C);
  SEC3:=Security("C:\Metastock Data\REUTERSINDEX\.TNX",C);
  D1:=200; {REGRESSION DAYS}D2:=15; {ROC DAYS}
  RS1:=ROC(C,D2,%); RS2:=ROC(SEC2,D2,%);
  b:=Correl(RS1,RS2,D1,0)*Stdev(RS1,D1)/(Stdev(RS2,D1)+.001);
  a:=mov(RS1,D1,S)-b*MOV(RS2,D1,S);
  pred:=b*RS2+a;
  DIVERG1:=(PRED-RS1); DIVERG:=Mov(DIVERG1,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  SDC:=Stdev(C,15)/Mov(C,15,S);SDADX:=SDC*ADX(15);
  DISY:=(C-Mov(C,10,E))/Mov(C,10,E)*100;DIS3:=(SEC3-Mov(SEC3,10,E))/Mov(SEC3,10,E)*100;
  DIS:=MOV((DIS3-DISY),3,E);
  MA:=REF(MOV(C,4,E),-1)+MOV(C,4,E)*1.2/100;
  CROSS(C, BBandTop(C,10,S,2.5))
  OR (HHV(IM,4)>70 AND IM<HHV(IM,4) AND MACD() >MOV (MACD(),9,E))
  OR (HHV(DIS,4) >4 and DIS <HHV(DIS,4) AND ((CROSS(C,MOV(C,10,S)) AND SEC2>MOV(SEC2,20,S)) or CROSS(STOCH(5,3),20)))
  ```

* **Universe Mapping & Proxy:**
  * Base: `USDJPY` (.DWX FX Pair)
  * Intermarket Partners:
    * `SPX`: Map to `SP500`. (Available).
    * `DXY`: *Not available directly.* Propose a deterministic log-basket proxy using EURUSD, USDJPY, GBPUSD, USDCAD, USDCHF (similar to QM5_12542). (Available).
    * `TNX`: US 10-year Treasury Yield. *Not available.*
* **R3 Verdict:** **R3_FAIL**
  * This system relies directly on US 10-year Treasury yields (`TNX`) to compute the Yen-TNX disparity ($DIS$). There is no deterministic, tradeable proxy for US government bond yields in our allowed symbol set. Therefore, this system is flagged as R3_FAIL.
* **Proposed Card Slug:** `QM5_12547_katsanos-yen-volatility`
* **Expected Trades/Year:** **5.6** (low frequency).

---

### System 17.2: Yen Futures (GLOBEX:6J) Daily Intermarket Volatility System
* **Asset Class:** Forex Futures (JPY/USD)
* **Intermarket Partners:** SPX, TNX, DXY
* **Periodicity:** Daily
* **Parameters:** Same as System 17.1 (inverse correlation adjustment: $DIS = EMA(-DIS3 - DISY, 3)$)

* **Exact Entry/Exit Rules:**
  * Direct inverse of System 17.1. Long signals trigger when USD/JPY falls (i.e. JPY appreciates), and short signals trigger when USD/JPY rises.
  * Uses minus sign in the disparity formula to account for negative correlation with US bond yields (TNX).

* **Appendix A Code Block:**
  ```metastock
  { Long }
  SEC1:=Security("C:\Metastock Data\REUTERSINDEX\.SPX",C);
  SEC2:=Security("C:\Metastock Data\REUTERSINDEX\.DXY",C);
  SEC3:=Security("C:\Metastock Data\REUTERSINDEX\.TNX",C);
  D1:=200; D2:=15; RS1:=ROC(C,D2,%);RS2:=ROC(SEC2,D2,%);
  b:=Correl(RS1,RS2,D1,0)*Stdev(RS1,D1)/(Stdev(RS2,D1)+.001);
  a:=mov(RS1,D1,S)-b*MOV(RS2,D1,S);pred:=b*RS2+a;DIVERG:=MOV((PRED-RS1),3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  SDC:=Stdev(C,15)/Mov(C,15,S);SDADX:=SDC*ADX(15);
  DISY:=(C-Mov(C,10,E))/Mov(C,10,E)*100;
  DIS3:=(SEC3-Mov(SEC3,10,E))/Mov(SEC3,10,E)*100;
  DIS:=MOV((-DIS3-DISY),3,E);
  (HHV(IM,4)>70 AND IM<HHV(IM,4)-4 AND MOV(C,2,S) >MOV(C,10,S) AND (DIS>0 OR ROC(SEC1,1,%)<-2) AND C>O)
  OR (LLV(SDADX,3)<0.11 AND CROSS(C, BBandTop(C,20,S,1.8)) AND DIS>0)
  OR (HHV(DIS,4)>2 and DIS <HHV(DIS,4) AND ALERT(CROSS(STOCH(10,3),20),3) AND STOCH(10,3) >MOV(STOCH(10,3),4,S) AND ROC(SEC2,4,%)<0)

  { Sell }
  SEC2:=Security("C:\Metastock Data\REUTERSINDEX\.DXY",C);
  SEC3:=Security("C:\Metastock Data\REUTERSINDEX\.TNX",C);
  D1:=200; {REGRESSION DAYS}D2:=15; {ROC DAYS}
  RS1:=ROC(C,D2,%); RS2:=ROC(SEC2,D2,%);
  b:=Correl(RS1,RS2,D1,0)*Stdev(RS1,D1)/(Stdev(RS2,D1)+.001);
  a:=mov(RS1,D1,S)-b*MOV(RS2,D1,S);
  pred:=b*RS2+a;
  DIVERG1:=(PRED-RS1); DIVERG:=Mov(DIVERG1,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  SDC:=Stdev(C,15)/Mov(C,15,S);SDADX:=SDC*ADX(15);
  DISY:=(C-Mov(C,10,E))/Mov(C,10,E)*100;
  DIS3:=(SEC3-Mov(SEC3,10,E))/Mov(SEC3,10,E)*100;
  DIS:=MOV((-DIS3-DISY),3,E);
  CROSS(BBandBOT(C,10,S,2.5),C)
  OR (LLV(IM,4)<30 and IM >LLV(IM,4) AND MACD()<MOV(MACD(),9,E))
  OR (LLV(DIS,4)<-2 and DIS>LLV(DIS,4) AND (CROSS(80,STOCH(5,3)) OR SEC2>MOV(SEC2,20,S)))

  { Sell Short }
  SEC1:=Security("C:\Metastock Data\REUTERSINDEX\.SPX",C);
  SEC2:=Security("C:\Metastock Data\REUTERSINDEX\.DXY",C);
  SEC3:=Security("C:\Metastock Data\REUTERSINDEX\.TNX",C);
  D1:=200; D2:=15; RS1:=ROC(C,D2,%); RS2:=ROC(SEC2,D2,%);
  b:=Correl(RS1,RS2,D1,0)*Stdev(RS1,D1)/(Stdev(RS2,D1)+.001);
  a:=mov(RS1,D1,S)-b*MOV(RS2,D1,S);
  pred:=b*RS2+a; DIVERG1:=(PRED-RS1); DIVERG:=Mov(DIVERG1,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  SDC:=Stdev(C,15)/Mov(C,15,S);SDADX:=SDC*ADX(15);
  DISY:=(C-Mov(C,10,E))/Mov(C,10,E)*100;
  DIS3:=(SEC3-Mov(SEC3,10,E))/Mov(SEC3,10,E)*100;
  DIS:=MOV((-DIS3-DISY),3,E);
  (LLV(IM,4)<30 and IM >LLV(IM,4)+4 AND MOV(C,2,S) <MOV(C,10,S) AND (DIS<0 OR ROC(SEC1,1,%)>2) AND C< O)
  OR (LLV(SDADX,3)<.11 AND CROSS(BBandBOT(C,20,S,1.8),C) AND (DIS<0 OR SEC2<MOV(SEC2,20,S)))
  OR (LLV(DIS,4)<-2 and DIS >LLV(DIS,4) AND ALERT(CROSS(80,STOCH(10,3)),3) AND STOCH(10,3) <MOV(STOCH(10,3),4,S) AND ROC(SEC2,4,%)>0)

  { Buy to Cover }
  SEC2:=Security("C:\Metastock Data\REUTERSINDEX\.DXY",C);
  SEC3:=Security("C:\Metastock Data\REUTERSINDEX\.TNX",C);
  D1:=200; {REGRESSION DAYS}D2:=15; {ROC DAYS}
  RS1:=ROC(C,D2,%); RS2:=ROC(SEC2,D2,%);
  b:=Correl(RS1,RS2,D1,0)*Stdev(RS1,D1)/(Stdev(RS2,D1)+.001);
  a:=mov(RS1,D1,S)-b*MOV(RS2,D1,S);
  pred:=b*RS2+a;
  DIVERG1:=(PRED-RS1);
  DIVERG:=Mov(DIVERG1,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S) * 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  SDC:=Stdev(C,15)/Mov(C,15,S);SDADX:=SDC*ADX(15);
  DISY:=(C-Mov(C,10,E))/Mov(C,10,E)*100;
  DIS3:=(SEC3-Mov(SEC3,10,E))/Mov(SEC3,10,E)*100;
  DIS:=MOV((-DIS3-DISY),3,E);
  CROSS(C, BBandTop(C,10,S,2.5))
  OR (HHV(IM,4)>70 AND IM<HHV(IM,4) AND MACD() >MOV (MACD(),7,E))
  OR (HHV(DIS,4) >2 and DIS <HHV(DIS,4) AND CROSS(C,MOV(C,10,S)) AND (CROSS(STOCH(5,3),20) OR SEC2<MOV(SEC2,20,S)))
  ```

* **Universe Mapping & Proxy:**
  * Same mapping as System 17.1 (requires `TNX`).
* **R3 Verdict:** **R3_FAIL**
  * Direct dependency on US 10-year Treasury yields (`TNX`) which are not available in our tradeable universe.
* **Proposed Card Slug:** `QM5_12548_katsanos-jpyfut-volatility`
* **Expected Trades/Year:** **5.6** (low frequency).

---

### System 17.3: Yen (USD/YEN) Daily Intermarket Regression System (Pure Regression)
* **Asset Class:** Forex Spot (USD/JPY)
* **Intermarket Partners:** SPX, TNX, DXY
* **Periodicity:** Daily
* **Parameters:** Same as System 17.1, but:
  * Disparity Period ($OPT1$): 10 days
  * No volatility filter ($SDADX$) or Bollinger Band breakouts are used for entry.

* **Exact Entry/Exit Rules:**
  * **Long Entry:** $HHV(IM, 4) > 65$ AND $IM < HHV(IM, 4) - 10$ AND $Ref(MA(USDJPY, 2), -1) > Ref(MA(USDJPY, 15), -1)$ AND $MA(USDJPY, 2) > MA(USDJPY, 15)$ AND ($DIS > 0$ OR $ROC(SPX, 1, \%) > 1.2$).
  * **Long Exit (Sell):** $LLV(IM, 4) < 30$ AND $IM > LLV(IM, 4)$ AND $MACD() < EMA(MACD(), 9)$, OR $Alert(Cross(80, Stoch(20,3)), 3)$ AND $Stoch(20,3) < 78$ AND $Stoch(20,3) < MA(Stoch(20,3), 4, S)$ AND $LLV(DIS, 2) < 0$ AND $DIS > Ref(DIS, -1)$.
  * **Short Entry (Sell Short):** $LLV(IM, 4) < 30$ AND $IM > LLV(IM, 4) + 10$ AND $Ref(MA(USDJPY, 2), -1) < Ref(MA(USDJPY, 15), -1)$ AND $MA(USDJPY, 2) < MA(USDJPY, 15)$.
  * **Short Exit (Buy to Cover):** $HHV(IM, 4) > 65$ AND $IM < HHV(IM, 4)$ AND $MACD() > EMA(MACD(), 9)$, OR $Alert(Cross(Stoch(20,3), 20), 3)$ AND $Stoch(20,3) > 22$ AND $Stoch(20,3) > MA(Stoch(20,3), 4, S)$ AND $HHV(DIS, 2) > 0$ AND $DIS < Ref(DIS, -1)$.

* **Appendix A Code Block:**
  ```metastock
  { Long }
  SEC1:=Security("C:\Metastock Data\REUTERSINDEX\.SPX",C);
  SEC3:=Security("C:\Metastock Data\REUTERSINDEX\.TNX",C);
  SEC2:=Security("C:\Metastock Data\REUTERSINDEX\.DXY",C);
  D1:=200; {REGERSSION DAYS}D2:=15; {ROC DAYS}
  RS1:=ROC(C,D2,%);RS2:=ROC(SEC2,D2,%);
  b:=Correl(RS1,RS2,D1,0)*Stdev(RS1,D1)/(Stdev(RS2,D1)+.001);
  a:=mov(RS1,D1,S)-b*MOV(RS2,D1,S);
  pred:=b*RS2+a;DIVERG:=(PRED-RS1); DIVERG:=Mov(DIVERG,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  SDC:=Stdev(C,15)/Mov(C,15,S);SDADX:=SDC*ADX(15);
  DISY:=(C-Mov(C,OPT1,E))/Mov(C,OPT1,E)*100;
  DIS3:=(SEC3-Mov(SEC3,OPT1,E))/Mov(SEC3,OPT1,E)*100;
  DIS:=MOV((DIS3-DISY),3,E);
  HHV(IM,4)>65 AND IM<HHV(IM,4)-10 AND REF(MOV(C,2,S),-1)>REF(MOV(C,15,S),-1) AND MOV(C,2,S)>MOV(C,15,S) AND (DIS>0 OR roc(sec1,1,%)>1.2)

  { Sell }
  SEC3:=Security("C:\Metastock Data\REUTERSINDEX\.TNX",C);
  SEC2:=Security("C:\Metastock Data\REUTERSINDEX\.DXY",C);
  D1:=200; {REGRESSION DAYS}D2:=15; {ROC DAYS}
  RS1:=ROC(C,D2,%); RS2:=ROC(SEC2,D2,%);
  b:=Correl(RS1,RS2,D1,0)*Stdev(RS1,D1)/(Stdev(RS2,D1)+.001);
  a:=mov(RS1,D1,S)-b*MOV(RS2,D1,S);
  pred:=b*RS2+a;
  DIVERG1:=(PRED-RS1); DIVERG:=Mov(DIVERG1,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  DISY:=(C-Mov(C,OPT1,E))/Mov(C,OPT1,E)*100;
  DIS3:=(SEC3-Mov(SEC3,OPT1,E))/Mov(SEC3,OPT1,E)*100;
  DIS:=MOV((DIS3-DISY),3,E);
  (LLV(IM,4)<30 and IM >LLV(IM,4) AND MACD()<MOV(MACD(),9,E)) OR (ALERT(CROSS(80,STOCH(20,3)),3) AND STOCH(20,3) <78 AND STOCH(20,3)<mov(STOCH(20,3),4,S) AND LLV(DIS,2)<0 AND DIS>REF(DIS,-1))

  { Sell Short }
  SEC3:=Security("C:\Metastock Data\REUTERSINDEX\.TNX",C);
  SEC2:=Security("C:\Metastock Data\REUTERSINDEX\.DXY",C);
  D1:=200; {REGERSSION DAYS} D2:=15; {ROC DAYS}
  RS1:=ROC(C,D2,%); RS2:=ROC(SEC2,D2,%);
  b:=Correl(RS1,RS2,D1,0)*Stdev(RS1,D1)/(Stdev(RS2,D1)+.001);
  a:=mov(RS1,D1,S)-b*MOV(RS2,D1,S);
  pred:=b*RS2+a; DIVERG1:=(PRED-RS1); DIVERG:=Mov(DIVERG1,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  SDC:=Stdev(C,15)/Mov(C,15,S);SDADX:=SDC*ADX(15);
  DISY:=(C-Mov(C,OPT1,E))/Mov(C,OPT1,E)*100;
  DIS3:=(SEC3-Mov(SEC3,OPT1,E))/Mov(SEC3,OPT1,E)*100;
  DIS:=MOV((DIS3-DISY),3,E);
  (LLV(IM,4)<30 and IM >LLV(IM,4)+10 AND REF(MOV(C,2,S),-1)<REF(MOV(C,15,S),-1) AND MOV(C,2,S)<MOV(C,15,S))

  { Buy to Cover }
  SEC3:=Security("C:\Metastock Data\REUTERSINDEX\.TNX",C);
  SEC2:=Security("C:\Metastock Data\REUTERSINDEX\.DXY",C);
  D1:=200; {REGERSSION DAYS}D2:=15; {ROC DAYS}
  RS1:=ROC(C,D2,%); RS2:=ROC(SEC2,D2,%);
  b:=Correl(RS1,RS2,D1,0)*Stdev(RS1,D1)/(Stdev(RS2,D1)+.001);
  a:=mov(RS1,D1,S)-b*MOV(RS2,D1,S);
  pred:=b*RS2+a;DIVERG1:=(PRED-RS1);DIVERG:=Mov(DIVERG1,3,E);
  IM:=(Mov(DIVERG - LLV(DIVERG,200), 3,S)* 100)/(Mov(HHV(DIVERG,200) - LLV(DIVERG,200), 3,S));
  DISY:=(C-Mov(C,OPT1,E))/Mov(C,OPT1,E)*100;
  DIS3:=(SEC3-Mov(SEC3,OPT1,E))/Mov(SEC3,OPT1,E)*100;
  DIS:=MOV((DIS3-DISY),3,E);
  (HHV(IM,4)>65 AND IM<HHV(IM,4) AND MACD()>MOV(MACD(),9,E)) OR (ALERT(CROSS(STOCH(20,3),20),3) AND STOCH(20,3)>22 AND STOCH(20,3)>mov(STOCH(20,3),4,S) and HHV(DIS,2)>0 AND DIS<REF(DIS,-1))
  ```

* **Universe Mapping & Proxy:** Same as System 17.1 (requires `TNX`).
* **R3 Verdict:** **R3_FAIL**
  * Direct dependency on US 10-year Treasury yields (`TNX`) which are not available in our tradeable universe.
* **Proposed Card Slug:** `QM5_12549_katsanos-yen-regression`
* **Expected Trades/Year:** **4.0** (low frequency).

---

### System 17.4: Euro (EURO/USD) Daily MA-Intermarket System
* **Asset Class:** Forex Spot (EUR/USD)
* **Intermarket Partners:** CRB Index (Commodities), 10-year Treasury Yield (TNX)
* **Periodicity:** Daily
* **Parameters:**
  * Fast MA ($MA$): 10 days
  * Volatility filter ($FILT$): 20-day standard deviation of daily log returns of 10-day MA: $PC = Log(\frac{MA(C, 10)}{Ref(MA(C, 10), -1)})$, $FILT = Stdev(PC, 20)$.
  * Congestion Index ($CI$): 39 days (smoothed with 7-period EMA)
  * Commodities Filter: 35-day moving average of CRB index
  * Yields Filter: 5-day moving average of TNX
  * Exit Stop: Parabolic SAR ($AF = 0.04$, Max $= 0.10$)

* **Exact Entry/Exit Rules:**
  * **Long Entry (Buy next day at Close):**
    * $MA(EURUSD, 10) > LLV(MA(EURUSD, 10), 3) + 0.7 \times FILT$ AND $EURUSD > SAR(0.04, 0.1)$ AND $CRB > MA(CRB, 35)$ AND $TNX < MA(TNX, 5)$ AND $ABS(CI) > 40$ AND $CI > LLV(CI, 3) + 3$.
  * **Long Exit (Sell next day at Close):**
    * $EURUSD < SAR(0.04, 0.1)$.
  * **Short Entry (Sell Short next day at Close):**
    * $MA(EURUSD, 10) < HHV(MA(EURUSD, 10), 3) - 0.7 \times FILT$ AND $EURUSD < SAR(0.04, 0.1)$ AND $CRB < MA(CRB, 35)$ AND $TNX > MA(TNX, 5)$ AND $ABS(CI) > 40$ AND $CI < HHV(CI, 3) - 3$.
  * **Short Exit (Buy to Cover next day at Close):**
    * $EURUSD > SAR(0.04, 0.1)$.

* **Appendix A Code Block:**
  ```metastock
  { Long }
  SEC1:=Security("C:\Metastock Data\REUTERSINDEX\.CRB",C);
  SEC3:=Security("C:\Metastock Data\REUTERSINDEX\.TNX",C);
  PC:=Log(MOV(C,10,S)/Ref(MOV(C,10,S),-1));
  FILT:=Stdev(PC,20);
  CI:=ROC(C,40-1,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  CI:=Mov(CI,7,E);
  MOV(C,10,S)>LLV(MOV(C,10,S),3)+.7*FILT AND C> SAR(.04,.1) AND SEC1>MOV(SEC1,35,S) AND SEC3<MOV(SEC3,5,S) AND ABS(CI)>40 AND CI>LLV(CI,3)+3

  { Sell }
  C<SAR(.04,.1)

  { Sell Short }
  SEC1:=Security("C:\Metastock Data\REUTERSINDEX\.CRB",C);
  SEC3:=Security("C:\Metastock Data\REUTERSINDEX\.TNX",C);
  PC:=Log(MOV(C,10,S)/Ref(MOV(C,10,S),-1));
  FILT:=Stdev(PC,20);
  CI:=ROC(C,40-1,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  CI:=Mov(CI,7,E);
  MOV(C,10,S)<HHV(MOV(C,10,S),3)-.7*FILT AND C<SAR(.04,.1) AND (SEC1<MOV(SEC1,35,S) AND SEC3>MOV(SEC3,5,S)) AND ABS(CI)>40 AND CI<HHV(CI,3)-3

  { Buy to Cover }
  C>SAR(.04,.1)
  ```

* **Universe Mapping & Proxy:**
  * Base: `EURUSD` (.DWX FX Pair)
  * Intermarket Partners:
    * `CRB`: Commodity Research Bureau Index. *Not available.*
    * `TNX`: US 10-year Treasury Yield. *Not available.*
* **R3 Verdict:** **R3_FAIL**
  * Direct dependency on two unavailable datasets (`CRB` and `TNX`). There are no deterministic, tradeable proxies in our universe that can adequately replace these macro variables.
* **Proposed Card Slug:** `QM5_12550_katsanos-euro-ma-intermarket`
* **Expected Trades/Year:** **7.6** (infrequent).

---

## 6. Summary Matrix of Card Proposals

| System Name | Base Symbol | Intermarket Partner(s) | Proxy Used | Expected Trades/Year | R3 Verdict | Proposed Card Slug |
|---|---|---|---|---|---|---|
| **DAX Disparity** | `GDAXI` | CAC 40 Futures | `UK100` | 5.8 | **PASS** | `QM5_12543_katsanos-dax-disparity` |
| **DAX MACross** | `GDAXI` | None | None | 13.5 | **PASS** | `QM5_12544_katsanos-dax-macross` |
| **DAX MACross Enhanced** | `GDAXI` | EuroStoxx 50 Futures | `UK100` | 6.9 | **PASS** | `QM5_12545_katsanos-dax-macross-enhanced` |
| **DAX Component Stocks** | 10 Stocks | CAC 40 Futures | None | 29.4 (total) | **FAIL** (No Stocks) | `QM5_12546_katsanos-dax-stocks-disparity` |
| **Yen Volatility** | `USDJPY` | SPX, TNX, DXY | DXY Basket | 5.6 | **FAIL** (No TNX) | `QM5_12547_katsanos-yen-volatility` |
| **JPY Futures Volatility** | JPY Futures | SPX, TNX, DXY | DXY Basket | 5.6 | **FAIL** (No TNX) | `QM5_12548_katsanos-jpyfut-volatility` |
| **Yen Regression** | `USDJPY` | SPX, TNX, DXY | DXY Basket | 4.0 | **FAIL** (No TNX) | `QM5_12549_katsanos-yen-regression` |
| **Euro MA-Intermarket** | `EURUSD` | CRB, TNX | None | 7.6 | **FAIL** (No TNX/CRB) | `QM5_12550_katsanos-euro-ma-intermarket` |

---

## 7. Next Steps for Codex Review

1. **Card Screen:** Propose only the three passing DAX-based cards (`QM5_12543`, `QM5_12544`, `QM5_12545`) for backtesting.
2. **Proxy Validation:** Ensure that using `UK100` instead of CAC 40 or EuroStoxx 50 does not introduce regime-dependent slippage or mismatch.
3. **Out-of-Sample Verification:** Backtest the passing cards strictly from 2008 to 2026. This out-of-sample period is required to address the in-sample optimization bias (book p. 179).
4. **Frequency Mitigation:** Because these systems trade less than 15 times per year, they cannot be deployed as standalone EAs on FTMO targets. They must be packaged as a diversified portfolio engine.
