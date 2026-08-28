# QM5_1252 FX Q02 infrastructure repair and CPU stop

Date: 2026-08-28

Branch: `agents/board-advisor`

EA: `QM5_1252_carver-handcraft-ens`

Farm task: `25d7265a-332b-4d4c-8c5e-6518c7caa52a`

Outcome: **SOURCE/SPEC REPAIRED; GOVERNED COMPILE RELEASED; Q02 NOT ENQUEUED
BECAUSE THE 97% CPU STOP WALL FIRED**

## Selection and collision control

The highest-diversity approved build, `QM5_41191_wti-samecal-srank`, acquired
an EA directory and compile row on another paced lane during preflight. No
other approved card lacked an EA directory. The next priority was therefore a
diverse built-but-stuck package. `QM5_1252` is a reputable-source,
low-frequency D1 forex-capable ensemble (approximately 35 expected trades per
year per symbol) with no open work item or agent task at selection time.

The exact append-only repair scope was claimed in the farm DB as ops task
`25d7265a-332b-4d4c-8c5e-6518c7caa52a` before editing. It names only the
historically stranded EURUSD/GBPUSD Q02 lineages. No competing `QM5_1252`
work item was open.

## Diagnosis and repair

The package's EX5 dated 2026-06-21 had SHA-256
`89e4ba8ccb83755624f0d7a5dc998207ffaaea5f0769f0f619ab191cb23b69c9`
and predated the current source/framework build contract. Current hardening
found exactly two source defects:

- framework-managed `OnTick()` lacked the explicit
  `QM_FrameworkTrackOpenPositionMae()` call;
- the median-spread collector indexed a dynamic buffer without an explicit
  `ArraySize` bound proof.

Both were repaired without changing a signal, threshold, weight, timeframe,
position rule, or exit. The legacy `SPEC.md` was normalized to the seven
current mandatory sections using the already approved card/source. It records
the six implemented fixed-weight rule families, D1 timing, fixed thresholds,
registered universe, reputable Rob Carver/pysystemtrade sources, and the Q02
`RISK_FIXED=1000` / `RISK_PERCENT=0` contract.

The repaired working-copy MQ5 SHA-256 is
`cf41554ab02caa59610e3379bd6e9ca49774ee5727ea68697a9cbd331a641afd`.

## Governed compile handoff

Ad-hoc `build_check` correctly failed closed with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because factory terminals were alive.
An exact task/EA-bound source-repair authority was added to the existing
governed compile queue, with a negative test for wrong labels and wrong task
IDs.

`farmctl enqueue-compile` admitted one append-only `COMPILE_EA` row:

- work item: `62044bf3-dcf2-4337-a5f9-7196eb4a2efa`;
- expected MQ5 SHA-256: `cf41554a...a641afd`;
- source-repair authority:
  `router_ops_issue:25d7265a-332b-4d4c-8c5e-6518c7caa52a`;
- timeframe/universe: D1, 12 registered symbols;
- initial state: pending, unclaimed, no verdict.

The exact-row rollout dry run matched the queued/current source hashes. The
governed hold release applied at `2026-08-28T18:34:54Z` and produced backup
`D:\QM\strategy_farm\state\backups\farm_state_before_compile_wave_20260828T183422Z_85074657.sqlite`
(SHA-256
`7912d4a63fee95495e72a594b351898d3346586268f0503e630ceb323b959d7c`).
At the stop point, the compile row remained pending behind existing paced work;
no terminal was claimed or launched manually.

## Q02 lineage preserved

The intended first canary is the preserved pre-binding EURUSD row
`edfcba29-ad06-4b74-907f-38eba94d2610` (`failed / INFRA_FAIL`,
`summary_missing_retries_exhausted`, 2015-2024). GBPUSD predecessor
`8cc9c3c2-1ecd-42f6-8b40-b292b782bf88` has the same infrastructure-only
class. Their later INVALID poison-pill dispositions also remain unchanged.

No Q02 successor was enqueued. A current `COMPILE_OK` EX5 receipt is required
first, and the CPU ceiling fired while the governed compile was pending. A
future paced pass may verify the compile receipt and use `seed-fresh-q02` with
the exact current EX5 hash and noncanonical-setfile reconciliation. It should
seed one FX canary first, not fan out the entire universe.

## Verification and stop evidence

- `skill_build_ea_guard.py`: registry row, active magic rows, and EA directory
  all present.
- `build_gate_hardening.py`: PASS after repair; zero failures.
- `validate_build_guardrails.py`: PASS for the MQ5 and all 12 backtest
  setfiles; every baseline set retains `RISK_FIXED=1000` and
  `RISK_PERCENT=0`.
- `validate_spec_doc.py`: 1 PASS, 0 FAIL after normalization.
- `test_compile_work_items.py`: 27 passed.
- `test_release_compile_wave.py`: 3 passed.
- `test_candidate_repair_enqueue.py` plus
  `test_validate_ex5_commit_guard.py`: 50 passed.
- Pre-handoff five-sample CPU at `2026-08-28T18:39:41Z`: average 89.93%,
  maximum 93.28%; the wall was not yet binding.
- Stop sample at `2026-08-28T18:45:17Z`: 89.16%, 86.47%, 97.96%, 97.17%,
  81.25%; average 90.40%, maximum 97.96%. The governed 97% average-or-maximum
  rule was binding, so no Q02 enqueue or further compute work was performed.

No strategy mechanics, historical verdict, portfolio gate, T_Live file,
deploy manifest, AutoTrading setting, portfolio admission, or certification
state was changed.
