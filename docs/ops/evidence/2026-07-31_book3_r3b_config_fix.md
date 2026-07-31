# Book3 R3b — coverage-bound config repair

Date: 2026-07-31

Router task: `78d4d826-704a-4f46-88ad-0eb207a2edff`

Predecessor: `d9c409f7-f372-4eac-a7cb-52af0314dccf`

Mode: configuration preparation only; **no `evaluate` invocation and no diagnostic result**

## Result

Claude's fail-closed refusal against prepared-config digest `0581c74b...` was
correct. The frozen `evaluation_end_utc` (`2025-12-30T22:59:59Z`) exceeded
the 9936 stream's actual last close (`2025-12-30T09:46:58Z`).

The replacement contract sets:

- `evaluation_end_utc`: `2025-12-30T09:46:58Z`;
- selection rule: minimum exact coverage authority across all three streams;
- all IS windows, block length 57, seed 20260731, 2,000 replicates,
  scenarios, rules, cost snapshot/digest, claim labels, and input byte
  identities: unchanged.

## Coverage authority

The bound summaries and reports all state the inclusive requested period
`2018.07.02 - 2025.12.31`, but that date-only field is not an exact coverage
instant. Exact authorities were selected as follows and are now embedded in
each historical stream binding under `coverage_authority` in both the spec and
prepared config.

| Sleeve | Exact authority | Coverage instant (UTC) | Bound evidence |
|---|---|---|---|
| 9936 / USDJPY | Stream last-close fallback | `2025-12-30T09:46:58Z` | Summary/report provide no exact run-end instant; stream maximum `time` is corroborated by the report's final deal. Report SHA `fab231b7...` |
| 10145 / XAUUSD | Hash-bound report `end of test` | `2025-12-30T23:58:59Z` | Report exact close and stream maximum `time` agree. Report SHA `325467c2...` |
| 13108 / XTIUSD | Hash-bound report `end of test` | `2025-12-30T23:59:42Z` | Report exact close and stream maximum `time` agree. Report SHA `6656847d...` |

The minimum is the 9936 instant. In Europe/Prague it remains on the frozen
historical end day 2025-12-30, so the diagnostic window identity is narrowed
without changing its declared end date or any selection parameter.

## Prepared artifacts

- Updated IS-only spec:
  `docs/ops/evidence/2026-07-31_book3_r3_is_only_spec.json`

  SHA-256: `80a59dd6c4dc15e3df7ed693e1946314f2e0b27ab5f077a31a2d5191f02e93aa`
- Re-prepared config:
  `docs/ops/evidence/2026-07-31_book3_r3_prepared_config.json`

  SHA-256: `e53a73dcdf5c7532780ba55981e016219b41eae12eafeb98834dd761fdca4da7`

Both artifacts have updated sibling `.sha256` files.

## Verification

- `book3_bound_eval.py prepare-config`: `PREPARED`, digest `e53a73dc...`.
- Strict config validation and all hash-bound input verification: PASS.
- Coverage preflight: evaluation end is at or before all three exact stream
  coverage instants; limiting sleeve `9936` is equal at the boundary.
- Focused evaluator unit tests: PASS (`16 passed`).

No backtest, requeue, database write, Factory action, terminal launch, T5,
T_Live, AutoTrading, pipeline verdict, paid-challenge action, or evaluator
`evaluate` command occurred. Claude remains the designated evaluator/reviewer.
