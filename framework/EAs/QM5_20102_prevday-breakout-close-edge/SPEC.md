# QM5_20102_prevday-breakout-close-edge - Strategy Spec

**EA ID:** QM5_20102
**Slug:** `prevday-breakout-close-edge`
**Source:** FF-PROC-PDBE-1075281 (see card QM5_20102)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

H1 previous-day breakout with close confirmation on a cyclic 22:00-UTC
trading day. Previous-day high/low = max/min over all closed H1 bars of the
preceding complete cyclic day, frozen until the next 22:00-UTC roll. Long on
the FIRST H1 body close strictly above the frozen high (short: below the
low), one event per direction per day, consumed even if the entry is vetoed
(no late chases). Entry at the next H1 bar's first tick; SL 12.5 pips, TP 25
pips from actual fill; set-and-forget (no trailing, no extra exits — the
deliberate difference vs QM5_10007's invented extras, which failed Q04).
Optional SMA(34) close filter, default OFF (source-optional).

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-003-previous-day-breakout-edge/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_filter` | false | on/off | optional SMA(34) trend filter (source: "optional") |
| `strategy_sma_period` | 34 | 34 | filter period (source-fixed) |
| `strategy_sl_pips` | 12.5 | 12.5 | stop loss (source-fixed) |
| `strategy_tp_pips` | 25.0 | 25.0 | take profit (source-fixed, 1:2) |
| `strategy_day_anchor_utc_hour` | 22 | 22 | cyclic-day start, UTC (source-fixed) |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1) — the author's backtested pairs. Magics
201020000-201020001.

---

## 4. Timeframe

H1 execution; closed-bar reads only; day bucketing via the framework
broker↔UTC primitive (no invented DST arithmetic; DST-week ≤1-bar ambiguity
documented).

---

## 5. Expected Behaviour

~100-200 first-close events/yr/symbol before vetoes; win rate structurally
<50% with 1:2 R:R. Honesty note: the thread contains a NEGATIVE mechanical
test (−3R/13mo EURUSD unfiltered) — this build exists for faithful
falsification; pipeline evidence only.

---

## 6. Source Citation

Proc (~2021), "Previous Day Breakout Edge System", ForexFactory thread
1075281, https://www.forexfactory.com/thread/1075281/previous-day-breakout-edge-system
— post #1 (core rules), p.5 (uniform SL/TP, >=1:2), p.9 (London=preference),
p.10 (negative test), p.13-14 (first-close-only). Card: QM5_20102 (g0
cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade); fixed 12.5-pip stop;
KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout fail-closed
(replaces the author's discretionary fundamentals); Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 2, ledger STR-003).
