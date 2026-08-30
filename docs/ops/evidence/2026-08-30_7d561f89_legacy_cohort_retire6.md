# Legacy cohort measured-Q08 pair retirements — execution evidence

- Router task: `7d561f89-f031-4806-9f0f-d0eac630b7e4`
- OWNER decision: `OWNER-DEC-LEGACY-COHORT-DISPO-20260830` (`YES`, receipt `68a58c95`)
- Sealed source audit: `2026-08-30_359988fb_legacy_q12_anchor_audit.md`
- Scope: exactly six `(EA, symbol)` pairs classified `RETIRE_CANDIDATE`

This artifact is created before the transaction so every append-only disposition
and supersession edge can bind its canonical evidence path. The execution plan,
receipt, exact successor IDs, source-row before/after hashes, portfolio state
readback, backup hash, and SQLite quick-check are appended after verification.

No source work-item status, verdict, payload, evidence path, or artifact binding
is edited. Other symbols for the same EA identities are outside scope.

## Execution

- Plan: `2026-08-30_7d561f89_legacy_cohort_retire6_plan.json`
- Plan SHA-256: `70969a91f29b7a80c11b2ceeff8b27caca1aa59617979aab5844dfbbe4cf733d`
- Receipt: `2026-08-30_7d561f89_legacy_cohort_retire6_receipt.json`
- Receipt SHA-256: `e9f1737507f11f353d63028cfd0afc1b511a6225a6610567670ef14565ef0ef4`
- Online backup: `D:\QM\strategy_farm\state\backups\farm_state_before_legacy_retire6_20260830T081023Z_a1fd7976.sqlite`
- Backup SHA-256: `99e17f489515d4f73700b6565efc7f8ade2a393dd688531442931ddc87873564`

| Pair | Q08 source | Append-only RETIRE successor |
|---|---|---|
| `QM5_1567/XAGUSD.DWX` | `78849592-dffe-4344-8edc-fdf9d1c8fc64` | `def43866-a101-54a6-b7bb-6a75373a136d` |
| `QM5_10476/USDCAD.DWX` | `f7f379d3-841d-455a-a64f-ea69ea3fc5ef` | `a111b287-3020-573d-8f8c-ff0f011fd926` |
| `QM5_10919/XTIUSD.DWX` | `cac0d840-73e9-4601-95dd-d37533b32f29` | `b013edcf-7086-5306-aa14-67b092827873` |
| `QM5_11421/AUDUSD.DWX` | `a472a5f9-c614-4c7d-9ff0-8542085e9a02` | `33d3b4ca-fb29-5756-b6f0-5d4e5d7779dc` |
| `QM5_12567/XNGUSD.DWX` | `084a05e0-99cf-435e-bce3-d464d97081e0` | `e206d58b-4d0b-51af-9a8c-e3072b8316a6` |
| `QM5_13117/QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1` | `d9f360d4-6fa3-47ab-bddb-6a33a616f540` | `840c629e-b8a1-5373-accd-e4c67cca35ce` |

All six successors read back as canonical `status=done`, `verdict=RETIRE`,
`verdict_taxonomy=strategy`, `sh3_enforced=0`. Exactly six supersession edges
were added and the exact six matching `portfolio_candidates` rows moved from
`Q12_REVIEW_READY` to `RETIRED`; same-EA rows on other symbols were not selected.
Every source work-item full-row SHA-256 matched its pre-transaction value after
the insertions. `PRAGMA quick_check` returned `ok`.

Verdict: `PASS_EXACT_6_PAIR_SCOPED_APPEND_ONLY_RETIRES_ZERO_HISTORICAL_MUTATION`.
