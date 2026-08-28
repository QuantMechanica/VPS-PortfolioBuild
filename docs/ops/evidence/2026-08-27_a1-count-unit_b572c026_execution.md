# OWNER decision execution — OWNER-DEC-A1-COUNT-UNIT

Date: 2026-08-28
Task: `agent_task ee10e42f-c3cb-5697-8e47-fa00312cebe1` (QM-TODO-20260824-520)
Decision: `OWNER-DEC-A1-COUNT-UNIT` = YES, receipt `b572c026-18ed-464b-aa4e-ba0730f77232`,
decided 2026-08-27T11:49:11Z.
Question: "Soll der >=25-Buch-Trigger primaer terminale (EA, Symbol)-Paare zaehlen?"
Selected effect: "Die laufende v4-Auffangregel bleibt bestaetigt; keine Pipeline-Aenderung
ist noetig."
Mode: `DOCUMENT_AND_VERIFY` — no gate/runtime logic changes; verification only.

## What this ratifies

Sub-decision A1 in `decisions/2026-08-23_owner_gate_manifest_v4_linear.md`, already executed
under the Stehende Vollmacht Auffangregel on 2026-08-23: the >=25 book-build trigger counts
terminal **(EA, Symbol) pairs**, with distinct EAs and strategy families reported alongside
as diversity controls (not as the trigger count itself).

## Verified implementation (no drift found)

`tools/strategy_farm/book_build_guard.py`:

- `MIN_QUALIFIED_PAIRS = 25` (line 24) — the trigger constant.
- `_qualified_pair_rows()` (line 71) builds the candidate pool via
  `rebaseline_census.build_pairs()`, keyed `(ea_id, symbol)`, and keeps only rows whose
  `highest_contiguous_valid_gate == terminal_gate`. This is the primary count unit —
  literally an `(EA, Symbol)` pair count.
- `terminal_gate` is resolved from `gate_manifest.load_gate_manifest().terminal_requalification_gate`
  (never a hardcoded literal) — confirmed to resolve to `Q14` under the active v4 manifest
  (see A2 execution artifact for the manifest verification).
- `_count_distinct_eas()` (line 96) and `_count_strategy_families()` (line 84) compute the
  two diversity controls from the same qualified-row pool, surfaced on `GuardResult` as
  `distinct_eas` and `strategy_families` fields alongside `qualified_pairs` — reported, not
  substituted for the trigger.
- `check_book_build_allowed()` (line 171) gates solely on
  `qualified_pairs < MIN_QUALIFIED_PAIRS` (line 195) for the count condition — distinct EAs
  and strategy families are never used as the trigger threshold, only carried through to the
  `GuardResult` for reporting.

This is an exact match to the ratified recommendation: `(EA, Symbol)` pairs are the primary
operative count; distinct EAs and strategy families are reported diversity controls, not
alternate trigger units.

## Acceptance check

- No gate or runtime logic changes made — pure verification. `qualified_pairs`,
  `distinct_eas`, and `strategy_families` remain three distinct, non-conflated fields on
  `GuardResult`.
- A durable evidence artifact (this file) records every checked surface.

## Conclusion

A1 is already correctly implemented; nothing to change. The router task moves to REVIEW for
independent orchestrator close-out per `review_required: INDEPENDENT_ORCHESTRATOR_CLOSEOUT`.
