# Canonical Checkout Guard Propagation Evidence - 2026-07-03

Task: `09e692a9-d2b5-40bc-9747-5c4fbce5fb11`

## Result

Merged the canonical-checkout guard stack to `main` through `C:/QM/worktrees/cto_main`.

Main commits:

- `aef8ad739` - `fix(farm): anchor FRAMEWORK_EAS_DIR to canonical checkout (guard layer 1, 07:42 incident)`
- `36337782c` - `fix(farm): canonical-checkout guard layers 1-3 (task 1a52d28d)`

The second commit carries the 9-test focused guard suite at:

- `tools/strategy_farm/tests/test_canonical_checkout_guard.py`

## Verification

Focused guard tests on `main`:

```text
python -m unittest tools.strategy_farm.tests.test_canonical_checkout_guard
Ran 9 tests in 0.104s
OK
```

Parity check against `C:/QM/repo/tools/strategy_farm/{farmctl,repair}.py`:

- `farmctl._ea_dir_from_setfile_path`: MATCH
- `farmctl._preferred_ea_dir`: MATCH
- `repair._pending_work_item_artifact_failure`: MATCH
- `repair.repair_pending_unclaimable_work_items`: MATCH
- `farmctl._assert_canonical_checkout`: intentional main-side wrapper difference only; `main` keeps the broader `_STATE_MUTATING_COMMANDS` command guard while retaining no-arg test compatibility.

## Dependent Task

Dependent task to unblock: `c8051e18`

Required payload note:

```text
all farmctl invocations from C:/QM/repo only (rule 23)
```

Router update performed after this evidence was written.
