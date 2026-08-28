# V4a Phase 5 — Build-6140 rebase preparation and execution stop

Task: `9018743b-5731-4b34-8aa4-61426e1db1c4`  
Observed: `2026-08-28` (`Europe/Berlin`)  
Verdict: **HONEST NO — FRESH COLD COHORT READY; SAME-BUILD WARM RUN NOT AUTHORIZED**

Twenty fresh USDJPY/GBPUSD factory cells from the current Berlin calendar day
were re-authenticated on MT5 Build 6140. Their complete cold elapsed time is
`4,885.034 s`. No warm cell was launched: the signed DEV2 contract still pins
Build 5833, the Build-6140 candidate package is not fully hashed or
OWNER-signed, and the unchanged validation code rejects this Phase-5 task ID.
Warm parity and batch speedup are therefore null, not inferred.

This is an operations evidence packet, not pipeline evidence and not an
activation verdict.

## Acceptance disposition

| Criterion | Result |
|---|---|
| DEV2 current build, signed or OWNER template | **PARTIAL / OWNER TEMPLATE** — unsigned Build-6140 rebase template created; live DEV2 remains signed to Build 5833 and unchanged |
| 20 fresh references | **PASS** — 20 fully authenticated Build-6140 references from `2026-08-28 Europe/Berlin` |
| Same-build warm parity and batch speedup | **NOT RUN** — same-build lane and task-bound validation prerequisites failed before launch |
| Checklist or honest finding | **PASS: HONEST NO** — the V4a premise remains untested on one build |
| Durable evidence | **PASS** — committed report, reference CSV, and unsigned OWNER template |

## Fresh Build-6140 cold cohort

The deterministic selection traversed completed `OPT_CENSUS / MEASURED`
USDJPY/GBPUSD rows in descending `(updated_at, work_item_id)` order within the
Berlin calendar day and retained the first 20 that passed byte
re-authentication. The accepted time interval is
`2026-08-28T00:35:08+02:00` through `2026-08-28T03:36:44+02:00`.

Every accepted row proved:

- `run_smoke/v2`, deterministic `PASS`, exactly one `OK` run, real-tick marker;
- native report bytes matched the recorded hash and declared `Build 6140`;
- logger-sample bytes matched the recorded hash;
- source setfile bytes matched the work-item binding;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, and no stale-news override above 336;
- history receipt was `qm.custom-history-copy-on-claim/v1 / PASS_PRIVATIZED`
  and bound common manifest
  `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`;
- staged EX5 was verified before and after the run and execution identity stayed
  stable;
- canonical report-metric and closed-trade hashes were recomputed from native
  report bytes.

Two otherwise eligible DB rows were excluded rather than counted:

| Work item | Reason |
|---|---|
| `bdd2c453-646a-56ba-9ee3-81e8faa7863e` | `logger_sample` and `logger_sample_path` are null |
| `e02776d1-1791-5217-b706-b75dad86984e` | logger receipt is absent; full authentication failed |

The complete 20-row identity/hashing table is
`9018743b_v4a_phase5_build6140_cold_references_2026-08-28.csv`, SHA-256
`9ab369d2034f52391ab9369897345976c916faeccfd299a9b677a5a6934ea9c2`.

Cold timing summary:

| Cells | Total s | Mean s | Median s | Minimum s | Maximum s |
|---:|---:|---:|---:|---:|---:|
| 20 | 4,885.034 | 244.252 | 226.234 | 193.961 | 356.696 |

## Build-6140 rebase template

The current signed lane contract remains
`framework/registry/dev2_lane_contract.json`, SHA-256
`866e4e346187e47c33e32beb30bb96dc4085e98cc316819fb33f7925306dda06`,
and pins the Build-5833 program tuple documented by Phase 4.

The representative current factory root `D:/QM/mt5/T1` reports:

| Program | File version | Bytes | SHA-256 state |
|---|---:|---:|---|
| `terminal64.exe` | `5.0.0.6140` | 121,845,984 | `86c563c8c113e4af8802dc91241ecd51fc06caf92cc86fc40026dd8046e526ed` (Phase-4 T1/T2/T10 sample) |
| `metatester64.exe` | `5.0.0.6140` | 21,810,944 | OWNER capture required |
| `MetaEditor64.exe` | `5.0.0.6140` | 116,791,384 | OWNER capture required |

Repeated read-only hash attempts for the two missing files did not complete
during active factory I/O and were stopped without touching any terminal
process. Their hashes were left null instead of guessed. The unsigned OWNER
template is
`9018743b_v4a_phase5_build6140_owner_template_2026-08-28.json`, SHA-256
`87cfe0048fc15a8bef19761f175d8112d6edbd6bc735cf2ca5013c8f4b9c5e5d`.
It contains the quiescent-source requirement, complete three-program hash gate,
candidate-contract binding, rollback requirements, task-bound validation seal,
and explicit null OWNER signature fields. It authorizes nothing in its current
state.

## Why warm execution stopped before launch

The existing validator is intentionally task-bound. Supplying an otherwise
well-formed Phase-5 validation template for this task returns exactly:

```text
VALIDATION_TASK_ID_INVALID
VALIDATION_RESTART_TASK_ID_INVALID
```

In addition, the governed backend verifies every DEV2 program byte against the
current Build-5833 lane contract before opening a logical session. Substituting
Build 6140 without a reviewed contract delta and OWNER seal would fail closed
and would violate the sealed-comparator premise.

Consequently:

- warm comparisons: `0 / 20`;
- exact comparisons: `0 / 20`;
- warm batch elapsed time: `null`;
- speedup `cold / warm`: `null`;
- V4a parity verdict: `UNTESTED`, not PASS or FAIL.

## Cold-path and containment verification

The four governed cold-path files remain byte-identical to the Phase-3 task
boundary and equal to repository HEAD:

| Path | SHA-256 |
|---|---|
| `tools/strategy_farm/terminal_worker.py` | `78d98a793f501bd833d98a912a7d4f8395fd8830d3f2ed6a389a8920b93144bb` |
| `framework/scripts/run_smoke.ps1` | `750478498f9280b61d2cb02ba1ee03a52b54bb448461b2d3d3cc246af411cf4a` |
| `tools/strategy_farm/opt_census.py` | `1c23cf9cf399902bff07fcbd1e02e104c0c5f09c8ec16d990a89c681f6f18f9a` |
| `tools/strategy_farm/dl089_matrix_service.py` | `30e3929f3408b801fc47c93f68adcc288f1e418b8ed7d8fe3e707ecaaebf8bb7` |

At `2026-08-28T08:42:02Z`:

- `QM_ENABLE_WARM_CELL_RUNNER` was absent (Default-OFF);
- DEV2 program process count was `0`;
- residual `QM_DEV2*` Scheduled Task count was `0`;
- the `QMDev2` account was disabled and password-required;
- DEV2 lane-contract hash was unchanged;
- no terminal was started manually or through the DEV2 controller;
- no T1-T10 process was interrupted;
- no T_Live or AutoTrading state was enabled or changed;
- no queue, receipt, database, pipeline, cold-path, DEV2, or factory bytes were
  mutated by this investigation.

## Required next governed action

OWNER may complete and sign the template only in a quiescent source window,
after all three program hashes and the candidate lane-contract hash are bound.
A reviewed code delta must then bind this task (or a newly routed successor) to
the governed-restart validator. Only after the signed Build-6140 DEV2 contract,
task-bound validation seal, frozen 20-row CSV hash, common history manifest,
EX5/setfile bindings, and rollback proof all agree may the first warm cell run.
The runner must still stop on the first deviation and must report complete-batch
speedup only after all 20 cells authenticate.
