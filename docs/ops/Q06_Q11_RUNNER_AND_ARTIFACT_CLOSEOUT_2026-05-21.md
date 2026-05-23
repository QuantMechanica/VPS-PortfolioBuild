# Q06-Q11 Runner And Artifact Closeout

Status: CURRENT MIRROR  
Date: 2026-05-21

## Scope

Closeout for the two remaining operational cleanup items:

- legacy EA build artifacts for `QM5_1002` and `QM5_1003`
- Q06-Q11 runner wiring validation

## EA Artifact Cleanup

Legacy artifacts were moved out of the active runnable EA tree and into:

`docs/ops/legacy_ea_artifacts/2026-05-21/`

Archived items:

- `QM5_1002_davey_eu_night/`
- `QM5_1002_davey-eu-night_build/`
- `QM5_1003_davey_baseline_3bar/QM5_1003.ex5`

Active artifacts left in `framework/EAs`:

- `framework/EAs/QM5_1002_davey-eu-night/`
- `framework/EAs/QM5_1003_davey_baseline_3bar/QM5_1003_davey_baseline_3bar.ex5`

Verification:

```powershell
python - <<'PY'
import sys
sys.path.insert(0, 'tools/strategy_farm')
import farmctl
for ea in ['QM5_1002', 'QM5_1003']:
    print(ea, farmctl._ea_build_artifact_failure(ea))
PY
```

Result:

```text
QM5_1002 None
QM5_1003 None
```

Meaning: the active queue guard no longer sees ambiguous EA directories or duplicate `.ex5` artifacts for these two EAs.

## Q06-Q11 Runner Validation

Operator-facing phase names are Q-only. Internal runner keys remain implementation details where existing scripts require them.

Validated behavior:

- Q06-Q11 cascade wiring creates the expected phase runner commands from upstream evidence.
- Missing required upstream evidence marks the job as waiting for input instead of promoting.
- Q08 hard PASS requires real MT5 crisis-slice evidence, not report-only output.
- Q11 hard PASS requires real news replay/deal-replay evidence, not synthetic matrix-only output.
- Phase runners remain dry-run/idempotence safe for reruns.

Commands run:

```powershell
python -m pytest tools\strategy_farm\tests\test_cascade_chain_p2_to_p8.py framework\scripts\tests\test_phase_runners_contract.py framework\scripts\tests\test_p8_news_driver.py framework\scripts\tests\test_phase_verdict_semantics.py -q
python -m pytest framework\scripts\tests\test_phase_runners_idempotence.py framework\scripts\tests\test_phase_end_to_end_dryrun.py tools\strategy_farm\tests\test_p2_full_dwx_fanout.py -q
```

Results:

```text
10 passed in 10.64s
6 passed in 8.46s
```

Closeout decision: the Q06-Q11 runner wiring gap is closed. Future Q06-Q11 failures should be treated as candidate evidence outcomes or missing-input cases, not as an open structural wiring topic unless a new reproducible runner defect appears.
