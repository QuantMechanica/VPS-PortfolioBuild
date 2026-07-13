# QM5_13137_breadth-tue - Strategy Spec

**EA ID:** QM5_13137

## 1. Strategy Logic

On Monday at broker 23:00, enter long on the host sleeve only when both
SP500.DWX and WS30.DWX declined from their exact 16:30 M30 open to their exact
22:30 M30 close. Exit Tuesday at broker 23:00. A 1.0x prior-D1 ATR(14) stop is
the only price exit.

## 2. Parameters

Signal symbols, cash timestamps, entry/exit hour, ATR14 and 1.0 ATR stop are
frozen by the approved card. Q02 uses RISK_FIXED=1000.

## 3. Symbol Universe

SP500.DWX slot 0, WS30.DWX slot 1 and XAUUSD.DWX slot 2. SP500.DWX is
backtest-only and cannot pass a future live-routing gate without a new book.

## 4. Timeframe

M30 host and signal bars, with completed D1 ATR for the host stop.

## 5. Expected Behaviour

Approximately 13-18 completed trades/year/symbol, one-night long exposure,
and correlated results across the three host sleeves.

## 6. Source Citation

OWNER FTMO survivor handoff, 2026-07-11, source ID
OWNER-FTMO-SURVIVORS-20260711. Full approved card is copied under docs.

## 7. Risk Model

Backtest uses RISK_FIXED=1000 and RISK_PERCENT=0. Friday flattening and news
entry filtering are disabled to preserve the frozen exact rule. Framework
kill switch, risk sizing and one-position-per-magic remain mandatory.
