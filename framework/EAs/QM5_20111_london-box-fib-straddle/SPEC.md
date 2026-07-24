# QM5_20111_london-box-fib-straddle - Strategy Spec

**EA ID:** QM5_20111
**Slug:** `london-box-fib-straddle`
**Source:** FF-MER-LONDONBOX-230640 (see card QM5_20111)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

London-box fib-straddle on M15: box = high/low of the 03:00-06:00 UTC
window (GMT-fixed per source, converted via QM_BrokerToUTC); veto boxes
over 40 pips. Buy stop above the top and sell stop below the bottom, each
offset 32.6% of the box size beyond the edge (midpoint of the source's
"between the 27 and 38.2 fib extensions"); TP = box size from entry; SL =
the opposite box side. Option A: one filled trade per box — the opposite
pending is deleted on fill and nothing re-arms; open trades flattened and
pendings cleared at the next box start. No martingale (source musings not
built — hard rule).

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-035-london-box-fib-breakout/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_box_start_utc_hour` | 3 | 3 | box window start, UTC (source-fixed) |
| `strategy_box_end_utc_hour` | 6 | 6 | box window end (source-fixed) |
| `strategy_entry_ext_pct` | 32.6 | 27-38.2 | entry offset, % of box (midpoint mechanization, flagged) |
| `strategy_max_box_pips` | 40.0 | 40 | box veto (restrictive end of source 40-50) |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1), USDJPY.DWX (2), EURJPY.DWX (3),
USDCHF.DWX (4) — the author's monitored pairs. Magics 201110000-201110004.

---

## 4. Timeframe

M15 execution; UTC box anchors via the framework broker↔UTC primitive.

---

## 5. Expected Behaviour

~180-220 valid boxes/yr/symbol after the 40-pip veto; TP≈SL≈box-size
geometry; adverse in-thread 2010 evidence recorded.

---

## 6. Source Citation

mer071898 (2010), "A Simple London Breakout", ForexFactory thread 230640,
https://www.forexfactory.com/thread/230640/a-simple-london-breakout — post
#1 (rules), p.13-16 (opposite-side SL clarification), xmph backtests.
Card: QM5_20111 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade off the box-width SL);
KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout
fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 5, ledger STR-035).
