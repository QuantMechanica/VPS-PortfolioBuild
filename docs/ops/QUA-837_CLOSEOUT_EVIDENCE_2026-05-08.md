# QUA-837 Closeout Evidence (2026-05-08)

## Scope
- Issue: QUA-837
- Topic: Strategy Wiki tooling (`lint_strategy_wiki.py` + wiki extension in `research_dedup_check.py`)

## Commit Evidence
- `framework/scripts/lint_strategy_wiki.py`
  - `f5b6137bf42834003fb78a3b7d431d373efe36a6` (2026-05-08T13:33:40+02:00)
- `framework/scripts/research_dedup_check.py`
  - `f5b6137bf42834003fb78a3b7d431d373efe36a6` (2026-05-08T13:33:40+02:00)

## Verification Commands + Outputs
1. Unit tests
- Command:
  - `python -m unittest framework.scripts.tests.test_lint_strategy_wiki framework.scripts.tests.test_research_dedup_check -v`
- Result:
  - `Ran 5 tests in 0.040s`
  - `OK`

2. Lint script on empty vault
- Command:
  - `python framework/scripts/lint_strategy_wiki.py --vault %TEMP%\\qua837_empty_vault`
- Result:
  - `OK: no strategy wiki lint violations`

3. Dedup check (clean path)
- Command:
  - `python framework/scripts/research_dedup_check.py check --slug hb90-slug --strategy-id SRC06_S06 --vault %TEMP%\\qua837_empty_vault`
- Result:
  - `VERDICT: CLEAN — no duplicate detected; ea_id allocation OK.`

4. Dedup cross-source duplicate detection (test evidence)
- Source: unit test execution output
- Result snippet:
  - `EXACT DUPLICATE: [wiki] ...\\dup.md (dup-slug / SRC12_S03)`
  - `VERDICT: DUPLICATE — link as _v<n> enhancement per DL-029/033, NOT new ea_id`

## Working Tree Check (target files)
- Command:
  - `git status --short -- framework/scripts/lint_strategy_wiki.py framework/scripts/research_dedup_check.py framework/scripts/tests/test_lint_strategy_wiki.py framework/scripts/tests/test_research_dedup_check.py`
- Result:
  - clean (no pending changes)

## Outstanding Item (Delegated)
- Acceptance criterion: both scripts listed in `06 Infrastructure/Tools and Scripts.md` (delegated to Doc-KM).
- Current repo check: no matching path found in this workspace (`rg --files | rg "Tools and Scripts\\.md$|Infrastructure"` returned no hit).
- Unblock owner/action:
  - Owner: Doc-KM
  - Action: provide/update canonical tooling index path and add entries for:
    - `framework/scripts/lint_strategy_wiki.py`
    - `framework/scripts/research_dedup_check.py`

## CLI Availability Evidence
- `python framework/scripts/lint_strategy_wiki.py --help`
  - shows `--vault` with default `G:\My Drive\09 Strategy Wiki`
- `python framework/scripts/research_dedup_check.py --help`
  - shows subcommands: `check`, `list`, `audit`
