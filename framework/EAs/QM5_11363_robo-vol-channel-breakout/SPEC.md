# QM5_11363_robo-vol-channel-breakout — Strategy Spec

**EA ID:** QM5_11363
**Slug:** robo-vol-channel-breakout
**Framework:** QuantMechanica V5
**Approved card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11363_robo-vol-channel-breakout.md`

## 1. Strategy Logic

On each new M15 bar, enter long when closed bar 1 is simultaneously above EMA(5)+ATR(30) and EMA(4)+ATR(14). Enter short when it is below both corresponding lower channels. ATR(14) must exceed five pips. Entry is submitted on the next bar.

The take profit is two ATR(14) from entry. The stop starts at EMA(5); when that is closer than one ATR(30), use the one-ATR(30) distance, then cap the final stop distance at 20 pips. Entries have a 15-pip spread cap. Only one position per EA magic and symbol is allowed. Framework news, Friday-close, kill-switch, and trade-manager controls remain authoritative.

## 2. Parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `strategy_ema_wide` | 5 | Wide-channel EMA period |
| `strategy_atr_wide` | 30 | Wide-channel ATR period |
| `strategy_ema_tight` | 4 | Tight-channel EMA period |
| `strategy_atr_tight` | 14 | Tight-channel ATR period |
| `strategy_tp_multiplier` | 2.0 | ATR(14) target multiplier |
| `strategy_sl_max_pips` | 20 | Maximum stop distance |
| `strategy_spread_cap_pips` | 15.0 | Maximum entry spread |
| `strategy_min_vol_pips` | 5 | Minimum ATR(14) |

## 3. Symbol Universe

The approved M15 universe is `EURUSD.DWX`, `GBPUSD.DWX`, and `GBPJPY.DWX`, mapped to magic slots 0, 1, and 2 respectively.

## 4. Timeframe

M15 only. All channel and volatility calculations use closed bar 1, and entry is submitted after that bar closes.

## 5. Expected Behaviour

The card expects about 70 trades per year per symbol, profit factor 1.2, and drawdown near 18%. These are expectations, not gate results. Existing historical Q outcomes remain authoritative and are not changed by this review.

## 6. Source Citation

RoboForex, *Forex Trading Strategies Collection*, “Volatility channel breakout strategy,” local PDF identified in the approved card. Lineage source ID: `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`. The approved Strategy Card is the binding implementation contract.

## 7. Risk Model

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. Stops and targets are mechanical, with the stop capped at 20 pips. There is no martingale, grid, adaptive sizing, or ML. The framework news blackout remains mandatory with `qm_news_stale_max_hours=336`; neither this spec nor its compile authority permits live trading.

## Revision History

| Date | Change |
|---|---|
| 2026-09-12 | Added canonical seven-section card-to-module contract during Codex rework. |

