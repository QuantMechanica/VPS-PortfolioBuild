# QM5_20046_wti-halloween-ls

**EA ID:** QM5_20046

## 1. Strategy Logic

Monthly WTI symmetric Halloween regime: long November-April, short May-October, renewed at each broker-month boundary. One persisted attempt per month, frozen D1 ATR(20) x 4 hard stop, 35-day stale guard, and no same-month re-entry.

## 2. Parameters

The locked Q02 baseline uses long-month boundaries 11/4, ATR period 20, stop multiple 4.0, maximum hold 35 days, and maximum spread 1500 points.

## 3. Symbol Universe

`XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

D1 host with broker-calendar monthly boundaries and completed D1 ATR values.

## 5. Expected Behaviour

Twelve monthly packages per year before framework filters, alternating between six winter longs and six summer shorts.

## 6. Source Citation

Burakov, Freidin and Solovyev (2018), *International Journal of Energy Economics and Policy* 8(2), 121-126. The paper supplies the fixed Halloween partition; QM supplies explicit execution and risk controls.

## 7. Risk Model

Backtest uses `RISK_FIXED=1000` and `RISK_PERCENT=0`, with one frozen ATR hard stop per monthly package. No live artifact is created.

Source: Burakov, Freidin and Solovyev (2018), *International Journal of Energy Economics and Policy* 8(2), 121-126. Canonical rules and non-duplicate boundary are in `strategy-seeds/cards/wti-halloween-ls_card.md`.
