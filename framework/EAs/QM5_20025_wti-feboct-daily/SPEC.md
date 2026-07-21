# QM5_20025 wti-feboct-daily

**EA ID:** QM5_20025

## 1. Strategy Logic
Buy each February D1 session, sell each October session, close next D1.

## 2. Parameters
Months 2/10, ATR(20)*2.75 stop, one-day hold, 2500-point spread cap.

## 3. Symbol Universe
XTIUSD.DWX only, slot 0.

## 4. Timeframe
D1 only.

## 5. Expected Behaviour
About 40-45 daily-reset packages/year with opposite month directions.

## 6. Source Citation
Gorska and Krawiec (2015), DOI 10.22630/PRS.2015.15.4.54, Tables 4-5.

## 7. Risk Model
Q02 uses RISK_FIXED=1000, RISK_PERCENT=0, weight 1. No live authority.
