# Card heading language intake gate

- Task: `fe6e8a54-2815-4c4c-95dd-09dc2ed3faff`
- Date: 2026-08-23
- Branch: `agents/board-advisor`
- Implementation commit: `db7fca1f4`
- Verdict: PASS

## Scope and decision

New Markdown Strategy Cards now fail closed at both deterministic intake boundaries when an ATX section heading is a mapped German heading or a conservatively identified unseen German heading. Existing approved cards are intentionally not rewritten: they remain historical evidence, retain their content identity, and continue to receive render-only English normalization in the archive dashboard.

The render and intake paths now share one exact German-to-English heading map. A previously unseen probable German heading is returned in the structured `unmapped_headings` result with `normalization_map_update_required=true`, making map extension explicit instead of silently translating or altering source content. Ambiguous cross-language headings (`Filter`, `Signal`, `Status`) remain valid.

## Enforcement

- `agent_router.update_task`: rejects a `research_strategy` transition to `REVIEW` before duplicate admission when the new review card violates the heading-language contract.
- `farmctl.approve_card`: rejects a non-approved-source card before mutation or movement into `cards_approved`.
- `archive_matrix`: imports the same exact normalization map and leaves unknown headings untouched.
- Historical cards already located under `cards_approved` bypass the new approval-time check; no corpus rewrite or factory-wide retroactive block was introduced.

## Focused verification

- `python -m py_compile tools/strategy_farm/card_heading_language.py tools/strategy_farm/farmctl.py tools/strategy_farm/agent_router.py tools/strategy_farm/dashboards/archive_matrix.py` — PASS.
- `python -m pytest tools/strategy_farm/tests/test_card_heading_language.py -q` — 4 passed.
- `python -m pytest tools/strategy_farm/tests/test_agent_router.py -q` — 33 passed.
- `python -m pytest tools/strategy_farm/tests/test_mnt012_build_guards.py -q` — 11 passed.
- `git diff --cached --check` before commit — PASS.

No card, verdict, pipeline state, terminal state, or historical corpus content was changed.
