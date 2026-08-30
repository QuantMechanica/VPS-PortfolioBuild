# Legacy cohort exact Q09 re-entry — execution evidence

- Router task: `f3cacf27-bd47-4e70-bc7d-66506d9a8281`
- Authority: OWNER-directed legacy-cohort re-entry, 2026-08-30
- Sealed audit: `2026-08-30_359988fb_legacy_q12_anchor_audit.md`
- Scope: exactly `QM5_10403/XAUUSD.DWX`, `QM5_10911/GDAXI.DWX`, and
  `QM5_12969/USDJPY.DWX`

The three audit-qualified Q08 dossiers are byte-bound by separate JSON anchor
files. The canonical `farmctl.py enqueue-backtest` path is used with the exact
Q08 predecessor and an exact terminal Q09 row as an immutable append-only rerun
target. Existing Q09 and `Q09_PORTFOLIO` rows remain untouched.

Execution row IDs, payload bindings, claimability, source-row before/after
hashes, and SQLite integrity readback are appended after verification.

## Verified enqueue

| Pair | Q08 dossier anchor | New append-only Q09 row | Immutable Q09 rerun target |
|---|---|---|---|
| `QM5_10403/XAUUSD.DWX` | `7fd4caf6-b599-4833-a431-a132a404b60b` / `bb57935a...` | `ee4062b1-3940-45ce-bd66-b463e55afc1e` | `35436575-96f9-4f38-960a-958b864d2e38` |
| `QM5_10911/GDAXI.DWX` | `55256268-50f8-4d94-8d9a-83652c64b013` / `df2d728c...` | `6b4532f2-9de5-4b99-b824-c05ce2848cac` | `e3267f2a-5788-4d5c-9149-0f2f164dfdbb` |
| `QM5_12969/USDJPY.DWX` | `f14ad921-721e-413d-a2de-6506ceaf8483` / `f47e8f6e...` | `c38e2fbf-8fbb-4c79-b66a-b51cbe4378af` | `8cdc3bc9-12dc-47c4-8836-655f78d2470b` |

At `2026-08-30T08:18:48Z`, all three new rows were `phase=Q09`,
`gate_contract_version=v4`, `status=pending`, unclaimed, and free of active
holds, hence claimable. Each payload binds the exact audit Q08 work-item ID,
the on-disk aggregate SHA-256, the sealed audit path/hash, the current MQ5/EX5/
setfile hashes, and its immutable append-only rerun target. Each setfile reads
`RISK_FIXED=1000` and `RISK_PERCENT=0`.

The full-row SHA-256 values of all three Q08 anchors and all three cited prior
Q09 rows were identical before and after enqueue. No portfolio row was used as
a Q09 baseline. `PRAGMA quick_check` returned `ok`.

- Machine receipt: `2026-08-30_f3cacf27_legacy_q09_reentry_receipt.json`
- Receipt SHA-256: `8fb2781cbe9e3188905e266fc5463be9e1fd4292445e34d30804e2eabca2d0f3`

Verdict: `PASS_EXACT_3_APPEND_ONLY_Q09_SEEDS_HASH_BOUND_AND_CLAIMABLE`.
