# QM5_20116_ema512-rsi7-m15 - Strategy Spec

**EA ID:** QM5_20116
**Slug:** `ema512-rsi7-m15`
**Source:** FF-SASHADEOL-EMARSI-316055 (see card QM5_20116)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

EURUSD M15 bare OP baseline: LONG when EMA(5) crosses above EMA(12) on the
closed bar (strict edge: beyond at shift 1, at/inside at shift 2) AND
RSI(7) at shift 1 is strictly above 50; SHORT mirror. Entry next bar; SL
20 pips (OP fixed option); TP 25 pips (in-thread implementer's selection
from the OP's 10-30 range, flagged); one position; no reversal. NO session
window and NO spread filter — the prior build QM5_9701 invented both
(bulk-audit 2026-07-24); its outcomes are not transferable.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-044-ema512-rsi7-m15/04_spec_final.md`
(reconciliation + addendum in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 5 | 5 | source-fixed |
| `strategy_ema_slow` | 12 | 12 | source-fixed |
| `strategy_rsi_period` | 7 | 7 | source-fixed |
| `strategy_rsi_level` | 50.0 | 50 | source-fixed |
| `strategy_tp_pips` | 25.0 | 10-30 | in-thread selection (flagged) |
| `strategy_sl_pips` | 20.0 | 20 | OP fixed option |

---

## 3. Symbol Universe

EURUSD.DWX (0) — OP-explicit. Magic 201160000.

---

## 4. Timeframe

M15 execution; closed-bar reads only.

---

## 5. Expected Behaviour

~300+ crosses/yr (churn); adverse p.24 implementer evidence recorded;
falsification build.

---

## 6. Source Citation

sashadeol (~2011), "EMA & RSI Intraday M15 system", ForexFactory thread
316055, https://www.forexfactory.com/thread/316055/ema-rsi-intraday-m15-system
— post #1 (rules), p.24 (implementer variant + adverse results). Card:
QM5_20116 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade); KS_DAILY_LOSS 3%;
KS_PORTFOLIO_DD external guard; news blackout fail-closed; Friday close
21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 6, ledger STR-044).
