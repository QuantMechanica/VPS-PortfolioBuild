# Q-PRESCREEN Model-1 marker gate repair — task 519c11fe

**RESULT (Q-only): REVIEW — live enqueue and ordinary fleet claim are proven;
the last execution blocker is repaired and 107 focused tests pass. Existing
pending cells remain for the scheduled fleet; no row was manually rerouted or
reverdictized.**

## Re-issue finding

The approved implementation in commit `2fd096cd2f` remains the controlling
design, but the live program is no longer only a dry run. Read-only inspection
of `WINSWEEP_QM5_41405_PRESCREEN_DRYRUN_2019_2025` found:

| row class | count |
|---|---:|
| original Model-1/PRESCREEN cells | 350 |
| append-only reruns | 2 |
| queue-owner declaration | 1 |
| pending Model-1/PRESCREEN | 347 |
| attempted Model-1/PRESCREEN | 5 |
| PRESCREEN rows carrying verdict `MEASURED` | 0 |

The declaration and ledger are present under
`D:/QM/strategy_farm/artifacts/opt_census/WINSWEEP_QM5_41405_PRESCREEN_DRYRUN_2019_2025/`:

- declaration SHA-256:
  `f105937397f3fc8f31ccd0daf3341f80b2eadae6ec243abb19616b6f641aa24f`;
- ledger SHA-256:
  `74fd2361362dd39944ca949119ca62c8e6a3e007842b94ef3167c12eb6c8ad32`.

The five attempts prove the normal claim/dispatch path on T2, T4, T5, and T7,
including bound EX5/setfile identities, private custom history, Job Object
containment, and `run_smoke.ps1`. They did not yield a measurement:

- `62538f30-df4e-5d61-b807-b6099af9d7cf` and
  `35a985c0-9c67-5551-bed9-5249eed2d664` predate the SH-3 taxonomy repair and
  failed when `prescreen_measurement` was not yet admitted by the DB check;
- `9fdbcfa4-a3e2-5f0d-b86e-1659003a43ae`,
  `c734c260-9044-558f-a354-8d6bebda3c51`, and
  `8810cd45-d9c8-5dc0-822c-16dd7445671f` produced native runner evidence but
  closed `G1_NO_REAL_TICKS`.

The latter is a runner defect: Model 1 deliberately cannot emit the Model-4
"generating based on real ticks" marker. The initial implementation bound the
input pair correctly, but the common report validator still demanded that
marker after execution.

## Repair

`run_smoke.ps1` now admits only the two exact input pairs:

- `Model=1`, `EvidenceClass=PRESCREEN`;
- `Model=4`, `EvidenceClass=REAL_TICKS`.

The real-tick marker remains mandatory for the second pair. For the first pair,
marker absence no longer creates `NO_REAL_TICKS_MARKER_FAST_FINISH`,
`MODEL4_MARKER_REQUIRED`, or a failed global marker gate. The summary continues
to report the actual marker value (false for Model 1), plus explicit
`model_marker_required` and `model_marker_passed` fields; no real-tick evidence
is manufactured. All other report, history, OnInit, minimum-trade,
determinism, timeout, log-bomb, and artifact-identity gates remain unchanged.

On a healthy result the existing reviewed farmctl mapping is therefore
reachable and closes the cell as `PRESCREEN_MEASURED/prescreen_measurement`,
never `MEASURED/measurement`. Promotion, seeded control selection, false-
negative reporting, and the greater-than-10% suspension rule remain the
reviewed implementation from `2fd096cd2f`; no selection or promotion was run
in this repair.

## Verification and operational boundary

```text
PowerShell AST parse framework/scripts/run_smoke.ps1
PASS

python -m pytest -q \
  tools/strategy_farm/tests/test_config_sweep.py \
  tools/strategy_farm/tests/test_opt_census_dispatch.py \
  tools/strategy_farm/tests/test_research_canary.py \
  tools/strategy_farm/tests/test_terminal_worker_prescreen_verdict.py \
  tools/strategy_farm/tests/test_schema_hardening_sh2_sh3.py
107 passed
```

The dry plan still resolves to 350 trials and made no write. The live DB probe
found zero `evidence_class=PRESCREEN AND verdict=MEASURED` rows. This task did
not start or interrupt a terminal, reload a worker, enqueue/reroute a row,
enable T_Live/AutoTrading, promote an arm, or issue a pipeline verdict. The 347
pending cells are intentionally left to the normal scheduled fleet. A fresh
post-repair cell receipt is still required before the operational acceptance
can be considered fully observed.

