# Q12 misrun append-only dispositions

- Router task: `6034d56a-d6ce-4296-a472-26915f6b726c`
- OWNER decision: `OWNER-DEC-Q12-MISRUN-DISPO-20260826`
- Authority: `decisions/2026-08-26_owner_q12_disposition_ftmo_position.md` §1
- Branch: `agents/board-advisor`
- Applied at: `2026-08-26T13:55:44+00:00`

## Result

Exactly two `disposition_only` rows were appended to
`D:/QM/strategy_farm/state/farm_state.sqlite`. Both carry
`recommended_disposition=ACKNOWLEDGE_INVALID_FOR_DECLARED_Q12`, verdict
`INVALID`, the OWNER decision ID/hash, the immutable source-row hash, and the
already-authorized measuring successor. No backtest or pipeline verdict was
created.

| Immutable source row | Appended disposition row | EA / symbol | Authorized successor |
|---|---|---|---|
| `dfca24fa-28df-5f5e-818f-8dcf53611822` | `4bc6b24f-989c-5e74-847a-54281ac3e72c` | `QM5_10706 / GBPUSD.DWX` | `1a92b33e-e34f-532e-80b3-e0144f3b3755` |
| `d0e53004-659c-563c-8314-c24ad4ab2a68` | `63fd6133-d2d4-5b6a-b41c-1d2b5a8157ae` | `QM5_11421 / EURUSD.DWX` | `c4bc189b-372d-54c9-be45-046ac77b245b` |

## Source preservation proof

The tool hashes the canonical representation of every source-row column before
the transaction, re-reads and hashes both rows again before commit, and aborts
on any mismatch.

| Source row | SHA-256 before | SHA-256 after |
|---|---|---|
| `dfca24fa-28df-5f5e-818f-8dcf53611822` | `c4a4539b783cd28b0f4f71f92ad1304e1b09db79d9fc446cd0afe8c5a3b949f7` | `c4a4539b783cd28b0f4f71f92ad1304e1b09db79d9fc446cd0afe8c5a3b949f7` |
| `d0e53004-659c-563c-8314-c24ad4ab2a68` | `24f8da5b7ba695db0cd08e312ffe631df10dc801b7ae82486ec5d3ec87bd4373` | `24f8da5b7ba695db0cd08e312ffe631df10dc801b7ae82486ec5d3ec87bd4373` |

The transaction reports `source_rows_updated=0` and
`source_rows_deleted=0`. The originals remain `done / PASS` with their original
`updated_at` timestamps.

## Verification and receipt

- Pre-apply dry run: exact source count `2`; prior dispositions `0`; planned
  appends `2`; source identity/payload/full-row guards all passed.
- Post-apply dry run: dispositions `2`; additional appends `0`; both source
  full-row hashes unchanged.
- Readback: two `failed / INVALID` disposition rows, both with
  `disposition_only=true` and the exact OWNER decision ID.
- Event readback: two `owner_q12_misrun_invalid_appended` events.
- Syntax compilation and `git diff --check` passed.
- Durable receipt:
  `D:/QM/reports/state/q12_misrun_disposition_receipt_20260826.json`, SHA-256
  `9e8b99b147948577091ea1dd80c2c99ffabf59cf1f8f7b0e944ed7509a517cb9`.

Rollback is append-only: a later OWNER-authorized superseding disposition may
be appended. Historical rows and these disposition receipts must not be
deleted or overwritten.
