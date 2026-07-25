# CODEX BRIEF — Tranche 11 blind specs (STR-085 / STR-086 / STR-087)

Repo: C:\QM\repo (branch agents/board-advisor). Same methodology as
tranches 2-10 (see docs/ops/source_harvest/CODEX_BRIEF_t10_specs_*.md).

## Task

Write your INDEPENDENT spec for each of the three strategies below.
**Blind rule: you MUST NOT read `01_spec_claude.md` in these dirs.**
Read ONLY `00_source.md` (verbatim source extract) plus the ledger row in
docs/ops/source_harvest/SOURCE_LEDGER.csv.

Dirs (write `02_spec_codex.md` into each):

1. `docs/ops/source_harvest/strategies/STR-085-stoch-ema50-pullback/`
   — FF thread 837301, GazFx stoch(5,3,3)+EMA50 H4 trend-continuation.
   NOTE: prior build QM5_10017 exists; per your own G0_REVIEW_T6 contest
   its 5-bar structure stop / ATR slope quantification / max-stop, time
   and opposite-cross exits were unsourced — spec strictly from THIS
   source only.
2. `docs/ops/source_harvest/strategies/STR-086-dibs-inside-bar/`
   — FF thread 86766, DIBS method (jarroo/PeterCrowns), H1 inside-bar
   breakout off the 06:00-GMT daily open.
3. `docs/ops/source_harvest/strategies/STR-087-roundnum-sma50-h1/`
   — FF thread 922813, Fx-ken 25-pip round-number pendings + SMA50 H1.
   NOTE: prior build QM5_10039; your contest found its 3-bar pending
   expiry / 10-bar time exit / spread veto / opposite-grid gate
   unsourced — again spec strictly from THIS source.

## Spec format (as in prior tranches)

Rules (numbered, mechanized, closed-bar), symbol cohort + TF, inputs
with defaults, hooks sketch (V5 skeleton 5 hooks), every interpretation
beyond the literal source FLAGGED. House constraints: no martingale/
grid/ML/stacking; one position per magic (bounded projections must be
labeled); RISK_FIXED backtest / RISK_PERCENT live ≤1%; no invented
commission/swap/DST values; broker time = NY-close GMT+2/+3, GMT/UTC
anchors via QM_BrokerToUTC (QM_DSTAware.mqh).

## Delivery

Write the three `02_spec_codex.md` files, then commit them on the
current branch with pathspecs:
`git commit docs/ops/source_harvest/strategies/STR-085-stoch-ema50-pullback/02_spec_codex.md docs/ops/source_harvest/strategies/STR-086-dibs-inside-bar/02_spec_codex.md docs/ops/source_harvest/strategies/STR-087-roundnum-sma50-h1/02_spec_codex.md -m "docs(harvest): codex blind specs tranche 11"`

Finish your final message with the line:
`T11_SPECS_DONE: <comma-separated paths>`
