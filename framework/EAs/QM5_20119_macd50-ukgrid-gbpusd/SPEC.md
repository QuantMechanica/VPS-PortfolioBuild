# QM5_20119_macd50-ukgrid-gbpusd - Strategy Spec

**EA ID:** QM5_20119
**Slug:** `macd50-ukgrid-gbpusd`
**Source:** FF-GUVNOR-MACD50-33362 (see card QM5_20119)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

GBPUSD MACD(5,13,1) four-hour difference momentum on the AUTHOR'S UK
grid: custom 4h bars aligned to UK civil 00/04/08/12/16/20, aggregated
in-EA from closed M15 data (the thread explicitly declines broker-grid
equivalence); UK-DST via calendar arithmetic (last Sunday March/October)
patterned on QM_DSTAware's US helper. At UK 08/12/16/20 Mon-Fri: delta =
MACD_main(just-closed custom bar) − MACD_main(two bars earlier); >=
+0.00050 absolute price → long, <= −0.00050 → short; flat-only; no
backfill. Netted campaign: SL 30 pips; half out at +30 + breakeven;
remainder TP +45. MACD main = manual EMA(5)−EMA(13) recursion on custom
closes, 240-bar fixed seed. COMPLEXITY FLAG: heaviest EA of the harvest.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-051-macd50-h4-momentum/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 5 | 5 | source-fixed |
| `strategy_macd_slow` | 13 | 13 | source-fixed |
| `strategy_delta_price` | 0.00050 | 0.00050 | absolute price delta (5 pips) |
| `strategy_p1_tp_pips` | 30.0 | 30 | half-out level (source-fixed) |
| `strategy_p2_tp_pips` | 45.0 | 45 | remainder TP (source-fixed) |
| `strategy_sl_pips` | 30.0 | 30 | source-fixed |
| `strategy_seed_bars` | 240 | 240 | custom-bar EMA seed depth (determinism) |

---

## 3. Symbol Universe

GBPUSD.DWX (0) — author-explicit. Magic 201190000.

---

## 4. Timeframe

Chart `M15` (aggregation base); strategy grid = custom UK 4h bars.

---

## 5. Expected Behaviour

~60-150 signals/yr; four decisions/day; skipped boundaries on incomplete
bars (weekends/holidays/data gaps).

---

## 6. Source Citation

the_guvnor (2007), "50 +/- MACD 4hour", ForexFactory thread 33362,
https://www.forexfactory.com/thread/33362/50-macd-4hour — post #1, plan
v0.1 p.19-20, grid evidence p.8/31-32. Card: QM5_20119 (g0 cross-approval
codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (1% campaign, netted two-leg
source campaign); KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news
blackout fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 7, ledger STR-051).
