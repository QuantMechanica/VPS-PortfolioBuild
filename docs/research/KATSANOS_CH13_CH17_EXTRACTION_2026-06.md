# Katsanos Book Mining: Ch.13 DAX & Ch.17 Forex Systems

**Audit date:** 2026-07-23

**Status:** APPROVED — source-audited research accepted; two Strategy Card
Drafts await a separate OWNER G0 decision

**Task:** `f96d0a4f-a0d0-4ece-8bab-47660ccb0df5`

**Extraction:** agy; **source and universe audit:** Codex

**Follow-up artifacts:** canonical
[`source.md`](../../strategy-seeds/sources/KATSANOS-INTERMARKET-2008/source.md);
Draft Cards
[`kats-dax-maci_card.md`](../../strategy-seeds/cards/kats-dax-maci_card.md)
and
[`kats-eu-macisar_card.md`](../../strategy-seeds/cards/kats-eu-macisar_card.md)

**Source:** Markos Katsanos, *Intermarket Trading Strategies* (Wiley, 2008), OWNER-declared licensed copy

**Evidence cache:** `D:/QM/strategy_farm/source_cache/katsanos_intermarket_2008.txt`

**Page map in the reviewed sections:** `PDFPAGE = printed book page + 18`

---

## 1. Overview & Operating Guidelines

This document inventories and audits the conventional mechanical systems in:

- **Chapter 13:** Trading DAX Futures (book p. 201+)
- **Chapter 17:** Forex Trading Using Intermarket Analysis (book p. 261+, Yen & Euro systems)

Neural systems in Chapter 14 and Appendix B are outside scope. Buy-and-hold columns are benchmarks, not recurring timing systems. The Australian-dollar section contains observations and correlation studies, but no rule-complete trading system.

Universe checks below use `framework/registry/dwx_symbol_matrix.csv` and
`framework/registry/dwx_symbol_history_ranges.csv` as of 2026-07-23. Relevant
available series are `GDAXI.DWX`, `SP500.DWX`, `UK100.DWX`, `EURUSD.DWX`,
`USDJPY.DWX`, the other `.DWX` FX pairs, and the existing commodity/equity
index set. CAC/FCE, Euro Stoxx/FESX, TNX, CRB, DXY, Nikkei/6J futures, and the
ten DAX component stocks are absent. A proposed substitute does not turn the
source system into an R3 pass; it creates a different, unvalidated research
variant.

Notation follows MetaStock. In particular, the source's bare `MACD()` is the
platform 12-EMA minus 26-EMA definition; any explicitly printed 7- or 9-bar
EMA is the separate signal comparison. [Glossary book pp. 375 and 381 /
PDFPAGE 393 and 399]

---

## 2. Honest sample and optimization caveat

Book p. 179 / PDFPAGE 197 belongs to the Chapter 11 gold comparison and must
not be applied as a blanket statement to Chapters 13 and 17.

- Chapter 13 describes development/optimization on DAX index history and a
  final 2004–2007 continuous-FDAX segment as out of sample. Partner selection,
  long/short optimization, and rule-combination search still introduce
  selection bias. The final sample is short and strongly bullish. The later
  1999–2007 index comparison overlaps development-era history and is a regime
  stress comparison, not untouched future evidence. See book pp. 201–213 /
  PDFPAGE 219–231.
- The Chapter 17 USD/JPY tests use 2001–2007 as the reported out-of-sample
  segment after an earlier development segment, with the SPX clause adjusted
  later. The EUR/USD comparison reserves 2003-01-22 through 2008-01-21 as
  out of sample. These are better than full-sample optimization, but the
  samples and trade counts remain small and the author calls for periodic
  correlation re-evaluation. See book pp. 271–285 / PDFPAGE 289–303.

All performance figures below are historical source results, not forecasts.
Any proxy substitution invalidates direct comparison with those figures.

---

## 3. Trade-frequency screen

The frequency field is derived from the source trade count divided by its test
years; it is not a forward estimate. The current Q02 floor is at least five
trades/year/symbol.

- FDAX disparity: 22 trades / about 3.8 years = **5.8/year**.
- DAX-index disparity comparison: 49 / about 8.8 = **5.5/year**.
- Classic DAX MA/CI/stochastic: 51 / about 3.8 = **13.5/year**.
- Enhanced DAX MA: 26 / about 3.8 = **6.9/year**.
- Ten-stock portfolio: 116 / about 3.9 = **29.4/year in aggregate**, only
  about **2.9/year/stock**.
- Pure USD/JPY regression: 28 / 7 = **4.0/year**, below the floor.
- Combined USD/JPY system: 39 / 7 = **5.6/year**.
- Classic EUR/USD MA/CI/SAR: 62 / 5 = **12.4/year**.
- Enhanced EUR/USD system: 38 / 5 = **7.6/year**.
- The 6J inverse variant has no reported full test or trade count; its source
  frequency is **unknown**.

---

## 4. Chapter 13: DAX Futures Systems

### System 13.1: DAX Daily Disparity System

**Evidence:** book pp. 201–209 / PDFPAGE 219–227; results Table 13.1,
book pp. 206–207 / PDFPAGE 224–225; Appendix A.4 book pp. 327–329 /
PDFPAGE 345–347.

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
  * Protective Stop: none in the Chapter 13 FDAX system

  The nearby `1.6 * ATR(8)` line belongs to the preceding Chapter 12 code,
  before the Appendix A.4 heading. It is not part of this system. Only the
  later ten-stock adaptation adds an ATR-based exit. [Appendix book
  pp. 326–327 / PDFPAGE 344–345]

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
  * **Time exit:** close either direction after 80 trading bars if no signal
    exit fires. There is no printed FDAX protective-price or ATR stop.

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
  * Base: `GDAXI.DWX` (German DAX Index).
  * Intermarket Partner: CAC 40 Futures (`FCE` or `^FCHI`). *CAC 40 is not available.*
  * **Proxy research variant:** `UK100.DWX` is the closest currently available
    European-index candidate; `SP500.DWX` is a second candidate. Neither has
    yet been validated as a deterministic replacement for CAC/FCE.
* **R3 Verdict:** **R3_FAIL_AS_WRITTEN** (missing CAC/FCE).
  A `UK100.DWX` substitution is `PROXY_RESEARCH_ONLY`, not a pass.
* **Proposed Slugs:** source-faithful `katsanos-dax-disparity-d1`;
  proxy experiment `katsanos-dax-disparity-uk100-proxy-d1`.
  No EA ID is allocated and no card is created.
* **Expected Trades/Year:** **5.8** (extremely low frequency).

---

### System 13.2: DAX MACrossoverSystem (Standard)

**Evidence:** book pp. 209–213 / PDFPAGE 227–231; results Table 13.2,
book p. 210 / PDFPAGE 228; Appendix A.4 book p. 329 / PDFPAGE 347.

* **Asset Class:** Equity Index Futures (DAX)
* **Intermarket Partner:** None (explores standard indicators with trend/congestion switching)
* **Periodicity:** Daily
* **Parameters:**
  * Fast MA ($MA1$): 15 days (Long), 10 days (Short)
  * Slow MA ($MA2$): 20 days (Long & Short)
  * Long-Term Trend Filter: 150 days
  * Congestion Index ($CI$): 39 days (40-period HHV/LLV)
  * Stochastic periods: 5 days (trigger), 40 days (congestion filter)
  * Time Exit: 60 trading days
  * Protective Stop: none printed

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
  * **Time exit:** close either direction after 60 trading bars. No
    protective-price or ATR stop is printed.

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
  * Base: `GDAXI.DWX` (DAX).
  * Intermarket Partner: None.
* **R3 Verdict:** **R3_PASS_AS_WRITTEN**
  * Straightforward moving average/stochastic system with no dependencies on external datasets.
* **Proposed Slug:** `katsanos-dax-ma-ci-stoch-d1`.
  No EA ID is allocated and no card is created.
* **Expected Trades/Year:** **13.5** (higher frequency trend/congestion switcher).

---

### System 13.3: DAX Intermarket Enhanced MA Crossover System

**Evidence:** book pp. 209–213 / PDFPAGE 227–231; results Table 13.2,
book p. 210 / PDFPAGE 228; Appendix A.4 book pp. 329–331 /
PDFPAGE 347–349.

* **Asset Class:** Equity Index Futures (DAX)
* **Intermarket Partner:** EuroStoxx 50 Futures (FESX)
* **Periodicity:** Daily
* **Parameters:** Same as System 13.2, plus:
  * Disparity Period ($D1$): 10 days
  * Divergence ($DIV2$): $DIS2 - DIS1$ (EuroStoxx Disparity - DAX Disparity)
  * Time Exit: 60 trading days
  * Protective Stop: none printed

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
  * **Time exit:** the same 60-bar exit as System 13.2; no protective-price
    or ATR stop is printed.

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
  * Base: `GDAXI.DWX` (DAX).
  * Intermarket Partner: EuroStoxx 50 Futures (`STXEc1` or `FESX`). *EuroStoxx is not available.*
  * **Proxy research variant:** `UK100.DWX`; `SP500.DWX` is a secondary
    candidate. The source performance does not transfer to either substitute.
* **R3 Verdict:** **R3_FAIL_AS_WRITTEN** (missing Euro Stoxx/FESX).
  A proxy substitution remains `PROXY_RESEARCH_ONLY`.
* **Proposed Slugs:** source-faithful `katsanos-dax-ma-intermarket-d1`;
  proxy experiment `katsanos-dax-ma-intermarket-uk100-proxy-d1`.
  No EA ID is allocated and no card is created.
* **Expected Trades/Year:** **6.9** (infrequent).

---

### System 13.4: DAX Component Stock Disparity System

**Evidence:** book pp. 202–203 and 209–211 / PDFPAGE 220–221 and 227–229;
results Table 13.2, book p. 210 / PDFPAGE 228; Appendix A.4
book pp. 331–332 / PDFPAGE 349–350.

* **Asset Class:** Equities (DAX Component Stocks)
* **Intermarket Partner:** CAC 40 Futures (FCE)
* **Periodicity:** Daily
* **Parameters:** Same as System 13.1 (Long only), plus:
  * Time Stop: 50 trading days
  * Trailing Stop: `STOP = HHV(C, 3) - 2.2 * ATR(10)`

* **Exact Entry/Exit Rules:**
  * **Long Entry:** Same as System 13.1 Long conditions.
  * **Long Exit:** Same as System 13.1 Sell conditions, OR
    `Cross(STOP,L)`, OR the 50-bar time exit. In the printed TradeSim setup
    every exit is delayed one bar and filled at the next open; the ATR
    expression is therefore an exit trigger, not an intraday fill at `STOP`.

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
  * We hold no individual German equity stock symbols (only index
    `GDAXI.DWX` is available). The source portfolio cannot run in the current
    universe.
* **Proposed Slug:** none. This portfolio is not a current-universe card lead.
* **Expected Trades/Year:** **29.4** across a 10-stock portfolio
  (~2.9 trades/year per stock), hence `Q02_BELOW_FLOOR` on the required
  per-symbol basis.

---

## 5. Chapter 17: Forex Systems (Yen & Euro)

### System 17.1: Yen (USD/YEN) Daily Intermarket Volatility System

**Evidence:** book pp. 269–277 / PDFPAGE 287–295; results Tables 17.2–17.4,
book pp. 274–276 / PDFPAGE 292–294; Appendix A.8 book pp. 348–350 /
PDFPAGE 366–368.

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
  * **Long Entry:**
    * *Regression Divergence Trigger:* $HHV(IM, 4) > 70$ AND $IM < HHV(IM, 4) - 4$ AND $MA(USDJPY, 2) > MA(USDJPY, 10)$ AND ($DIS > 0$ OR $ROC(SPX, 1, \%) > 2$) AND $USDJPY > Open$.
    * *OR Disparity Divergence Trigger:* $HHV(DIS, 4) > 4$ AND $DIS < HHV(DIS, 4)$ AND $Stoch(5,3)$ crosses above 20.
    * *OR Volatility Breakout Trigger:* $LLV(SDADX, 3) < 0.11$ AND $USDJPY$ crosses above Bollinger Band Top (20, 1.8) AND ($DIS > 0$ OR $DXY > MA(DXY, 20)$).
  * **Long Exit:**
    * *Volatility Stop:* $USDJPY$ crosses below Bollinger Band Bottom (10, 2.5).
    * *OR Regression Divergence Exit:* $LLV(IM, 4) < 30$ AND $IM > LLV(IM, 4)$ AND $MACD() < EMA(MACD(), 7)$.
    * *OR Disparity Exit:* $LLV(DIS, 4) < -4$ AND $DIS > LLV(DIS, 4)$ AND $Stoch(5,3)$ crosses below 80.
  * **Short Entry:**
    * *Regression Divergence Trigger:* $LLV(IM, 4) < 30$ AND $IM > LLV(IM, 4) + 4$ AND $MA(USDJPY, 2) < MA(USDJPY, 10)$ AND ($DIS < 0$ OR $ROC(SPX, 1, \%) < -2$) AND $USDJPY < Open$.
    * *OR Disparity Divergence Trigger:* $LLV(DIS, 4) < -4$ AND $DIS > LLV(DIS, 4)$ AND $Stoch(5,3)$ crosses below 80.
    * *OR Volatility Breakout Trigger:* $LLV(SDADX, 3) < 0.11$ AND $USDJPY$ crosses below Bollinger Band Bottom (20, 1.8) AND $DIS < 0$.
  * **Short Exit:**
    * *Volatility Stop:* $USDJPY$ crosses above Bollinger Band Top (10, 2.5).
    * *OR Regression Divergence Cover:* $HHV(IM, 4) > 70$ AND $IM < HHV(IM, 4)$ AND $MACD() > EMA(MACD(), 9)$.
    * *OR Disparity Cover:* $HHV(DIS, 4) > 4$ AND $DIS < HHV(DIS, 4)$ AND (($USDJPY$ crosses above $MA(USDJPY, 10)$ AND $DXY > MA(DXY, 20)$) OR $Stoch(5,3)$ crosses above 20).

  **Execution conflict:** Chapter 17 says signals were executed the same day at
  the close (book p. 271 / PDFPAGE 289), while Appendix A.8 instructs the
  tester to use the open (book p. 348 / PDFPAGE 366). The source does not
  specify a next-bar delay. G0 must freeze one convention before reproduction.

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
  OR (LLV(DIS,4)<-4 and DIS >LLV(DIS,4) AND CROSS(80,STOCH(5,3)))

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
  OR (LLV(DIS,4)<-4 and DIS >LLV(DIS,4) AND CROSS(80,STOCH(5,3)))
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
  * Base: `USDJPY.DWX`
  * Intermarket Partners:
    * `SPX`: map to `SP500.DWX` (available for backtesting).
    * `DXY`: no direct series. The existing weighted FX log-basket is
      constructible but remains `PROXY_RESEARCH_ONLY`; common component history
      is shorter than the individual EURUSD/USDJPY ranges.
    * `TNX`: US 10-year Treasury Yield. *Not available.*
* **R3 Verdict:** **R3_FAIL**
  * This system relies directly on US 10-year Treasury yields (`TNX`) to compute the Yen-TNX disparity ($DIS$). There is no deterministic, tradeable proxy for US government bond yields in our allowed symbol set. Therefore, this system is flagged as R3_FAIL.
* **Proposed Slug:** `katsanos-usdjpy-regdiv-volbreak-d1`.
  No EA ID is allocated and no card is created.
* **Expected Trades/Year:** **5.6** (low frequency).

---

### System 17.2: Yen Futures (GLOBEX:6J) Daily Intermarket Volatility System

**Evidence:** book pp. 268–274 / PDFPAGE 286–292; Appendix A.8
book pp. 350–352 / PDFPAGE 368–370.

* **Asset Class:** Forex Futures (JPY/USD)
* **Intermarket Partners:** SPX, TNX, DXY
* **Periodicity:** Daily
* **Parameters:** Same core 200-bar regression/IMO and 15-bar volatility
  definitions as System 17.1, with Appendix-specific inverse rules:
  `DIS = EMA(-DIS3 - DISY,3)`, disparity thresholds ±2, 10-bar stochastic
  branches with three-bar alerts, and altered MACD/DXY/SPX gates.

* **Exact Entry/Exit Rules:**
  * Structurally inverted from System 17.1 for the YEN/USD quotation, but not a
    literal Boolean inverse: Appendix A.8 changes the disparity thresholds to
    ±2, uses 10-bar stochastic branches with three-bar alerts, and changes
    several DXY/SPX signs and alternatives.
  * Uses a minus sign in the disparity formula to account for the inverse
    relationship with TNX.

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
  * The source trades full-size GLOBEX 6J, which is absent. `USDJPY.DWX`
    provides an inverse spot orientation but does not remove the TNX dependency.
* **R3 Verdict:** **R3_FAIL**
  * Missing 6J and TNX; a spot inversion would be a materially different test.
* **Proposed Slug:** none; the 6J version duplicates the combined yen concept
  in inverse quotation.
* **Expected Trades/Year:** **unknown**. The author reports only limited
  testing and publishes no complete 6J result or trade count (book pp. 273–274 /
  PDFPAGE 291–292).

---

### System 17.3: Yen (USD/YEN) Daily Intermarket Regression System (Pure Regression)

**Evidence:** book pp. 271 and 274–276 / PDFPAGE 289 and 292–294;
Appendix A.8 book pp. 352–355 / PDFPAGE 370–373.

* **Asset Class:** Forex Spot (USD/JPY)
* **Intermarket Partners:** SPX, TNX, DXY
* **Periodicity:** Daily
* **Parameters:** shares System 17.1's 15-bar ROC, 200-bar regression/IMO, and
  3-bar divergence smoothing, but uses different signal parameters: IMO
  upper/retreat `65/10`, MA state checks `2/15` on both prior and current bars,
  and 20-bar stochastic exits.
  * Disparity Period (`OPT1`): **undefined in Appendix A.8**. Table 17.2
    reports 10 days, so `OPT1=10` is an inference, not self-contained source
    code (book p. 276 / PDFPAGE 294; Appendix pp. 352–355 /
    PDFPAGE 370–373).
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

* **Execution:** the same Chapter-close versus Appendix-open conflict applies.
* **Universe Mapping & Proxy:** `USDJPY.DWX` exists; `SP500.DWX` exists; a
  deterministic DXY log-basket can be calculated from available FX pairs, but
  TNX is absent.
* **R3 Verdict:** **R3_FAIL**
  * Direct dependency on US 10-year Treasury yields (`TNX`) which are not available in our tradeable universe.
* **Proposed Slug:** `katsanos-usdjpy-regression-d1`.
  No EA ID is allocated and no card is created.
* **Expected Trades/Year:** **4.0**, below the current Q02 floor even before
  the missing-partner failure.

---

### System 17.4: EUR/USD Conventional MA/CI/SAR System

**Evidence:** book pp. 279–285 / PDFPAGE 297–303; results Table 17.6,
book pp. 284–285 / PDFPAGE 302–303; shared Appendix A.8 implementation,
book p. 355 / PDFPAGE 373.

This is the separately reported pre-intermarket comparator in Table 17.6, not
buy-and-hold. It uses only EUR/USD daily OHLC and therefore belongs in the
conventional-system inventory. The Appendix does not print it as a separate
four-formula block; it is the Appendix euro implementation with the CRB/TNX
clauses removed. [book pp. 279–285 / PDFPAGE 297–303; Appendix p. 355 /
PDFPAGE 373]

* **Parameters:**
  * `MA = SMA(C,10)`
  * `FILT = Stdev(Log(MA / Ref(MA,-1)),20)`
  * `CIraw = ROC(C,39,%) / (((HHV(H,40)-LLV(L,40)) /
    (LLV(L,40)+0.01))+0.000001)`; `CI = EMA(CIraw,7)`
  * Parabolic SAR: step `0.04`, maximum `0.10`
* **Long entry:** `MA > LLV(MA,3) + 0.7*FILT`, `C > SAR`,
  `ABS(CI) > 40`, and `CI > LLV(CI,3) + 3`.
* **Long exit:** `C < SAR(0.04,0.10)`.
* **Short entry:** `MA < HHV(MA,3) - 0.7*FILT`, `C < SAR`,
  `ABS(CI) > 40`, and `CI < HHV(CI,3) - 3`.
* **Short exit:** `C > SAR(0.04,0.10)`.

* **Appendix-derived code block:**

  ```metastock
  PC:=Log(Mov(C,10,S)/Ref(Mov(C,10,S),-1));
  FILT:=Stdev(PC,20);
  CI:=ROC(C,39,%)/((HHV(H,40)-LLV(L,40))/(LLV(L,40)+.01)+.000001);
  CI:=Mov(CI,7,E);

  { Long }
  Mov(C,10,S)>LLV(Mov(C,10,S),3)+.7*FILT
  AND C>SAR(.04,.1) AND ABS(CI)>40 AND CI>LLV(CI,3)+3
  { Sell } C<SAR(.04,.1)

  { Sell Short }
  Mov(C,10,S)<HHV(Mov(C,10,S),3)-.7*FILT
  AND C<SAR(.04,.1) AND ABS(CI)>40 AND CI<HHV(CI,3)-3
  { Buy to Cover } C>SAR(.04,.1)
  ```

* **Material source conflict:** equations 17.2 and 17.5 print
  `ABS(CI) < 40`, while the executable Appendix block uses `ABS(CI) > 40`.
  The prose about filtering trendless periods supports `>40`, but the source
  never explicitly corrects the equations. Both published interpretations
  must be retained until G0 freezes one. [book pp. 279, 281 /
  PDFPAGE 297, 299; Appendix p. 355 / PDFPAGE 373]
* **Execution:** same-day close as stated for the euro test in Chapter 17.
  Appendix p. 355 specifies units and commission but does not override the
  execution price.
* **Universe Mapping:** base `EURUSD.DWX`; no external partner.
* **R3 Verdict:** **R3_PASS_AS_WRITTEN** on symbol availability, but
  **SPEC_UNRESOLVED** because of the CI inequality.
* **Proposed Slug:** `katsanos-eurusd-ma-ci-sar-d1`.
  No EA ID is allocated and no card is created.
* **Expected Trades/Year:** **12.4** (62 trades in the five-year reported
  out-of-sample segment).

---

### System 17.5: Euro (EUR/USD) Daily MA-Intermarket System

**Evidence:** book pp. 279–285 / PDFPAGE 297–303; results Table 17.6,
book pp. 284–285 / PDFPAGE 302–303; Appendix A.8 book p. 355 /
PDFPAGE 373.

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
  * **Long Entry:**
    * $MA(EURUSD, 10) > LLV(MA(EURUSD, 10), 3) + 0.7 \times FILT$ AND $EURUSD > SAR(0.04, 0.1)$ AND $CRB > MA(CRB, 35)$ AND $TNX < MA(TNX, 5)$ AND $ABS(CI) > 40$ AND $CI > LLV(CI, 3) + 3$.
  * **Long Exit:**
    * $EURUSD < SAR(0.04, 0.1)$.
  * **Short Entry:**
    * $MA(EURUSD, 10) < HHV(MA(EURUSD, 10), 3) - 0.7 \times FILT$ AND $EURUSD < SAR(0.04, 0.1)$ AND $CRB < MA(CRB, 35)$ AND $TNX > MA(TNX, 5)$ AND $ABS(CI) > 40$ AND $CI < HHV(CI, 3) - 3$.
  * **Short Exit:**
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
  * Base: `EURUSD.DWX`
  * Intermarket Partners:
    * `CRB`: Commodity Research Bureau Index. *Not available.*
    * `TNX`: US 10-year Treasury Yield. *Not available.*
* **R3 Verdict:** **R3_FAIL**
  * Direct dependency on two unavailable datasets (`CRB` and `TNX`). There are no deterministic, tradeable proxies in our universe that can adequately replace these macro variables.
* **Additional specification conflict:** equations 17.2/17.5 use
  `ABS(CI)<40`; Appendix uses `ABS(CI)>40`.
* **Proposed Slug:** `katsanos-eurusd-ma-crb-tnx-d1`.
  No EA ID is allocated and no card is created.
* **Expected Trades/Year:** **7.6** (infrequent).

---

## 6. Audited proposal matrix

`Expected trades/year` below is the historical source rate. It is not a
promise and does not survive a proxy substitution unchanged.

| Mechanical configuration | Current base | Missing source dependency | Historical rate | Audited R3/Q02 disposition | Research slug only |
|---|---|---|---:|---|---|
| FDAX disparity/divergence | `GDAXI.DWX` | CAC/FCE | 5.8 | `R3_FAIL_AS_WRITTEN`; UK100 substitution is proxy research | `katsanos-dax-disparity-d1` |
| Classic DAX MA/CI/stochastic | `GDAXI.DWX` | none | 13.5 | `R3_PASS_AS_WRITTEN`; source conflicts still require G0 normalization | `katsanos-dax-ma-ci-stoch-d1` |
| Enhanced DAX MA | `GDAXI.DWX` | Euro Stoxx/FESX | 6.9 | `R3_FAIL_AS_WRITTEN`; UK100 substitution is proxy research | `katsanos-dax-ma-intermarket-d1` |
| Ten-stock DAX portfolio | none | ten stocks and CAC/FCE | 29.4 total; 2.9/stock | `R3_FAIL` and `Q02_BELOW_FLOOR` per stock; no card lead | — |
| USD/JPY regression + disparity + volatility | `USDJPY.DWX` | TNX; DXY direct | 5.6 | `R3_FAIL`; DXY basket does not solve TNX | `katsanos-usdjpy-regdiv-volbreak-d1` |
| Inverse 6J variant | none | 6J, TNX; DXY direct | unknown | `R3_FAIL`; incomplete source test; no separate lead | — |
| Pure USD/JPY regression | `USDJPY.DWX` | TNX; DXY direct | 4.0 | `R3_FAIL` and `Q02_BELOW_FLOOR`; `OPT1` unresolved | `katsanos-usdjpy-regression-d1` |
| Classic EUR/USD MA/CI/SAR | `EURUSD.DWX` | none | 12.4 | `R3_PASS_AS_WRITTEN`; `SPEC_UNRESOLVED` (`ABS(CI)`) | `katsanos-eurusd-ma-ci-sar-d1` |
| Enhanced EUR/USD MA | `EURUSD.DWX` | CRB and TNX | 7.6 | `R3_FAIL_AS_WRITTEN` | `katsanos-eurusd-ma-crb-tnx-d1` |

No allocated `QM5_*` identifier is proposed here. The identifiers
`QM5_12543` through `QM5_12550`, used in the initial extraction draft, are
already allocated to unrelated EAs and have therefore been removed. This task
does not create Strategy Cards.

## 7. Material source discrepancies for G0

The Appendix is the closest thing to executable evidence, but it conflicts
with the prose and tables in several places. A downstream specification must
record an OWNER/G0 choice; it must not silently pick a convenient variant.

| System | Conflict |
|---|---|
| FDAX disparity | Narrative divergence threshold `>2`; Appendix and Table 13.1 use `>0` (book pp. 203, 207 / PDFPAGE 221, 225; Appendix p. 327 / PDFPAGE 345). |
| FDAX disparity | Narrative describes a roughly 35-day CI; Appendix computes ROC39 over a 40-bar range (book pp. 203–204 / PDFPAGE 221–222; Appendix pp. 327–328 / PDFPAGE 345–346). |
| FDAX disparity | Short-entry prose says 20-bar LRS; Appendix uses 40 bars (book p. 205 / PDFPAGE 223; Appendix p. 328 / PDFPAGE 346). |
| FDAX disparity | Cover prose says MA10 below MA150; Appendix requires MA10 above MA150 (book p. 205 / PDFPAGE 223; Appendix p. 329 / PDFPAGE 347). |
| FDAX disparity | No ATR stop exists in the FDAX system. The `1.6*ATR(8)` line belongs to Chapter 12. The stock adaptation alone has `HHV3(C)-2.2*ATR(10)`. |
| Classic/enhanced DAX MA | Narrative summarizes trend/congestion and stochastic “crosses”; Appendix uses directional CI limits (`>30`/`<-30`), separate congestion limits 20/25, three-bar stochastic averages, and mostly state comparisons (book pp. 211–212 / PDFPAGE 229–230; Appendix pp. 329–331 / PDFPAGE 347–349). |
| USD/JPY systems | Chapter says same-day close; Appendix tester says open (book p. 271 / PDFPAGE 289; Appendix p. 348 / PDFPAGE 366). |
| Pure USD/JPY | `OPT1` is undefined; Table 17.2 suggests 10. The Appendix also uses IMO upper 65/retreat 10 while Table 17.2 reports upper 70 (book p. 276 / PDFPAGE 294; Appendix pp. 352–355 / PDFPAGE 370–373). |
| EUR/USD systems | Equations 17.2/17.5 print `ABS(CI)<40`; Appendix code uses `ABS(CI)>40` (book pp. 279, 281 / PDFPAGE 297, 299; Appendix p. 355 / PDFPAGE 373). |

Other implementation details that the source does not fully freeze include
same-bar conflict priority, pyramiding, holiday alignment between markets, and
how a daily close-based SAR/Bollinger condition is filled.

## 8. Evidence, available history, and review decision

Source integrity:

- PDF SHA-256:
  `B48AA0B83A783FDF6676199F399D5AFEEE48D259EF4A5F011C5131BC32E81D99`
- Text-cache SHA-256:
  `C9DB82117A0AB4D9E6D015DF0BC370B2521FBF0C73C5657FA44D76E4A01A778D`
- Provenance:
  `D:/QM/strategy_farm/source_cache/katsanos_intermarket_2008.provenance.json`
- Chapter 13 evidence: book pp. 201–213 / PDFPAGE 219–231; Appendix A.4
  book pp. 327–332 / PDFPAGE 345–350.
- Chapter 17 evidence: book pp. 261–292 / PDFPAGE 279–310; Appendix A.8
  book pp. 348–355 / PDFPAGE 366–373.

The local D1 history does not support the initial draft's proposed
“2008–2026” run. Registry coverage is currently:

| Symbol | D1 history |
|---|---|
| `EURUSD.DWX` | 2017–2026 |
| `USDJPY.DWX` | 2017–2026 |
| `GDAXI.DWX` | 2018–2026 |
| `SP500.DWX` | 2018–2026 |
| `UK100.DWX` | 2018–2025 |

**Review decision:** retain two source-faithful current-universe leads for a
future G0 decision: the classic DAX MA/CI/stochastic system and the classic
EUR/USD MA/CI/SAR system. The latter cannot be carded until the CI inequality
is frozen. The DAX lead also needs explicit resolution of source discrepancies
and a V5 risk-design decision because the source has only signal/time exits and
no disaster stop. All intermarket variants remain failed as written or
proxy-research-only. No build, pipeline phase, or live authorization follows
from this extraction.
