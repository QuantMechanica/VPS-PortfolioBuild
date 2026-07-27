# Q02 progress-aware reaper

Date: 2026-07-27  
Task: `371a7dc0-58e9-4a4a-91c9-b669e0755a7b`  
Verdict: PASS — the outer reaper no longer kills a work-item merely because it
crossed the old 45-minute Q02 wall-clock threshold.

## Mechanism and change

The old implementation compared `work_items.updated_at` only with the fixed
phase table (`tools/strategy_farm/farmctl.py:216`) and killed every active row
past that age. A Q02 child can carry `timeout_seconds=7200`, so the 45-minute
outer check pre-empted a still-progressing two-hour child.

The replacement at `farmctl.py:4951-5114`:

1. binds terminal evidence to the work item by finding its UUID in the MT5
   `tester.ini` launch line;
2. reads only subsequent `AutoTesting processing N %` records from that
   terminal log;
3. reaps after 20 minutes without an increase in percentage
   (`ACTIVE_PROGRESS_STALL_MIN`, line 233);
4. does not reap when evidence is missing while the child remains inside its
   budget (fail open);
5. retains an absolute ceiling at least ten minutes beyond
   `timeout_seconds`; and
6. writes `reap_reason`, child/outer budgets, percentage, timestamp, stalled
   minutes, and source log path into both the returned event and durable
   work-item payload.

Repeated reports of the same percentage do not reset the clock. Evidence is
work-item-bound, so progress from a previous job on the same terminal cannot
keep a hung job alive.

## The 2026-05-23 protection

The protection is preserved and sharper. A launched job whose bound percentage
does not advance is killed after 20 minutes rather than waiting 45 minutes.
If MT5 never exposes a trustworthy bound signal, the reaper deliberately fails
open inside the child's own timeout, then the absolute outer ceiling terminates
it. Thus a silently failed inner timeout still has a backstop, while a readable
working run is governed by progress rather than elapsed duration.

## Historical share

Read-only query against
`D:/QM/strategy_farm/state/farm_state.sqlite` at approximately 19:40 UTC:

```sql
SELECT id
FROM work_items
WHERE phase='Q02'
  AND payload_json LIKE '%summary_missing_retries_exhausted%';
```

The current database contains 45,037 matching rows (the brief's 43,422 was an
earlier snapshot). The retained T1-T10 terminal-log set contains 89 dated logs
from 2026-07-19 through 2026-07-27. UUID binding found 558 matching graveyard
rows; 161 had advanced above 0% before their terminal stream ended:

- retained, bound cohort: **161 / 558 = 28.85%** showed forward progress;
- full graveyard proven lower bound: **161 / 45,037 = 0.357%**;
- 44,479 rows have no retained bound terminal log, so their status is
  **NOT ESTABLISHED**;
- consequently, the full-history fraction is not measurable from retained
  evidence (formal bound 0.357% to 99.12%).

This does not extrapolate the 28.85% cohort to expired logs. It establishes that
progress-at-loss is material in the observable cohort and that retention is
insufficient for a defensible all-history point estimate.

## Other phases

The same fixed phase table covers Q03-Q10. No second proven inversion was found:

- Q03-Q10 phase runners derive their child timeout from the payload
  `timeout_min` (`farmctl.py:4274-4283`), which is also applied to the outer
  timeout (`farmctl.py:5215-5249`).
- Q05/Q06 have 120-minute outer limits versus documented 90-minute child
  budgets; Q08 computes a workload-aware aggregate ceiling; Q05-Q07 additionally
  scale for history/seeds.
- The new generic `timeout_seconds` floor applies whenever a phase supplies that
  explicit child budget, preventing a future outer/inner inversion.

This is a static contract check, not pipeline evidence.

## Verification

Focused verification:

```text
python -m pytest \
  tools/strategy_farm/tests/test_progress_aware_reaper.py \
  tools/strategy_farm/tests/test_basket_work_items.py::BasketWorkItemsTests::test_basket_q02_active_timeout_uses_longer_window \
  tools/strategy_farm/tests/test_basket_work_items.py::BasketWorkItemsTests::test_basket_q02_active_timeout_still_reaps_after_basket_window \
  tools/strategy_farm/tests/test_basket_work_items.py::BasketWorkItemsTests::test_payload_timeout_extends_phase_active_timeout \
  tools/strategy_farm/tests/test_terminal_worker_adoption.py -q

11 passed in 1.29s
```

`python -m py_compile tools/strategy_farm/farmctl.py
tools/strategy_farm/tests/test_progress_aware_reaper.py` also passed.

The new regression cases prove: recent advancement survives the old 45-minute
threshold; a bound stalled run is reaped with evidence; missing evidence fails
open inside 7,200 seconds; and the absolute outer ceiling is looser than the
child timeout.

No work items were requeued. Factory OFF/ON, T5, T_Live, AutoTrading, terminal
launches, and active backtests were not touched.
