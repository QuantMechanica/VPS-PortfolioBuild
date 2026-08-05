# Build-Claim Q02 Exclusion Preflight

Date: 2026-08-05 (Europe/Berlin)

Router task: `a5be72b1-504c-4b69-aacd-4f1f3396fa08`

## Outcome

The shared `build_ea` claim guard now refuses ordinary build selection and
dispatch for either of these existing Q02-exclusion conditions:

1. the normalized EA ID is present in
   `D:/QM/strategy_farm/state/requeue_excluded_eas.txt`; or
2. the approved card declares more than 100 expected trades per year per
   symbol and every declared instrument is a supported fiat FX pair.

The deterministic refusal is surfaced as `Q02_EXCLUDED`. The guard remains
read-only and is already used by the paced build selection and the
post-atomic-claim dispatch recheck, so the exclusion is applied before an
agent build or Q01 smoke can consume capacity.

An explicit `allow_q02_excluded=True` policy-owner override exists at the
shared guard and defaults to false. No production caller enables it.

## Implementation

- Added strict fiat-FX pair classification for AUD, CAD, CHF, EUR, GBP, JPY,
  NZD, and USD pairs. Metals, indices, energy, crypto-like symbols, missing
  symbol declarations, and mixed-asset cards do not match the FX-only rule.
- Extended `_build_task_claim_guard` to emit the exclusion source, expected
  frequency, and declared symbols with its refusal evidence.
- File-listed EA IDs fail before a dispatch claim is created. The card-derived
  rule is evaluated only after the card is readable, approved, and R-gate
  ready.
- Added focused regression coverage for a file-listed row, an FX-only card at
  101 trades/year/symbol, an unaffected high-frequency metal card, and the
  explicit override.

Code/test commit on `agents/board-advisor`:
`8b5eb1ba0e9909bd8741c81f5468b065d49de7b8`.

## One-Shot Exposure Sweep

The live farm DB was inspected read-only after the guard landed. The sweep
selected `build_ea` rows with `status='pending'`, excluded live in-flight task
IDs, and compared ordinary guard output with the explicit override output.
This identifies rows that are otherwise claimable but refused only because of
the Q02 exclusion.

| Measurement | Count |
|---|---:|
| Pending build rows | 8 |
| In-flight pending rows skipped | 0 |
| Otherwise-claimable `Q02_EXCLUDED` rows | 0 |

There is no remaining currently claimable exposure in this cohort. No task,
card, exclusion entry, registry row, or work item was mutated by the sweep.

## Verification

Command:

```powershell
python -m pytest tools/strategy_farm/tests/test_build_q02_exclusion_preflight.py tools/strategy_farm/tests/test_mnt012_build_guards.py tools/strategy_farm/tests/test_auto_build_routing.py -q
python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/tests/test_build_q02_exclusion_preflight.py
```

Result: `45 passed, 12 subtests passed`; Python compilation passed.

## Safety Boundary

- `requeue_excluded_eas.txt` was read, not edited.
- No card was retired or moved.
- No registry or pipeline policy was changed.
- No Q02 work item was enqueued, requeued, or mutated.
- No terminal was launched or interrupted.
- `T_Live` and AutoTrading were not touched.
