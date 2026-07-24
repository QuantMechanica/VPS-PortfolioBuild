# QM5_20107_asian-range-straddle-m15 - Strategy Spec

**EA ID:** QM5_20107
**Slug:** `asian-range-straddle-m15`
**Source:** FF-KNODLZ-RANGEBREAK-1299658 (see card QM5_20107)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

USDJPY M15 asian-range straddle: range = high/low of the completed M15 bars
with open in [01:00, 06:00) broker time; at 06:00 place Buy Stop at the
high and Sell Stop at the low, each with SL on the opposite border and no
TP (two-phase placement, one request per EntrySignal call); the opposite
pending survives a fill (max 2 entries/day via the shared border level).
Untriggered pendings deleted at 13:00 (literal source clock; the "1.5h
before NY open" gloss is flagged inconsistent); all positions flattened at
20:00; per new closed M15 bar the SL trails to the previous bar's extreme
(never widening). Date blocked entirely if a boundary is pre-crossed or an
order invalid (no one-sided straddle).

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-016-asian-range-breakout/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_start_hhmm` | 100 | 100 | range window start, broker clock (source-fixed) |
| `strategy_range_end_hhmm` | 600 | 600 | range window end (source-fixed) |
| `strategy_cancel_hhmm` | 1300 | 1300 | pending deletion clock (source-fixed, flagged) |
| `strategy_flat_hhmm` | 2000 | 2000 | position flatten clock (source-fixed) |

---

## 3. Symbol Universe

USDJPY.DWX (0) — the only symbol with source-stated rules. Magic 201070000.

---

## 4. Timeframe

M15 execution; range from closed M15 bars; broker-clock day cycle.

---

## 5. Expected Behaviour

~250 straddles/yr; long trends deliver runners via the bar-extreme trail;
chop delivers border whipsaws (source-acknowledged). Sibling QM5_9936 (H1)
is live mid-pipeline — competing variant, Q09 arbitrates.

---

## 6. Source Citation

Knodlz (~2024), "Range Breakout System", ForexFactory thread 1299658,
https://www.forexfactory.com/thread/1299658/range-breakout-system — post #1
(full USDJPY ruleset), server-time correction reply. Card: QM5_20107 (g0
cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1% per side off the range-width
SL); KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout
fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 4, ledger STR-016).
