# Century Suite build program — batch 1 preflight

- Router task: `1cfde12d-8a5b-4fbd-a05e-b281e5312f96`
- Worklist: `artifacts/century_clean_buildable.json`
- Date: 2026-08-16
- Progress: **0/77 built**
- Result: **batch aborted before directory or registry mutation**

## Worklist and race checks

- Worklist exists and contains exactly `77` rows.
- `framework/registry/magic_numbers.csv` and
  `framework/include/QM/QM_MagicResolver.mqh` were clean at preflight.
- No affected EA directory existed for the first five rows.
- No terminal, compile, Q02 enqueue, or pipeline action was started.

## First batch — deterministic identity failures

The `qm-build-ea-from-card` contract requires a slug of at most 16 characters
and a compiled EA label of at most 32 characters. All five first-batch registry
identities violate both limits:

| EA | registry slug length | proposed label length | active magic rows |
|---|---:|---:|---:|
| `QM5_30002` | 31 | 41 | 0 |
| `QM5_30003` | 44 | 54 | 0 |
| `QM5_30008` | 36 | 46 | 0 |
| `QM5_31002` | 33 | 43 | 0 |
| `QM5_31003` | 40 | 50 | 0 |

The slugs are already bound in `ea_id_registry.csv` and in the approved cards.
Silently shortening them during Development would break the required
card/registry/folder slug equality. A governed rekey is required before these
can be called buildable.

## Preflight defect found

`framework/scripts/skill_build_ea_guard.py` reports
`"magic_registry_rows": true` for every first-batch EA despite the table above.
Its implementation currently sets that check to `REG_MAGIC.exists()`; it tests
only that the CSV file exists, not that the requested EA has any row. Therefore
the script gives a false PASS and cannot establish the build skill's magic-row
precondition. This was detected read-only; the guard was not patched because
the deterministic router assigned an EA build program, not framework
maintenance.

The routed method explicitly authorizes governed in-build allocation after the
directory is created, so zero magic rows alone would be reconcilable for this
task. It does not reconcile the identity-length violations above.

## Card completeness check

The second row, `QM5_30003`, also cannot be implemented without inventing
mechanics. Its approved card names three modules (linear-regression channel
fade, Asian-session breakout, and H4 volatility surge), but gives no numerical
channel calculation, Asian range/window, H4 surge threshold, or deterministic
module-3 parameter. The parameter table exposes only two enable flags and a
hold time. This contradicts the card's `r2_mechanical: PASS` claim and the
instruction to implement only card-authorized logic.

## Review disposition

Return the program to REVIEW at `0/77`. Before requeue:

1. govern a deterministic short-slug rekey for the Century worklist and both
   registries/cards, preserving EA IDs;
2. repair `skill_build_ea_guard.py` to verify exact active `(ea_id, slot)` rows
   (or explicitly recognize the narrow in-build allocation workflow without a
   false PASS); and
3. return under-specified cards such as `QM5_30003` to Research for closed-form
   R2 completion.

No pipeline verdict can be inferred from this preflight.
