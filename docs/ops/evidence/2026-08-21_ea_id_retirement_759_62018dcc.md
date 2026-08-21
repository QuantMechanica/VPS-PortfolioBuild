# Governed EA-ID retirement: task 62018dcc

Date: 2026-08-21

Task: `62018dcc-de2f-489a-ab35-eab61efc89f5`

Branch: `agents/board-advisor`

Mechanism commit: `d48c256a9`

Disposition source: `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`

Disposition source SHA-256: `b3bba0e9ae27124906708c77361bb25f9a8587d9939f1239a28d7af35ce29924`

## Outcome

`farmctl retire-ea-ids` retired exactly the 759 rows whose decision is `RETIRE`. The operation used eight bounded apply waves under the existing `.ea_id_registry.lock`; every registry rewrite used `_write_csv_atomic`. There were zero guard refusals and zero residual eligible rows.

The 204 rows with decisions `ADJUDICATE` (191), `INVESTIGATE` (8), or `RECHECK` (5) were filtered before classification and remained active. `QM5_20001` remains active with action `INVESTIGATE` and its one magic row intact.

| Measure | Before | After |
|---|---:|---:|
| Registry rows | 4,584 | 4,584 |
| `active` | 4,501 | 3,742 |
| `retired` | 39 | 798 |
| Decision rows retired with complete provenance | 0 | 759 |
| Non-RETIRE decision rows still active | 204 | 204 |

Registry SHA-256 before: `9f6ce5af4b4d2bb445033171fdd62f6bb145635ffb68fbbe272f5ac520bd4e19`

Registry SHA-256 after: `25d90fbde6a51e5e43516f1ee74f872ea3ee7fd2b9e3f04b8bc43ff5132383a4`

Every transitioned row records:

- `retired_at`
- `retired_reason = OWNER-approved D1 disposition; action=RETIRE only`
- `retired_evidence = docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`

## Guarded command contract

- Dry-run is the default.
- Apply requires an explicit positive `--limit`.
- Decision CSV input admits only `action=RETIRE` rows.
- An EA ID is refused if an EA directory, any runtime `work_items` row, or any magic row exists.
- Registry status and provenance are replaced atomically while holding the same registry lock used by reservation.
- Each invocation writes an atomic JSON receipt beneath canonical `docs/ops/evidence/`.
- Reapplying the completed input is an idempotent registry no-op.

## Wave receipts

| Receipt | Mode | Applied | Already retired | Refused | Deferred | Registry SHA before -> after |
|---|---|---:|---:|---:|---:|---|
| `2026-08-21_ea_id_retirement_dry_run_20260821T184811Z_7ae1ffcf.json` | dry-run | 0 | 0 | 0 | 0 | `9f6ce5af4b4d` -> `9f6ce5af4b4d` |
| `2026-08-21_ea_id_retirement_apply_20260821T185227Z_5f5f2f55.json` | apply | 100 | 0 | 0 | 659 | `9f6ce5af4b4d` -> `e96e4adc60b6` |
| `2026-08-21_ea_id_retirement_apply_20260821T185230Z_75db1432.json` | apply | 100 | 100 | 0 | 559 | `e96e4adc60b6` -> `60f5767fcdf7` |
| `2026-08-21_ea_id_retirement_apply_20260821T185231Z_7acdc355.json` | apply | 100 | 200 | 0 | 459 | `60f5767fcdf7` -> `366de195f046` |
| `2026-08-21_ea_id_retirement_apply_20260821T185232Z_b011f63e.json` | apply | 100 | 300 | 0 | 359 | `366de195f046` -> `43a7a45aa93f` |
| `2026-08-21_ea_id_retirement_apply_20260821T185233Z_8abfc563.json` | apply | 100 | 400 | 0 | 259 | `43a7a45aa93f` -> `9fdde69a8da1` |
| `2026-08-21_ea_id_retirement_apply_20260821T185234Z_bc422537.json` | apply | 100 | 500 | 0 | 159 | `9fdde69a8da1` -> `b1e9da2380d7` |
| `2026-08-21_ea_id_retirement_apply_20260821T185235Z_860b5598.json` | apply | 100 | 600 | 0 | 59 | `b1e9da2380d7` -> `eeffb763ab20` |
| `2026-08-21_ea_id_retirement_apply_20260821T185236Z_4963b206.json` | apply | 59 | 700 | 0 | 0 | `eeffb763ab20` -> `25d90fbde6a5` |
| `2026-08-21_ea_id_retirement_apply_20260821T185259Z_b6e84dc5.json` | idempotency apply | 0 | 759 | 0 | 0 | `25d90fbde6a5` -> `25d90fbde6a5` |

## Verification

Focused and reservation regression suite:

```text
python -m pytest tools/strategy_farm/tests/test_ea_id_retirement.py tools/strategy_farm/tests/test_ea_id_reservation.py tools/strategy_farm/tests/test_farmctl_scope_audit_isolation.py -q
12 passed in 3.28s
```

Post-apply reconciliation independently re-read the decision CSV, EA-ID registry, and magic registry:

```text
RETIRE decision rows:                 759
RETIRE rows now retired:              759
RETIRE rows with complete provenance: 759
Non-RETIRE rows still active:         204 / 204
QM5_20001:                            INVESTIGATE, active, 1 magic row
Second apply:                         0 applied, 759 already retired, SHA unchanged
Residual eligible RETIRE rows:        0
```

No EA directory, work-item, magic registry, setfile, terminal, AutoTrading, or live state was changed by this operation.
