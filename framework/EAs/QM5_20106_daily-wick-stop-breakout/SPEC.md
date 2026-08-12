# QM5_20106_daily-wick-stop-breakout - Strategy Spec

**EA ID:** QM5_20106
**Slug:** `daily-wick-stop-breakout`
**Source:** FF-ROCKZZ-YOUREAV3-1233107 (see card QM5_20106)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

D1 stop-order breakout with wick-asymmetry direction: at each new broker D1
bar, wickBuy = prevOpen-prevLow, wickSell = prevHigh-prevOpen (strict
comparison, equality places nothing). Larger lower wick: BUY STOP at
prevHigh+2 pips (SL prevHigh-30, TP entry+100); larger upper wick: SELL STOP
at prevLow-2 (SL prevLow+30, TP entry-100). One directional pending per day,
cancelled at day roll (+ server expiry belt); market already through the
planned entry at placement means skip the day; an open position blocks new
pendings. No ATR filter, no time stop (deliberate fidelity difference vs
QM5_9959, Q04-FAIL).

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-012-daily-wick-asymmetry-breakout/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pips_above_high` | 2.0 | 2 | stop offset above prev high (author restatement) |
| `strategy_pips_below_low` | 2.0 | 2 | stop offset below prev low |
| `strategy_sl_pips` | 30.0 | 30 | level-anchored SL (author settings) |
| `strategy_tp_pips` | 100.0 | 100 | TP from planned entry |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1), AUDUSD.DWX (2), USDJPY.DWX (3), EURAUD.DWX
(4) — the thread-backtested pairs. Magics 201060000-201060004.

---

## 4. Timeframe

D1 execution; all reads from D1 shift 1; day roll = broker D1 bar change.
Sunday-candle dataset identity recorded in evidence (source-reported
sensitivity).

---

## 5. Expected Behaviour

~150-250 pendings/yr/symbol, fill fraction unknown; R1 honesty: OP admits
live SL-hammering and tester-vs-live divergence — deliberate falsification
build; expect harsh Q02/Q04.

---

## 6. Source Citation

rockzz (2023), "Your EA v3 - Daily Low & High Strategy", ForexFactory thread
1233107, https://www.forexfactory.com/thread/1233107/your-ea-v3-daily-low-high
— post #1 (12-point ruleset + attached .mq4 + TP100/SL30 + 2-pip offsets),
post #2 (live warning), pages 3-6 (2000-2023 backtests). Card: QM5_20106
(g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade sized off planned
entry to level-anchored SL); KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external
guard; news blackout fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 3, ledger STR-012).
