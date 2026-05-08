# QUA-837 Non-Scope Audit Note (2026-05-08)

## Context
During heartbeat verification we executed:

`python framework/scripts/research_dedup_check.py audit --vault %TEMP%\\qua837_empty_vault`

## Observed output
- `ea_id 1001 (breakout-atr) has 35 magic_numbers rows (expected 36)`

## Scope assessment
- This is a data/registry consistency issue in baseline records.
- It is **not** caused by QUA-837 changes (`lint_strategy_wiki.py` + wiki-source extension in `research_dedup_check.py`).
- QUA-837 acceptance evidence remains valid and complete; remaining dependency is Doc-KM documentation registration.
