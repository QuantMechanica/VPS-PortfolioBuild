# QM5_11301_tc-m5-macd1-stoch-ema5-open-close — Strategy Spec

**EA ID:** QM5_11301  
**Slug:** tc-m5-macd1-stoch-ema5-open-close  
**Framework:** QuantMechanica V5  
**Approved card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11301_tc-m5-macd1-stoch-ema5-open-close.md`

## 1. Strategy Logic

Evaluate the most recently closed M5 bar and enter at the next available tick only when all four approved conditions align.

Long entry:

1. Stochastic(5,3,3) %K crosses above 20 from below and the current value is not above 80.
2. MACD(12,26,1) main value rises from the preceding closed bar.
3. The signal candle is bullish (`Close > Open`).
4. EMA(5, Close) crosses above EMA(5, Open).

Short entry is the symmetric condition: %K crosses below 80 from above and remains at or above 20, MACD main falls, the candle is bearish, and EMA(5, Close) crosses below EMA(5, Open).

Only one position per EA magic and symbol is allowed. Positions exit when the EMA(5, Close)/EMA(5, Open) relationship crosses in the opposite direction or when the fixed stop is hit. There is no take-profit target. Entries are restricted to the London/New York session and a three-pip spread cap. Framework news, Friday-close, kill-switch, and position-management controls remain authoritative.

## 2. Parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `strategy_timeframe` | M5 | Signal timeframe |
| `strategy_macd_fast` | 12 | MACD fast EMA |
| `strategy_macd_slow` | 26 | MACD slow EMA |
| `strategy_macd_signal` | 1 | MACD signal period |
| `strategy_stoch_k` | 5 | Stochastic %K period |
| `strategy_stoch_d` | 3 | Stochastic %D period |
| `strategy_stoch_slowing` | 3 | Stochastic slowing |
| `strategy_stop_pips` | 20 | Fixed initial stop |
| session | 10:00–24:00 broker time | London/New York entry window |
| spread cap | 3 pips | Maximum entry spread |

## 3. Symbol Universe

- `EURUSD.DWX` — primary approved major FX symbol, magic slot 0.
- `GBPUSD.DWX` — approved secondary major FX symbol, magic slot 1.

No other symbol is authorized by the approved card.

## 4. Timeframe

M5 only. Signals use closed bars at shifts 1 and 2, and entry is submitted after the signal bar closes.

## 5. Expected Behaviour

The card expects approximately 30 trades per year per symbol, profit factor 1.2, and drawdown around 16%. These are expectations, not achieved gate verdicts. Sparse or zero trades require governed Q01/Q02 evidence and must not be inferred from compilation.

## 6. Source Citation

Thomas Carter, *20 Forex Trading Strategies (5 Minute Time Frame)* (2014), System #1. Lineage source ID: `e78a9f1f-4e6a-563c-a080-915133d6ed28`. The approved Strategy Card is the binding implementation contract.

## 7. Risk Model

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. The source default retains the card's live-size declaration, but live use is not authorized by this package or review. Initial stop distance is 20 pips. No martingale, grid, adaptive sizing, or ML is present. The framework's mandatory news blackout remains enabled with `qm_news_stale_max_hours=336`.

## Revision History

| Date | Change |
|---|---|
| 2026-08-10 | Initial generated package. |
| 2026-09-12 | Replaced incomplete SPEC with the canonical seven-section card-fidelity contract. |

