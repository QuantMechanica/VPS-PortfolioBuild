# QM5_20121_mtf-rsi2-align-m15 - Strategy Spec

**EA ID:** QM5_20121
**Slug:** `mtf-rsi2-align-m15`
**Source:** FF-TXFX-MTFRSI-504229 (see card QM5_20121)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

M15-executed MTF RSI alignment (edited post-#1 baseline): LONG when
RSI(2) is strictly above 50 on H4, H1, M30, M15, M5 and M1, each on its
own last closed bar (D1 optional-excluded); SHORT when all below. Entry
on the alignment-completion edge; TP 30 / SL 20 pips server-side; one
position; no reversal. The pre-edit original (RSI 55 + progressive
martingale MM) is superseded and hard-rule-excluded.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-066-mtf-rsi50-alignment/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 2 | 2-3 | edited post "2 or 3"; 2 baseline, 3 variant |
| `strategy_level` | 50.0 | 50 | source-fixed |
| `strategy_tp_pips` | 30.0 | 30 | source-fixed |
| `strategy_sl_pips` | 20.0 | 20 | source-fixed |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1) — test-design. Magics 201210000-201210001.

---

## 4. Timeframe

M15 execution; six-TF closed-bar RSI reads (MTF discipline, per-TF
BarsCalculated gating).

---

## 5. Expected Behaviour

~100-300 alignments/yr/symbol (M1/M5 flip fast); churn judged by Q02.

---

## 6. Source Citation

txfxtrader (2014), "MTF RSI Trading System", ForexFactory thread 504229,
https://www.forexfactory.com/thread/504229/mtf-rsi-trading-system —
edited post #1 (final rules), p.2 (pre-edit requote, excluded), p.7 (H4
addition). Card: QM5_20121 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade); KS_DAILY_LOSS 3%;
KS_PORTFOLIO_DD external guard; news blackout fail-closed; Friday close
21:00 broker.

---

## Revision History

- 2026-07-25 — initial spec (harvest build run tranche 8, ledger STR-066).
