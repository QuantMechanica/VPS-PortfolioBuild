# Zero-Trade Prevention Gates

Date: 2026-05-22
Status: REVIEW_READY
Router task: `bc4af09c-8bb9-473a-830c-e33880a1d286`

## Implemented

Strengthened the pipeline before broad Q02 fanout:

- Q01 trade-generation gate:
  - `enqueue_backtest(..., "P2")` now blocks if the latest build smoke for the EA reports `zero_trades`.
  - Block reason: `q01_trade_generation_zero_trades`.
  - This prevents a build that cannot trade on its reference run from entering Q02.
- G0 / prebuild entry-frequency scrutiny:
  - `prebuild_validate_card` compares declared `expected_trades_per_year_per_symbol` against a conservative inference from the card entry cadence.
  - Implausible declarations are blocked with `entry_frequency_implausible:*`.
- Universe discipline:
  - P2 work-item creation now filters setfiles to the approved card's declared universe when the card declares symbols.
  - Basket manifests still use the basket path; undeclared-card legacy cases keep the existing fallback behavior.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_research_backlog_inventory.py tools/strategy_farm/tests/test_zero_trade_prevention.py` -> PASS.
- `python -m py_compile tools/strategy_farm/farmctl.py` -> PASS.

## Guardrails

- Model=4 policy unchanged.
- No T_Live or AutoTrading changes.
- No manual `terminal64.exe` start.
- No gate or verdict semantics loosened.
- Existing per-symbol zero-trade recovery remains separate; this gate only blocks cannot-trade-at-all build-smoke cases before Q02.
