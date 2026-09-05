# CEO backlog compile Q02 handoff audit

Date: `2026-09-05T23:06:59Z`

Branch: `agents/board-advisor`

Router task: `3c0503cc-d574-4783-af50-008ba0bd886b`
Outcome: `NINE COMPILE_OK BINARIES VERIFIED; ZERO Q02 ROWS; ALL NINE DRY-RUN HANDOFFS REFUSED — NO GOVERNED FIRST-Q02 PATH`

## Scope and safety boundary

This was a canonical-checkout, read-only farm/database audit plus governed dry
runs. No `--apply` flag was used. No task, work item, build record, setfile,
registry, terminal, pipeline verdict, or live state was changed. No tester was
started or interrupted. `T_Live` and AutoTrading were not touched.

The canonical farm database was opened read-only at
`D:/QM/strategy_farm/state/farm_state.sqlite`. At the audit snapshot it had
`12,906` pending and `7` active work items. Every target had exactly zero Q02
rows; its only work-item lineage was COMPILE_EA history.

## Compile, preset, and registry evidence

For every target, the latest work-item row was `done / COMPILE_OK`, its evidence
reported `build_check.result=PASS`, `compile_result=PASS`, zero compile errors,
and zero warnings, and the current canonical EX5 hash matched the hash sealed in
that row. Every canonical `_backtest.set` inspected declared
`RISK_FIXED=1000` and `RISK_PERCENT=0`.

| EA | COMPILE_EA row | Current/evidence EX5 SHA-256 | Canonical backtest presets | Active magic rows |
|---|---|---|---:|---|
| `QM5_41164` | `2b5f0303-968c-4181-9bc8-62366035a406` | `2992eac18012548c22ac5c8823609fd546b0195e950b25ca5fbe621721cd669f` | 3 | `XAUUSD.DWX=411640000`; `XAGUSD.DWX=411640001` |
| `QM5_41165` | `ce864ce1-3957-49c8-97a8-048cb4dc9569` | `196c37ed88a4aba954d31adc566da38c47f8df9787b02df82d6768b32a57a1d5` | 1 | `XTIUSD.DWX=411650000` |
| `QM5_41166` | `8cc3c581-d71a-48d9-9e79-fc2b4b53718e` | `f9e0354ebf4c731da193f95c553db9547848caa72b5011cd35c759e82197b11c` | 3 | `XAUUSD.DWX=411660000`; `XAGUSD.DWX=411660001` |
| `QM5_41172` | `d9949538-e279-402b-bc05-8f8199f2b8d1` | `53fbffa7d147c779a403df23dc3d26d3d6bc034a7d545395971777be3ca50769` | 1 | `XTIUSD.DWX=411720000` |
| `QM5_41176` | `4fd60078-4862-45ca-ab65-558b29fcb9ac` | `663eca68c975bacffbd74c6c8670df9a6ed8a070094ad3b98407da0e2d9a5300` | 1 | `XTIUSD.DWX=411760000` |
| `QM5_41224` | `7b947ba4-f327-4eb2-af86-a0333e27de6a` | `ae19548f7fc338a260b01ea574808040a9efed2ef08ddc4d9ce76b12a577d965` | 1 | `XTIUSD.DWX=412240000` |
| `QM5_41285` | `e23cfbc8-3f6d-4b27-b369-c6061a6b44a5` | `c5eaa6ac55c2d8e3ca4dc361b626c939022ffbabe3bdf1f1838ad6d3c4f34187` | 3 | `XAUUSD.DWX=412850000`; `XAGUSD.DWX=412850001` |
| `QM5_41312` | `f57662e7-6e12-4d96-b109-f0c437d6ce7f` | `bddf06f7700055ce6f81a5d0ea190917a2d54c37e9c929d717dd3304232cfa1c` | 1 | `XTIUSD.DWX=413120000` |
| `QM5_41336` | `0a80a328-3b81-4125-aa48-ed5686b7a962` | `c62f35222d069bb4f1cb81a545f2fec1ad61058141d2a5920ca91d42fb2e9f6d` | 1 | `XTIUSD.DWX=413360000` |

The exact current preset hashes are:

| EA | Preset | SHA-256 |
|---|---|---|
| `QM5_41164` | logical basket | `70121821b8bcaa875ea1cb91e7775c99a9029d757eb89defc943180d38809ca8` |
| `QM5_41164` | XAGUSD.DWX D1 | `188016fbee28266a97dec18abfa7af80b9a6539b5c340b3ad740b3348a00ec61` |
| `QM5_41164` | XAUUSD.DWX D1 | `ea7d1eb067b9ca2eee59a06cc821d9b828b8aeb0463df0ff6de44f9f9d89c771` |
| `QM5_41165` | XTIUSD.DWX D1 | `f73bc2d3f8500b9c0b4b68db215e13f05d13f0d4d1d0e1b7279e285a4b41d0c1` |
| `QM5_41166` | logical basket | `960fd8011f42d1722c2a17a486efe2a9bbf7d84ae4bd16a9b0e8ab6e9a0ce024` |
| `QM5_41166` | XAGUSD.DWX D1 | `d63da9a01871127ba5fc8d4f7e1c69fa17996f4fbdead89caa3e45e17f030d24` |
| `QM5_41166` | XAUUSD.DWX D1 | `52d3eba24879e45bdc124344c059c8fb7f8c6898643cf6d2e2722f06d61e057b` |
| `QM5_41172` | XTIUSD.DWX D1 | `8b8908146652286e972381c2d9db4b7ab53f877a2cbbddf6bd0618e88a1fb883` |
| `QM5_41176` | XTIUSD.DWX D1 | `417228e22dae4477441d05f4be46396ee76196d167fa4cd86b358cdc17e0207f` |
| `QM5_41224` | XTIUSD.DWX D1 | `1d28d8663210fee057b592a27728909ea68f509a519b24b65fb11920fee63a14` |
| `QM5_41285` | logical basket | `4b74ad036e91c597344938a7f98afd3c820be41c06eb6b0173fb76ed30f0e573` |
| `QM5_41285` | XAGUSD.DWX D1 | `96602ade154267adbbe78f0d5fdca46b8156eb07109c2aa7924808cddf04d64f` |
| `QM5_41285` | XAUUSD.DWX D1 | `6985ff35222a31d3c5b7cbc349d888e765d2f0436b64c4dbfceb1eeeb45a15b4` |
| `QM5_41312` | XTIUSD.DWX D1 | `81d88201759dc0b6f87fcc870e822465f2035b092106983ac267cd461f84418e` |
| `QM5_41336` | XTIUSD.DWX D1 | `9f5c156865742068db9c40b98d918615d9b2499b65ec6cc8f1176adc82ca41b0` |

## Governed first-Q02 path audit

There is no usable governed first-Q02 command for these nine in the current
canonical controller:

1. `sweep_enqueue_built_eas.py` describes Part 1 as the first-Q02 producer, but
   it builds `wi_eas` from every phase in `work_items` and only considers an EA
   when it is absent from that set. Each target's COMPILE_EA row therefore
   excludes it before the Q02 candidate logic. This is why each targeted dry run
   returned neither an enqueue nor a skip record.
2. `farmctl seed-fresh-q02` requires `--old-work-item-id` naming an exact
   terminal pre-binding Q02 row. All nine have zero Q02 rows, so fabricating an
   ID would violate its append-only requalification contract.
3. `farmctl record-build` has no dry-run mode and is a build-task transition,
   not a backlog-compile intake command. Eight targets have open pending build
   tasks, but their COMPILE_EA rows explicitly say
   `BUILD_TASK_BINDING_NOT_REQUESTED`; using `record-build` here would require a
   new governed result/smoke binding. `QM5_41176` has no matching build task at
   all. It therefore cannot be used as a read-only Q02 seed workaround.

The required control-plane repair is a canonical, append-only first-Q02 intake
that accepts an exact `done / COMPILE_OK` work-item ID, verifies its current EX5
hash, canonical fixed-risk setfile(s), active magic rows, review-entry gate, and
absence of existing Q02 rows, then stages one canary with normal deferral
semantics. That repair is outside this read-only review task and must be
separately routed and reviewed before any enqueue.

## Nine dry-run results and paced command plan

Each command below was run from `C:/QM/repo` without `--apply`:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41164 --queue-ceiling 7000
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41165 --queue-ceiling 7000
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41166 --queue-ceiling 7000
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41172 --queue-ceiling 7000
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41176 --queue-ceiling 7000
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41224 --queue-ceiling 7000
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41285 --queue-ceiling 7000
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41312 --queue-ceiling 7000
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41336 --queue-ceiling 7000
```

All nine outputs were identical:

```text
APPLY=False
part1 never_tested: enqueued=0 skipped=0
part2 stranded:     enqueued=0 skipped=0
part1 skip reasons: {}
part2 by phase: {}
part3 deferred: promoted=0 kept=0
priority_track items: 0
```

Explicit disposition for every EA: `REFUSED_NO_GOVERNED_FIRST_Q02_PATH`.
The empty skip list is itself an observability defect: the target is silently
dropped by the phase-blind `wi_eas` filter rather than reported as ineligible.

After the separate producer repair is reviewed, the dry-run pacing must remain
at most two EAs per scheduler tick. The exact bounded target batches are:

```text
tick 1: --ea QM5_41164,QM5_41165
tick 2: --ea QM5_41166,QM5_41172
tick 3: --ea QM5_41176,QM5_41224
tick 4: --ea QM5_41285,QM5_41312
tick 5: --ea QM5_41336
```

These are target batches, not authorization to add `--apply`; the current
producer would still refuse them and the queue already exceeds its 7,000-row
ceiling.

## CPU-ceiling provenance and applicability

Two related rules must not be conflated:

- The resident worker's code-enforced OWNER rule is in
  `tools/strategy_farm/terminal_worker.py`: `CPU_MAX_LOAD_PERCENT=97.0`,
  `CPU_RESUME_LOAD_PERCENT=90.0`, and a worker pauses a new claim when its
  sustained loop sample is greater than the applicable threshold. The source
  comment attributes this admission policy to OWNER on 2026-08-15.
- The build lane's five-sample preflight—stop when either the five-sample
  average or maximum is at least 97%—is a conservative paced-lane convention
  repeatedly recorded in evidence, including
  `docs/ops/evidence/2026-09-05_paced_fleet_diversity_cpu_ceiling_2149z.md`.
  It is not implemented by the Q02 enqueue producer and its exact `>=` plus
  average-or-maximum formulation is not the worker's `>` comparison. Evidence
  calls it mission-explicit, but no durable global OWNER policy document was
  available in the canonical checkout; the referenced `G:` company drive was
  not mounted in this headless session.

The OWNER worker ceiling necessarily governs any eventual tester claims from
these handoffs. For a mere append-only queue insertion it is not an independent
controller guard. Nevertheless, a future paced handoff mission should retain
the stricter five-sample preflight if its OWNER task contract repeats it; this
task independently requires at most two seeds per tick to avoid displacing
census throughput. No enqueue is justified here in any case because the
governed first-Q02 producer is missing and the pending queue is already above
its configured ceiling.

## Review verdict

`REVIEW — evidence complete; nine handoffs explicitly refused. Route a bounded
canonical first-Q02 producer/observability repair, then repeat dry runs in the
five two-or-fewer-EA batches. No Q02 enqueue or pipeline verdict is claimed.`
