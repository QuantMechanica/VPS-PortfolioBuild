# QM5_20125_rsi2-obos-scalp-m15 - Strategy Spec

**EA ID:** QM5_20125
**Slug:** `rsi2-obos-scalp-m15`
**Source:** FF-KOSOMOLATE-RSI2-539300 (see card QM5_20125)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

M15 RSI(2) OBOS scalp: BUY when RSI(1) < 30 strict, SELL when RSI(1) >
70; persistence of the condition remains a valid signal (one decision per
closed bar, earliest re-entry the next bar). Entry next bar; SL 25 pips /
TP 10 pips server-side; break-even at +5 pips to entry+1 (once,
retry-latched). One position.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-071-rsi2-obos-m15/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 2 | 2 | source-fixed |
| `strategy_buy_level` | 30.0 | 30 | source-fixed |
| `strategy_sell_level` | 70.0 | 70 | source-fixed |
| `strategy_sl_pips` | 25.0 | 25 | source-fixed |
| `strategy_tp_pips` | 10.0 | 10 | source-fixed |
| `strategy_be_trigger_pips` | 5.0 | 5 | source-fixed |
| `strategy_be_plus_pips` | 1.0 | 1 | source-fixed |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1) — test-design. Magics 201250000-201250001.

---

## 4. Timeframe

M15 execution; closed-bar reads.

---

## 5. Expected Behaviour

High-frequency (~400/yr/symbol), high-WR inverted-R:R profile; unaudited
600%-claims recorded; falsification build; Q02/Q04 judge.

---

## 6. Source Citation

Kosomolate (~2015), "No long story - RSI system", ForexFactory thread
539300, https://www.forexfactory.com/thread/539300/no-long-story-rsi-system
— post #1 (rule table + EA), follow-ups (fixed-lot claims). Card:
QM5_20125 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade); KS_DAILY_LOSS 3%;
KS_PORTFOLIO_DD external guard; news blackout fail-closed; Friday close
21:00 broker.

---

## Revision History

- 2026-07-25 — initial spec (harvest build run tranche 9, ledger STR-071).
