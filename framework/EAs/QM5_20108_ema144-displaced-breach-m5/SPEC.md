# QM5_20108_ema144-displaced-breach-m5 - Strategy Spec

**EA ID:** QM5_20108
**Slug:** `ema144-displaced-breach-m5`
**Source:** FF-JAMESAGNEW-144EMA-1348501 (see card QM5_20108)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

M5 displaced-EMA breach (OP variant 1): LONG when the M5 close strictly
crosses above the 34-EMA displaced +16 bars (prior close at/inside); SHORT
mirror. SL = the EMA(144) price at the signal bar (server-side static;
invalid geometry skips the signal); TP = 17 pips. One position; opposite
signal never reverses. Variant 2 (hold until opposite close) documented in
the card, unbuilt. Cohort is explicit test-design (source names no
symbols).

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-024-144ema-displaced-breakout/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_ema_period` | 34 | 34 | trigger EMA (source-fixed) |
| `strategy_entry_ema_shift` | 16 | 16 | forward displacement (source-fixed) |
| `strategy_stop_ema_period` | 144 | 144 | SL EMA (source-fixed) |
| `strategy_tp_pips` | 17.0 | 17 | target (source-fixed) |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1), USDJPY.DWX (2) — test-design cohort
(non-authorial, flagged). Magics 201080000-201080002.

---

## 4. Timeframe

M5 execution; closed-bar reads; displaced read = unshifted EMA34 buffer at
shift 1+16.

---

## 5. Expected Behaviour

High-frequency M5 cross system (~hundreds/yr/symbol); thread-skepticism
recorded — falsification build; expect harsh Q02/Q04.

---

## 6. Source Citation

jamesagnew (~2024), "144 ema method", ForexFactory thread 1348501,
https://www.forexfactory.com/thread/1348501/144-ema-method — post #1
(ruleset), author follow-up (variant 2). Card: QM5_20108 (g0 cross-approval
codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade off the variable EMA144
distance); KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout
fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 4, ledger STR-024).
