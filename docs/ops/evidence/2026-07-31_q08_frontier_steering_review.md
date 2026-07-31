# Q08 frontier steering — adversarial plan review R1

Date: 2026-07-31  
Router task: `695f5585-81f7-41eb-a61a-52ed33c9f51a`  
Reviewer: Codex  
Scope: strict read-only review of Topic D; no requeue, setfile edit, database write,
terminal launch, or Factory/AutoTrading change was performed.

## Verdict

**Approval: 28%. R2 required; do not execute any of the three stages as written.**

The diagnosis is directionally useful: QM5_20039 has a retryable Q06 cold-cache
failure, QM5_10582 exposes a real legacy-setfile/parser incompatibility, and
QM5_20007 is queue-bound. The proposed execution is nevertheless non-executable
against the live state and the checked-in contracts:

1. The Q06 Wave-1 dry-run is `BLOCKED`: exactly four rows are eligible, not the
   OWNER-locked five.
2. The Q08 Wave-1 dry-run is `BLOCKED`: zero rows are eligible. QM5_10582 is
   deliberately classified `q08_invalid_report_non_retryable`, so the proposed
   command can never requeue it.
3. Adding a comment is MT5-semantic-neutral but **not byte-identity-neutral**. It
   changes all four setfile SHA-256 values, including the exact ablation-00 hash
   bound into the existing Q08 evidence.
4. The three named priority rows no longer have the state asserted by the plan:
   GDAXI is terminal `failed/INFRA_FAIL`, XAU already has `priority_track=true`
   but is recovery-class (and therefore still sorts last), and only NDX is an
   ordinary pending row missing the flag.
5. The recovery tool's apply contract requires Factory OFF and a quiescent DB.
   At the observation point the flag was absent and seven work items were active.

## Read-only observation boundary

Live observations below were taken between `2026-07-31T11:24Z` and
`2026-07-31T11:29:20Z`. The SQLite database was opened with `mode=ro`; claim-order
simulation used an in-memory copy only. The two recovery commands were run in
their default dry-run mode, whose planner also opens SQLite with `mode=ro`
(`requeue_stranded_infra.py:559-562`).

At `2026-07-31T11:29:20Z`:

- `D:/QM/strategy_farm/state/FACTORY_OFF.flag`: absent.
- Active work items: 7.
- Canonical claim-order candidates: 2,219 pending rows.

Active rows were:

| Terminal | Work item | EA / symbol | Phase |
|---|---|---|---|
| T6 | `34ae575d-61be-41d6-99bb-5c8746391f2d` | QM5_10399 / NDX.DWX | Q02 |
| T1 | `533c2222-bff6-4276-b0d2-ff2a136f7721` | QM5_11096 / XAUUSD.DWX | Q02 |
| T2 | `89b48e73-9d0d-429e-b8fb-ca52efb0b14b` | QM5_1568 / EURCAD.DWX | Q02 |
| T8 | `76bd82c9-8cbf-4ac6-a811-26326c1e984f` | QM5_20184 / `QM5_20184_XAU_XAG_XMOM3_D1` | Q02 |
| T9 | `6a5bd2d0-eb83-4730-a31f-92c5ab011267` | QM5_9998 / EURUSD.DWX | Q02 |
| T3 | `ef04015b-d855-47bb-8c3d-7cd961266848` | QM5_10204 / GBPUSD.DWX | Q04 |
| T4 | `b90b3278-4ded-44da-940e-42ff75855b40` | QM5_11748 / GBPJPY.DWX | Q04 |

No active row is one of the named 10582/20039/20007 targets, but that does not
satisfy the recovery tool's stronger Factory-OFF/DB-quiescent apply contract.

## Finding 1 — Q06 Wave 1 is not a five-row wave

Command executed without `--apply` and without `--snapshot-out`:

```text
python tools/strategy_farm/requeue_stranded_infra.py --phases Q06 --wave 1
```

Result: `BLOCKED`, `wave_1_requires_exactly_5_eligible:found=4`. The four
deterministically selected eligible rows are:

| Order | Work item | EA / symbol | Prior reason | Artifact |
|---:|---|---|---|---|
| 1 | `4381a4bc-a8bd-4e58-862f-83dd05cda5ce` | QM5_20039 / NDX.DWX | `invalid_summary:BARS_ZERO,EMPTY_EXPERT,EMPTY_SYMBOL,HISTORY_CONTEXT_INVALID,INCOMPLETE_RUNS,M0_1970_PERIOD,NO_HISTORY,RUN_STATUS_INVALID` | survives |
| 2 | `a89f917e-b8e0-4654-bca0-f89601cdb561` | QM5_10692 / GDAXI.DWX | `invalid_summary:BARS_ZERO,EMPTY_EXPERT,EMPTY_SYMBOL,INCOMPLETE_RUNS,M0_1970_PERIOD,RUN_STATUS_INVALID` | survives |
| 3 | `9f2ed43f-b802-4076-b12b-0c238b05f8b4` | QM5_12742 / EURUSD.DWX | `invalid_summary:BARS_ZERO,EMPTY_EXPERT,EMPTY_SYMBOL,HISTORY_CONTEXT_INVALID,INCOMPLETE_RUNS,M0_1970_PERIOD,NO_HISTORY,RUN_STATUS_INVALID` | survives |
| 4 | `681a9ede-cefd-49b7-8cc7-7873b970bad9` | QM5_10123 / GDAXI.DWX | `invalid_summary:BARS_ZERO,EMPTY_EXPERT,EMPTY_SYMBOL,INCOMPLETE_RUNS,M0_1970_PERIOD,RUN_STATUS_INVALID` | survives |

Two other stranded Q06 groups are correctly refused as historical:

- `7ff90737-019f-47d3-9734-244e1f90ebb6`, QM5_10145/GDAXI: superseded by
  Q07 `35922c10-bf0c-4ed9-b883-aa576dd70a20` (`done/FAIL`).
- `e2d738bb-749d-4f95-bac5-436c259de28b`, QM5_13301/GDAXI: superseded by
  Q09_NEWS `2bd6d6f5-2dc1-44a7-942f-745146b3a993`.

The contract is not caller-adjustable: `RECOVERY_WAVE_SIZES={1:5,2:25}`
(`requeue_stranded_infra.py:150-154`), selection is deterministic
(`:565-628`), and apply refuses a non-READY or wrong-size wave
(`:1294-1305`). The proposed `--apply` would therefore exit without mutation.
Do not manufacture a fifth member or relax the exact-five lock. R2 must either
wait for a legitimate fifth eligible Q06 row or obtain an explicit OWNER change
to the MNT-007 release boundary through a separate reviewed plan.

## Finding 2 — the 10582 parser defect is real, but editing evidence-bound bytes is the wrong repair

`parse_setfile_assignments` does not begin harvesting until it sees a line
starting with `; strategy-specific params` (`q08_5_neighborhood_runner.py:126-168`).
All four named files have strategy assignments, no marker, and currently return
zero parsed assignments. `inspect_baseline_setfile` then rejects the empty result
and records the raw-byte SHA-256 (`:171-208`).

The following was computed entirely in memory. `hyp_sha` is the hash after
inserting the proposed single marker immediately before the first `strategy_`
assignment while preserving the file's newline form:

| Setfile | Current bytes | Parser count | Current SHA-256 | `hyp_sha` after comment |
|---|---:|---:|---|---|
| base | 770 | 0 | `082028275fbb0870d5e0665f5c3131d2d360bb8ff36597aada955c3692eb9d04` | `462ca2be4bdf3c8b1a8d0602cc621433ad226c3ee68b34bee1361d1e15813b79` |
| ablation_00 | 1,008 | 0 | `8d47c4cc8191e067af31920bceb3cdcb1af2ebea63b4ddb8df954b9a975cb4f3` | `5e3152ee6bae2bbb8ddeb12ec38fba53179ecb4fd47cd70510e0de8a7d7d6e74` |
| ablation_01 | 1,008 | 0 | `f2bf459a3255c09eaf4b2333d870eb1a7d06462132c18e0d85dc3a06ac73d5d6` | `cb2c4f26a83c5456f3bda7b0908d5e8f031b7fb926b4811799ffa29814962845` |
| ablation_02 | 1,008 | 0 | `477bc9142a10fc09e590d32aad14e056af0710d520f35882525313e4babc6cf1` | `c53fd56471efa9d2c0a93fcd5965cbdcc77d3c0ae0e2875ec2949642cdd90afc` |

The existing Q08 aggregate binds ablation-00 twice to its current hash:

- `baseline_setfile_sha256=8d47c4...` at
  `D:/QM/reports/work_items/95015420-11d0-4c11-bb98-25fa2a361048/QM5_10582/Q08/XAUUSD_DWX/aggregate.json:306-307`.
- `source_setfile_sha256=8d47c4...` and
  `identity_status=BOUND_STREAM_BUILD_SETFILE_SOURCE_AND_REPORT` at `:362-366`.

This is part of the general evidence contract, not Q08 decoration:

- `run_smoke.ps1` hashes source/deployed setfiles, requires an exact match, and
  checks stability through the run (`framework/scripts/run_smoke.ps1:2175-2178,
  2300-2307,2688-2693,2844-2849`).
- The canonical aggregate importer reconstructs the immutable tester.ini
  setfile identity and hard-refuses a surviving hash mismatch as
  `setfile_hash_mismatch` (`ingest_phase_aggregates.py:241-243,255-315,
  387-399`). It explicitly describes this as refusing bytes edited after the run.

Therefore “MT5 ignores comments” supports execution-semantic equivalence, but
does not preserve evidence identity. The minimal R2 repair is code-forward:

1. Keep all four setfiles byte-identical.
2. Add a legacy fallback to `parse_setfile_assignments`: only when the marker is
   absent, parse exact `^strategy_[A-Za-z0-9_]+=` assignments; retain duplicate,
   empty-RHS, optimiser-cell, and framework-parameter fail-closed checks.
3. Add regression tests for marked files, legacy unmarked files, duplicate keys,
   empty values, and a non-strategy assignment before/after the block.
4. Re-run the four-file parser check and prove the current SHA-256 values did
   not change.

If R2 instead elects to edit the setfiles, it must explicitly establish a new
setfile evidence vintage and state which Q02-Q07 evidence remains admissible or
must be rerun. It may not call the resulting files “bit-identical” in the
evidence sense.

## Finding 3 — Q08 Wave 1 has no members, and 10582 is barred by design

Command executed without `--apply` and without `--snapshot-out`:

```text
python tools/strategy_farm/requeue_stranded_infra.py --phases Q08 --wave 1
```

Result: `BLOCKED`, `wave_1_requires_exactly_5_eligible:found=0`:

- 13 stranded groups inspected.
- 8 refused as `q08_invalid_report_non_retryable`.
- 5 refused as `historical_phase_advanced`.
- Wave member list: **empty**.

QM5_10582 work item `95015420-11d0-4c11-bb98-25fa2a361048` is one of the eight
non-retryable rows. Its reason contains the preserved `lineage_invalid` token;
the classifier intentionally recognizes explicit or tokenized INVALID evidence
(`requeue_stranded_infra.py:401-427,516-518`). The OWNER-locked MNT-007 contract
states that these rows can never enter either recovery wave
(`docs/ops/evidence/2026-07-29_mnt007_wave_contract.md:15-22`).

Consequently, fixing the parser does not make the existing row eligible for
this tool. R2 needs a separately reviewed, OWNER-authorized, **single-target Q08
requalification mechanism** after the code fix. It must preserve/archive the
old invalid evidence, create or reset exactly the intended row under an explicit
exception contract, bind the current code/build/setfile hashes, and use a
durable snapshot plus compare-and-swap. Do not weaken the global
`q08_invalid_report_non_retryable` invariant to release this one row.

## Finding 4 — the three-row priority mutation is stale and has no suitable shipped controller

Live row state at the review boundary:

| Prefix / symbol | State | `priority_track` | Other decisive field | Current canonical rank |
|---|---|---:|---|---:|
| `0928164a` / GDAXI | `failed/INFRA_FAIL` | absent | `shared_bases_history_lock_transient_cap_exhausted` | not claimable |
| `6dce5d90` / NDX | `pending` | absent | ordinary row | 577 |
| `80c64b67` / XAUUSD | `pending` | true | `recovery_class=stranded_infra_fail` | 601 |

Thus an exact `WHERE status='pending'` operation can affect at most the NDX row
meaningfully. GDAXI first needs its normal classified recovery decision; it
cannot be prioritized while terminal. XAU already has the requested flag, and
`_recovery_rank` sorts it after every non-recovery row before priority is even
considered (`farmctl.py:905-920,986-989`), so re-setting the flag cannot steer it.

No exact farmctl priority mutation subcommand exists in `build_parser`
(`farmctl.py:8961+`). The only dedicated repository tool found,
`prioritize_intraday_ftmo.py`, is unsuitable: it selects the whole intraday Q02
reservoir (`:46-59`), updates every selected row and timestamps (`:69-100`), and
has no per-ID scope, pre-state hash, durable snapshot, or guarded revert.

The row creation policy is also not persistent for this EA. New Q02 rows inherit
priority only for a fresh build/first Q02/force-build or when
`strategy_priority.compute_scores()` returns true (`farmctl.py:1638-1671`). The
live read-only score for QM5_20007 is `priority_track=false`, `tf=NA`,
`asset=unknown`, with unresolved symbols. A one-time payload patch would leave
the next fresh row vulnerable to the same omission.

Claim order is not a “times ten” multiplier. Its effective score is
`priority_track_rank*10 + phase_rank - whole_age_weeks`
(`farmctl.py:895-989`). In an in-memory copy, adding the missing flag to NDX
moved it from rank 577 to rank 7 and worsened 570 other rows by one position:

| Displaced cohort | Rows |
|---|---:|
| Q02 | 468 |
| Q03 | 56 |
| Q04 | 45 |
| Q05 | 1 |
| Q04+ total | 46 |
| Metal symbols (all phases, overlapping above) | 225 |

That may be an acceptable explicit OWNER trade-off for the named FTMO motor,
but it is not a small local tie-break and it cuts ahead of downstream drain.
R2 must acknowledge this quantified effect.

The sanctioned replacement should be two-part:

1. Repair the persistent source of truth (card/scorer symbol/timeframe resolution
   or an explicit OWNER priority registry) so later QM5_20007 rows inherit the
   decision through `_q02_priority_track_required`.
2. If an immediate backfill is still required, add a dry-run-first, exact-ID
   controller with repeated `--work-item-id`, required expected status/phase and
   payload SHA-256, durable pre/post journal, `BEGIN IMMEDIATE`, exact row-count
   assertions, a farm event, and guarded revert. Re-census the three IDs just
   before apply; do not pretend failed GDAXI or recovery-class XAU can be fixed
   by the flag.

## Finding 5 — Factory collision boundary is procedural, not enforced by the tool

The recovery tool documents apply as “Factory OFF + DB quiescent” at
`requeue_stranded_infra.py:59-62` and in CLI help at `:1592-1596`. Its apply path
checks wave readiness and obtains `BEGIN IMMEDIATE` (`:1286-1337`), but does not
itself assert the Factory-OFF flag or zero active rows. Therefore the caller must
prove that precondition; a successful SQLite write lock alone is not the
operational quiescence contract.

Both proposed recovery applies are already blocked before this issue, but an R2
execution plan must include a fresh pre-apply receipt showing Factory OFF,
zero active work items, no active T1-T10 backtest, exact row pre-state, and the
expected selection hash. Restart/release remains an OWNER/operations action and
is outside this review.

## Required R2 sequence

1. **Q06:** preserve MNT-007. Present a new dry-run only when exactly five
   legitimate Q06 rows are eligible, or obtain a separately reviewed OWNER
   amendment. Do not pad or hand-select the wave.
2. **10582 code fix:** implement/test the markerless `strategy_` parser fallback
   while proving all four setfile hashes remain unchanged.
3. **10582 execution:** use a separately authorized one-row Q08 requalification
   controller; the stranded-INFRA wave is categorically the wrong mechanism.
4. **20007 policy:** fix the persistent priority source, re-census the named IDs,
   and quantify the then-current claim-order displacement. Use an exact,
   snapshotted CAS controller only for rows still pending and missing the flag.
5. **Mutation window:** execute each approved mutation as its own staged action
   only after a Factory-OFF/zero-active receipt. Verification of resulting
   pipeline outcomes is a separate evidence task; no pipeline verdict may be
   inferred from a requeue or flag change.

## Focused verification record

Read-only checks completed:

- Q06 Wave-1 dry-run: `BLOCKED`, 4/5, deterministic member list above.
- Q08 Wave-1 dry-run: `BLOCKED`, 0/5, 8 invalid-report blocks + 5 historical.
- Four current setfile hashes and hypothetical one-line hashes computed in
  memory; current parser count is 0 for all four.
- Existing Q08 aggregate hash binding checked against current ablation-00 bytes:
  exact match at `8d47c4...`.
- Canonical claim SQL inspected and executed read-only; priority scenario run
  against an in-memory database copy only.
- Exact target rows, recovery marker, live scorer result, Factory-OFF flag, and
  seven active rows re-censused.

No mutation or pipeline verdict was produced by this review.
