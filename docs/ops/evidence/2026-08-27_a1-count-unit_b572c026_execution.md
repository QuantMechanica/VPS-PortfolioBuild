# Execution evidence — OWNER-DEC-A1-COUNT-UNIT = YES

Router task: `ee10e42f-c3cb-5697-8e47-fa00312cebe1` (`QM-TODO-20260824-520`)
Mode: `DOCUMENT_AND_VERIFY` — no gate, threshold, or runtime logic changed.

## Decision being executed

OWNER receipt `b572c026-18ed-464b-aa4e-ba0730f77232`, decided 2026-08-27T11:49:11Z:
question "Soll der >=25-Buch-Trigger primaer terminale (EA, Symbol)-Paare zaehlen?" —
answer **YES**. Selected effect: "Die laufende v4-Auffangregel bleibt bestaetigt; keine
Pipeline-Aenderung ist noetig."

This ratifies sub-decision A1 in
`decisions/2026-08-23_owner_gate_manifest_v4_linear.md`, which had already been
executed under the Stehende Vollmacht (Auffangregel, 2026-08-20) 12h-fallback since
2026-08-23: `(EA, Symbol)` pairs at terminal Q14 are the primary >=25 book trigger;
distinct EAs and strategy families are reported alongside as diversity controls, not
conflated into the primary count.

## Runtime verification (read-only)

`tools/strategy_farm/book_build_guard.py`:
- `MIN_QUALIFIED_PAIRS = 25` (line 28) gates on `qualified_pairs`, which is
  `len(measured_rows)` where each row is one `(ea_id, symbol)` pair whose
  `highest_contiguous_valid_gate == terminal_gate` (`_qualified_pair_rows`,
  lines 72-84).
- `terminal_gate` is resolved via `gate_manifest.load_gate_manifest().terminal_requalification_gate`
  (line 189-190), which is contract-version-aware: it returns the gate whose
  `evidence_role` starts with `SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT`
  (`gate_manifest.py` lines 212-231) — Q14 under the active v4 contract, matching the
  Alt->Neu mapping table in the decision record (Q14 = Best-Settings Head-to-Head +
  Holdout, terminal per-EA gate).
- `distinct_eas` (`_count_distinct_eas`) and `strategy_families`
  (`_count_strategy_families`, via `concentration_tail.family_fingerprints`) are
  computed separately from `qualified_pairs` and reported as independent fields on
  `GuardResult` (lines 40-46) — they are diversity controls, never substituted for
  the primary count and never combined into a single trigger number.
- `check_book_build_allowed` (lines 173-218) only compares `qualified_pairs` against
  `MIN_QUALIFIED_PAIRS`; `distinct_eas`/`strategy_families` do not gate `allowed`,
  consistent with "report ... alongside" rather than a second hard threshold.

Verdict: runtime already implements the selected effect exactly as decided. No code
change required or made.

## Governance documentation verification

`docs/ops/OPEN_ITEMS_STATUS.md` line 83 (section "0d - Ultracode-Sitzung 2026-08-23
nachmittags") still listed A1 inside the open `Entscheidungsschlange (OWNER, <=5)` as
"Auffangregel läuft" (standing-authority recommendation running, not yet OWNER-ratified).
That line is stale as of 2026-08-27T11:49:11Z and is corrected by this task to state the
decision is OWNER-ratified YES, receipt `b572c026`.

Vault mirror `G:\My Drive\QuantMechanica - Company Reference\03 Pipeline\Pipeline
Rebaseline Directive 2026-08-23.md` could not be checked or updated this cycle: the `G:`
drive is not mounted in this worktree session (`C:\QM\worktrees\claude-orchestration-2`).
Flagged as INFRA_BLOCKED, not silently skipped; a future cycle with `G:` mounted should
verify/update the vault mirror for consistency.

## Scope discipline

No gate threshold, criterion, or candidate-universe logic touched. No factory pause,
T_Live, AutoTrading, or book-construction action taken. This is a documentation
correction plus a read-only runtime verification, matching `implementation_mode:
DOCUMENT_AND_VERIFY` and the task's `forbidden_actions`.

## Artifacts touched this task

- `docs/ops/OPEN_ITEMS_STATUS.md` (governance wording correction)
- This evidence file
