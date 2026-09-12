# QM5_11362_robo-one-two-bb-reversal — Strategy Spec

**EA ID:** QM5_11362
**Slug:** robo-one-two-bb-reversal
**Framework:** QuantMechanica V5
**Approved card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11362_robo-one-two-bb-reversal.md`

## 1. Strategy Logic

On each new M15 bar, inspect closed bars 1–3. A long requires bar 1 to close between BB(20,2) lower and middle bands, two consecutive declining closes (`Close[1] < Close[2] < Close[3]`), and bearish bars 1 and 2. A short is symmetric in the upper BB zone with consecutive rising closes and bullish bars 1 and 2. Enter at the next bar.

Skip a signal when bar 1 spans more than 15 pips. The initial stop is five pips beyond bar 1's extreme, capped at 20 pips from entry. Exit at the dynamic BB middle band. Entries have a five-pip spread cap. Only one position per EA magic and symbol is allowed. Framework news, Friday-close, kill-switch, and trade-manager controls remain authoritative.

## 2. Parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `strategy_bb_period` | 20 | Bollinger Band period |
| `strategy_bb_deviation` | 2.0 | Bollinger Band deviation |
| `strategy_sl_pips` | 20 | Maximum initial stop distance |
| `strategy_sl_offset_pips` | 5 | Stop offset beyond signal-bar extreme |
| `strategy_max_signal_range_pips` | 15 | Maximum signal-bar range |
| `strategy_spread_cap_pips` | 5.0 | Maximum entry spread |

## 3. Symbol Universe

The approved M15 universe is `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`, and `USDJPY.DWX`, mapped to magic slots 0 through 5 in that order.

## 4. Timeframe

M15 only for this package. Signals use fully closed bars and entry is submitted after bar 1 closes.

## 5. Expected Behaviour

The card expects about 80 trades per year per symbol, profit factor 1.2, and drawdown near 18%. These are expectations, not gate results. Existing historical Q outcomes remain authoritative and are not changed by this review.

## 6. Source Citation

RoboForex Strategy Collection, “Strategy One-Two,” pages 28–29, local PDF identified in the approved card. Lineage source ID: `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`. The approved Strategy Card is the binding implementation contract.

## 7. Risk Model

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. Stops are mechanical and capped at 20 pips. There is no martingale, grid, adaptive sizing, or ML. The framework news blackout remains mandatory with `qm_news_stale_max_hours=336`; neither this spec nor its compile authority permits live trading.

## Revision History

| Date | Change |
|---|---|
| 2026-09-12 | Added canonical seven-section card-to-module contract during Codex rework. |

