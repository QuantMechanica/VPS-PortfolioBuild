# rb-backfill-planner — implementation evidence

Date: 2026-08-23
Ticket: `rb-backfill-planner` / proposal ticket 5
Mode used for production artifacts: **dry-run only**

## What changed

- Added the read-only frontier planner at `tools/strategy_farm/backfill_planner.py`.
  - SQLite is opened with a `file:...?...mode=ro` URI and `PRAGMA query_only=ON`
    (`backfill_planner.py:82`).
  - Pair actions and the strict Q09_NEWS-versus-informational-Q09_PORTFOLIO handling
    are computed before command selection (`backfill_planner.py:288`, `:453`, `:495`).
  - Ranking is recovery-last, contiguous-frontier descending, remaining-gates ascending,
    then oldest pair first (`backfill_planner.py:636`).
  - Economic-run dedup changes later identical proposals to `SKIP_REUSABLE`
    (`backfill_planner.py:644-657`).
  - CSV, JSON, counts, phase medians, estimated hours and the top-50 Markdown table are
    emitted by `write_outputs` (`backfill_planner.py:675`, `:750`).
  - Apply is bounded and invokes argv directly (no shell); reruns must contain
    `--append-only-rerun-of`, and planned symbol occupancy cannot exceed the active cap
    (`backfill_planner.py:782-817`). The CLI refuses apply without both
    `--i-understand-append-only` and positive `--max-rows N`
    (`backfill_planner.py:828-840`).
- Added unit coverage at `tools/strategy_farm/tests/test_backfill_planner.py` for:
  earliest-hole selection (`:64`), Q09 portfolio non-authority (`:78`), exact reuse skip
  (`:101`), terminal economic FAIL (`:121`), frontier/age ranking (`:135`), economic-run
  dedup (`:157`), both apply guards (`:192`), read-only SQLite (`:198`), compile-log
  classification (`:212`), append-only subprocess invocation, and the active-symbol cap
  (`:269`).
- Generated the governed Markdown plan at
  `docs/ops/rebaseline/BACKFILL_PLAN_2026-08-23.md`.
- Generated machine artifacts outside Git, as required:
  - `D:/QM/reports/rebaseline/backfill_plan_2026-08-23.csv` (7,168,710 bytes)
  - `D:/QM/reports/rebaseline/backfill_plan_2026-08-23.json` (22,436,236 bytes)

## Dry-run result

Command:

```text
python tools/strategy_farm/backfill_planner.py --db D:/QM/strategy_farm/state/farm_state.sqlite --census-csv D:/QM/reports/rebaseline/census_2026-08-23.csv --out-dir D:/QM/reports/rebaseline --md-dir docs/ops/rebaseline --date 2026-08-23 --quiet
```

Result from `backfill_plan_2026-08-23.json`:

| Measure | Result |
|---|---:|
| Pair rows | 14,513 |
| COMPILE_EA classification rows | 94 |
| Enqueue-eligible rows after binding/cap checks | 1,471 |
| Estimated factory hours | 34,834.780 |
| FILL_MISSING | 5,019 |
| REBIND_STALE | 84 |
| RERUN_INFRA | 1,060 |
| SKIP_REUSABLE | 0 |
| STOP_ECONOMIC_FAIL | 7,439 |
| STOP_NOT_APPLICABLE | 12 |
| UNKNOWN | 993 |

The COMPILE_EA subset contains 32 `RERUN_INFRA` rows with a reachable MetaEditor log
carrying the documented missing-stdlib signature and 62 `UNKNOWN` rows without that exact
reachable signature. Compile rows never receive a backtest command because compile repair
is a separate ticket.

No `--apply` invocation was made. No backtest was enqueued or deleted, no verdict row was
changed, the factory was not toggled, and `C:/QM/mt5/T_Live` was not accessed.

## Test evidence

Focused planner plus touched census module:

```text
python -m pytest tools/strategy_farm/tests/test_backfill_planner.py tools/strategy_farm/tests/test_rebaseline_census.py -q
........................                                                 [100%]
24 passed in 0.68s
```

Syntax and whitespace checks:

```text
python -m py_compile tools/strategy_farm/backfill_planner.py
git diff --check
PASS (no output; only a pre-existing worktree CRLF warning was printed before its index
stat was refreshed)
```

Broader suite smoke (failure is outside the touched modules):

```text
python -m pytest tools/strategy_farm/tests -q -x
.................................................F
1 failed, 49 passed in 5.54s
```

First failure: `test_agent_router.py:137`, `StopIteration` because the fixture's status
contains no `claude` registry row. The focused planner/census suite remains green; this
unrelated router behavior was not changed by this ticket.

## Risks / constraints

- The plan binds the currently active `v3` runtime contract. The v4 manifest is still a
  read-inert proposal; this ticket does not activate or renumber it.
- Q14+ rows are reported but not apply-eligible because the current
  `farmctl enqueue-backtest` surface does not support those optimization gates.
- Factory-hour estimates are medians of `work_items.updated_at - created_at`, exactly as
  requested; these timestamps can include queue/hold time and therefore are conservative
  wall-clock estimates rather than pure tester CPU time.
- Eligibility and symbol occupancy are snapshots. Apply rechecks its bounded in-memory
  symbol headroom, while farmctl/worker claim guards remain the final concurrency authority.

## Rollback

Revert the ticket commit to remove the planner, its tests, and the two tracked Markdown
artifacts. The CSV/JSON files under `D:/QM/reports/rebaseline/` are derived dry-run outputs
and can be archived or removed independently; they contain no state needed by the farm.
No database, verdict, queue, factory, or live-terminal rollback is required because this
ticket executed no apply path.
