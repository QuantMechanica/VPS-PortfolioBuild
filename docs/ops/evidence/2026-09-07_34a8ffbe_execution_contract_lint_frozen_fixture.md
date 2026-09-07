# Execution-contract news-calendar fixture repair

- Router task: `34a8ffbe-4678-4828-b330-fa8c748d6fe7`
- Review state: `REVIEW`
- Implementation branch: `agents/codex-lint-calendar-fixture-20260906`
- Implementation commit: `2ed61d4357`

## Root cause

`test_execution_contract_lint.py` read the rolling deployed calendar bundle under
`D:/QM/data/news_calendar`. Daily refresh changed the bundle SHA-256 and coverage
end date, so assertions and lint calls that intentionally pinned the prior bundle
became nondeterministic.

## Repair

Two minimal immutable CSV fixtures encode the asserted inclusive coverage window
(`2015-01-01` through `2026-08-29`). An autouse test fixture rewrites only the
in-memory temporary registry's news-calendar source/dependency paths, hashes, and
coverage to those repository fixtures. Production registry data and deployed
calendar files are unchanged. Hash mismatch, copy-drift, declared-coverage drift,
expiry, and fail-closed policy assertions remain exercised. The fixture CSV files
are marked `-text` locally so checkout line-ending conversion cannot change their
bound hashes.

## Verification

Command:

`python -m pytest tools/strategy_farm/tests/test_execution_contract_lint.py -q`

Result: `57 passed in 23.29s`.

`git diff --check` passed before commit. No `.ex5`, setfile, live terminal,
AutoTrading, production registry, or deployed calendar mutation was made.
