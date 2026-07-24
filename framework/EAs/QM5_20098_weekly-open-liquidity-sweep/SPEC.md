# QM5_20098_weekly-open-liquidity-sweep — Strategy Spec

**EA ID:** QM5_20098
**Slug:** `weekly-open-liquidity-sweep`
**Source:** `FF-SOL72-2025-WOLS`
**Author of this spec:** Claude (board-advisor; codex cross-review per build run 2026-07-24)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

Weekly-open liquidity-sweep reversal on M15 (metals). Long side: after an M15 bar trades below BOTH the weekly open and the previous day low (sell-side liquidity sweep), track the most recent bearish M15 candle wholly below the weekly open (order block; formed after the sweep). When an M15 bar closes above the OB high, place a BUY LIMIT at the OB high with SL one tick below the OB low; at fill, TP = fill + 2*(fill-SL). Pending expires at week end and cancels if an M15 close breaches the OB low pre-fill. One pending/position per symbol; opposite side blocked while exposed. Optional tick-volume confirmation input, default OFF (source p.25 demotes volume). Short mirrors.

Authoritative hook-level spec: `docs/ops/source_harvest/strategies/STR-021-weekly-open-liquidity-sweep/04_spec_final.md`
(reconciled Claude/Codex, tie-breaks documented in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_vol_confirm_enabled` | false | false/true | optional volume confirmation (variant WOLS_021_VOLOPT, default off) |
| `strategy_vol_mult` | 2.0 | 2.0 | tick-volume multiple vs SMA (if enabled) |
| `strategy_vol_lookback` | 96 | 96 | tick-volume SMA window (if enabled) |
| `strategy_rr_ratio` | 2.0 | 2.0 | TP = fill +/- rr*R from actual fill (source option, variant _RR2) |

---

## 3. Symbol Universe

XAUUSD.DWX (slot 0), XAGUSD.DWX (slot 1) — the author's stated gold transfer target plus silver. Magics 200980000-200980001.

---

## 4. Timeframe

M15 execution; weekly open from broker W1 bar, previous-day extremes from closed D1 bars (variant _BROKERWK: broker time, not the author's UTC — constant 2-3h anchor shift documented).

---

## 5. Expected Behaviour

Episodic event-driven reversal: requires weekly-level sweep + OB + confirmation + retrace fill. Est. 8-25 fills/yr/symbol — thinnest of the three builds, Q02-floor watch flagged. Intraweek holds; Friday-close flattens residuals.

---

## 6. Source Citation

Sol72 (2025), "Algorithm for Entering a Trade" in ForexFactory thread 1328051 (trading system based on monthly, weekly and daily levels), https://www.forexfactory.com/thread/1328051 — PDF p.14-15 (algorithm), p.12/p.27 (M15 candles), p.25 (final hierarchy; volume=confirmation only), p.11/p.16 (tick-volume caveat, gold/oil intent). Card: QM5_20098 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live; risk on OB-geometry stop (variable); setups with sub-stops-level geometry are SKIPPED, never widened; per-trade cap <=1%; KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run, ledger STR-021).
