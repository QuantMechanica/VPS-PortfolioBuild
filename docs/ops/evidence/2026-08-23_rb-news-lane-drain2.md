# rb-news-lane-drain2 evidence — 2026-08-24 execution

## Scope and controls

Executed ticket `rb-news-lane-drain2` from `C:\QM\worktrees\rb-news-lane-drain2` against `D:\QM\strategy_farm`. Read-only census queries used `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`. Runtime writes used the existing governed append-only paths (`farmctl enqueue-news-expansions`, `farmctl enqueue-backtest`, autoseal/bind, and the CAS-guarded `expedite_batch_rows.py`). No verdict was overwritten, no row was deleted, the factory was not toggled, no backtest was deleted, no gate criterion changed, and `C:\QM\mt5\T_Live` was not touched.

Required context read before execution:

- `docs/ops/rebaseline/GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md`
- `docs/ops/rebaseline/FACTORY_AUTOMATION_INVENTORY_2026-08-23.md`
- `docs/ops/rebaseline/GATE_NAME_CENSUS_2026-08-23.md`
- `G:\My Drive\QuantMechanica - Company Reference\03 Pipeline\Pipeline Rebaseline Directive 2026-08-23.md`

## Code changes

- `tools/strategy_farm/build_q09_include_closure.py:98` accepts an already authenticated exact EA directory and preserves the prior fail-closed glob for callers without one; build and validation use the same directory (`:153`, `:224`).
- `tools/strategy_farm/farmctl.py:15961` recognizes only the authenticated launch-fault class: failed/`INFRA_FAIL`, exact `summary_missing:launch_fault`, immutable plan and manifest hashes intact, missing path below a `worktrees` component, and same-hash canonical EX5. `author_news_expansion_continuations` at `:16031` then permits one append-only retry and records the failed child plus stale/canonical paths. Autoseal anchors closure construction to the setfile-owned EA directory at `:16245` and `:16365`.
- `tools/strategy_farm/q09_news_runner.py:854` revalidates the closure against the immutable manifest's EX5 directory, eliminating runner-time sibling-directory ambiguity.
- `tools/strategy_farm/news_gate_service.py:17` maps structured autoseal failures to stable hold classes. `service_metrics` at `:127` now returns counts and exact rows per class.
- `tools/strategy_farm/health.py:4130` counts optimization backlog only when the payload is authored by the optimization-fork schema and carries an active manifest hash. This preserves historical v3 payload rows but excludes them from v4 backlog, with `backlog_scope=optimization_fork_schema+active_manifest_sha256` in the check detail. `chk_news_gate_service_rate` at `:4168` publishes the hold-cause breakdown.

Regression coverage is at:

- `tools/strategy_farm/tests/test_build_q09_include_closure.py:39`
- `tools/strategy_farm/tests/test_news_gate_service.py:44` and `:113`
- `tools/strategy_farm/tests/test_optimization_fork_driver.py:283`
- `tools/strategy_farm/tests/test_q09_news_farmctl_integration.py:650`
- `tools/strategy_farm/tests/test_q09_news_runner_v2.py:109`

## Expansion launch faults

The three failed immutable manifests pointed at EX5 files below the removed authoring worktree `C:\QM\worktrees\rb-news-gate-dam\...`; the canonical `C:\QM\repo\framework\EAs\...` EX5 existed and matched each sealed `identities.ex5_sha256`. The child logs end in `RunnerError: ex5 missing: C:\QM\worktrees\rb-news-gate-dam\...`:

| failed child | pair | log / immutable evidence | append-only successor | observed 2026-08-24 ~07:34 local |
|---|---|---|---|---|
| `07d44cb2-8f7a-42cd-b422-1b92f32cf978` | QM5_21505 / XAGUSD.DWX | `D:\QM\strategy_farm\logs\work_item_07d44cb2-8f7a-42cd-b422-1b92f32cf978.log`; `D:\QM\reports\work_items\07d44cb2-8f7a-42cd-b422-1b92f32cf978\q09_contract_v3\input_manifest.json` | `463fa52a-33fa-4d23-b318-dda3d73b12e1` | active T5 |
| `d00ee295-0e9b-4346-aaf7-7c3378bcc015` | QM5_12849 / XTIUSD.DWX | `D:\QM\strategy_farm\logs\work_item_d00ee295-0e9b-4346-aaf7-7c3378bcc015.log`; immutable manifest under the same work-item report root | `e58b8c4c-3894-4aa7-8c9f-fd2d34ac3ebe` | active T1 |
| `5f1b3b71-51f3-4cbe-9cf5-08ce6d11404d` | QM5_20266 / XTIUSD.DWX | `D:\QM\strategy_farm\logs\work_item_5f1b3b71-51f3-4cbe-9cf5-08ce6d11404d.log`; immutable manifest under the same work-item report root | `9416f0ce-ede3-457e-bf9a-5ed9f892e177` | active T9 |

The exact-pair allowlist dry run planned these three retries and the apply created exactly three rows. Autoseal then sealed all three (29 cells each) and released their `Q09_AWAITING_SEALED_PLAN` holds. The same exact-directory fix sealed `13f41983-74c6-4058-8a41-c787633a1391` (QM5_1328/EURJPY) and `73b21148-65be-4aad-a2dd-fb7c2f22e9bc` (QM5_9936/USDJPY), the two former include-closure ambiguity holds.

## PENDING_RUNNER terminal placeholders

Query:

```sql
SELECT * FROM work_items
WHERE phase IN ('Q09_NEWS','Q10_NEWS')
  AND status='done' AND verdict='PENDING_RUNNER'
ORDER BY ea_id,symbol,id;
-- 18 rows
```

Every terminal placeholder has a live pair-level v4 frontier. Where historical setfile variants existed, the governed v4 selection is explicitly named rather than fabricating parallel news rows.

| placeholder id | pair | disposition |
|---|---|---|
| `0d1ca438-8406-4d1a-be3d-78747bded77f` | QM5_10123/XAUUSD | v4 frontier `04a3fe87`; Q07 regen `3c8b743c` |
| `dc8acca8-ad76-4537-a26b-2e27bb50de27` | QM5_10128/XAUUSD | exact v4 successor `2ac15e24`; Q07 regen `a110f85e` |
| `45e542dc-054c-4840-8f82-07f46e8fd3b8` | QM5_10142/SP500 | exact v4 successor `64453ed3` pending |
| `a43668a9-3c24-4e7d-85d8-8170f082464a` | QM5_10145/XAUUSD | governed selected v4 frontier `360a3045`; Q07 regen `00f84670` |
| `aae933c1-da29-4162-88a3-13b623f377de` | QM5_10145/XAUUSD | governed selected v4 frontier `360a3045`; Q07 regen `00f84670` |
| `d983f1c5-cf07-48a1-8219-8d9db5323df4` | QM5_10145/XAUUSD | exact v4 successor `360a3045`; Q07 regen `00f84670` |
| `4181f033-98ec-4be6-9110-010be9561856` | QM5_10183/XAUUSD | exact v4 successor `ce131b6f`; Q07 regen `35532806` |
| `cd7c4076-55e1-4ca2-8e47-69d1966b74b8` | QM5_10692/NDX | exact v4 successor `99f28ea8`; Q07 regen `64c42802` |
| `54b09aa1-8b23-4bab-a178-71aaa0ab1bd5` | QM5_10911/GDAXI | exact v4 successor `9c6ca9c7`; Q07 retry `cc0cdf9e` |
| `5e8fc613-35d7-433f-8db0-bf51f32cc30f` | QM5_10938/GDAXI | exact v4 successor `a25b2479`; Q07 regen `902f7307` |
| `b368b117-9122-4d77-a63d-6bf2eaa80bb7` | QM5_11421/EURUSD | exact v4 successor `30584122`; Q08 rerun `9d183609` |
| `87af2578-b9ba-4010-9776-07faa4e729d5` | QM5_11422/USDCAD | v4 row `21eb42e1`; expansion child `d712832c` pending |
| `2c9c441a-e2e4-42ee-879a-be2c659fd60b` | QM5_12567/XAUUSD | exact v4 successor `7bbeef66`; Q08 rerun `c089a98d` |
| `2571184b-22cc-431b-8c12-aad057a98931` | QM5_13013/NDX | exact v4 successor `36304cfd`; existing Q07 regen `68875929` |
| `7efd8e39-4d1c-4b6d-8cfd-637122aad25f` | QM5_13036/GDAXI | exact v4 successor `174e2b8f` pending |
| `0334a69e-bccb-4305-8235-ce7484488fa6` | QM5_1328/EURJPY | exact v4 successor `13f41983`, sealed and hold released |
| `2bd6d6f5-2dc1-44a7-942f-745146b3a993` | QM5_13301/GDAXI | exact v4 successor `84c6e9e9`; Q07 regen `e04ed006` |
| `eca6862c-4f3e-462f-89f4-c8895d3dbfa7` | QM5_20048/XTIUSD | exact v4 successor `05ac13bc`; Q07 regen `bf54ff43` |

No additional news row was required for this census.

## Bind-fail census and governed disposition

The active hold query joined `work_items` to `work_item_holds` on active `Q09_AWAITING_SEALED_PLAN`, then read `payload_json.q09_autoseal_failure`. Before the two closure releases it returned 46 rows: Q07 evidence missing 23, Q07 lineage missing 3, Q08 vintage 17, Q08 evidence missing 1, and include closure 2. After the exact-directory repair the 2 include-closure holds were released; health now reports 44 active holds with the remaining four cause classes.

| held news id | pair | exact cause | disposition / successor |
|---|---|---|---|
| `9812fc7b` | QM5_10114/SP500 | Q07 evidence missing | WAITS_ON_Q07_REGEN `fba8d002` |
| `1773b453` | QM5_10115/GDAXI | Q07 evidence missing | WAITS_ON_Q07_REGEN `517ebc7b` |
| `04a3fe87` | QM5_10123/XAUUSD | Q07 evidence missing | WAITS_ON_Q07_REGEN `3c8b743c` |
| `2ac15e24` | QM5_10128/XAUUSD | Q07 evidence missing | WAITS_ON_Q07_REGEN `a110f85e` |
| `6ea0cd9f` | QM5_10145/SP500 | Q07 evidence missing | WAITS_ON_Q07_REGEN `0edd8fd6` |
| `360a3045` | QM5_10145/XAUUSD | Q07 evidence missing | WAITS_ON_Q07_REGEN `00f84670` |
| `15cf7483` | QM5_10146/AUDUSD | Q07 evidence missing | WAITS_ON_Q07_REGEN `08e7d4fb` |
| `ce131b6f` | QM5_10183/XAUUSD | Q07 evidence missing | WAITS_ON_Q07_REGEN `35532806` |
| `b321eb30` | QM5_10403/XAUUSD | Q08 vintage + missing durable Q07 evidence | WAITS_ON_Q07_REGEN `831c9521` |
| `2dd1aef8` | QM5_10513/XAUUSD | Q08 vintage + missing durable Q07 evidence | WAITS_ON_Q07_REGEN `ec0344ec` |
| `99f28ea8` | QM5_10692/NDX | Q07 evidence missing | WAITS_ON_Q07_REGEN `64c42802` |
| `cdfc4ddc` | QM5_10706/GBPUSD | Q08 vintage | WAITS_ON_Q07_REGEN `81cd341c` (pre-existing priority row) |
| `57d8bacd` | QM5_10815/GDAXI | Q08 evidence file missing | BLOCKED_Q08_EVIDENCE_MISSING_REBUILD_REQUIRED |
| `49a059da` | QM5_10847/GDAXI | Q07 lineage absent | BLOCKED_Q05_ECONOMIC_FAIL_NO_Q06_Q07 |
| `f11985e3` | QM5_10848/XAUUSD | Q07 evidence missing | WAITS_ON_Q07_REGEN `e0f6453a` |
| `9c6ca9c7` | QM5_10911/GDAXI | Q08 vintage + prior Q07 regen failed | WAITS_ON_Q07_REGEN retry `cc0cdf9e` |
| `a25b2479` | QM5_10938/GDAXI | Q07 evidence missing | WAITS_ON_Q07_REGEN `902f7307` |
| `9639a773` | QM5_10939/GBPUSD | Q08 vintage | NEEDS_Q08_RERUN enqueued `8234812d` |
| `92158087` | QM5_10939/XAUUSD | Q08 vintage | NEEDS_Q08_RERUN enqueued `5692fd6b` |
| `c9c3c2a2` | QM5_11124/SP500 | Q08 vintage + missing durable Q07 evidence | WAITS_ON_Q07_REGEN `b7726d9d` |
| `3888c02c` | QM5_11124/WS30 | Q07 evidence missing | WAITS_ON_Q07_REGEN `209f2f40` |
| `30584122` | QM5_11421/EURUSD | Q08 vintage | NEEDS_Q08_RERUN enqueued `9d183609` |
| `08fe4173` | QM5_11476/USDJPY | Q07 lineage absent | BLOCKED_Q07_PREDECESSOR_MISSING |
| `f290aa11` | QM5_11708/EURUSD | Q08 vintage + missing durable Q07 evidence | WAITS_ON_Q07_REGEN `f35e08ce` |
| `7bbeef66` | QM5_12567/XAUUSD | Q08 vintage | NEEDS_Q08_RERUN enqueued `c089a98d` |
| `5302ac48` | QM5_12623/XAUUSD | Q07 evidence missing | WAITS_ON_Q07_REGEN `1505ff12` (pre-existing priority row) |
| `e6aaf4b4` | QM5_12823/USDJPY | Q07 evidence missing | WAITS_ON_Q07_REGEN `5ab267f0` |
| `84608819` | QM5_12831/custom XTI-AUDUSD | Q07 evidence missing | WAITS_ON_Q07_REGEN `9398e0b3` |
| `cc670aa2` | QM5_12847/NDX | Q07 evidence missing | WAITS_ON_Q07_REGEN `d5484501` (pre-existing priority row) |
| `00f61d53` | QM5_12915/SP500 | Q07 evidence missing | WAITS_ON_Q07_REGEN `e78721f3` |
| `5b3d7bb3` | QM5_12969/USDJPY | Q08 vintage + missing durable Q07 evidence | WAITS_ON_Q07_REGEN `e30dbad3` |
| `1cff016c` | QM5_12989/XAUUSD | Q08 vintage | BLOCKED_REBUILD_REQUIRED (documented source/closure drift) |
| `36304cfd` | QM5_13013/NDX | Q07 lineage absent | WAITS_ON_Q07_REGEN `68875929` (pre-existing open row) |
| `bf7557c3` | QM5_13108/XTIUSD | Q07 evidence missing | WAITS_ON_Q07_REGEN `88d316c5` |
| `aa80274f` | QM5_13128/NDX | Q08 vintage | BLOCKED_SOURCE_CLOSURE_DRIFT_REBUILD_REQUIRED |
| `72f7d4c1` | QM5_13213/USDJPY | Q08 vintage + missing durable Q07 evidence | WAITS_ON_Q07_REGEN `002ccb7f` |
| `84c6e9e9` | QM5_13301/GDAXI | Q08 vintage + missing durable Q07 evidence | WAITS_ON_Q07_REGEN `e04ed006` |
| `d81d9ea8` | QM5_1556/XAUUSD | Q08 vintage | NEEDS_Q08_RERUN enqueued `5a396f28` |
| `2604a1f0` | QM5_1567/EURUSD | Q08 vintage | BLOCKED_COMPILE_REBUILD_REQUIRED |
| `ab2fd18a` | QM5_20047/XTIUSD | Q07 evidence missing | WAITS_ON_Q07_REGEN `719a1b21` |
| `05ac13bc` | QM5_20048/XTIUSD | Q07 evidence missing | WAITS_ON_Q07_REGEN `bf54ff43` |
| `e8722c6b` | QM5_9403/GDAXI | Q07 evidence missing | WAITS_ON_Q07_REGEN `354dfecb` |
| `11874a1f` | QM5_9502/SP500 | Q07 evidence missing | WAITS_ON_Q07_REGEN `dc69608b` |
| `b4ebfe77` | QM5_9503/USDJPY | Q07 evidence missing | WAITS_ON_Q07_REGEN `28fffbdb` |

Result: 29 append-only Q07 rows and 5 append-only Q08 rows exist, all 34 carrying `priority_track=true`. At the final snapshot all 29 Q07 and all 5 Q08 rows were pending. The CAS priority journal is `D:\QM\reports\state\rb-news-lane-drain2-priority-journal.json`. The automatic continuation path is covered by `test_autoseal_replaces_immutable_predecessor_after_append_only_q08` and its adjacent pump retry-order test in `test_q09_news_farmctl_integration.py`; a completed authenticated Q07 can therefore produce its exact Q08 rerun and the regenerated Q08 produces a replacement news row for autoseal without changing the held row's immutable dependency.

## Stranded v3-payload Q12 rows

No general farmctl governed payload-supersession writer exists. Per the ticket's explicit fallback, the rows remain unchanged and are documented as inert historical payloads:

| id | column contract | payload contract | payload manifest | state | v4 backlog disposition |
|---|---|---|---|---|---|
| `48183f09-ad48-5c42-b1b6-9e7787b5ac32` | v4 | v3 | `988f9dea709bb71de5d7b6bce3c02ea02417cd63f447767853281c8f5f8fc6ce` | pending, no verdict | excluded: payload manifest is not active v4 |
| `8eda68d9-aae3-509c-a0cc-6e738e1bde99` | v4 | v3 | `988f9dea709bb71de5d7b6bce3c02ea02417cd63f447767853281c8f5f8fc6ce` | pending, no verdict | excluded: payload manifest is not active v4 |
| `9975987c-d408-5724-8863-f4e49a214d4b` | v4 | v3 | `988f9dea709bb71de5d7b6bce3c02ea02417cd63f447767853281c8f5f8fc6ce` | pending, no verdict | excluded: payload manifest is not active v4 |

Live `chk_opt_fork_service_rate` from the worktree reports `status=OK`, `pending_or_active=0`, and the explicit active-manifest backlog scope. No payload or verdict on these three rows was overwritten.

## Health evidence

Live worktree check after the two closure releases:

```text
news_gate_service_rate WARN
conclusive_verdicts_24h=0; expansions_pending=12; PENDING_RUNNER=18;
active_holds=44; hold_causes={"Q07_EVIDENCE_MISSING": 23,
"Q07_LINEAGE_MISSING": 3, "Q08_EVIDENCE_MISSING": 1, "Q08_VINTAGE": 17}

opt_fork_service_rate OK
pending_or_active=0; backlog_scope=optimization_fork_schema+active_manifest_sha256
```

The health status remains WARN until a conclusive news verdict completes; the drain is active and observable rather than falsely reported clear.

## Tests

```text
python -m pytest tools/strategy_farm/tests/test_build_q09_include_closure.py \
  tools/strategy_farm/tests/test_news_gate_service.py \
  tools/strategy_farm/tests/test_optimization_fork_driver.py \
  tools/strategy_farm/tests/test_q09_news_farmctl_integration.py \
  tools/strategy_farm/tests/test_q09_news_runner_v2.py \
  tools/strategy_farm/tests/test_health_q09_sealed_plan_hold_age.py \
  tools/strategy_farm/tests/test_mnt035_health_contract.py -q
95 passed in 86.65s

python -m pytest tools/strategy_farm/tests/test_optimization_fork_driver.py -q
7 passed in 1.75s  # final health-detail change

python -m pytest tools/strategy_farm/tests -q
4594 passed, 4 skipped, 6 failed, 42 subtests passed in 1619.78s
```

The six full-suite failures reproduce when run alone (`6 failed in 13.51s`) and do not touch changed files:

- `test_build_gate_hardening.py::test_qm5_411xx_sources_have_no_unbounded_numeric_buffers`: five existing QM5_411xx source lint findings.
- Four `test_execution_contract_lint.py` nodes: external `D:\QM\data\news_calendar\news_calendar_2015_2025.csv` hash/coverage differs from its registry contract.
- `test_opt_census_dispatch.py::test_opt_census_ranks_tier6_not_priority`: existing OPT_CENSUS/Q04 active-manifest rank expectation mismatch (`6 != 7`).

## Rollback

- Code: revert the ticket commit; do not reset the worktree or alter unrelated changes.
- Priority payloads: `python C:/QM/repo/tools/strategy_farm/expedite_batch_rows.py --revert D:/QM/reports/state/rb-news-lane-drain2-priority-journal.json`. This removes only markers written by this batch.
- Runtime successor rows are append-only evidence and must not be deleted. If a successor proves invalid, preserve it and use the governed append-only supersession/rerun path with an exact predecessor and reason.
- Sealed plan artifacts are immutable under `D:\QM\reports\work_items\<id>\q09_contract_v3`; rollback must not overwrite them.

## Residual risks / open questions

- Six blocked pairs require OWNER/upstream build decisions; this ticket correctly does not bypass their economic, source-closure, compile, or missing-predecessor failures.
- The 34 regeneration rows must complete before their held pairs can automatically rebind; health now exposes the remaining cause count throughout that drain.
- The service still has zero conclusive verdicts in 24h at the snapshot. Three repaired expansion rows are active, so the next evidence point is their terminal adjudication, not another enqueue.
- The three inert v3-payload Q12 rows remain preserved because no farmctl governed supersession writer exists. The active-manifest health filter prevents permanent false backlog without rewriting historical payloads.
