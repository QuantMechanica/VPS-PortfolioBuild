# QM-TODO-20260820-003: public Strategy Archive contract

Date: 2026-08-21  
Router task: `ee42fad4-b12e-40bf-99e5-a28ef4b07dfb`  
Branch: `agents/board-advisor`  
Status: Codex-reviewed implementation; REVIEW only

## Outcome

The staging-only emitter in
`tools/strategy_farm/website_archive_contract.py` produces an addressable
EA -> Strategy Card -> symbol/Q-gate result -> opaque report-reference tree.
It reads the clean farm view without mutating the database and writes only to
`D:/QM/exports/website_contract_preview/`. Publication is not performed.

The public projection is allowlist-based. Unknown fields are dropped, sensitive
keys are refused even if accidentally allowlisted, and free text is scrubbed for
absolute Windows/UNC/POSIX paths, file URIs, account/login/magic identifiers,
credentials, IP addresses, and labelled host/server/VPS details. The writer
refuses targets below the canonical `public-data/` tree, leaving publication
behind the existing public-snapshot export guard.

Codex review found and repaired two gaps in the Claude draft:

- drive-letter paths using `/`, or paths containing spaces, could leave a
  sensitive tail visible; the fail-closed path patterns now cover both forms;
- the strategy-summary era roll-up stored the mapped Q phase and could label a
  newest legacy P-row as current; it now preserves the raw storage phase.

Regression tests cover both repairs while proving public HTTPS citations remain
unchanged.

## Focused verification

```text
python -m pytest tools/strategy_farm/tests/test_website_archive_contract.py \
  tools/strategy_farm/tests/test_mission_control_v2_data.py -q
59 passed in 7.60s

python -m py_compile tools/strategy_farm/website_archive_contract.py \
  tools/strategy_farm/mission_control_v2_data.py
PASS

git diff --check -- <four implementation/test paths>
PASS
```

Live read-only generation completed successfully:

```text
eas=3737
cards=3271
gate_results=24811
reports_referenced=23506
```

Durable preview files:

- `D:/QM/exports/website_contract_preview/strategy_summaries.json`
- `D:/QM/exports/website_contract_preview/strategy_cards_public.json`
- `D:/QM/exports/website_contract_preview/gate_results.json`
- `D:/QM/exports/website_contract_preview/report_manifest.json`
- `D:/QM/exports/website_contract_preview/index.json`

No live export, terminal, AutoTrading, T_Live, work-item verdict, or pipeline
gate was touched. This artifact remains for independent review and does not
self-authorize publication.
