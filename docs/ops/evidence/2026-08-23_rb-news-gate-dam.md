# rb-news-gate-dam evidence — 2026-08-23

## Outcome

The news gate now has a bounded, append-only service path from an authenticated
`expanded_7x4_matrix_required` adjudication to a current-contract child, a
contract-v3 one-physical-seed/seam-reconstructed 7x4 plan, a released plan hold,
ordinary terminal-worker claimability, and final adjudication by the existing
contract rules. No news threshold, material-effect rule, verdict criterion, or
historical verdict row was changed.

The authorized top-80 backfill created four children (limit 10). All four are
sealed with 29 physical run cells, seed 17, two evidence windows, and
`matrix_scope=7x4`. T3 claimed and launched one child; the other three remain
`pending/RUNNABLE_BOUND`, have inactive plan holds, and are returned by the shared
claim selector.

## Required sources read

- `docs/ops/rebaseline/GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md`
- `docs/ops/rebaseline/FACTORY_AUTOMATION_INVENTORY_2026-08-23.md`
- `docs/ops/rebaseline/GATE_NAME_CENSUS_2026-08-23.md`
- `docs/ops/rebaseline/PATH_TO_25_CANDIDATES_2026-08-23.md`
- `docs/ops/evidence/2026-08-23_rb-q09-autoseal.md`
- `docs/ops/Q09_ACCELERATION.md`
- `G:/My Drive/QuantMechanica - Company Reference/03 Pipeline/Pipeline Rebaseline Directive 2026-08-23.md`
- `G:/My Drive/QuantMechanica - Company Reference/03 Pipeline/Q10 News Impact + FTMO Recommendation.md`

The vault criteria were treated as read-only ROT. The OWNER E1 instruction that
the gate conclusion is `CONFIG_LOCKED` only is reflected in service-rate counting;
the portfolio arm remains outside this economic conclusion.

## Code evidence

- `tools/strategy_farm/news_gate_service.py:25` authenticates the aggregate path,
  exact SHA-256, `REVIEW_REQUIRED` verdict, and the single exact expansion reason.
- `tools/strategy_farm/news_gate_service.py:56` selects the newest authenticated
  request per exact EA/symbol/setfile identity across manifest-derived storage lanes.
- `tools/strategy_farm/farmctl.py:15828` creates a new current-contract child,
  preserves the source row, binds its exact frozen-input dependency/hash, and
  installs the sealed-plan hold. The source full UUID and aggregate SHA-256 are
  durable payload fields, and a prior child deduplicates the operation.
- `tools/strategy_farm/farmctl.py:16013` preserves stale immutable include closures
  and creates a work-item-scoped immutable successor when source inventory or EX5
  identity has legitimately moved.
- `tools/strategy_farm/farmctl.py:16042` supports exact-ID sealing for deterministic
  bounded operations; `tools/strategy_farm/farmctl.py:16178` asks the unchanged
  contract-v3 planner for the full matrix only on expansion children.
- `tools/strategy_farm/farmctl.py:19020` places bounded expansion authoring before
  late autoseal in the pump, so a new request can be authored, sealed, bound, and
  released in one pump cycle. The ordinary terminal worker remains the runner.
- `tools/strategy_farm/farmctl.py:27177` adds a dry-run-default CLI with an explicit
  `--apply`, pair allowlist, historical UNION-read option, and hard row limit.
- `tools/strategy_farm/health.py:4160` adds `news_gate_service_rate`; its current
  value contains conclusions in 24 hours, unresolved expansions, their child IDs,
  and the historical `PENDING_RUNNER` count.
- Role-based v4 tests are in `tools/strategy_farm/tests/test_news_gate_service.py:22`
  and exact-ID/closure lifecycle coverage is in
  `tools/strategy_farm/tests/test_q09_news_farmctl_integration.py:901`.

## Runtime application

Command (the noncanonical flag allows the explicitly required worktree code to
run; it does not alter factory state):

```powershell
$env:QM_ALLOW_NONCANONICAL='1'
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-news-expansions --include-historical --pair-allowlist-csv D:/QM/reports/rebaseline/path_to_25_top80.csv --limit 10 --apply
```

Result: `candidate_count=7`, `planned_count=4`, `created_count=4`, `skipped=[]`.
The exact rows are:

| Rank | Pair | Source adjudication | Frozen-input row | Expansion child | Plan SHA-256 | Plan file SHA-256 | Snapshot state |
|---:|---|---|---|---|---|---|---|
| 3 | QM5_11422 / USDCAD.DWX | `4984cca7-e1a3-49a8-a066-066ac51eb063` | `9fe3eb5f-ab0d-4c84-82fe-d6748c3aa270` | `d712832c-b41b-471c-a986-79f7f17f8dfb` | `802ca4aff8e7d2651949c4b2f102e24608f1d34ad564248efdf8f5610fbdc12b` | `d77f90914e1b827b329d74e3459d75528da811b70adb1f911217480065628f33` | pending / RUNNABLE_BOUND / hold inactive |
| 19 | QM5_20266 / XTIUSD.DWX | `4263d6b3-1418-47c4-afe1-de7cb6bf61d4` | `87731bac-29cc-4846-ac26-b348b13af59b` | `5f1b3b71-51f3-4cbe-9cf5-08ce6d11404d` | `2320ac4462f9c9244f949a4780d37af29d34a759f828b3b47506dcd56e32c16c` | `d392fd0e85db3623799d20471a4af881f9d6b41b9590793a8ff486b443704e75` | pending / RUNNABLE_BOUND / hold inactive |
| 21 | QM5_12849 / XTIUSD.DWX | `db92d69a-c86f-4a48-a31b-e68f1034e006` | `bdd1662a-245a-4d3e-9e8f-2afb4727cd41` | `d00ee295-0e9b-4346-aaf7-7c3378bcc015` | `f0f3f9e8bb40258cad757611a35dbd4cfd83adf127cf207042d1ff1f5fcb4de1` | `f82726c14278f961d5124d521e8f16802c537ae457023fd2d82a810d35c89675` | pending / RUNNABLE_BOUND / hold inactive |
| 25 | QM5_21505 / XAGUSD.DWX | `c8f1f977-46fe-48ea-9d20-68926f938d7c` | `9c51f7eb-d3a2-435c-a50d-66ade0356f5c` | `07d44cb2-8f7a-42cd-b422-1b92f32cf978` | `0495ec57cb2b906eccdf85bc2e9981ca453d5b27e5dcfae10b37d20ab5e1b89e` | `ce399ed0f32a3863b8caaf4cc793b267e417c46ed7adb9863fc02bc417624423` | active / T3 / runner spawned |

Plan paths are
`D:/QM/reports/work_items/<child>/q09_contract_v3/run_plan.json`. Direct JSON
inspection returned `schema_version=q09-news-run-plan/v3`,
`contract_version=q09-news-evidence/v3`, `cell_count=29`, `window_count=2`,
`matrix_scope=7x4`, and the sole unique physical seed `[17]` for every row.

The fourth row initially failed closed on an old source-inventory closure. Its old
closure was not overwritten; the new code authored a child-scoped closure and the
targeted retry then sealed successfully.

## `PENDING_RUNNER` root cause and per-row disposition

Read-only query:

```sql
SELECT id,status,verdict,
       json_extract(payload_json,'$.terminal') AS terminal,
       json_extract(payload_json,'$.claimed_at_iso') AS claimed_at,
       json_extract(payload_json,'$.verdict_reason') AS verdict_reason
FROM work_items
WHERE phase='Q09_NEWS' AND verdict='PENDING_RUNNER';
```

All 18 rows are `status=done`, were claimed by T1/T6/T8/T9/T10 on 2026-07-31,
and have the same exact reason: `phase runner not implemented yet -- skipping for
now`. They are not unclaimed queue rows: all have no active hold, no evidence path,
and no sealed-plan payload. Consequently the honest disposition is to preserve
them as terminal historical placeholders. Every pair already has current
append-only news work, so this ticket did not create duplicate placeholder reruns.

| Legacy row | Pair | Current continuation | Match | Current state at audit |
|---|---|---|---|---|
| `0d1ca438-8406-4d1a-be3d-78747bded77f` | QM5_10123 / XAUUSD.DWX | `04a3fe87-42a7-4600-bfea-dbc3fe8af2dd` | pair | pending / awaiting sealed plan |
| `dc8acca8-ad76-4537-a26b-2e27bb50de27` | QM5_10128 / XAUUSD.DWX | `2ac15e24-869c-471f-bd4d-39cbd2cfc2c7` | exact | pending / awaiting sealed plan |
| `45e542dc-054c-4840-8f82-07f46e8fd3b8` | QM5_10142 / SP500.DWX | `64453ed3-225f-4984-9a33-fa43f70d047c` | exact | pending / runnable bound |
| `a43668a9-3c24-4e7d-85d8-8170f082464a` | QM5_10145 / XAUUSD.DWX | `360a3045-8d6c-48f1-9da5-993f3a1b4804` | pair | pending / awaiting sealed plan |
| `aae933c1-da29-4162-88a3-13b623f377de` | QM5_10145 / XAUUSD.DWX | `360a3045-8d6c-48f1-9da5-993f3a1b4804` | pair | pending / awaiting sealed plan |
| `d983f1c5-cf07-48a1-8219-8d9db5323df4` | QM5_10145 / XAUUSD.DWX | `360a3045-8d6c-48f1-9da5-993f3a1b4804` | exact | pending / awaiting sealed plan |
| `4181f033-98ec-4be6-9110-010be9561856` | QM5_10183 / XAUUSD.DWX | `ce131b6f-4805-4b08-8781-b6b676784224` | exact | pending / awaiting sealed plan |
| `cd7c4076-55e1-4ca2-8e47-69d1966b74b8` | QM5_10692 / NDX.DWX | `99f28ea8-582f-4fc7-859b-48766eab6f47` | exact | pending / awaiting sealed plan |
| `54b09aa1-8b23-4bab-a178-71aaa0ab1bd5` | QM5_10911 / GDAXI.DWX | `9c6ca9c7-a215-40e8-ab5c-d7628c74355a` | exact | pending / awaiting sealed plan |
| `5e8fc613-35d7-433f-8db0-bf51f32cc30f` | QM5_10938 / GDAXI.DWX | `a25b2479-8455-4156-af58-a1298e55e6f7` | exact | pending / awaiting sealed plan |
| `b368b117-9122-4d77-a63d-6bf2eaa80bb7` | QM5_11421 / EURUSD.DWX | `30584122-b7b3-41eb-8e1a-b03517554d4d` | exact | pending / awaiting sealed plan |
| `87af2578-b9ba-4010-9776-07faa4e729d5` | QM5_11422 / USDCAD.DWX | `d712832c-b41b-471c-a986-79f7f17f8dfb` | exact | pending / runnable bound |
| `2c9c441a-e2e4-42ee-879a-be2c659fd60b` | QM5_12567 / XAUUSD.DWX | `7bbeef66-becf-4bd3-aa5c-1d00bde262d8` | exact | pending / awaiting sealed plan |
| `2571184b-22cc-431b-8c12-aad057a98931` | QM5_13013 / NDX.DWX | `36304cfd-02c5-48e5-9502-a67f253ac6d8` | exact | pending / awaiting sealed plan |
| `7efd8e39-4d1c-4b6d-8cfd-637122aad25f` | QM5_13036 / GDAXI.DWX | `174e2b8f-53b4-401b-ac61-f581f948b7ab` | exact | pending / awaiting sealed plan |
| `0334a69e-bccb-4305-8235-ce7484488fa6` | QM5_1328 / EURJPY.DWX | `13f41983-74c6-4058-8a41-c787633a1391` | exact | pending / awaiting sealed plan |
| `2bd6d6f5-2dc1-44a7-942f-745146b3a993` | QM5_13301 / GDAXI.DWX | `84c6e9e9-76a8-4cd4-87b4-647d7fad3c1a` | exact | pending / awaiting sealed plan |
| `eca6862c-4f3e-462f-89f4-c8895d3dbfa7` | QM5_20048 / XTIUSD.DWX | `05ac13bc-cd1c-4a78-bba3-42e5d4face89` | exact | pending / awaiting sealed plan |

Executing `pending_claim_order_sql()` against the runtime database after binding
returned all four new expansion child UUIDs. T3 subsequently claimed
`07d44cb2-8f7a-42cd-b422-1b92f32cf978`; the same query then returned the other
three. `D:/QM/strategy_farm/logs/work_item_07d44cb2-8f7a-42cd-b422-1b92f32cf978.log`
records the 2026-08-23T19:06:01Z spawn of `q09_news_runner.py execute`, and cell
receipts are present below the child's plan directory. This proves the corrected
lifecycle releases bound rows into the existing runner; terminal historical
placeholder rows correctly remain excluded because their status is `done`.

## Health snapshot

Read-only URI:
`file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`.

`chk_news_gate_service_rate` returned `WARN` with
`conclusive_verdicts_per_day=0`, `expansions_pending=7`, and
`pending_runner_count=18`. Four of the seven unresolved authenticated expansion
requests now contain the child IDs in the runtime table above; the other three
pairs were outside the authorized top-80 allowlist. This warning is the intended
visible dam signal until a child concludes `CONFIG_LOCKED`.

## Tests

```text
python -m pytest -q tools/strategy_farm/tests/test_news_gate_service.py tools/strategy_farm/tests/test_q09_news_farmctl_integration.py
27 passed in 5.35s

python -m pytest -q tools/strategy_farm/tests/test_news_gate_service.py tools/strategy_farm/tests/test_q09_news_contract_v2.py tools/strategy_farm/tests/test_q09_news_runner_v2.py tools/strategy_farm/tests/test_q09_news_schema_v2.py tools/strategy_farm/tests/test_q09_news_seam.py tools/strategy_farm/tests/test_q09_news_farmctl_integration.py tools/strategy_farm/tests/test_q09_news_migration_v2.py tools/strategy_farm/tests/test_health_q09_sealed_plan_hold_age.py tools/strategy_farm/tests/test_q09_autoseal_hold_census.py tools/strategy_farm/tests/test_health_vacuousness.py tools/strategy_farm/tests/test_v4_runtime_wiring.py
155 passed in 108.23s

python -m pytest -q tools/strategy_farm/tests
4237 passed, 4 skipped, 282 failed, 42 subtests passed in 1575.74s

python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/health.py tools/strategy_farm/news_gate_service.py
PASS

git diff --check
PASS
```

The mandatory full-directory run completed. Its 282 failures are pre-existing,
repository-wide baseline failures outside the touched news files (prominent
clusters include `test_agent_router.py`, `test_target_outcome_dossier.py`, and
`test_target_rulepacks.py`). The final touched-module run above is green and was
executed after the last code/test edit.

## Runtime risk and follow-up

One of four expansions is active and three are queued, so the health check must
remain WARN until adjudication produces `CONFIG_LOCKED`. During the audit, an
early T3 restart logged a transient schema-6/schema-7 version-skew error in
`D:/QM/strategy_farm/logs/terminal_worker_T3.log.err`; a subsequent T3 startup
passed its startup gate and claimed the active child. Monitor worker restarts for
recurrence when this branch is merged to the canonical worker checkout. The
factory was not toggled and no extra worker process was launched.

## Rollback

Code rollback is `git revert <this-commit>`. Runtime rollback must remain
append-only: do not delete the four children or rewrite their source verdicts.
If the service must be withdrawn, preserve the rows and use the governed
supersession/hold mechanism with a durable reason. The four immutable plan and
closure artifacts under `D:/QM/reports` can remain as evidence; removing them
while rows reference their hashes would break provenance.
