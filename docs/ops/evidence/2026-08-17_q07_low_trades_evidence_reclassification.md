# Q07 low-trade evidence reclassification

Date: 2026-08-17  
Router task: `c6343474-97ec-410f-b258-789c333f7267`  
Scope: Q07 verdict classification only; no tester reruns and no live action

## Result

`framework/scripts/q07_multiseed.py::evaluate_seeds` no longer treats the
`run_smoke` wrapper exit code as tester health. A wrapper exit of 1 is expected
when a healthy deterministic run returns `MIN_TRADES_NOT_MET`. Tester health is
now derived from the stored summary's `runs[*].status`, per-run `exit_code`,
`oninit_failure_detected`, and `log_bomb_detected`, while `_run_seed`'s existing
`invalid_reason` and timeout fields remain fail-closed.

The dedicated missing-summary path remains `INVALID`. Seed-authentication
failures such as `effective_seed_mismatch` remain `INVALID`.

## Evidence-only row corrections

The following existing Q07 rows were corrected atomically from their intact
seed summaries. No Q07 work item was requeued or rerun.

| Work item | Pair | Prior verdict/reason | Derived verdict/reason |
|---|---|---|---|
| `e317cb4a-0486-4a4e-a47b-660162844345` | `QM5_1077` / `XAUUSD.DWX` | `INFRA_FAIL`; five `exit_code=1` seeds | `FAIL`; `seed_trades_below_floor:seeds=[42, 17, 99, 7, 2026]:floor=20` |
| `b37c01d6-3762-4f7d-9463-0272d444c007` | `QM5_1116` / `EURJPY.DWX` | `INFRA_FAIL`; seed 99 `exit_code=1` | `FAIL`; `seed_trades_below_floor:seeds=[99]:floor=20` |

The current Q07 runner imports its trade floor from Q05 (`20`). The cited
QM5_1077 historical summaries recorded a run-time minimum of 45, but all five
seeds produced zero trades, so both thresholds yield the same economic `FAIL`.

The live SQLite transaction preserved each original aggregate path, added a
`q07_low_trades_reclassification` payload record, and appended both a
`work_item_transition_ledger` row and an `events` row per correction.

Pre-mutation snapshot:

- `D:\QM\strategy_farm\state\backups\farm_state_before_q07_low_trades_reclassify_20260817T130013Z.sqlite`
- SHA-256 `4b022692a1e3e35389abf2068c2b15d7b1168df360c031953186097178c3438d`
- Size: 390,778,880 bytes

## Historical sweep

The sweep selected every current Q07 row whose canonical payload reason still
contained `seeds_invalid_evidence`, then evaluated `per_seed_detail` against
the stored summaries.

- 17 rows matched.
- 2 rows had healthy tester evidence and were reclassified above.
- 10 rows remain genuine `INVALID` because stored evidence contains non-OK
  tester runs and/or the existing `invalid_summary` reason.
- 5 rows are unresolvable because evidence was purged or absent; no verdict was
  guessed or changed.

Unresolvable rows:

| Work item | Pair | Missing evidence |
|---|---|---|
| `73b1e46c-69d7-4de2-8e5f-7ee3fe7345b9` | `QM5_10114` / `GDAXI.DWX` | per-seed summary paths absent from aggregate |
| `d7f50281-edfd-46b4-9253-1860171e4db2` | `QM5_12918` / `AUDUSD.DWX` | per-seed summary paths absent from aggregate |
| `3de052c5-7d71-4473-a57e-8befc2cf435b` | `QM5_20105` / `CADJPY.DWX` | per-seed summary path absent from aggregate |
| `8146c6c7-690c-4255-ab04-b289ca93fe96` | `QM5_1226` / `XTIUSD.DWX` | no current aggregate/evidence path |
| `f2ff5100-4b23-450b-af3e-90e9437ff9c2` | `QM5_10796` / `XAUUSD.DWX` | per-seed summary paths absent from aggregate |

## Focused verification

Command:

```text
python -m pytest framework/scripts/tests/test_q05_q07_verdicts.py -q
```

Result: `49 passed in 2.54s`.

Required controls covered:

1. Healthy tester + wrapper exit 1 + low trades => `FAIL / seed_trades_below_floor`.
2. Any non-OK per-run status => `INVALID`.
3. `oninit_failure_detected=true` => `INVALID`.
4. `effective_seed_mismatch` from `_run_seed.invalid_reason` => `INVALID`.
