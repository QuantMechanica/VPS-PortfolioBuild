# QM5_20122_bb-stoch-bandcross-h1 - Strategy Spec

**EA ID:** QM5_20122
**Slug:** `bb-stoch-bandcross-h1`
**Source:** FF-STINGRAY-BBSTOCH-506226 (see card QM5_20122)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

H1 four-case Bollinger band-cross system (the resolved variant-split):
crossing bar = shift 2 (vs shift 3), confirm candle = shift 1, entry next
bar, one case per bar in fixed precedence. Upper cross-out → BUY with
Stoch(14,3,3) main>signal, bullish confirm, main<80; upper cross-back →
SELL (mirror confirms, main>20); lower band mirror pair. TP 50 / SL 50
pips; MT4-style 15-pip per-tick trailing ratchet (≥1-pip step, never
widen). One position.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-067-bb-stoch-bandcross/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 20 | source-fixed |
| `strategy_bb_dev` | 2.0 | 2 | source-fixed |
| `strategy_stoch_k` | 14 | 14 | source-fixed |
| `strategy_stoch_d` | 3 | 3 | source-fixed |
| `strategy_stoch_slow` | 3 | 3 | source-fixed |
| `strategy_tp_pips` | 50.0 | 50 | source-fixed |
| `strategy_sl_pips` | 50.0 | 50 | source-fixed |
| `strategy_trail_pips` | 15.0 | 15 | source-fixed (ratchet mechanization flagged) |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1) — test-design ("Any Currency"). Magics
201220000-201220001.

---

## 4. Timeframe

H1 execution; closed-bar reads; per-tick trail in Manage.

---

## 5. Expected Behaviour

~100-250 signals/yr/symbol across the four cases; trailing converts
runners; prior fade-only build QM5_10015 not transferable.

---

## 6. Source Citation

StingrayEA (~2014), "Bollinger Band & Stochastic", ForexFactory thread
506226, https://www.forexfactory.com/thread/506226/bollinger-band-stochastic
— post #1 (rules/params), p.3 (support/resistance breakout explanation).
Card: QM5_20122 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade); KS_DAILY_LOSS 3%;
KS_PORTFOLIO_DD external guard; news blackout fail-closed; Friday close
21:00 broker.

---

## Revision History

- 2026-07-25 — initial spec (harvest build run tranche 8, ledger STR-067).
