# Fleet OHLC-M1 PRESCREEN cell class — build evidence

Task: `519c11fe-6b03-4e45-8f88-cb487382e492`  
Disposition: **REVIEW**  
Decision binding: `OWNER-DEC-PRESCREEN-OHLC-20260911`  
Production activation: **OFF**

## Outcome

The config/window-sweep adapter now supports a declared, hash-bound PRESCREEN
cell class. A declaration must state native `prescreen_model=1`,
`prescreen_evidence_class=PRESCREEN`, keep/control fractions, and a control seed.
Prescreen cell UUIDs are disjoint from their future real-tick UUIDs while using
the same phase (`OPT_CENSUS`), priority-track field, queue owner/frontier and
ordinary terminal-worker claim/preflight path.

The fleet runner admits Model 1 only when the payload is exactly
`OPT_CENSUS + evidence_class=PRESCREEN + prescreen_model=1`. It passes
`-Model 1 -EvidenceClass PRESCREEN` to `run_smoke.ps1`. That script binds the
pair and writes `evidence_class=PRESCREEN` into `summary.json`; the generated
tester INI differs from the corresponding Model-4 INI only at `Model=1`.
Malformed markers fail closed. Valid cells remain default-off until the
orchestrator reloads workers with `QM_OPT_CENSUS_PRESCREEN_ENABLED=1`.

Healthy Model-1 results close as verdict `PRESCREEN_MEASURED` with taxonomy
`prescreen_measurement`. They can never close as `MEASURED`. The ordinary
Model-4 path remains `MEASURED/measurement`, and only that exact verdict is
eligible for existing DL-089 pruning, selection and downstream evidence code.
The clean view and lifecycle vocabulary recognize the new class without
counting it as a strategy gate result.

## Governed promotion

`config_sweep.py promote --keep <fraction> --control 0.10 [--apply]`:

1. Requires the complete seven-year `PRESCREEN_MEASURED` bundle for every arm.
2. Reads only bound Model-1/PRESCREEN summaries and ranks arms by mean annual
   `return_to_maxdd`; years remain separate observations.
3. Requires CLI fractions to equal the sealed declaration, retains the control
   arm, rounds up keep/control arms, and uses SHA-256(seed, arm) ordering for
   the random control sample of drops.
4. Authors an immutable, self-hashed ranking snapshot and a self-hashed
   promotion amendment bound to the base ledger and snapshot file hashes.
5. On explicit apply, enqueues only new Model-4 `REAL_TICKS` rows for KEEP plus
   CONTROL bundles. Their payloads are rebuilt from a closed declaration-field
   allow-list, so no stale PID, terminal, claim time, result or verdict residue
   can cross from the prescreen rows.
6. Re-running apply is idempotent. Existing rows are accepted only when their
   immutable selection/binding fields match.

The promotion amendment records `prescreen_verdict_created=false`; it grants no
right to manufacture a pipeline verdict. `authenticate_ledger` rechecks the
declaration, base ledger, amendment, ranking snapshot, exact real cell and
setfile before an ordinary worker may claim a promoted row.

## False-negative report and suspension

`config_sweep.py prescreen-report` emits a per-cell CSV plus JSON. Once complete
Model-4 year bundles exist for all KEEP arms and sampled CONTROL arms, a control
arm above the worst retained real-tick arm is counted as a sampled false
negative. The report records numerator arms, completed-control denominator,
rate, `suspend_threshold=0.10`, and `prescreen_suspended=true` when the rate is
strictly above 10%. Incomplete denominators remain `null`, never zero. The
fixture forces one false negative out of one control and verifies suspension.

This is an operational tripwire, not authority to change the 70% decision or
to reinterpret PRESCREEN as full-truth evidence.

## WINSWEEP_QM5_41405 dry run

Input:
`docs/ops/evidence/2026-09-12_config_sweep_qm5_41405_prescreen_dryrun_declaration.json`

The declaration reuses the approved 50-config × 7-year card/matrix/artifact
identity, but has a distinct dry-run program ID and the new sealed fields:

```text
prescreen_model=1
prescreen_evidence_class=PRESCREEN
prescreen_keep_fraction=0.70
prescreen_control_fraction=0.10
declared_trial_count=350
declaration_sha256=b06112c14037a7d781b911f5188bc3920c4ce5322b4a03c33ac9b56f70a801f8
```

Command and result:

```text
python tools/strategy_farm/config_sweep.py plan \
  --declaration docs/ops/evidence/2026-09-12_config_sweep_qm5_41405_prescreen_dryrun_declaration.json \
  --artifact D:/QM/strategy_farm/artifacts/opt_census/WINSWEEP_QM5_41405_PRESCREEN_DRYRUN_2019_2025
{"controls_only": false, "planned_trials": 350,
 "program_id": "WINSWEEP_QM5_41405_PRESCREEN_DRYRUN_2019_2025"}
```

Post-check: artifact directory absent; production rows for the dry-run program
ID = **0**. No terminal was launched and no production enqueue/apply command was
run.

## Verification

- PowerShell AST parse: `run_smoke.ps1` PASS.
- Focused fleet/claim/config/model suite: **201 passed**.
- Extended evidence-binding/clean-view/lifecycle suite: **138 passed**.
- Promotion fixture: 28 prescreen cells (4 arms × 7 years), 2 keep arms,
  1 seeded control arm, 21 real cells; first apply inserts 21 and second apply
  reports 0 inserted / 21 existing.
- The same fixture proves PRESCREEN rows are `PRESCREEN_MEASURED`, promoted rows
  are `REAL_TICKS`, their ledger amendment authenticates, and 1/1 sampled false
  negative sets the suspension flag.
- No production row, program artifact, worker reload, terminal action,
  AutoTrading action, T_Live/FTMO action, selection, verdict or book change was
  performed by this task.

