# QM5_20112_ema9-pullback-m15 - Strategy Spec

**EA ID:** QM5_20112
**Slug:** `ema9-pullback-m15`
**Source:** FF-FELIKS-EMA9-242787 (see card QM5_20112)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

GBPUSD M15 EMA9 pullback breakout: an EMA9 close-cross opens a directional
setup (opposite cross flips it); each closed bar is a rolling candidate —
the first whose extreme stays >=5 pips off the EMA (long: low−ema >= 5
pips) AND whose close exceeds the previous bar's extreme (long: close >
prev high) triggers a market entry at the next bar; the setup is consumed
by its first entry. SL = previous bar's extreme -/+ (1 pip + current
spread) (sell-side source typo read as above the prev high, documented);
TP = 2R. One position.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-036-ema9-pullback-breakout/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 9 | 9 | source-fixed |
| `strategy_min_gap_pips` | 5.0 | 5 | pullback gap off the EMA (source-fixed) |
| `strategy_sl_buffer_pips` | 1.0 | 1 | + current spread (source-fixed) |
| `strategy_rr` | 2.0 | 2 | TP = rr × SL distance (source-fixed) |

---

## 3. Symbol Universe

GBPUSD.DWX (0) — the author's stated pair. Magic 201120000.

---

## 4. Timeframe

M15 execution; closed-bar reads; replay-based restart of the setup state.

---

## 5. Expected Behaviour

~100-200 entries/yr; abandoned-thread provenance = low prior;
falsification build.

---

## 6. Source Citation

Feliks (~2010), "Simple 1 EMA strategy on M15", ForexFactory thread
242787, https://www.forexfactory.com/thread/242787/simple-1-ema-strategy-on-m15
— rules post p.2-3, candidate Q&A, withheld-filters admission p.12-13.
Card: QM5_20112 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade); KS_DAILY_LOSS 3%;
KS_PORTFOLIO_DD external guard; news blackout fail-closed; Friday close
21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 5, ledger STR-036).
