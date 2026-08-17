# QM5_31003 governed Q02 withholding — task cbf7e4df

Date: 2026-08-17  
Branch: `agents/board-advisor`  
Router task: `cbf7e4df-ad2c-4e61-a176-df4bca19c821`  
Verdict: `PASS_FOR_REVIEW`

## Outcome

All three pending QM5_31003 Q02 rows now have active, non-restart holds and
are absent from the farm's actual pending claim selector:

| Work item | Symbol | Status retained | Hold active | Claimable |
|---|---|---|---|---|
| `848e9cdd-2e03-479e-a2cc-3b874d1d1cd5` | AUDUSD.DWX | pending | yes | no |
| `eda90444-01d5-4e30-aac3-50395ee2b1f1` | EURUSD.DWX | pending | yes | no |
| `647ddb38-0cbf-45ac-bb04-348525f8c406` | GBPJPY.DWX | pending | yes | no |

The hold code is `WITHHELD_FOREIGN_SYMBOL_SCOPE`. `release_on_restart=0`, so
a factory restart cannot silently release these rows.

## Governed mechanism

Added `tools/strategy_farm/governed_work_item_hold.py` as the operator-facing
path for exact pending-row holds while the factory remains live. It does not
edit work-item status. Its apply path:

1. Takes a consistent SQLite backup and records its SHA-256.
2. Opens `BEGIN IMMEDIATE` and revalidates every exact `work_item_id=symbol`
   target as pending, unclaimed, verdict-null, correct EA, and correct Q phase.
3. Rejects conflicting existing holds and applies all requested holds in one
   transaction.
4. Writes one `governed_hold_activated` event per row.
5. Reads the rows back and proves each active hold excludes the row from the
   same hold predicate used by the canonical pending claim selector.

The command is idempotent for an identical active hold. Any precondition or
conflicting-hold mismatch aborts the whole transaction; tests cover the
no-partial-write behavior.

## Durable evidence

- Plan: `docs/ops/evidence/cbf7e4df_qm5_31003_hold_plan_2026-08-17.json`
- Apply receipt: `docs/ops/evidence/cbf7e4df_qm5_31003_hold_apply_2026-08-17.json`
- Pre-mutation database backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_governed_hold_20260817T051830Z.sqlite`
- Backup SHA-256:
  `6523013732aa1508511d86a197f154d2ff0d94fffbb3d7859d423ee64f426635`

The plan observed three claimable pending rows with no holds. The apply receipt
records three inserted holds and `all_unclaimable=true`.

## Release condition

Do not release until either:

1. the G8 strength cross-section is precomputed offline into a hash-bound
   artifact with no runtime foreign-symbol access; or
2. `basket_manifest.json` declares all 28 runtime pairs and a single canary has
   measured the resulting terminal footprint.

The full release condition is recorded in each audit event and the apply
receipt. A generic release command was intentionally not added: release needs
the separate implementation/canary evidence and review authorization described
above, not merely knowledge of a work-item ID.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_governed_work_item_hold.py \
  tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q
69 passed

Canonical farmctl.pending_claim_order_sql() readback:
target_count=3
active_nonrestart_holds=3
claimable_intersection=[]
audit_events=3

Idempotent post-apply plan:
PASS; all three rows read back held and unclaimable

git diff --check -- <explicit task paths>
PASS
```

No terminal was started or interrupted, no factory state or gate was changed,
no work-item status was edited, and neither T_Live nor AutoTrading was enabled.
