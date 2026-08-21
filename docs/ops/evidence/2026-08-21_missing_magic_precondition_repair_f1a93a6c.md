# Missing-magic build precondition repair — f1a93a6c

Date: 2026-08-21  
Branch: `agents/board-advisor`  
Router task: `f1a93a6c-be62-42e4-b703-7e4a30def91f`

## Outcome

Build preflight no longer ends at a non-actionable “missing magic rows” error.
It now distinguishes:

1. `never_allocated` — eligible for the governed allocator when the card has an
   active exact registry identity and explicit valid DWX symbols;
2. `allocated_then_retired` — review-required and explicitly forbidden from
   being revived;
3. `resolver_regeneration_missed` — regenerate and verify the resolver; do not
   allocate a second set of rows.

For an otherwise build-ready card, a failed magic precondition creates one
deduplicated router `ops_issue` carrying the exact card, declared symbols,
diagnosis, acceptance contract, evidence target, and executable governed
allocator command. The original build remains blocked until a fresh precheck
proves both active rows and resolver presence.

`governed_magic_allocator.py` now accepts repeatable exact `--card` inputs.
This mode remains bounded, uses the existing single allocator lock and rollback
transaction, and refuses any EA-ID with retired magic history instead of
deleting or reviving it.

## Root cause and full cohort

Both reported examples were never allocated:

- `QM5_11899`: zero active, retired, or other magic rows; exact-card dry run
  plans ten card-declared rows.
- `QM5_12946`: zero active, retired, or other magic rows; exact-card dry run
  plans three card-declared rows.

The full approved-card/active-registry inventory contains **212 EAs**, all
classified `never_allocated`. There are zero `allocated_then_retired` and zero
`resolver_regeneration_missed` rows in this exact cohort. Every affected EA is
listed with card path, slug, target symbols, row counts, directory state,
classification, and required action in:

`artifacts/reviews/f1a93a6c-be62-42e4-b703-7e4a30def91f.json`

Receipt SHA-256:
`8bb3efd018a645733bb4e2961288dfc888e01da5b3c862b5e091a346fb098a08`.

## Actionable handoffs

- `QM5_11899` -> router task `81b4cf48-ff12-430f-b824-8d5d1f45bc0e`
  (`TODO`, governed allocation).
- `QM5_12946` -> router task `09766d8d-27fd-409b-8a3c-e80a5c2edfd9`
  (`TODO`, governed allocation).

Repeating the QM5_11899 build precheck returned the existing task ID, proving
the handoff is idempotent rather than a task-flood source. The other 210 rows
are reported but were not bulk-enqueued; each receives the same deduplicated
handoff when its deterministic build precheck is reached.

## Verification

- Exact-card dry run: QM5_11899 -> 1 EA / 10 rows / 0 retired rows deleted.
- Exact-card dry run: QM5_12946 -> 1 EA / 3 rows / 0 retired rows deleted.
- Focused regression suite: `82 passed, 12 subtests passed`.
- Python syntax compilation: PASS.
- `git diff --check` on scoped code and tests: PASS.
- Implementation commit: `90ab1311b`.

No magic row, resolver, EA source, pipeline row, terminal, T_Live setting, or
AutoTrading setting was changed by this task. Allocation remains separate,
bounded router work and cannot be mistaken for a pipeline verdict.
