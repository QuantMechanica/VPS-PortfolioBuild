# OPT-S1 annual matrix tooling — DL-089

Date: 2026-08-21  
Router task: `4be5bc2a-e28b-47e7-b777-f9b343f65bc0`  
Branch: `agents/board-advisor`  
Verdict: **PASS_FOR_REVIEW; LIVE ENQUEUE CORRECTLY GATED**

## Delivered

- `tools/strategy_farm/opt_census.py`
  - deterministic 2019–2025 matrix planner;
  - exactly 77 predicate IDs read from `QM_PatternPermission.mqh`;
  - 155 arms per year (baseline + 77 BUY + 77 SELL), 1,085 cells total;
  - six-input blacklist surface (`opt_pp_buy1..3`, `opt_pp_sell1..3`), with one
    active predicate per arm and all-zero baseline;
  - calendar-year window binding in both setfile evidence headers and work-item
    payloads;
  - append-only `OPT_CENSUS` work items, deterministic UUIDs, and collision-
    checked idempotency;
  - `qm.opt-census.v1` ledger with `declared_trial_count=154` and
    `planned_trials=1085`;
  - hard precondition on fixture-harness work item
    `83b89730-bb86-4c18-955a-efefe3039cc5` being `done/PASS`;
  - cell self-report derived from the existing run-smoke/native-report stream:
    trades, entry trading days, PF, net, max DD, and return/max-DD.
- `farmctl.py` recognizes `OPT_CENSUS` as a one-run annual measurement with an
  exact payload-bound date window. It does not alias the rows into Q02.
- Focused regression tests in `tools/strategy_farm/tests/test_opt_census.py`.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_opt_census.py -q
.......                                                                  [100%]
7 passed in 5.14s

python -m py_compile tools/strategy_farm/opt_census.py tools/strategy_farm/farmctl.py
PASS
```

The idempotency test performs two complete enqueue passes against a temporary
farm database:

| pass | inserted | existing | OPT_CENSUS rows | Q02 rows |
|---|---:|---:|---:|---:|
| first | 1,085 | 0 | 1,085 | 0 |
| second | 0 | 1,085 | 1,085 | 0 |

Guardrail tests prove refusal for `RISK_FIXED <= 0`, `RISK_PERCENT != 0`, and
`qm_news_stale_max_hours > 336`.

## Existing-stream self-report proof

Command:

```text
python tools/strategy_farm/opt_census.py report-cell --summary D:\QM\reports\work_items\1967cdf4-0821-4fcd-aac9-2cd0c8ce8aaf\QM5_21501\20260813_153207\summary.json
```

Result, reconciled to the native `report.htm` (`report_reconciled=true`):

| trades | entry trading days | PF | net | max DD | return/max-DD |
|---:|---:|---:|---:|---:|---:|
| 888 | 888 | 1.12 | 46,636.78 | 21,852.77 | 2.1341358555 |

## Live-enqueue state

No census rows or generated matrix setfiles were written to the production farm.
The named prerequisite currently reads:

```text
status=failed
verdict=INFRA_FAIL
reason=ea_dir_missing
```

The enqueue command therefore fails closed before writing either setfiles or DB
rows. OPT-S0 may proceed, but a census run remains forbidden until the fixture
harness is freshly `done/PASS`.
