# QM5_9940 EURJPY Q02 repaired-infrastructure enqueue

Date: 2026-08-14
Branch: `agents/board-advisor`
EA: `QM5_9940_ff-ha-ma-fractal-h1`
Scope: one diverse JPY-cross funnel-throughput unit; append one reviewed
repaired-infrastructure Q02 canary and leave execution to the governed factory

## Outcome

Exactly one `EURJPY.DWX` Q02 work item was appended:

- New work item: `97a9799d-de3a-4809-b864-7297710d999c`
- Status immediately after enqueue: `pending`, unclaimed, attempt count 0
- Append-only predecessor: `aebeeafb-3d68-43fd-b350-c92cd3baca91`
- Enqueued at: `2026-08-14T18:48:38+00:00`
- Transaction flags: `append_only_rerun=true`,
  `repaired_infra_rerun=true`, `historical_work_item_preserved=true`
- Open QM5_9940 rows after enqueue: this EURJPY canary only

No pump, dispatch tick, terminal, tester, or concurrent GBPJPY run was started
manually.

## Selection and farm coordination

The approved-card/build-directory audit found 462 approved cards and no
genuinely unbuilt approved card, so this unit used mission priority 2. The
selected sleeve is forex diversity rather than another index, metal, or energy
build.

- Approved card:
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_9940_ff-ha-ma-fractal-h1.md`
- Card state: `g0_status: APPROVED`; R1-R4 all PASS.
- Card SHA-256:
  `5727a9c9c5d4643a21924588040de8402f24985a2e43a5a499490fabff2e86c5`
- Source ID: `6e967762-b26d-59a3-b076-35c17f2e7c36`.
- Reputable source: gftcfd, "Heiken-Ashi System + Moving Average +
  Fractals," ForexFactory, 2012.
- Mechanics: deterministic H1 Heiken-Ashi/LWMA/confirmed-fractal stop entries,
  one position, no ML, grid, martingale, or pyramiding.
- Diversity target: `EURJPY.DWX`, H1.
- Coordinating task: `13ab8cfc-8ba7-413b-baa4-70ffd4374162`, claimed
  `IN_PROGRESS` by `codex:agents/board-advisor` before enqueue.

A live pre-enqueue query found no pending or active
`QM5_9940`/`Q02`/`EURJPY.DWX` row. The public append-only transaction repeated
that collision check under its database lock. Other inspected diverse
candidates were excluded when the DB showed an existing successor or an
economic, rather than infrastructure, terminal result.

The pre-claim online database backup is retained at
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_9940_eurjpy_enqueue_claim_20260814T184216Z.sqlite`
(385,712,128 bytes; SHA-256
`10814a4b4a632e18c7f74826407380aa02b0a4a66f3b78c857f540dea9fb7739`).
The bounded full `quick_check` did not complete, so no integrity result is
asserted for that backup.

## Bound failure and reviewed repair

The append-only lineage is bound to the predecessor evidence at:

`D:\QM\reports\work_items\aebeeafb-3d68-43fd-b350-c92cd3baca91\QM5_9940\20260807_062121\summary.json`

The retained summary SHA-256 is
`5106059a963f371ea11134f4e13922cc3c2f07fc3c45cac37fe4040d3aa2620e`.
It records `INFRA_FAIL` on `EURJPY.DWX` H1, Model 4, for
2022-07-01 through 2022-12-31 on T8. Its only attempt timed out after 1,800
seconds with a zero-byte report and reason classes `TIMEOUT`,
`METATESTER_HUNG`, and `INCOMPLETE_RUNS`. There was no OnInit failure or
economic report to interpret.

The already reviewed same-lineage repair is commit
`db634897fe1bcf0ed0ad6fb9cad8a683d60241d8`. It caches reconstructed
Heiken-Ashi shifts 1-3 once per completed H1 bar and avoids requesting that
state when no owned pending order exists. It removes the deterministic
per-tick hot path without changing parameters, entries, exits, sizing, or the
approved card mechanics.

## Artifact and capacity verification

- Focused cache-contract regression: PASS, 2 tests.
  - `python -m pytest -q framework/EAs/QM5_9940_ff-ha-ma-fractal-h1/docs/test_ha_cache_contract.py`
- Strict compile: PASS, 0 errors, 0 warnings.
  - Log:
    `C:\QM\repo\framework\build\compile\20260813_044009\QM5_9940_ff-ha-ma-fractal-h1.compile.log`
  - Log SHA-256:
    `1ef485f16245e8df18f9a48f36ef2aaff4f053caaeef82179c835a4f6cbffc2e`
- EA-scoped build check: PASS, 0 failures, 0 warnings.
  - Report: `D:\QM\reports\framework\21\build_check_20260813_044058.json`
  - Report SHA-256:
    `d2c3962606dc5d5d14f23b30b897e82ab4523cbfdb3a27d0b11e2b680633b3e8`
- MQ5 SHA-256:
  `30de5f2384ab81c8680cdd0f976354cb54f37b270e50538a694475f3bba98293`
- EX5 SHA-256:
  `6e5e7a6920506153a96c0467de8db25554bdf2835a98678fcd21df8763e35d32`
- EURJPY setfile SHA-256:
  `c56e449b4b02b99480b9c396e2aeb076fb00779eea1f20ac31d0f16f22e5d104`
- Risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Binding capacity samples: 61.9%, 51.0%, 56.5%, 65.0%, 55.4%; average
  58.0%.
- Governed factory terminals visible: `T4`, `T5`, `T6`; no duplicate terminal
  workers were reported.

The enqueue command bound the current EX5 hash explicitly. The resulting DB
payload also bound the current MQ5 and setfile hashes, approved symbol and
period, risk values, source evidence path and hash, and the 2022-07-01 through
2022-12-31 canary window.

## Recovery ledger

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
| --- | --- | --- | --- | --- | --- | --- | --- |
| QM5_9940 | `aebeeafb-3d68-43fd-b350-c92cd3baca91` | Per-tick recursive Heiken-Ashi reconstruction drove a 1,800-second tester timeout; no report was produced | Same-lineage closed-H1 cache and exposure-first pending-order check | PASS, 0/0 | Not observable in the zero-byte predecessor report | Not observable in the zero-byte predecessor report | Governed Q02 result for `97a9799d-de3a-4809-b864-7297710d999c` remains pending; no economic claim is made |

## Safety

- No `T_Live` file, process, deploy manifest, or AutoTrading state was touched.
- No portfolio gate, Q08 contribution, or portfolio KPI artifact was changed.
- The historical failed row and its evidence remain immutable.
- Existing unrelated worktree changes were preserved and excluded.
