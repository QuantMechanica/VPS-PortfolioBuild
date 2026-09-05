# Compile backlog binding review — 2026-09-05

Router task: `27c0ea5a-510f-4233-822f-27d4ece5f40b`. Result: **REVIEW; dry-run only**. Snapshot: 2026-09-05T17:22:30.176134+00:00.

The report covers all 25 rows in the current scope: 21 held pending utility-compile rows and the four named failed waves. The wider raw census contains 54 pending/failed-today rows; it is included in census.json to make exclusions reviewable. This is a current snapshot, not a frozen reconstruction of the ticket-creation cohort: QM5_12947 entered the queue at 17:10Z. There are 24 distinct EAs because QM5_1538 has two held rows.

The premise “all remaining rows bind BLOCKED tasks” is false. Six rows bind pending tasks, five source-fresh rows are unbound, and eight rows have source drift. No row or build result was rewritten. The task binding uses the legacy `tasks` table (`kind=build_ea`, `status`), not `agent_tasks.state`; original block text is in task payloads (usually `codex_result.blocked_reason`). Related router verdicts, when present, are retained separately in census.json.

## Four failed waves

QM5_41164/41165/41166 were blocked on 2026-08-30 after ad-hoc compilation was refused and the governed row remained under the rollout hold. Their recorded reason describes infrastructure/rollout, not a new magic defect or quota exhaustion. QM5_41166 also carries a generic `magic_collision` fail code; the full reason says the existing queue was held, so that code alone is not the root cause. QM5_41172 has a circular duplicate reconciliation: one task names the other as survivor, and both are blocked. Reopening either blindly would undo dedup evidence.

At this snapshot all four EAs already have a different sole open build task. **Do not mint a third task or reopen an old one.** The existing unchanged-source retry helper authenticates their failure evidence and new task binding, then refuses on `WORK_ITEMS_EXIST` and `BOUND_SETFILE_HASH_EXISTS`. Its sanctioned lineage covers only the immediate failed predecessor; these rows have earlier history and bound sets. An explicitly reviewed extension for the exact existing lineage/setfile evidence is needed before any apply. No history or setfile header should be deleted to bypass these checks.

The retry contract requires a different task id (`BUILD_TASK_BINDING_NOT_RENEWED` for the old id). Reopening the old task cannot meet that contract. See `tools/strategy_farm/compile_work_items.py:4312`, binding status check at line 2962 and worker recheck at line 4838. The general source-repair successor at line 4176 is a different contract: it requires changed source and forbids silently replacing a nonempty old build binding. The QM5_41345 recipe cannot be generalized across these cases.

## Per-row table

Full hashes, original block text, every other build task payload, related agent verdicts, actual candidate decisions and four actual dry-run outputs are in [census.json](2026-09-05_compile_backlog_binding/census.json). Hash prefixes below are for reading only.

| EA / work item | Bound build task / state | Recorded reason | Source expected → actual | Recommendation |
|---|---|---|---|---|
| QM5_41176 / `f89d82e9-f4e2-4567-b8f2-464d4997ce09` | `none` / unbound | No task binding | `23ca6f5cef5b` → `f2d1a3023857` (STALE_OR_MISSING) | SOURCE: coordinate fd5e3ce3; no second authority |
| QM5_41179 / `9ced0252-9ceb-4fe7-a2c5-d7a8d0b30a82` | `none` / unbound | No task binding | `74e7f100f5d5` → `5e373104ee5b` (STALE_OR_MISSING) | SOURCE: coordinate fd5e3ce3; no second authority |
| QM5_41189 / `e5505264-01c4-4102-b3cd-9a275a6839ee` | `none` / unbound | No task binding | `3d0ba8910aca` → `e401421c63ff` (STALE_OR_MISSING) | SOURCE: coordinate fd5e3ce3; no second authority |
| QM5_41164 / `059d4860-337e-4833-91f3-5fdf81b55603` | `c521d1f2-f965-4f5b-b31d-d119e652400a` / blocked | build_check.ps1 refused ad-hoc execution: LIVE_FACTORY_AD_HOC_COMPILE_REFUSED (terminal64 processes are alive; ad-hoc compile/build_check is fail-closed refused while the factory i… (full text in census) | `e63f2177cec4` → `e63f2177cec4` (MATCH) | RETRY: use existing sole alternative; lineage/setfile review required |
| QM5_41165 / `c71f00bd-1f15-4db5-b4e8-20d73936a092` | `d78eaed8-8830-4fe9-aabe-c55c24841b25` / blocked | LIVE_FACTORY_AD_HOC_COMPILE_REFUSED: build_check.ps1 refused ad-hoc execution because terminal64 processes are alive ("terminal64 processes are alive; ad-hoc compile/build_check is… (full text in census) | `cf2a09f42cd6` → `cf2a09f42cd6` (MATCH) | RETRY: use existing sole alternative; lineage/setfile review required |
| QM5_41166 / `c495527e-9058-41e9-a63f-d791c25d7554` | `2dfb95ff-0e46-4a93-8d77-330998cd575d` / blocked | ad_hoc_build_check_refused_live_factory: build_check.ps1 -EALabel QM5_41166_xauxag-mrobust3-agree-rv returned failure_class=LIVE_FACTORY_AD_HOC_COMPILE_REFUSED ('terminal64 process… (full text in census) | `217d7f59a6f2` → `217d7f59a6f2` (MATCH) | RETRY: use existing sole alternative; lineage/setfile review required |
| QM5_41172 / `8fd59f9d-96d1-4a13-b820-f2960886822d` | `407940c1-ea15-4ee2-bea8-f041f8383bf3` / blocked | duplicate_pending_build_ea_reconciled | `9318ee56cadb` → `9318ee56cadb` (MATCH) | RETRY: use existing sole alternative; lineage/setfile review required |
| QM5_41168 / `a543f9c8-cdd1-4e9e-8c2a-30d19c2259ca` | `cb1f7ab7-e071-4b81-b3d2-7abde79d3415` / blocked | build_check.ps1 ad-hoc invocation refused fail-closed with LIVE_FACTORY_AD_HOC_COMPILE_REFUSED (terminal64 processes are alive; ad-hoc compile/build_check is refused, governed path… (full text in census) | `1b082c829da4` → `1b082c829da4` (MATCH) | PENDING: keep old closed; alternative exists; no generic rebind |
| QM5_41105 / `72e08081-b13c-4168-8988-8b790fa0340c` | `none` / unbound | No task binding | `9fa2683395d7` → `9fa2683395d7` (MATCH) | UNBOUND: retain governed lineage; inspect existing row |
| QM5_41207 / `7628b4c2-f7de-4532-912f-aed19c367100` | `f9442c68-f3dc-4be2-8793-51b84d25df89` / failed | governed_compile_queue_activation_hold: ad-hoc build_check.ps1 refused with LIVE_FACTORY_AD_HOC_COMPILE_REFUSED (terminal64 processes alive; pipeline_hint=farmctl.py enqueue-compil… (full text in census) | `ffbfc3e4845c` → `ffbfc3e4845c` (MATCH) | CLOSED: review pending-row renewal contract |
| QM5_41224 / `7b947ba4-f327-4eb2-af86-a0333e27de6a` | `ff4d22ef-de6d-49f1-83ac-80d62b4b810b` / pending | No block recorded | `fede16790ec2` → `fede16790ec2` (MATCH) | OPEN: retain task; evaluate existing row |
| QM5_1538 / `674da780-53ef-4e37-993c-b02ca4f0a243` | `b8761494-8807-41d8-b4a0-f1d4141588c4` / failed | build_check.result=FAIL LIVE_FACTORY_AD_HOC_COMPILE_REFUSED: terminal64 processes are alive; the governed compile path is required | `0bbcf752c7b5` → `f4d84bdfac61` (STALE_OR_MISSING) | SOURCE: coordinate fd5e3ce3; no second authority |
| QM5_1538 / `550b62ec-516d-4fba-b845-e0b1d61e9437` | `b8761494-8807-41d8-b4a0-f1d4141588c4` / failed | build_check.result=FAIL LIVE_FACTORY_AD_HOC_COMPILE_REFUSED: terminal64 processes are alive; the governed compile path is required | `78c02c2f7342` → `f4d84bdfac61` (STALE_OR_MISSING) | SOURCE: coordinate fd5e3ce3; no second authority |
| QM5_41192 / `0d00bf54-535c-4049-ad7f-fde0c6b13f12` | `none` / unbound | No task binding | `630cf4a9c18a` → `fec27056d36d` (STALE_OR_MISSING) | SOURCE: coordinate fd5e3ce3; no second authority |
| QM5_41268 / `7f224c84-9ae2-446e-a905-cb386e9695cc` | `a7bd58e8-3abc-41ff-8e8d-6076e0e793ec` / pending | No block recorded | `1be16d1d56e2` → `1be16d1d56e2` (MATCH) | OPEN: retain task; evaluate existing row |
| QM5_41285 / `e23cfbc8-3f6d-4b27-b369-c6061a6b44a5` | `5589bbaa-7b6c-433a-ae64-fad387bca3fc` / pending | No block recorded | `94954df95dc7` → `94954df95dc7` (MATCH) | OPEN: retain task; evaluate existing row |
| QM5_41308 / `bfc98851-3477-4f05-bf48-9636ed10da47` | `none` / unbound | No task binding | `96c6fd5a23bc` → `96c6fd5a23bc` (MATCH) | UNBOUND: retain governed lineage; inspect existing row |
| QM5_41312 / `f57662e7-6e12-4d96-b109-f0c437d6ce7f` | `cc48d74e-9541-46a1-a244-e1d69dfb06d7` / pending | No block recorded | `354ce0c1a52d` → `354ce0c1a52d` (MATCH) | OPEN: retain task; evaluate existing row |
| QM5_41142 / `07a09214-86ba-4946-9e0b-c9e7baa8b6fc` | `9d978a4c-4161-4e15-982d-0d1c56b696a7` / done | No block recorded | `1bb336bbbd3b` → `cb33049fcc85` (STALE_OR_MISSING) | SOURCE: coordinate fd5e3ce3; no second authority |
| QM5_41319 / `74fb5a2d-a4cd-43e3-bc12-e7dbeac67ac1` | `cd3a3f60-895d-49cc-850c-c2c42f09cc9d` / pending | No block recorded | `b13f136a3358` → `b13f136a3358` (MATCH) | OPEN: retain task; evaluate existing row |
| QM5_41336 / `0a80a328-3b81-4125-aa48-ed5686b7a962` | `cd7a9e1c-3677-4168-be52-60badda01d21` / pending | No block recorded | `a44763ce85b4` → `a44763ce85b4` (MATCH) | OPEN: retain task; evaluate existing row |
| QM5_41338 / `779b4e98-8ef6-4918-8903-07d074a8c523` | `none` / unbound | No task binding | `405202f5fa35` → `405202f5fa35` (MATCH) | UNBOUND: retain governed lineage; inspect existing row |
| QM5_41339 / `d79fa1aa-f91e-4d47-ac34-58633ce5eddf` | `none` / unbound | No task binding | `95a9c0486710` → `95a9c0486710` (MATCH) | UNBOUND: retain governed lineage; inspect existing row |
| QM5_41352 / `494b3cf3-1f24-4e33-bccf-673c7b3b5f64` | `none` / unbound | No task binding | `8f30b07b7f29` → `85042318f9b0` (STALE_OR_MISSING) | SOURCE: coordinate fd5e3ce3; no second authority |
| QM5_12947 / `e4bcce97-6655-45b9-92b8-8702d8c07966` | `none` / unbound | No task binding | `8f18ae119c72` → `8f18ae119c72` (MATCH) | UNBOUND: retain governed lineage; inspect existing row |

## Commands and task-state proposals

The following commands are all dry runs. The collector itself has no apply mode and opens SQLite with `mode=ro` and `query_only=ON`. It mirrors the worker candidate check including authenticated predecessor lineage, force-rebuild allowlist and source-repair authority. `release_compile_wave.py` validates source freshness only; its “release” list does not establish build-task authority or permission to release. The canonical script accepts max-items 1–10, so the older suggestion `--max-items 30` is invalid.

```powershell
python C:/QM/repo/docs/ops/evidence/2026-09-05_compile_backlog_binding/collect.py --dry-run
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 10
```

### Recheck successors for the four failed waves

These use the exact existing open alternative ids. All four actual dry runs returned the two remaining blockers above.

```powershell
python C:/QM/repo/tools/strategy_farm/retry_compile_stale_build_binding.py --predecessor 059d4860-337e-4833-91f3-5fdf81b55603 --build-task-id 4337ddb4-b486-48b5-a7b6-7d445bcba229
python C:/QM/repo/tools/strategy_farm/retry_compile_stale_build_binding.py --predecessor c71f00bd-1f15-4db5-b4e8-20d73936a092 --build-task-id e26af1ef-1d08-4930-8732-1506c4d67a52
python C:/QM/repo/tools/strategy_farm/retry_compile_stale_build_binding.py --predecessor c495527e-9058-41e9-a63f-d791c25d7554 --build-task-id b3301c0d-f730-488d-bb7c-9fb109746bde
python C:/QM/repo/tools/strategy_farm/retry_compile_stale_build_binding.py --predecessor 8fd59f9d-96d1-4a13-b820-f2960886822d --build-task-id 5c86aaca-f996-4fc7-8019-b79259c0a489
```

### Pending rows

For QM5_41168 a sole open alternative also already exists (`b7ec404b-4681-4d64-a5d9-3a7aeafb13b3`). Preserve the old blocked row; reopening it would produce two open tasks. The generic unchanged-source retry requires a failed predecessor and cannot rebind this pending row. QM5_41207 is failed at the build-task layer, pending at the work-item layer; its infrastructure explanation does not authorize changing either layer. An exact pending-row renewal proposal must preserve the current work item and its source/authority lineage; no supported generic CLI implements that renewal.

The remaining open/unbound rows need no automatic task minting. Their captured worker checks, source hashes, existing successors and original holds determine whether the CEO can release a wave. A source match alone is insufficient. The eight stale rows (seven distinct EAs, including two QM5_1538 rows) remain with `fd5e3ce3-9f48-497d-9c2f-3b6be0f2eac8`; no source-repair authority was duplicated here.

Exact read-only wave commands for every pending row:

```powershell
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id f89d82e9-f4e2-4567-b8f2-464d4997ce09
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id 9ced0252-9ceb-4fe7-a2c5-d7a8d0b30a82
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id e5505264-01c4-4102-b3cd-9a275a6839ee
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id a543f9c8-cdd1-4e9e-8c2a-30d19c2259ca
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id 72e08081-b13c-4168-8988-8b790fa0340c
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id 7628b4c2-f7de-4532-912f-aed19c367100
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id 7b947ba4-f327-4eb2-af86-a0333e27de6a
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id 674da780-53ef-4e37-993c-b02ca4f0a243
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id 550b62ec-516d-4fba-b845-e0b1d61e9437
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id 0d00bf54-535c-4049-ad7f-fde0c6b13f12
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id 7f224c84-9ae2-446e-a905-cb386e9695cc
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id e23cfbc8-3f6d-4b27-b369-c6061a6b44a5
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id bfc98851-3477-4f05-bf48-9636ed10da47
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id f57662e7-6e12-4d96-b109-f0c437d6ce7f
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id 07a09214-86ba-4946-9e0b-c9e7baa8b6fc
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id 74fb5a2d-a4cd-43e3-bc12-e7dbeac67ac1
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id 0a80a328-3b81-4125-aa48-ed5686b7a962
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id 779b4e98-8ef6-4918-8903-07d074a8c523
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id d79fa1aa-f91e-4d47-ac34-58633ce5eddf
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id 494b3cf3-1f24-4e33-bccf-673c7b3b5f64
python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id e4bcce97-6655-45b9-92b8-8702d8c07966
```

### Why there is no re-open/mint executable in this report

The requested re-open/mint **dry-run** command is unavailable in the current canonical CLI. `farmctl.py build-ea --card ...` writes immediately (`farmctl.py:30209`, parser near 33981); it has no `--dry-run`. The existing blocked-build reconciler only accepts pending→blocked operations, the opposite direction. Inventing a flag or presenting a writing command with `--apply` omitted would not be a dry run. This report supplies the concrete per-row proposal and supported successor commands; the absence of a governed task-state planner is an explicit review limitation. No fake UUID was minted, no duplicate build task was created, and no task was reopened.

## Focused verification

[verification.json](2026-09-05_compile_backlog_binding/verification.json) records PASS: exact coverage of the 21 held rows against the independent wave survey, four failed waves, 25 distinct ids, eight source-drift rows, all captured current source hashes verified, four refusal results verified, and rejection of `--apply` by the read-only collector. [wave_dry_run.json](2026-09-05_compile_backlog_binding/wave_dry_run.json) captures the canonical survey. No production task/work-item/hold/source changes, compiler invocation, worker operation, or authority apply occurred. Pipeline verdicts remain those already recorded by the pipeline.
