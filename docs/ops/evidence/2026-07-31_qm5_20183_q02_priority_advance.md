# QM5_20183 GBPUSD/USDCHF Cointegration Q02 Priority Advance

Date: 2026-07-31 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20183_gbpusd-chf-coint`

## Outcome

The existing logical-basket Q02 row for `QM5_20183` was advanced in place.
No duplicate work item was created. The row now carries
`priority_track=true`, and its canonical pending rank moved from 506 to 6.
The immediate post-mutation state remained `pending`, attempt 0, unclaimed;
this record does not claim a Q02 verdict.

## Non-Duplicate Selection

The two positive-beta anchors from the original 66-pair scan are not blocked
at Q02:

- `QM5_12532` has logical-basket Q02 PASS followed by Q05 FAIL.
- `QM5_12533` has logical-basket Q02 PASS followed by Q04 FAIL.

The governed strict scan rows also already have builds and terminal Q02
evidence. The valid mission continuation was therefore the already-built
`QM5_20183` GBPUSD/USDCHF negative-beta basket. It was the highest OOS-ranked
sign-aware scan row without a dedicated basket before its card/build, and it
already had exactly one open logical Q02 work item:

- Work item: `564a8012-bb2b-4edf-a9f1-acd04b177d64`
- Logical symbol: `QM5_20183_GBPUSD_USDCHF_COINTEGRATION_D1`
- Host/companion: `GBPUSD.DWX` / `USDCHF.DWX`
- Setfile:
  `framework/EAs/QM5_20183_gbpusd-chf-coint/sets/QM5_20183_gbpusd-chf-coint_QM5_20183_GBPUSD_USDCHF_COINTEGRATION_D1_D1_backtest.set`
- Risk/tester contract: `RISK_FIXED=1000`, USD 100,000

## Enqueue-Path Repair

The legacy never-tested sweep created the first Q02 row without the standard
first-Q02 priority marker. With 2,194 pending rows, the basket was at claim
rank 506 even though `farmctl._q02_priority_track_required` already defines a
fresh EA's first Q02 as priority work.

`tools/strategy_farm/sweep_enqueue_built_eas.py` now delegates that decision
to the shared helper (while preserving the explicit legacy priority cohort).
The existing logical-basket regression asserts both the payload and evidence
report carry `priority_track=true`. This prevents future fresh basket EAs from
being stranded by the same enqueue-path mismatch.

## Guarded Existing-Row Mutation

The farm database was backed up before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_20183_q02_priority_20260731T150635Z.sqlite`

Under the factory mutation lock, the update required the exact work item to
remain `pending`, unclaimed, attempt 0, and the only pending/active Q02 row for
the EA/logical-symbol pair. It added:

- `priority_track=true`
- `priority_reason=owner_2026-07-31_fx_cointegration_q02_first_enqueue_parity`
- a durable no-new-work-item dedupe marker

The original `created_at` and `updated_at` values were preserved. Farm event
`priority_track_set` was recorded as event id `340276`; its detail explicitly
records `pipeline_verdict_changed=false`.

Post-update read-back:

| Check | Result |
|---|---|
| Open Q02 rows for exact basket | 1 |
| Status / attempt / claim | `pending` / 0 / null |
| Priority marker | `true` |
| Canonical pending rank | 6 (was 506) |

## Validation

- Strategy-card schema lint: PASS; no missing sections or ML hits.
- G0 card lint: PASS.
- V5 build check (`-SkipCompile`): PASS, zero failures and warnings;
  `D:/QM/reports/framework/21/build_check_20260731_150441.json`.
- Symbol-scope validation: `BASKET_OK`, zero violations.
- Basket sweep regressions (logical basket plus multi-symbol first cohort):
  2 PASS.
- Shared first-Q02 priority and FX basket-manifest suites: 28 PASS.
- Python compile and scoped `git diff --check`: PASS.

## Paced-Fleet and Safety Boundary

The final pre-mutation capacity check observed two running factory terminals
(`T7`, `T8`) and five active work items, below the seven-backtest ceiling.
The separate pre-existing `T_Live` process was observed only to exclude it.

During post-update validation the paced workers filled the available capacity.
The final read-only snapshot reported eight active work items and five visibly
running factory terminals (`T1`, `T4`, `T6`, `T8`, `T10`). `QM5_20183`
remained pending at rank 6. Because the canonical active count was now above
the seven-backtest ceiling, no further wait, enqueue, claim, dispatch, or
backtest action was attempted.

No tester was manually launched, no terminal was dispatched or controlled,
and no AutoTrading state changed. No portfolio admission, KPI, Q08
contribution, T_Live manifest, live setfile, or deploy artifact was touched.
Execution remains owned by the paced terminal workers.
