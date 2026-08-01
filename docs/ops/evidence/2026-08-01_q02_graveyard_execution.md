# Q02 graveyard execution — frequency-floor retirements, sequence-1 canaries, and disposition-repair design

**Execution date:** 2026-08-01

**Router task:** `27086064-a384-4e30-b04a-2043c4edeecf` (`IN_PROGRESS`, assigned to Codex at execution)

**Approved predecessor:** `5589f742-8071-4aed-942a-2773b90df27f`

**Scope verdict:** the two authorized frequency-floor retirements were applied; four eligible sequence-1 Q02 successors were appended; the LOG_BOMB member was deferred before enqueue; no sequence-2 member was enqueued; the ten disposition mismatches were not changed.

## Authority and safety boundary

The approved source packet is
`docs/ops/evidence/2026-07-31_q02_stranded_pairs_classification.md` with its
JSON and CSV companions. The approved execution task explicitly names the two
retirement rows, the five sequence-1 source rows, and the ten design-only
disposition mismatches.

Before the first write, an online SQLite backup was created and verified:

- `D:\QM\strategy_farm\state\backups\farm_state_pre_q02_graveyard_execution_20260801_010222.sqlite`
- size: 354,004,992 bytes
- backup `PRAGMA quick_check`: `ok`

The execution did not enable T_Live or AutoTrading, start `terminal64.exe`, stop
or interrupt a T1-T10 run, alter `qm_news_stale_max_hours`, import history, or
dispatch work manually. Pipeline claims are not made for the pending canaries;
their future verdicts must come from their own row-bound pipeline evidence.

## Applied: exact frequency-floor retirements

Both source aggregates were re-read under `BEGIN IMMEDIATE`. Each was a
row-bound `run_smoke/v2` result with one `OK` run, zero trades,
`MIN_TRADES_NOT_MET`, stable execution identity, and its approved evidence hash.
The pair-level guard required zero open Q02 rows and zero other non-infrastructure
terminal rows. The update was an exact compare-and-swap over the prior status,
verdict, `updated_at`, payload bytes, evidence path, EA, symbol, phase, and null
claim.

| EA / symbol | Work item | Before | After | Evidence SHA-256 | Prior payload SHA-256 | New payload SHA-256 |
|---|---|---|---|---|---|---|
| `QM5_10989 / GDAXI.DWX` | `801b1c3b-ad77-4ecb-8d71-8434f10c26f5` | `failed / INFRA_FAIL`, updated `2026-07-29T12:18:03+00:00` | `done / RETIRED_LOW_FREQ`, updated `2026-08-01T01:03:52+00:00` | `16cae7e736b75e35d4459a9ca3a47c214ef3ea09d4829e16bce120181e17525b` | `bd8db1c1ef6e9fcd92ea9d3dead6d225628fd22dfbff2779ec405f9833a796de` | `c5b9c94dd52dc34057f8585da8b81be3434b1ae2cce87e44c95f6d99be1d8419` |
| `QM5_11257 / EURUSD.DWX` | `61d328fa-d97f-4408-a457-7acf555d3b2e` | `failed / INFRA_FAIL`, updated `2026-07-29T12:18:03+00:00` | `done / RETIRED_LOW_FREQ`, updated `2026-08-01T01:03:52+00:00` | `37cffd81af9a4ee2c4c9617e1ef5eee202d399f2964e3cbb8960334d9891e26c` | `8b5b04eff8386c60b0b3464db0c1236ef2ea79f7523d6aee7cad6836087e537c` | `89dd7907b2a428deedcd5d772e21611f8d4bb6bf56e73a0ed0e2a90c07d37817` |

The evidence paths were preserved. Each payload now contains a
`qm-frequency-floor-retirement/v1` audit object binding the router authority,
approved predecessor, backup, evidence hash, prior row state, and prior payload
hash. One `q02_frequency_floor_retired` event was appended per row. The
post-commit database `PRAGMA quick_check` returned `ok`.

## Applied: append-only sequence-1 canaries

Commit `f8dbdc493` extends the append-only exact-row mechanism introduced by
`8e30c2069` to Q02. The Q02 branch is intentionally narrower than the later-Q
path. It requires:

- the source ID and rerun ID to be identical;
- an exact terminal `INFRA_FAIL` source with retained evidence and no claim;
- unchanged MQ5, EX5, setfile, expert, period, and symbol bindings from the
  historical payload;
- `RISK_FIXED > 0` and `RISK_PERCENT = 0` in the exact setfile;
- no prior successor for that source, no open pair row, and no other non-infra
  terminal result; and
- one `BEGIN IMMEDIATE` insert that leaves the historical row untouched and
  adds `append_only_rerun_of_work_item` lineage.

Runtime, prior failure, terminal, reaper, and cold-cache fields are not copied
into the new row. Stable Q02 window/context fields and authenticated artifact
hashes are retained.

Focused verification before use:

```text
python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/tests/test_farmctl_cascade.py
python -m pytest -q tools/strategy_farm/tests/test_farmctl_cascade.py
...................... [100%]
22 passed, 4 subtests passed
git diff --check -- tools/strategy_farm/farmctl.py tools/strategy_farm/tests/test_farmctl_cascade.py
PASS
```

### Per-cause fail-closed preflight

The news preflight was run without cache immediately before every enqueue. All
four checks returned `OK`, no missing or mismatched files, the same source and
SYSTEM FILE_COMMON bundle identity
`de6b180644a441df3d640a5c251ce25156cddfee484d397f508aae0f4660dc1d`,
and `max_age_hours=336`.

| Cause | Checked UTC | Calendar age | Cause-specific check |
|---|---|---:|---|
| `ONINIT_FAILED` | `2026-08-01T01:04:38.513501Z` | 39.430615 h | Exact source is attributable: `Strategy104_Init()` calls `Strategy104_HandlesReady()` and its band self-test; readiness requires at least `Strategy104_WarmupBars()` (floor 40) from all three handles during init. The prior report records init failure rather than an unidentified artifact mismatch. |
| `ACTIVE_TIMEOUT` | `2026-08-01T01:05:08.665157Z` | 39.438991 h | Progress-aware reaper commit `850784f97` is an ancestor of the executing canonical checkout. |
| `BARS_ZERO` | `2026-08-01T01:05:49.348227Z` | 39.450291 h | `XAUUSD.DWX` has required 2022 history coverage on every terminal T1-T10. |
| `NO_HISTORY_TRANSIENT` | `2026-08-01T01:06:25.802588Z` | 39.460418 h | `NDX.DWX` has required 2021-2022 history coverage on every terminal T1-T10. |

Every exact source also re-passed terminal-state, pair uniqueness, active hold,
poison-row, risk, artifact-hash, and execution-identity checks immediately before
its own insert.

| EA / symbol | EX5 SHA-256 | MQ5 SHA-256 | Setfile SHA-256 | Risk fixed / percent |
|---|---|---|---|---:|
| `QM5_20143 / GBPUSD.DWX` | `32be593045e544aa1c462993af5aae97e55a98c12b1a26a717719d85c5ccb470` | `d7515c40b636c0de1f70446915e511aae0cc06d08dea76f17cf4dea92e175b79` | `07a0e73612727d485e2c0dccd3652333742ab5fbdbf85dd4d3a1e4d6f3e7e8bb` | `1000 / 0` |
| `QM5_20045 / EURGBP.DWX` | `a943ebc64365c1f39b52cca177ddb18386b36ef0d0676d6bcf75db6d92968e6e` | `92454e44dbf1814497b74250d5d91f3381459196de2b4cff5810ed1125b91c4d` | `5efd06a68194f8f7ff05cd936cfe42f971b53abb235d7fecf71fde018fd42a8b` | `1000 / 0` |
| `QM5_10505 / XAUUSD.DWX` | `cc702479b617074e190b94833eb60cb9f9b5571cbfe6e39747633223b7a03bbb` | `8d9ea77e84af7b76a528b3e9abee953e5c49cb94e5fcee175fce13d47fc63a8f` | `d13392b780774adcc8ef1b0816d8c824c3accd430731ba404f726f8c47d567a9` | `1000 / 0` |
| `QM5_12382 / NDX.DWX` | `4becb87dd87d3c31fc9415c7076f2bd2e245ac38d851d598eb252647b403a4f4` | `2b8760ad41e1dd3f5d9cfbdd13ba89a4ff585705f1a2d1b6cc7247b89d2c151a` | `b66a61b9cdf3ac73e919270f556deca498b71d0b267de979a330cc65027cf508` | `1000 / 0` |

### Append-only result

Snapshot at approximately `2026-08-01T01:07Z`:

| Cause | Preserved historical row | New successor | Snapshot state |
|---|---|---|---|
| `ONINIT_FAILED` | `a03d2d06-57a0-4e81-aa80-1cbb93ea882b` | `97c83ebb-2290-4d75-916a-db0ce34d85ab` | `pending`, no verdict/evidence/claim |
| `ACTIVE_TIMEOUT` | `4fb3901c-3d70-420f-8727-8f36d190136a` | `fc1e0091-c8bd-4f01-a018-676927b8e33f` | `pending`, no verdict/evidence/claim |
| `BARS_ZERO` | `20a72dd9-4c4c-4236-8cd6-1353ac8548c9` | `9586db87-3f3d-4fdd-b9a1-ad9bb031a00e` | `pending`, no verdict/evidence/claim |
| `NO_HISTORY_TRANSIENT` | `c1b2c4c8-f068-4d6d-aa63-821b1b45b253` | `c02cef21-c648-4e06-af6e-b25ec5ecd61f` | `pending`, no verdict/evidence/claim |

All four historical rows retain their original status, verdict, evidence path,
and `updated_at`. Each successor has
`historical_work_item_preserved=true`, `enqueued_by=farmctl.append_only_exact_row_rerun`,
and the exact source ID in `append_only_rerun_of_work_item`.

### LOG_BOMB deferred before enqueue

No successor was created for source
`5d28d955-129d-413c-a1a9-294c65628627` (`QM5_1560 / USDJPY.DWX`). Its bound
summary records `LOG_BOMB`, an incomplete run, and a tester journal killed at
4.01 GB. In the current source, `RefreshMonthlyStateIfNeeded()` returns early
only when `g_state_valid` is true; when `ComputeMonthlyState()` fails,
`g_state_valid` stays false and `MONTHLY_MACD_STATE_INVALID` can be emitted on
every tick. This is a code/logging defect, not an enqueue-only repair.

A later separately routed repair must throttle the invalid-state event, compile
and validate the changed EA, prove a bounded journal, bind the new MQ5/EX5
hashes, and only then create one new successor from this historical source. The
source row itself must never be flipped back to pending.

The database contains zero append-only successors for the LOG_BOMB source and
for all five sequence-2 sources:

- `b8fa58d1-64a7-48f2-81be-ed98ae4017ef`
- `d119f278-5901-4ab5-93de-089201323756`
- `1acf7591-3cd7-4b23-b8b8-06d273f9ba3c`
- `8c0f5a34-448e-4cf4-808d-13dde7895eb3`
- `ef639b97-ac85-4585-b194-f87c3a96ee80`

## Design only: guarded disposition repair for ten PASS mismatches

No row in this section was modified. The current read-only design snapshot
contains the exact ten approved source rows and canonical JSON plan SHA-256
`5abc62608f1fc5ebce7ee226490c261132aa592a1d5569601bf74cb35666a25d`
(`qm-q02-disposition-repair-plan/v1`, 5,676 canonical bytes). This hash is a
candidate review binding, not authorization to apply.

| EA / symbol | Exact row | Current state | PASS trades | Evidence SHA-256 | Payload SHA-256 |
|---|---|---|---:|---|---|
| `QM5_1910 / EURUSD.DWX` | `e78b1e33-179f-44ea-aa9b-57b5181f7299` | `failed / INFRA_FAIL` | 25 | `37e6cc21c01786ebc4ee50439d6e1ad794ba18b98cbd01fef8976bbe11ebd336` | `a788afed1b9cebe58886c01278b5bff3011f1d2b353036e53484bf819b3e20ee` |
| `QM5_9351 / EURUSD.DWX` | `49a7c514-5aa0-43c1-a00b-94d0acc7b07b` | `failed / INFRA_FAIL` | 18 | `b0c53dd68314bc64f309469cdfc6ea2936e1483ee346f3adeadfeee749674ce6` | `7f7f81e6f0b7346c09397ae577fbc00c2e741788f34f69466474239d5075eae5` |
| `QM5_9940 / SP500.DWX` | `fc0e5325-67da-4659-848c-abc9d0580b11` | `failed / INFRA_FAIL` | 26 | `e0fd141e3b8d53f596e9246cb1be9bf443cc5cb918638886e7ab8ce04261e172` | `40c6ad834ac0ae4320078edd3d67727dc81c99cd32195378d9e0d3413788e6db` |
| `QM5_10098 / GBPUSD.DWX` | `e8f476da-a7e5-48ba-aa94-285b2cdb8b8f` | `failed / INFRA_FAIL` | 42 | `49540b17041f887396563956d20edfac2d93a64719b1c5bd9af3180357831d8a` | `7f4859ff38d9e5191404005e2a0825ad6b6bd16b980ff6edb277ecbb9392a0d5` |
| `QM5_10485 / USDJPY.DWX` | `e346032c-5762-4941-b0eb-7a7496bbd649` | `failed / INFRA_FAIL` | 621 | `d9f6352e0f4fd9cb1ace5b7689ba73a81bcb7dff243351cb750df271ff449045` | `e3178cd19e24af3deb3af1a0c0440bbc2f7918d90c68cfa291020d0ebef74ed2` |
| `QM5_10503 / EURUSD.DWX` | `9f7d6e83-dc82-4fbd-9e13-128b71704db7` | `failed / INFRA_FAIL` | 153 | `f43644204fb3299649395302840482577bce9e847425e84a5a18063d4847220c` | `11f6a83cdde47b8187e3faf052ad6cc277dfc2b24915a540b54214f3e0cde498` |
| `QM5_10593 / XAUUSD.DWX` | `677c9a45-b30b-4e97-a028-987f80430a94` | `failed / INFRA_FAIL` | 105 | `fba8bf81fb2b7126f38748889f398edfe33af28183938c95f5dd3a52f6fc4a42` | `783911567a10ffe3a160bdafa9989306f1f413e09a5f5083229e6395eb9602a9` |
| `QM5_10752 / EURUSD.DWX` | `7916bcf9-f1d1-4ea2-94e2-9156044d4caf` | `failed / INFRA_FAIL` | 127 | `687679881749b3926e10ab9622c99f24cf07732b0a0d056b169cc911bdb23eea` | `e4deda286df5416353bd6250ae500d5791bc8ec652a94a3765993be8a33c10c5` |
| `QM5_11112 / EURUSD.DWX` | `5f08fb95-cf8b-4378-b8eb-6aec56005367` | `failed / INFRA_FAIL` | 69 | `d4e86b10aa63b63550f9f928ed487cfa72b80e9751c01cb61de6dd03400d5087` | `8b8072feb3dcf228ab56d342ef1138fdf4826f1379ee2fae4c19a0760e5a2176` |
| `QM5_12535 / GDAXI.DWX` | `ce645ca9-26c9-414f-996f-4036cecb61d1` | `failed / INFRA_FAIL` | 25 | `509c9b634a8f8b499a45408561d163ca671b4d81926dbad7f0d97cf6b6f8eb10` | `8bb377e8f63a096e551eb2c4a2703fbd870eff372c01c1de15b460f7e18d261a` |

### Proposed apply contract

The repair controller should follow the same safety shape as
`q08_single_target_requal.py`:

1. Generate an immutable JSON plan in read-only mode. Bind every exact row's
   full preimage, payload bytes/hash, evidence path/hash, EA/symbol/phase,
   claimed state, `updated_at`, row-bound summary result, `OK` run count, and
   positive trade count. Recompute pair-level open and non-infra counts.
2. Require a separate `APPROVED` agent task that names the exact plan SHA-256.
   This execution task does not provide that apply authority.
3. Require the Factory-OFF flag, zero active work items, the global Factory
   mutation lock, and a fresh online SQLite backup. Wait for active T1-T10 work
   to finish; never interrupt it.
4. Enter one `BEGIN IMMEDIATE` transaction and re-run every read-only gate. Any
   missing row, hash drift, claim, open successor, prior non-infra disposition,
   evidence change, non-PASS summary, non-OK run, or non-positive trade count
   aborts all ten updates.
5. For each row, exact-CAS `failed / INFRA_FAIL` to `done / PASS`; retain its
   evidence path, attempt count, parent reference, and historical payload;
   clear no fields except the terminal claim (already null); add an audit object
   containing authority, plan hash, backup, full prior disposition, prior
   payload hash, evidence hash, PASS facts, and timestamp. Use an exact `WHERE`
   clause over the complete preimage and require `rowcount == 1` for each row.
6. Append one disposition-repair event per row plus one cohort event, commit only
   after all ten CAS operations succeed, run `PRAGMA quick_check`, and write a
   pre/post journal with canonical hashes. Do not enqueue or rerun any row.
7. A guarded revert must independently require Factory OFF, zero active work,
   the mutation lock, the exact postimage/journal hashes, and a new append-only
   revert event. It must refuse partial or drifted state.

Legacy summaries without the `run_smoke/v2` schema remain bound by their exact
approved row/evidence hashes and the predecessor packet's row-bound `PASS/OK`
classification. The separate plan review must explicitly accept those legacy
bindings; the controller must not silently treat a missing schema as equivalent
to a v2 execution-identity envelope.

## Final verification snapshot

- live database `PRAGMA quick_check`: `ok`;
- both retirement rows: exact `done / RETIRED_LOW_FREQ` postimages with retained
  evidence;
- four and only four eligible sequence-1 successors: present with exact lineage;
- four historical canary sources: unchanged;
- LOG_BOMB plus every sequence-2 source: zero successors;
- ten disposition-mismatch rows: still `failed / INFRA_FAIL` (design only);
- no Q02 pipeline verdict inferred from a pending row.
