# Codex Router Cap 5

Date: 2026-05-22
Status: REVIEW_READY
Router task: `b3040550-b0d2-4a38-a909-13bac766bb8f`

## Change

Raised only Codex's `DEFAULT_AGENT_REGISTRY` cap in `tools/strategy_farm/agent_router.py`:

- `codex.max_parallel`: `3 -> 5`
- `claude.max_parallel`: unchanged at `3`
- `gemini.max_parallel`: unchanged at `2`

## Verification

- `python -m pytest tools/strategy_farm/tests/test_agent_router.py` -> PASS.
- `python -m py_compile tools/strategy_farm/agent_router.py` -> PASS.
- `agent_router.py status` after registry sync shows Codex `max_parallel=5`.
- `route-many` can now fill up to five Codex `IN_PROGRESS` slots, subject to available routable tasks and existing WIP.

## Push

Local commit made with explicit pathspecs. Push is blocked in this headless HTTPS context by missing GitHub credentials, same as the prior filter-library task:

- `GIT_TERMINAL_PROMPT=0 git push origin agents/board-advisor`
- Failure: `could not read Username for 'https://github.com': terminal prompts disabled`
