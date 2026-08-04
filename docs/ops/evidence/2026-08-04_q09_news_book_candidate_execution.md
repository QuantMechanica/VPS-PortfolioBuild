# Q09_NEWS v2 book-candidate execution — 2026-08-04

## Decision

Execution record for router task `82bd766f-a520-46e7-b069-7636d901b401`.
The OWNER-ordered sequence is strictly serial:

1. `QM5_11422 / USDCAD.DWX`;
2. only after that chain closes, `QM5_13036 / GDAXI.DWX`.

Each chain is fail-closed: a Q09_NEWS refusal or any verdict other than
`CONFIG_LOCKED` stops that candidate; Q10 requires both `CONFIG_LOCKED` and a
fresh same-Q08 `PASS_PORTFOLIO` row. All tester setfiles use
`RISK_FIXED=1000` and `RISK_PERCENT=0`. No T_Live, AutoTrading, or manual
`terminal64.exe` action is part of this execution.

**Outcome: FAIL CLOSED before cell execution.** The ordinary factory worker
constructed a Q09 executor command without the executor's required `--period`
argument. `argparse` refused the command. No cell, Q09 aggregate, adjudication
sidecar, Q09_PORTFOLIO row, Q10 row, or second-candidate row was produced. No
pipeline verdict is claimed.

## Sealed shared input

| Input | Identity |
|---|---|
| Calendar bundle | `q09cal-20150101-20260809-0bb19b5bb9790b76` |
| Manifest | `D:/QM/data/news_calendar/q09_bundles/q09cal-20150101-20260809-0bb19b5bb9790b76/manifest.json` |
| Manifest SHA-256 | `b204d1ab9fe40fe32afc254ae4284ed6c1df112829df07483912e5ed54527461` |
| Event content SHA-256 | `86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1` |
| Coverage | `2015-01-01T00:00:00Z` through `2026-08-09T02:00:00Z`; 48,245 events |
| Experiment window | full `2019-01-01..2025-12-31`; selection `2019-01-01..2023-12-31`; sealed holdout `2024-01-01..2025-12-31` |
| Window contract | `complete_months=60`; `holdout_complete_months=24` |
| Tester / cost profile | `REAL_TICKS` / `DXZ_CANONICAL_REAL_TICKS_V1` |

## Candidate input identities

| Identity | QM5_11422 / USDCAD.DWX | QM5_13036 / GDAXI.DWX |
|---|---|---|
| Fresh Q08 PASS row | `9fe3eb5f-ab0d-4c84-82fe-d6748c3aa270` | `fb3f0e20-1982-4f51-9e4b-52da2629a5ac` |
| Q08 aggregate SHA-256 | `c611ae3b628dc74b8ae38aa6a6420367290e9cd2fd43e201a20d9f467e2f58f4` | `1f829f2bb451c19349e0055cefa66472862a6f1850f0e01ec4632d650342b966` |
| Historical Q09_NEWS row retained | `87af2578-b9ba-4010-9776-07faa4e729d5` (`PENDING_RUNNER`) | `7efd8e39-4d1c-4b6d-8cfd-637122aad25f` (`PENDING_RUNNER`) |
| Baseline setfile SHA-256 | `715bce2fb8762cef12dcdff86eb6c144069b6d5a487d5e39fcaa1de71248a5ff` | `80dc96e896fa109ef31964af8c617468e6737b1f0823f1616d1117b44c732b70` |
| EX5 SHA-256 | `2b98e9e902313148be78d88513fcbda2476150b1a7605eb15a50b2cca6b32d66` | `2cd0f7270572d37bd67ca0d1f724eaad95d756b4af18859d2dd0203d0045b0be` |
| Include-closure SHA-256 | `a3fbf052f006b46cf0759ed47a7af2945819c8769d5f58de1b30d250506b9172` | `6ed8946b36a0e03028577a9ab4d4140765592f8d9e060bed1e1e49100c98daa2` |

## Governed execution ledger

### QM5_11422 / USDCAD.DWX

- New append-only Q09_NEWS row: `33df999d-aa4f-4e66-9c2f-44bdcd3e7852`.
- Run-plan logical SHA-256: `92554c45451ba940b0097defd3014053d3ad1bb2b4e71da3714b40a76ba1f129`.
- Exact run-plan file SHA-256: `32cda8fe8ee21d0a333a7d661b78802503a60579e9fa9d93b074f3d5b6b2fb47`.
- Input-manifest SHA-256: `497ed2ec0f538b32c3143aedec50eeff913db945087d00c19d1092b559ca51a8`.
- Dispatch-binding SHA-256: `a54e6bbbafae91b87f99b85b0186760e31f6d9e4ecd490e44c2c98c28014b2be`.
- Matrix: 40 cells, `7x1_target_compliance`, target compliance `DXZ`.
- Activation hold: released by `bind-q09-plan`; state `RUNNABLE_BOUND`.
- At activation, an older governed USDCAD Q02 row
  `f83e63c3-60f8-4807-9dac-c4bdb5e1a0aa` was active. Symbol serialization
  correctly kept Q09 pending; it was not interrupted.
- After that symbol lock released, the ordinary factory claimed the row on T3
  at `2026-08-04T05:37:49Z` and spawned the Q09 phase runner at
  `2026-08-04T05:38:00Z`.
- The spawned command omitted `--period D1`. The runner refused with:
  `q09_news_runner.py execute: error: the following arguments are required: --period`.
- The generic launch-fault guard correctly returned the row to `pending` with
  `verdict=NULL`, `launch_fault_count=1`, and
  `launch_not_before_utc=2026-08-04T05:43:15Z`; it did not invent an economic
  or pipeline verdict.
- Source mechanism in `tools/strategy_farm/farmctl.py`: the Q09 builder adds
  `--period` at line 5929, then the generic Q-phase bridge removes it at line
  5964. This is incompatible with the Q09 executor parser, which requires the
  argument.
- Mutable worker log SHA-256 at the fail-closed capture (`05:38:15Z`):
  `bddaf889f22f89f800a46c077a112b69a00c102ee5471d71b23e54c2ba72d585`.
- Result inventory at capture: zero `cell_receipt.json` files; Q09 output root
  absent; zero `q09_news_tests` rows for this work item; no aggregate or
  evidence path.
- Fresh Q09_PORTFOLIO row: **not created**.
- Q10 append-only rerun of `6f9400fa-9ca2-4835-9fcf-e1087289f9b1`:
  **not created**.

### QM5_13036 / GDAXI.DWX

This candidate was not started because the preceding candidate hit the
explicit machinery-refusal stop condition. No append-only Q09_NEWS row, fresh
Q09_PORTFOLIO row, or Q10 rerun of
`788d2371-4a37-42c3-b9b1-18d9fb09bd3f` was created.

## Verification

- Preflight authenticated both Q08 aggregates, baseline setfiles, current EX5
  binaries, recursive include-closure manifests, and the OWNER-approved calendar
  manifest.
- Representative CONTROL_OFF and POLICY_ON plan setfiles preserved
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the sealed bundle/content identity.
- Focused Q09/Q10 suite: `31 passed`:
  `test_q09_news_runner_v2.py`, `test_q09_news_contract_v2.py`,
  `test_q09_news_farmctl_integration.py`, and
  `test_q10_confirmation_contract_v2.py`.
- The focused suite did not cover the production command-composition
  interaction that removes Q09's required `--period`; the real ordinary-worker
  invocation exposed that missing integration case.

## Required follow-up (not executed in this task)

Repair the factory command-composition contract so Q09_NEWS retains its sealed
period, add a production-command regression test, then create a separately
authorized append-only rerun. Do not manually invoke `execute`, rewrite this
pending row, weaken the gate, or create downstream rows from the refusal.
