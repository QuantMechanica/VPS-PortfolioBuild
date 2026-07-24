# QM5_20109_vr-gap-fade-d1 - Strategy Spec

**EA ID:** QM5_20109
**Slug:** `vr-gap-fade-d1`
**Source:** FF-VOLDEMAR-VRGAP-1394867 (see card QM5_20109)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

Index D1 gap fade: at each new D1 bar, gap = Close(1) − Open(0) (the
immutable new-bar open is the only shift-0 read). |gap| strictly above the
minimum-gap threshold: open below prior close (down-gap) → BUY at market;
open above → SELL. TP = the gap-closure level (the prior close), attached
in management with attained-target market close + per-bar retry pacing
(QM5_20098 pattern); SL = fixed points, attached AT ENTRY (house deviation
from the source's fully-deferred protection — never unprotected). One
position; no other filters.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-027-vr-gap-fade/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_min_gap_points` | 100 | Q03 domain | minimum gap (PROVISIONAL, non-authorial, flagged) |
| `strategy_sl_points` | 300 | Q03 domain | fixed SL distance (PROVISIONAL, non-authorial, flagged) |

---

## 3. Symbol Universe

NDX.DWX (0), GDAXI.DWX (1). Magics 201090000-201090001.

---

## 4. Timeframe

D1 execution; gap measured open-vs-prior-close on broker D1 bars.

---

## 5. Expected Behaviour

Episodic (index overnight/weekend gaps); floor risk if .DWX daily bars are
near-continuous — below-floor Q02 RETIREs. Price-unit meaning of 100/300
points per symbol demonstrated in Q02 evidence review.

---

## 6. Source Citation

Voldemar227 (n.d., ~2024-2025), "VR Gap Open Source Trading Strategy",
ForexFactory thread 1394867,
https://www.forexfactory.com/thread/1394867/vr-gap-open-source-trading-strategy
(EA code https://www.mql5.com/en/code/9994 / /72239) — post #1 (complete EA
description). Card: QM5_20109 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade off the fixed-point
SL); KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout
fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 4, ledger STR-027).
