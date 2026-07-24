# QM5_20105_notable-number-breakout-m5 - Strategy Spec

**EA ID:** QM5_20105
**Slug:** `notable-number-breakout-m5`
**Source:** FF-JOYNY-NOTABLE-1182304 (see card QM5_20105)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

CADJPY M5 continuation at the notable-88 lattice: BUY when all previous 41
broker-D1 bars sit wholly BELOW the level and consecutive M5 opens cross it
upward (breakout continuation); SELL mirror. Machinery identical to
QM5_20104 with inverted polarity; separate EA identity (survivor-port
purity). TP 1.0% / SL 0.75% of entry; window 14:00-22:00 broker (source
"London+2h" = broker clock); one-fire latch; one position.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-009-notable-number-breakout/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_notable_suffix` | "88" | 88 | source-fixed |
| `strategy_lookback_d1_bars` | 41 | 41 | source-fixed |
| `strategy_sl_price_pct` | 0.75 | 0.75 | source-fixed |
| `strategy_tp_price_pct` | 1.00 | 1.00 | source-fixed |
| `strategy_window_start_hhmm` | 1400 | 1400 | source-fixed (broker clock) |
| `strategy_window_end_hhmm` | 2200 | 2200 | source-fixed |

---

## 3. Symbol Universe

CADJPY.DWX (0). Magic 201050000.

---

## 4. Timeframe

M5 execution; broker D1 bars (shifts 1..41) for the one-side gate.

---

## 5. Expected Behaviour

Very sparse (single symbol, 41-day gate). Under-floor Q02 trade count means
RETIRE per economics rule, accepted a priori (falsification build).

---

## 6. Source Citation

joyny (2022-2024), "Notable numbers strategy", ForexFactory thread 1182304,
https://www.forexfactory.com/thread/1182304 — CADJPY "reverse setup" post
(88/41d/TP1%/SL0.75%/14-22h); 2023-06-23 M5-openings edit. Card: QM5_20105
(g0 cross-approval codex).

---

## 7. Risk Model

As QM5_20104 (RISK_FIXED/RISK_PERCENT, <=1%, KS 3%, news fail-closed,
Friday close).

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 3, ledger STR-009).
