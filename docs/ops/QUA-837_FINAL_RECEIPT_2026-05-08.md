# QUA-837 Final Receipt (2026-05-08)

## Acceptance Criteria Mapping
- `framework/scripts/lint_strategy_wiki.py` committed
  - Evidence commit: `f5b6137b`
- CLI `python lint_strategy_wiki.py [--vault PATH]` with default path
  - Verified in evidence doc; default shown as `G:\My Drive\09 Strategy Wiki`
- `research_dedup_check.py` reads cards + wiki and reports duplicates
  - Runtime evidence includes both CLEAN and DUPLICATE verdict paths
  - Evidence commits: `49dc3455`, `df2b064a`, `c3a6967c`
- Closeout with commit hash + sample output
  - Consolidated in `docs/ops/QUA-837_CLOSEOUT_EVIDENCE_2026-05-08.md`

## Relevant Commits
- `f5b6137b` Add strategy wiki lint and dedup cross-source checks
- `49dc3455` docs(QUA-837): add closeout evidence and CLI proof
- `df2b064a` docs(QUA-837): add duplicate-verdict runtime evidence
- `c3a6967c` docs(QUA-837): add lint runtime measurement evidence

## Remaining Delegated Item
- Owner: Doc-KM
- Action: add entries for
  - `framework/scripts/lint_strategy_wiki.py`
  - `framework/scripts/research_dedup_check.py`
  in canonical `Tools and Scripts` documentation path.

## Current Operational Note
- `research_dedup_check.py list --vault %TEMP%\\qua837_empty_vault` currently reports `0 wiki` in that temp vault snapshot (expected for empty test vault), while card and registry sources are loaded correctly.
