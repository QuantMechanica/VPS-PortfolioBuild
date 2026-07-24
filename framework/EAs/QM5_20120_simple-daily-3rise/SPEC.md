# QM5_20120_simple-daily-3rise - Strategy Spec

**EA ID:** QM5_20120
**Slug:** `simple-daily-3rise`
**Source:** FF-THETHING-SIMPLEDAILY-38981 (see card QM5_20120)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

D1 three-rise continuation (no indicators — the author's later
clarifications win): LONG after three consecutive daily candles each with
a HIGHER open AND higher close than the previous candle (relative
definition, p.16; strict); entry at market on the new (4th) bar; SL = 2
pips beyond the previous candle's extreme or 90 pips from entry,
whichever is CLOSER; half out at +30 pips + breakeven move; remainder TP
+100 pips. Mirror short. One campaign; one evaluation per day.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-058-simple-daily-3candle/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sl_buffer_pips` | 2.0 | 2 | beyond prev extreme (source-fixed) |
| `strategy_sl_max_pips` | 90.0 | 90 | SL cap, closer-wins (source-fixed) |
| `strategy_p1_tp_pips` | 30.0 | 30 | half-out level (source-fixed) |
| `strategy_p2_tp_pips` | 100.0 | 100 | remainder TP (source-fixed) |

---

## 3. Symbol Universe

GBPUSD.DWX (0), EURUSD.DWX (1) — test-design cohort. Magics
201200000-201200001.

---

## 4. Timeframe

D1 execution; pure closed-bar price rules.

---

## 5. Expected Behaviour

~15-40 campaigns/yr/symbol; EMA-gated p.1 variant documented-unbuilt;
per-pair TP optimization = Q03 domain.

---

## 6. Source Citation

TheThing (2006-07), "Simple Daily System", ForexFactory thread 38981,
https://www.forexfactory.com/thread/38981/simple-daily-system — post #1,
requotes p.7/13, relative-candle clarification p.16, no-indicator
clarification p.18. Card: QM5_20120 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade off the min-rule SL);
KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout
fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 7, ledger STR-058).
