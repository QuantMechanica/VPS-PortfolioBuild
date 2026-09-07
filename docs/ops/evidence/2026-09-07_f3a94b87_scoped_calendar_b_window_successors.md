# Consumer B scoped Q10 window-seal successors

- Router task: `3ba316bc-5038-4f32-ad05-d70df46786f5`
- Cycle date: `2026-09-07`
- Agent: `codex`
- Branch: `agents/board-advisor`
- Disposition: `REVIEW`
- Scope: the nine D1/USD `Q10_NEWS` rows named by the router task and blocked only by `SEALED_Q10_WINDOW_UNAVAILABLE`

## Outcome

Eight rows had an exact Q09 PASS aggregate whose immutable evidence authenticated the full Q09 data window. Each received an append-only, non-claimable Q10 review successor with a `qm.scoped-q10-window-seal/v1` proof. The source Q10 row, its status, verdict, payload, and hold were not mutated. Each successor remains `pending`, has no verdict or claimant, has `terminal_claimable=false`, and remains under `Q09_AWAITING_SEALED_PLAN`.

One row, `72992810-aaf1-4fa8-9c12-c778bda0ae87`, has no exact Q09 PASS descendant and therefore cannot be sealed honestly. It was recorded as canonically superseded without a successor so it remains preserved as non-current Consumer B history and does not block the exact-identity successor for `d81d9ea8-b802-4c38-8fc9-8bdbab6ef75c`.

No hold was released. No terminal was started or interrupted. No live-trading or AutoTrading state was changed. This evidence is not a pipeline verdict and does not authorize promotion.

## Append-only lineage

| Source Q10 row | Exact Q09 PASS row | Review-only successor | EA / symbol | Authenticated UTC window | Result |
|---|---|---|---|---|---|
| `7bbeef66-becf-4bd3-aa5c-1d00bde262d8` | `8f43a2f8-d0be-472f-87ca-c2fd628136e4` | `c18cf1fa-60c0-498e-82db-637fc8320f58` | QM5_12567 / XAUUSD.DWX | 2017-01-01 through 2026-01-01 exclusive | Sealed; excluded by declared overlap |
| `d81d9ea8-b802-4c38-8fc9-8bdbab6ef75c` | `b9ae4345-e6d5-4062-9e05-e54dd40ee767` | `b6e02932-d34d-4fea-8f3c-f977c8efe7eb` | QM5_1556 / XAUUSD.DWX | 2017-01-01 through 2026-01-01 exclusive | Sealed; excluded by declared overlap |
| `72992810-aaf1-4fa8-9c12-c778bda0ae87` | none | none | QM5_1556 / XAUUSD.DWX | unavailable | Refused: no exact Q09 PASS descendant |
| `cec67ad5-2ca5-4d84-b347-a0c370415329` | `6074a203-df0c-401a-aa07-bcd6319aef61` | `ca96d7bf-51e0-4417-a5c6-94546e9d9946` | QM5_10513 / XAUUSD.DWX | 2017-01-01 through 2026-01-01 exclusive | Sealed; excluded by declared overlap |
| `bd840961-23a1-4fea-99ce-2e285c0d1914` | `8a4a5afb-3767-4687-a247-2e24d0f1ca78` | `f15ac955-9dbb-4f39-9a9e-8eb142f11138` | QM5_10145 / SP500.DWX | 2017-01-01 through 2026-01-01 exclusive | Sealed; excluded by declared overlap |
| `9d3f470e-5071-4398-86c7-7de4be979c3d` | `a99d51cd-ea47-4137-8e44-d8dd8319c5ed` | `136b0e0f-7896-4e0c-b34b-47991cc49342` | QM5_10513 / XAUUSD.DWX | 2017-01-01 through 2026-01-01 exclusive | Sealed; excluded by declared overlap |
| `d3312a9e-038a-4ab8-b392-0dbdfa2728e0` | `e32ff9d8-e3d3-4f92-93e1-4a3f36312f04` | `450fb9f6-9797-496d-937e-9bddc5f292a8` | QM5_10513 / XAUUSD.DWX | 2017-01-01 through 2026-01-01 exclusive | Sealed; excluded by declared overlap |
| `1d9a2d26-4407-4554-acbb-4e4c258f0b04` | `1a32886e-34dd-422b-b115-e934625ff99e` | `abea4df5-c03b-494a-a025-37747d0a1e32` | QM5_10513 / XAUUSD.DWX | 2017-01-01 through 2026-01-01 exclusive | Sealed; excluded by declared overlap |
| `bb02b701-0d7c-4de7-82b2-87d917f8dd1b` | `5ae91cae-4481-4a89-8151-cbcc04169794` | `6d528b09-59d8-4c2f-bfb2-a1102e8ae12c` | QM5_1230 / XAUUSD.DWX | 2017-01-01 through 2026-01-01 exclusive | Sealed; excluded by declared overlap |

The eight source aggregate evidence documents report Q09 PASS over `2017.01.01` through `2025.12.31`; the sealed half-open UTC range is therefore `2017-01-01T00:00:00+00:00` through `2026-01-01T00:00:00+00:00`.

## Guardrails implemented

`farmctl enqueue-cascade-backtest --scoped-q10-window-seal` now provides the narrow governed path used here. It requires an exact Q09 PASS predecessor, an exact pending Q10 source row, matching EA/symbol/setfile identity, current execution-artifact binding, and immutable Q09 aggregate evidence. It emits a content-hashed Consumer-B-only seal, marks the successor review-only and non-claimable, installs the ordinary plan hold, and records the old-to-new relation in `work_item_supersedes` in the same transaction.

The scoped activation dry run independently validates the seal hash, Q09 phase and PASS verdict, evidence hash and content, EA/symbol/setfile identity, review-only flags, and exact evidence-derived window. It excludes canonically superseded pending rows from the current candidate set. Any contradiction fails closed.

## Consumer B dry run

Artifact: `docs/ops/evidence/2026-09-07_f3a94b87_scoped_calendar_b_window_successors_dry_run.json`

- SHA-256: `af6a0cc819b258886a23685ccc70e961efe2918ccc86ccd28cf1a06f0eec0c55`
- Current non-superseded pending Q10 rows assessed: 31
- `ADMISSIBLE`: 0
- `EXCLUDED`: 31
- All eight new successors: `EXCLUDED` solely because of `DECLARED_EXCLUSION_OVERLAP`
- Hold releases: 0

The window defect is resolved for the eight sealable rows, but their declared calendar overlap makes them ineligible for scoped activation. The correct Consumer B result is therefore no release.

## Verification

Focused regression command:

```text
python -m pytest -q tools/strategy_farm/tests/test_farmctl_cascade.py tools/strategy_farm/tests/test_q09_news_farmctl_integration.py tools/strategy_farm/tests/test_news_calendar_scoped_activation.py tools/strategy_farm/tests/test_news_calendar_taint.py tools/strategy_farm/tests/test_path_to_25_metrics.py tools/strategy_farm/tests/test_archive_matrix_v4.py
```

Result: `127 passed, 13 subtests passed`.

After the final pending-row guard was tightened to require the scoped seal, the two directly affected suites were rerun: `32 passed`.

`git diff --check` passed for the two implementation files and their focused integration tests.

## State backup

The explicit no-successor supersession record for the unsealable row created the governed database backup:

- `D:/QM/strategy_farm/state/backups/farm_state_before_supersedes_20260907T055059Z.sqlite`
- SHA-256: `3edc7c59f8a6b24ecddbd0ffa47f35bad49b04f23d3109166cb65360bb6c4d87`

## Review boundary

This change and evidence remain in REVIEW on `agents/board-advisor`. Main integration and any later pipeline action require the normal Claude plus OWNER close-out path.
