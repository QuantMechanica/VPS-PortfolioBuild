# V5 Core Filter Library Build

Date: 2026-05-22
Status: REVIEW_READY
Router task: `573731f4-140b-4627-82d5-bc0081feca9d`

## Implemented

- Added reusable mechanical filter includes:
  - `framework/include/QM/QM_FilterNewsBlackout.mqh`
  - `framework/include/QM/QM_FilterRegime.mqh`
  - `framework/include/QM/QM_FilterVolatility.mqh`
  - `framework/include/QM/QM_FilterLibrary.mqh`
- Updated Strategy Card schema enforcement:
  - `agent_router.py` advertises `filters` as a required body field.
  - `farmctl.py` requires an explicit `Filters:` block or heading, not incidental filter prose.
- Updated setfile generation:
  - `gen_setfile.ps1` now emits pre-declared core filter on/off flags and parameters.
  - News is enabled by default with `qm_filter_news_mode=3` (`QM_NEWS_FTMO_PAUSE`).
  - Regime and volatility filters are off by default and become explicit variants when enabled.
- Updated framework spec:
  - `framework/V5_FRAMEWORK_DESIGN.md` documents filter inputs, include locations, schema contract, and variant semantics.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_agent_router.py tools/strategy_farm/tests/test_research_backlog_inventory.py` -> `20 passed`.
- `python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/agent_router.py` -> PASS.
- PowerShell parser check for `framework/scripts/gen_setfile.ps1` -> PASS.
- Static include check confirmed all core filter include guards and public functions are present.

## Guardrails

- No ML: regime filter is N-bar return thresholds only; volatility filter is ATR-ratio only.
- No new gate or verdict semantics.
- Filter on/off is represented as a pre-declared setfile variant.
- No T_Live or AutoTrading changes.
- No manual `terminal64.exe` start.

## Commit

Committed filter-library task files only with explicit pathspecs:

- `feat(framework): add first-class filter library`

Push was attempted but is blocked in this headless context by missing GitHub
HTTPS credentials:

- `git push origin agents/board-advisor` timed out after 120 seconds.
- `GIT_TERMINAL_PROMPT=0 git push origin agents/board-advisor` failed with
  `could not read Username for 'https://github.com': terminal prompts disabled`.
