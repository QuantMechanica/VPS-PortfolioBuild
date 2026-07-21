# QM5_20029 wti-monfri-daily

**EA ID:** QM5_20029

## 1. Strategy Logic

Sell each Monday D1 session, buy each Friday D1 session, and close at the next
D1 boundary; the framework Friday close flattens Friday exposure at 21:00.

## 2. Parameters

Weekdays 1/5, ATR(20)*2.75 stop, one-day hold, 2500-point spread cap.

## 3. Symbol Universe

XTIUSD.DWX only, slot 0.

## 4. Timeframe

D1 only.

## 5. Expected Behaviour

About 95-104 signed daily packages/year before holidays and framework filters.

## 6. Source Citation

Gorska and Krawiec (2015), DOI 10.22630/PRS.2015.15.4.54, Tables 1-2.

## 7. Risk Model

Q02 uses RISK_FIXED=1000, RISK_PERCENT=0, weight 1. No live authority.
