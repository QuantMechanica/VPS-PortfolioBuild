# QM5_13138_xau-m5-ema20 - Strategy Spec

**EA ID:** QM5_13138

## 1. Strategy Logic

Enter XAUUSD.DWX long on a completed M5 EMA20 cross above EMA50 when the
completed Heikin-Ashi bar is bullish and closes above EMA20. Activate a 1%
target after 12 bars, use a 10% catastrophe stop and exit after 5,760 M5 bars.

## 2. Parameters

EMA20/50, 200-bar HA reconstruction, 10% stop, 1% target, 12-bar target delay
and 5,760-bar maximum hold are frozen by the approved card.

## 3. Symbol Universe

XAUUSD.DWX only, magic slot 0.

## 4. Timeframe

M5 host and signal bars. Target management is per tick; entry and time exit are
new-bar gated.

## 5. Expected Behaviour

Approximately 40-55 completed trades/year with long multi-session exposure,
wide-stop minimum-lot risk and material floating-MAE sensitivity.

## 6. Source Citation

OWNER FTMO survivor handoff, 2026-07-11, source ID
OWNER-FTMO-SURVIVORS-20260711. Full approved card is copied under docs.

## 7. Risk Model

Backtest uses RISK_FIXED=1000 and RISK_PERCENT=0. Friday flattening and news
entry filtering are disabled to preserve exact research mechanics. Current
FTMO XAU costs and floating MAE remain downstream hard gates.
