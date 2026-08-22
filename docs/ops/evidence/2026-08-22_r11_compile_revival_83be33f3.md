# R11 COMPILE_EA append-only revival

Date: 2026-08-22
Router task: `83be33f3-a45d-453b-bb70-79d10a7841e9`
Branch: `agents/board-advisor`
Verdict: `PASS_90_REVIVED_APPEND_ONLY`

## Outcome

Exactly **90** source-fresh EAs are back in the governed `COMPILE_EA` queue as new pending,
activation-held work-item rows. The 91 historical rows falsely written as `failed/INVALID` by
R11 remain byte-for-byte unchanged; no stored verdict was deleted, cleared, or overwritten.
The new rows have `verdict=NULL`, `no_gate_verdict=true`, and the fixed-risk contract
`RISK_FIXED=1000`, `RISK_PERCENT=0`.

The exact incident selector was:

```sql
phase='COMPILE_EA'
AND status='failed'
AND verdict='INVALID'
AND json_extract(payload_json, '$.repair_handler')='R11_pending_unclaimable_work_item'
AND json_extract(payload_json, '$.verdict_reason')='ex5_missing'
```

No phase/status-only or broad historical-work selector exists in the recovery utility.

## Before and after

| Measurement | Before | After first apply | Second apply |
|---|---:|---:|---:|
| Exact historical incident rows | 91 | 91 | 91 |
| Source-fresh rows without successor | 90 | 0 | 0 |
| SHA-stale incident rows held | 1 | 1 | 1 |
| Append-only revival successors | 0 | 90 | 90 |
| Pending activation-held successors | 0 | 90 | 90 |
| Rows appended by invocation | 0 dry-run | 90 | 0 |
| SQLite backup created | no | yes | no |

The second `--apply` invocation reported `idempotent_noop=true`, `already_revived_count=90`,
`applied_count=0`, and `verification_ok=true`. Idempotency is keyed to the historical work-item
ID through both the successor payload and the unique transition-ledger key.

## SHA-stale exclusions

- `QM5_12946`, historical work item `ae9e93a6-4a77-4ac9-bd11-e9ec1363bc60`, was in the exact
  incident selector but its current MQ5 SHA-256 differs from its enqueued binding. It remains
  `failed/INVALID`, its existing hold remains active, and no successor was created.
- `QM5_41097`, work item `d646713d-c8ba-41ef-98f4-9b544780e714`, was outside the exact selector
  because it remains pending. Its current source is also SHA-stale, its rollout hold remains
  active, and no successor was created.

Both require the separate supersede/cancel and fresh-enqueue path.

## Transaction and evidence contract

The apply operation:

1. defaulted to dry-run and classified all 91 exact rows;
2. acquired `D:/QM/strategy_farm/state/FACTORY_MUTATION.lock`;
3. wrote and quick-checked a 415 MB online SQLite backup;
4. reselected the exact population inside `BEGIN IMMEDIATE`;
5. rehashed every canonical MQ5 and compared every historical row preimage;
6. appended 90 new work items, 90 activation holds, 90 transition-ledger rows, and paired old/new
   audit events in one transaction;
7. reread the live DB and verified the historical population, successor population, source holds,
   and no-gate-verdict contract;
8. released the factory mutation lock successfully.

Backup:

```text
D:\QM\strategy_farm\state\backups\farm_state_before_r11_compile_revival_20260822T052100Z_389d5f02.sqlite
SHA-256 470511470cea81d0e9d6b8701b20eae565f842a967794484864f1a52a6ea13a9
```

## Durable receipts

- `docs/ops/evidence/2026-08-22_r11_compile_revival_dry_run.json`
- `docs/ops/evidence/2026-08-22_r11_compile_revival_apply.json`
- `docs/ops/evidence/2026-08-22_r11_compile_revival_second_apply.json`

The full receipts include every old/new work-item mapping, source path/hash, historical preimage
hash, before/after counts, held-row reasons, backup binding, and lock-release status.

## Focused verification

```text
python -m py_compile tools/strategy_farm/revive_r11_compile_ea.py
PASS

python -m pytest \
  tools/strategy_farm/tests/test_revive_r11_compile_ea.py \
  tools/strategy_farm/tests/test_compile_work_items.py \
  tools/strategy_farm/tests/test_release_compile_wave.py -q
13 passed in 3.34s
```

No terminal was launched or stopped, no active backtest was interrupted, no setfile was changed,
and no pipeline/gate verdict was asserted. The revived rows remain held for the governed compile
wave rather than bypassing the rollout boundary.
