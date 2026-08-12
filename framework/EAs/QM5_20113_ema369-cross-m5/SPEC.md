# QM5_20113_ema369-cross-m5 - Strategy Spec

**EA ID:** QM5_20113
**Slug:** `ema369-cross-m5`
**Source:** FF-JAWS-EMA369-252779 (see card QM5_20113)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

M5 triple-EMA cross scalp: LONG when EMA(3) is above BOTH EMA(6) and
EMA(9) on the closed bar and was not on the prior bar (full-condition
edge); SELL mirror; entry at the next bar. SL 20 pips; TP 10 pips (the
author's 2.5%-of-balance target mechanized as his own pip approximation,
flagged). An open position closes at market when the opposite full cross
becomes true on a closed bar (ExitSignal level condition); re-entry only
on a fresh edge. One position.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-038-ema369-cross-scalp/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 3 | 3 | source-fixed |
| `strategy_ema_mid` | 6 | 6 | source-fixed |
| `strategy_ema_slow` | 9 | 9 | source-fixed |
| `strategy_tp_pips` | 10.0 | 10 | flagged mechanization of %-balance TP |
| `strategy_sl_pips` | 20.0 | 20 | source-fixed disaster stop |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1) — test-design cohort (source: any pair).
Magics 201130000-201130001.

---

## 4. Timeframe

M5 execution; closed-bar reads only.

---

## 5. Expected Behaviour

Extreme churn (several crosses/day); the thread's own ranging-destruction
prediction is the falsification hypothesis; Q02 economics judge.

---

## 6. Source Citation

jaws810 (~2010), "3,6,9 EMA system", ForexFactory thread 252779,
https://www.forexfactory.com/thread/252779/3-6-9-ema-system — post #1
(rules, untested disclosure), follow-up (opposite-cross exits). Card:
QM5_20113 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade); KS_DAILY_LOSS 3%;
KS_PORTFOLIO_DD external guard; news blackout fail-closed; Friday close
21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 5, ledger STR-038).
