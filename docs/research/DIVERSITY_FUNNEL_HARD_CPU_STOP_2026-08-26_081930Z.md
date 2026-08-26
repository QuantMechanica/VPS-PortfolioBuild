# Diversity funnel: full-saturation hard CPU stop

Date: 2026-08-26 UTC (`2026-08-26T08:19:30Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `4e5824c1034b4638e6646f1485726eeb393870ab`

Status: the highest-diversity approved frontier card fails the governed magic
precondition; the distinct branch-scoped FX infrastructure repair is already
complete; stopped at the explicit backtest CPU ceiling before any claim,
build, registry, queue, dispatch, reservation, or tester mutation

## Priority 1: diverse build frontier

The live governed allocation inventory generated at `2026-08-26T08:18:59Z`
identifies `QM5_41140_nzdjpy-carry-unwind-crisis-momentum` as an approved,
structural D1 FX card on `NZDJPY.DWX`. Its primary source is the peer-reviewed,
DOI-bearing Brunnermeier, Nagel and Pedersen carry-crash paper; the card records
`r1_track_record: TIER_A`, `ml_required: false`, and a fixed-risk backtest
contract.

This card is not build-admissible yet. The identity registry contains exactly
one active `41140` row, but the card has zero active or historical magic rows
and no EA directory. The inventory classification is `never_allocated` with
required action `GOVERNED_ALLOCATE`. The `qm-build-ea-from-card` preflight
therefore fails before implementation. Existing farm task
`8036a966-9f6b-4094-9280-820c6c75ba0e` already records the governed magic
precondition and was review-closed as an honest no-mutation refusal. No second
claim or allocator mutation was made.

## Priority 2: diverse Q02 infrastructure recovery

The distinct branch-scoped repair task is
`46e34047-c661-462c-96d5-b4f9d76914db` for the ten-symbol FX sleeve
`QM5_11900_kobasfx-4ema-macd-sentiment-h1`. It was claimed by
`codex:agents/board-advisor`, completed, and review-closed `APPROVED` on
2026-08-24. Its durable verdict says the repair commit is verified and compile
plus Q02 remain deferred at the 97% CPU ceiling. Re-claiming the task or
creating another queue row would duplicate completed coordination rather than
advance a distinct EA.

## Binding capacity stop

Five fresh one-second whole-host CPU readings were `100.00%`, `100.00%`,
`99.90%`, `100.00%`, and `100.00%` (average `99.98%`, maximum `100.00%`).
The ceiling binds when either average or maximum is at least `97%`; both bind
in this observation. Five `metatester64` processes were present, and the
immediately preceding farm slot scan attributed active factory work to T1, T3,
T4, T7, T8, and T9.

Per the mission stop condition, no new structural edge was mechanized, no farm
task was claimed or advanced, no card or EA was created, no registry or magic
row changed, no compile or build check ran, and no Q02 row, dispatch,
reservation, terminal, or tester action followed.

## Non-duplicate evidence delta and safety

The prior receipt at `2026-08-26T07:45:57Z` recorded `93.53%` average and
`99.32%` maximum CPU with five tester processes, so only its maximum bound the
ceiling. This sample is materially different: average CPU rose by `6.45`
percentage points and both average and maximum bind at near-total saturation.
It also captures two fresh coordination facts—the governed `QM5_41140`
preflight and the already-completed `QM5_11900` repair—without duplicating an
EA, task claim, or work-item row.

- No portfolio gate, portfolio KPI, or Q08 contribution path changed.
- No T_Live manifest, terminal, AutoTrading state, or live artifact changed.
- Concurrent unrelated worktree changes were preserved and excluded.
- Machine-readable evidence is in
  `artifacts/diversity_funnel_hard_cpu_stop_20260826T081930Z_board_advisor.json`.
