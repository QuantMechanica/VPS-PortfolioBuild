# CODEX BRIEF — Tranche 14 blind specs (STR-137 / STR-141 / STR-143) — FINAL tranche

Repo: C:\QM\repo (branch agents/board-advisor). Same methodology as
tranches 2-13. This is the LAST tranche of the harvest marathon.

## Task

Independent spec per strategy. **Blind rule: do NOT read
`01_spec_claude.md`.** Read ONLY `00_source.md` + the ledger row.

Dirs (write `02_spec_codex.md` into each):

1. `docs/ops/source_harvest/strategies/STR-137-emacross-stochhook-fibtrail-h4/`
   — babypips 70731, PhilipPirrip 2015: EMA20/50 cross + stochastic
   hook entry, fib-extension close-based trail ladder, H4. NOTE: the
   author's no-hard-stop doctrine (p.7, −350 pips) is house-
   inadmissible — handle explicitly. Stoch params on p.6.
2. `docs/ops/source_harvest/strategies/STR-141-dual-supertrend-confluence/`
   — babypips 1152145, sylc 2023: Supertrend(7,0.9)+(7,1.8) +
   EMA(99)-slope + RSI(9) + ADX(9)>25 confluence. NOTE ledger: prose
   says EMA 99, the posted code fragment says 9 — decide and flag.
   Supertrend is not built into MT5 — specify the exact recursion.
3. `docs/ops/source_harvest/strategies/STR-143-sma-cross-pullback-h1/`
   — babypips Art-of-Automation blog 2015-06-05: SMA100/200 cross
   arming + Stochastic(14,3,3) 25/75-level pullback trigger, SL 150 /
   TP 300, BE at +150, EURUSD H1.

## Spec format

As prior tranches: numbered mechanized closed-bar rules, cohort + TF,
inputs, five-hook sketch, every interpretation FLAGGED. House: no
martingale/grid/ML/stacking; one position per magic; RISK_FIXED
backtest / RISK_PERCENT live ≤1%; hard server-side stops mandatory
even where a source uses mental stops (label the deviation); no
invented commission/swap/DST values.

## Delivery

Commit the three files with pathspecs; update-task to REVIEW. Final:
`T14_SPECS_DONE: <paths>`
