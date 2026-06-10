# DL-074 — Q02–Q04 Compute Staging (Q04-early probe, symbol staging, prescreen completion, tiered ablation)

- **Date:** 2026-06-10
- **Decided by:** OWNER ("Do all of them!", 2026-06-10), implemented by Claude
- **Status:** ACTIVE
- **Supersedes:** nothing — gate *criteria* are unchanged everywhere; this
  decision only reorders and stages *compute*. OWNER gate philosophy
  (deliberately conservative robustness filters) is untouched.

## Decision

1. **Q04-early probe.** Every Q02-PASS primary (non-exploration setfile) is
   promoted directly to a Q04 walk-forward probe on its DEFAULT parameters,
   in parallel with the normal Q02→Q03 path. The §10b 50-point Q03 parameter
   grid spawns ONLY after the EA's default params have survived Q04
   (PASS/PASS_SOFT) for that symbol. Rationale: ~88% of EAs die at Q04
   (walk-forward overfitting); spending a 50-run grid before that test
   optimizes strategies that were never robust. Cascade dedupe: any existing
   Q04 row for the same (ea, symbol, setfile) now blocks a duplicate
   promotion regardless of source.

2. **Q02 symbol staging (OWNER-amended).** Multi-symbol cards enqueue a
   diverse stage-1 wave of ≤3 symbols (round-robin across index/metal/fx
   buckets), the remainder is deferred to
   `state/q02_deferred_symbols.json`. OWNER correction incorporated: symbols
   differ — a single-symbol gate would miss chances. Therefore deferred
   symbols are NEVER killed: they are promoted as soon as ANY stage-1 symbol
   passes Q02, or whenever the queue has spare capacity (pending < 50% of
   the sweep ceiling). Deferral is deprioritization, not filtering.

3. **Q02 prescreen completed + frequency guard.** The 6-month prescreen
   (P2-era design) was already applied to Q02 spawns, but the
   prescreen→full-window requeue stage only existed in farmctl's dispatch
   path — terminal_worker (the production claim path) recorded prescreen
   results as FINAL. Fixed: worker now requeues prescreen-PASS for the full
   window (`p2_prescreen_done`), marks prescreen-FAIL with the explicit
   `P2_PRESCREEN_` reason (final by design). Frequency guard: cards with
   `expected_trades_per_year_per_symbol < 12` skip the prescreen entirely
   (DL-070 swing protection — a seasonal card can legitimately trade 0 times
   in 6 months). Backfill: 762 thin-graded Q02 PASSes requeued for full
   confirmation runs (`claude_prescreen_backfill_2026-06-10.json`).

4. **Tiered ablation budget.** §10a random ablations per Q02-PASS: 8
   variants for priority_track EAs, 3 for the rest (was a flat 5).

## What is hard-bounded vs. open

- Hard-bounded and UNCHANGED: all Qxx gate criteria, phase naming, verdict
  semantics, evidence requirements.
- Changed (open interior): order and quantity of backtest compute per card.

## Evidence

- Audit + implementation: `docs/ops/ACCELERATION_2026-06-10.md`
- Thin-PASS scale: 764 of ~2,360 Q02 PASS rows were 6-month-graded
  (`smoke_year_count=1`, intraday primaries), 762 requeued.
- Implementation commits on `agents/board-advisor` (farmctl.py,
  terminal_worker.py, sweep_enqueue_built_eas.py).

## Revisit triggers

- Q04 probe queue depth starves Q03/Q05+ work (phase rank should prevent it).
- Deferred-symbol promotion leaves cards starved despite spare capacity.
- Prescreen FAIL rate on 6-month windows materially exceeds the full-window
  FAIL rate for the same cohort (would indicate the cheap-kill is too harsh).
