# QM5_39005 EURUSD Q02 worker-crash recovery

Date: 2026-09-10  
Branch: `agents/board-advisor`  
EA: `QM5_39005_forexfactory-genesis-matrix-scalper`  
Farm task: `6f132b33-334d-490e-b9d8-78a287e338c2` (`infra_repair`)  
Outcome: **ROOT CAUSE BOUND; EXACT COMPILE AUTHORITY COMMITTED; REPLACEMENT COMPILE HELD FOR GOVERNED WORKER ROLLOUT**

## Selection and collision control

The approved build backlog had no eligible non-duplicate forex, crypto, rates,
or new market-neutral build. The apparent forex backlog entry QM5_41011 was
already built and committed; the current fresh-card queue was concentrated in
WTI, XNG, and XAU/XAG.

QM5_39005 was the newest unclaimed diverse-instrument Q02 infrastructure
failure after excluding every EA with an open farm task or open work item. An
atomic `BEGIN IMMEDIATE` collision recheck found no open task and no pending or
active work item for this EA before it created the task above. The pre-claim
online SQLite backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_39005_worker_crash_claim_20260910T085252Z.sqlite`

Backup SHA-256:
`a4286d5274330ec7f17eae3fad0fbf9b1482434efaed9e266c5f48b5242639b7`.

## Immutable failure and diagnosis

The selected row is `f6816124-fe46-4e36-a25b-7361da4a97c7`
(`EURUSD.DWX / M5`, `failed / INFRA_FAIL`). It never launched MT5 and has no
economic verdict. Its authenticated payload ends with:

`sqlite3.IntegrityError: CHECK constraint failed: sh3_enforced=0 OR status<>'failed' OR (COALESCE(NULLIF(verdict_taxonomy,''),NULLIF(json_extract(payload_json,'$.verdict_taxonomy'),''))) IS NOT NULL`

The failure is the historical refusal-recording SH3 taxonomy defect, not
ONINIT, missing history, zero trades, or strategy economics. The immutable row
binds the same canonical EX5 SHA-256 still present today:
`9d692b666751c48aae2eafbd73fa6ed109c9a66211dd67e77082943f269bfea3`.

The canonical source SHA-256 is
`a82d69e1cf4691f741a0053d047f3b32c2fb34f9492c6ea620584d0984450d8d`.
Active magic rows are exact and contiguous: EURUSD slot 0 / 390050000 and
GBPUSD slot 1 / 390050001. Both canonical M5 backtest setfiles retain
`RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Exact compile provenance repair

Commit `75a1b68ce3` adds one task-and-label-bound compile authority:

`router_q02_infra_repair:6f132b33-334d-490e-b9d8-78a287e338c2`

It authorizes only `QM5_39005_forexfactory-genesis-matrix-scalper`, only through
the append-only COMPILE_EA path, and grants no strategy, backtest, gate-verdict,
or cross-EA authority. Focused regression coverage proves that the exact pair
is accepted while a wrong task or label is rejected, and that ordinary compile
remains refused when historical work and an EX5 already exist:

`python -m pytest tools/strategy_farm/tests/test_compile_work_items.py -k "39005 or 10116" -q`

Result: `4 passed, 84 deselected`.

## PACER guard and rollout boundary

Immediately before each governed compile enqueue, the binding audit ran on the
absolute MQ5 path:

`python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_39005_forexfactory-genesis-matrix-scalper/QM5_39005_forexfactory-genesis-matrix-scalper.mq5"`

Both runs returned exit 0, `ok=true`, predicate
`EA_FRAMEWORK_INPUT_PINNED`, and `hit_count=0`. No MQ5 change was required.

The pre-enqueue CPU sample remained below the binding 97% ceiling: 80.08%
average and 91.61% peak with five `terminal64` processes observed.

The first compile row, `fadbaff1-f997-4ad4-b97a-908519320499`, was released as
a bounded canary after the authority commit. The resident T3 worker had loaded
the older module before that commit, so its independent recheck correctly
failed closed with `CANDIDATE_RECHECK_REFUSED / SOURCE_REPAIR_AUTHORITY_INVALID`.
No compiler or build check ran and no EX5 changed. That failure remains
immutable evidence that worker rollout is required.

The replacement compile row is
`10749d8d-429e-4903-b291-2f02f20853ad`. It is `pending` behind active hold
`COMPILE_EA_WORKER_ROLLOUT_PENDING`, with `release_on_restart=1`, the exact
current source hash, two registered symbols, M5, and the fixed-risk contract.
The hold was not released again. No Q02 successor is permitted until a restarted
resident worker records `COMPILE_OK` and strict build-check PASS.

## Safety boundary

No backtest or manual tester was started. No worker was restarted. No T_Live
file or process, AutoTrading setting, live setfile, deploy manifest, portfolio
gate, portfolio KPI artifact, or certification verdict was changed.
