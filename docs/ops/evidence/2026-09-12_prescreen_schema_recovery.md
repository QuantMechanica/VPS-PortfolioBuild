# PRESCREEN taxonomy schema recovery — task 519c11fe

Date: 2026-09-12 UTC  
Disposition: REVIEW (schema and worker classification repaired; reload/rerun pending)

## Incident

The first two Model-1 PRESCREEN cells completed valid MT5 runs but the resident
worker could not persist `PRESCREEN_MEASURED`: the live SH-3 `work_items` CHECK
constraint did not admit the already-defined `prescreen_measurement` taxonomy.
The immutable failures remain at `62538f30-df4e-5d61-b807-b6099af9d7cf` and
`35a985c0-9c67-5551-bed9-5249eed2d664`.

## Code repair

- `artifact_identity.py` now owns the canonical verdict-taxonomy contract and
  completion writers validate the live table DDL before building their UPDATE.
- `schema_hardening.py` consumes the same contract and admits
  `prescreen_measurement`. Its apply path holds the global factory mutation
  lock and takes the backup from a second read connection while the primary
  connection owns `BEGIN IMMEDIATE`; backup, row digest, and rebuild therefore
  share one exact preimage even when tester jobs are active.
- `config_sweep.py` supplies an idempotent append-only PRESCREEN rerun path.
  Each successor has a separately sealed rerun amendment; the original ledger
  bytes and the failed source row remain unchanged.
- `terminal_worker.py` now mirrors the farmctl dispatch path and invokes the
  dedicated Model-1 classifier before projecting a healthy OPT_CENSUS result
  to `PRESCREEN_MEASURED`. The prior worker path incorrectly sent Model 1
  through the Model-4 real-tick classifier and emitted `G1_NO_REAL_TICKS`.
- The promotion fixture now proves that the declared control arm is retained
  even when it is not top-ranked.

Focused verification: `68 passed` across config sweep, SH-3, census dispatch,
preflight-failure, and worker-classification suites; py_compile passes for all
four changed runtime modules.

## Governed live migration

The first apply attempt created a consistent backup but refused and rolled back
because a tester completion changed `work_items` between the online backup and
the original preimage digest. No schema write survived. The corrected apply
completed under mutation-lock nonce `5266da8f291e49e3a6cccbe804a831bc`.

- exact preimage backup:
  `D:\QM\strategy_farm\state\farm_state.pre_prescreen_taxonomy_20260912T1154Z.sqlite`
- live and backup `PRAGMA quick_check`: `ok`
- live and backup preimage work-item rows: `148128`
- post-migration DDL contains `'prescreen_measurement'`: yes
- factory mutation lock after apply: absent

No terminal process was started, stopped, or directly assigned.

## Append-only recovery

Fresh governed backup receipt:
`D:\QM\strategy_farm\state\backups\prescreen_schema_recovery\farm_state_before_governed_hold_20260912T115925Z_db6892ba.sqlite`
(`bc56356b3f43d487ba889c58e7c4c680fa893a7b34203e14e2d9b577facf5591`).

Deterministic successors:

- `62538f30…` -> `c734c260-9044-558f-a354-8d6bebda3c51`
- `35a985c0…` -> `8810cd45-d9c8-5dc0-822c-16dd7445671f`

Their immutable amendments are under the program artifact's `reruns/`
directory. The same cold-file lane authenticator used by resident workers
returned `status=checked`, `candidate_pending=true` for `c734c260…`.
Both successors were claimed through the normal resident worker path and
produced valid Model-1 reports:

| successor | terminal | year | model | report result | trades | stored verdict |
|---|---|---:|---:|---|---:|---|
| `c734c260…` | T7 | 2019 | 1 | PASS | 98 | `INFRA_FAIL:G1_NO_REAL_TICKS` |
| `8810cd45…` | T2 | 2021 | 1 | PASS | 78 | `INFRA_FAIL:G1_NO_REAL_TICKS` |

This proves enqueue, claim, Model=1 tester rendering, evidence class, report
capture, and metric extraction, but it exposed the second worker-classifier
defect above. The failed rows and their report evidence remain immutable.

## Required activation sequence

The terminal-worker repair is Default-OFF until the orchestrator performs its
staggered worker reload. This Codex cycle did not reload or interrupt any
terminal worker and did not create a third rerun that an old resident process
could misclassify.

After reload, the orchestrator must dry-run and then create a new append-only
rerun from one of the two `G1_NO_REAL_TICKS` successors. A healthy result must
persist as `PRESCREEN_MEASURED` / `prescreen_measurement`, never `MEASURED`.
Only then can promote/control/FN reporting be exercised against live rows.

The queue-owner lever remains temporarily at `2000-01-01T00:00:00+00:00` and
347 `PRESCREEN_SCHEMA_FIX_PENDING` holds remain active. Restore the owner to
`2026-08-18T23:00:00+00:00` before any hold release. No holds were released in
this cycle.
