# Q08 Portfolio-Rescue Dashboard + Dedup Evidence

Task: ec961ba7-b667-4db2-a408-50ba2f572888
Date: 2026-06-03

## Scope

- Added Q08 portfolio-rescue cockpit panel showing standalone Q08 fail tier/reason, Q09 portfolio verdict, trade count, correlation, Sharpe delta, maxDD delta, standalone PF, and portfolio-only flag.
- Added EA-detail Q08 portfolio-rescue table in the strategy archive for EAs with Q08 standalone fail evidence.
- Changed Q08 FAIL_SOFT -> Q09_PORTFOLIO cascade dedup to key on `(ea_id, symbol)` instead of `(ea_id, symbol, setfile_path)`.
- Added an in-cycle duplicate guard so two Q08 soft rows for the same `(ea_id, symbol)` cannot spawn two Q09_PORTFOLIO rows in one pump pass.
- Added regression coverage for duplicate Q08 soft rows with different setfiles for the same EA/symbol.
- Dashboard readers merge Q08 aggregate artifacts with work-item payloads and accept both `verdict_classification` and `q08_verdict_classification`.

## Files

- `tools/strategy_farm/farmctl.py`
- `tools/strategy_farm/render_cockpit.py`
- `tools/strategy_farm/dashboards/render_dashboards.py`
- `tools/strategy_farm/tests/test_verdict_taxonomy_ws2.py`

## Verification

- `python -m py_compile tools/strategy_farm/render_cockpit.py tools/strategy_farm/dashboards/render_dashboards.py tools/strategy_farm/farmctl.py`
  - PASS
- `python -m unittest tools.strategy_farm.tests.test_verdict_taxonomy_ws2`
  - PASS: 15 tests
- `python tools/strategy_farm/render_cockpit.py`
  - PASS: wrote `D:\QM\strategy_farm\dashboards\cockpit.html`
- `python tools/strategy_farm/dashboards/render_dashboards.py`
  - PASS: rendered archive/dashboard output, including `D:\QM\strategy_farm\dashboards\portfolio.html` and `D:\QM\strategy_farm\dashboards\strategies.html`

## Notes

- `python -m pytest tools/strategy_farm/tests/test_verdict_taxonomy_ws2.py` could not run in this environment because `pytest` is not installed. The same focused tests were run through `unittest`.
- Left in REVIEW for Claude review/landing. No task was moved to PIPELINE.
