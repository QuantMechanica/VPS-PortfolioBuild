# CODEX BRIEF — Tranche 13 blind specs (STR-120 / STR-127 / STR-132)

Repo: C:\QM\repo (branch agents/board-advisor). Same methodology as
tranches 2-12.

## Task

Independent spec per strategy. **Blind rule: do NOT read
`01_spec_claude.md`.** Read ONLY `00_source.md` + the ledger row.

Dirs (write `02_spec_codex.md` into each):

1. `docs/ops/source_harvest/strategies/STR-120-london-orb-3candle-h1/`
   — babypips 326993, Cloudninee 2020: London breakout, H1, range =
   last 3 candles before London open, close-confirmed entry, SL at
   the opposite range end, TP 1.5R, US-close time exit, 6 pairs.
   Author clarifications on p.28-29 and 42 matter.
2. `docs/ops/source_harvest/strategies/STR-127-ndx-ema50-momentum-d1/`
   — babypips 1260721, tommor 2024: NASDAQ100 D1, close vs 50EMA
   regime, daily stop order at prior day's high/low, exit at next
   profitable close. The author's own drawdown critique is in-thread.
3. `docs/ops/source_harvest/strategies/STR-132-usdjpy-pretokyo-straddle/`
   — babypips 38113, marvindoriot 2011: USDJPY, 18:00-20:00 EASTERN
   range, straddle stops at exactly 2.0 pips beyond, 22:00-ET entry
   cutoff, SL 15 pips + spread, split TP 40/70 with BE-move after
   TP1. NOTE overlap analysis mandatory: QM5_20107
   asian-range-straddle-m15 (STR-016) and live QM5_9936 H1 straddle —
   state the concrete deltas you see.

## Spec format

As prior tranches: numbered mechanized closed-bar rules, cohort + TF,
inputs, five-hook sketch, every interpretation FLAGGED. House: no
martingale/grid/ML/stacking; one position per magic (bounded
projections labeled); RISK_FIXED backtest / RISK_PERCENT live ≤1%;
no invented commission/swap/DST values; broker NY-close GMT+2/+3;
UTC/ET/UK anchors via QM_BrokerToUTC + QM_DSTAware patterns.

## Delivery

Commit the three files with pathspecs; update-task to REVIEW. Final:
`T13_SPECS_DONE: <paths>`
