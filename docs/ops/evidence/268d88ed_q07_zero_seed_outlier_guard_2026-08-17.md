# Q07 sibling-relative zero-seed outlier guard

Date: 2026-08-17
Router task: `268d88ed-eec5-499c-801b-e14a3bc7ff95`
Scope: Q07 aggregation, ingestion taxonomy, and one evidence-only verdict correction
Live action: none; no terminal launch, tester rerun, T_Live, or AutoTrading action

## Outcome

Q07 now distinguishes a uniformly inactive strategy from a collapsed seed run.
After tester-health and missing-summary checks, the exact predicate is:

```text
seed trades == 0
AND median(trades across the complete seed cohort) >= Q07 MIN_TRADES (20)
```

Such a seed makes the aggregate `INVALID` with a reason that names every
outlier, the cohort median, and the floor. The seed is not removed: the
aggregate stops before PF/trade grading and retains all five seed trade counts
in its metrics. This is fail-closed and cannot let broken evidence improve a
verdict.

The predicate is sibling-relative because zero is suspect only when the cohort
majority clears Q07's economic trade floor. With five canonical seeds, the
median tolerates one or two collapsed runs but not a majority-zero cohort. The
implementation uses Q07's actual `seed_trades_below_floor` threshold (`20`), so
every cohort at or above the run_smoke floor (`45` in the production examples)
is covered while the aggregation rule remains aligned with its own grade.

`farmctl` now recognizes `seed_zero_trades_outlier` as evidence-invalid. It
maps Q07 aggregate `INVALID` to the operational work-item class `INFRA_FAIL`,
never to strategy `FAIL`.

## Required contrast

| Case | Seed trades | Median | Derived result |
|---|---:|---:|---|
| QM5_1077 / XAUUSD | `[0, 0, 0, 0, 0]` | 0 | `FAIL / seed_trades_below_floor`; unchanged |
| QM5_1116 / EURJPY | `[602, 612, 0, 612, 607]` | 607 | aggregate `INVALID / seed_zero_trades_outlier:seeds=[99]:median=607:floor=20` |
| two-outlier control shaped like QM5_11177 | `[271, 274, 273, 0, 0]` | 271 | aggregate `INVALID`; both seeds 7 and 2026 are named |

The first two cases and the two-outlier case are executable regression tests.

## Production-row disposition

Raw Q07 aggregates use `INVALID`; the operational database represents this
retry/evidence class as `INFRA_FAIL`. The five hold rows were bound as exact
preservation preimages and did not change.

| Work item | Pair | Trades | Aggregate / work-item disposition |
|---|---|---:|---|
| `b37c01d6-3762-4f7d-9463-0272d444c007` | QM5_1116 / EURJPY | `[602,612,0,612,607]` | derived aggregate `INVALID`; corrected `FAIL -> INFRA_FAIL`, attempt count remains 0 |
| `0e181bc9-506a-40b4-835f-29e96c6bc18b` | QM5_20004 / NDX | `[56,54,54,0,53]` | preserved aggregate `INVALID` / work item `INFRA_FAIL` |
| `3de052c5-7d71-4473-a57e-8befc2cf435b` | QM5_20105 / CADJPY | `[80,79,76,79,0]` | preserved aggregate `INVALID` / work item `INFRA_FAIL` |
| `50afe7d8-b012-40dc-89d0-dc9f0484bb72` | QM5_13013 / NDX | `[0,61,60,61,0]` | preserved aggregate `INVALID` / work item `INFRA_FAIL` |
| `eb1f411b-cda6-4a8e-a1ca-da621711bf79` | QM5_9573 / NDX | `[68,67,67,0,0]` | preserved aggregate `INVALID` / work item `INFRA_FAIL` |
| `eeb59ea4-9ab0-4bde-ad2b-ec4db891f41a` | QM5_11177 / XAUUSD | `[271,274,273,0,0]` | preserved aggregate `INVALID` / work item `INFRA_FAIL` |

The genuine uniform-zero control `e317cb4a` remains `FAIL`, attempt count 0,
with `seed_trades_below_floor:seeds=[42, 17, 99, 7, 2026]:floor=20`.

## Cause investigation: QM5_11177 / XAUUSD

The investigated row is `eeb59ea4`, using the XAUUSD D1 ablation-02 HARSH
setfiles. The five raw setfile hashes differ because their seed values differ,
but after replacing the `qm_rng_seed` line with one normalized value, all five
hash to:

```text
9d08606803a1710dd60ae724ddd225a9c5d8ba5173973a38e2f303d7dbb11127
```

Every other byte is identical, including `RISK_FIXED=1000`,
`RISK_PERCENT=0`, stress probability, filter settings, and strategy inputs.
This rules out seeded-setfile generation drift.

The run evidence identifies a tester/history failure:

| Seeds | Evidence |
|---|---|
| 42, 17, 99 | `status=OK`, `exit_code=0`, 271/274/273 trades |
| 7, 2026 | three attempts each, every run `status=INVALID`, `failure=NO_HISTORY`, no tester exit code, zero trades |

Both collapsed seeds report `EMPTY_EXPERT`, `EMPTY_SYMBOL`, `M0_1970_PERIOD`,
`BARS_ZERO`, `NO_HISTORY_LOG`, and `HISTORY_CONTEXT_INVALID`; their reports are
22,336 bytes versus 587,576 bytes for healthy seed 42. This is not a genuine
strategy no-signal outcome and not a generator bug. The historical aggregate
already classified these two seeds as invalid tester evidence.

## Slot-cost decision

I chose fail-closed `INVALID` and no immediate rerun. For `b37c01d6`, rerunning
only seed 99 would cost approximately one dispatch; the correction performed
zero dispatches and keeps the pair out of economic grading until governed seed
evidence is available. A wrong strategy `FAIL` would instead discard the pair's
entire remaining pipeline. No seed was silently omitted.

## Mutation evidence

- Plan: `268d88ed_q07_zero_seed_outlier_reclassification_plan_2026-08-17.json`
- Plan SHA-256: `3dfa7635226d5129f0b696252d32ded6b6acc493b066d641c7cfe96e1e3d9307`
- Receipt: `268d88ed_q07_zero_seed_outlier_reclassification_receipt_2026-08-17.json`
- Receipt SHA-256: `6816b635c80371e9c1cf5bf428fa3d8046dc408cc8093070bbee41976490f2ed`
- Pre-mutation backup: `D:\QM\strategy_farm\state\backups\farm_state_before_q07_zero_seed_guard_20260817143830Z.sqlite`
- Backup SHA-256: `288f3f3bb202ddebb49bda8a6c4b1c7076c7beb46a10184cce709aa7e6633b47`
- Target aggregate SHA-256: `fc4671d00989adff548227d56477c54c9538030bd6d1eedc0adf5a9d7dbd0ac0`
- SQLite `PRAGMA quick_check`: `ok`
- Transition ledger: sequence 1869, action `reclassify_q07_zero_seed_outlier`
- Event ledger: event 348689, `q07_zero_seed_outlier_reclassified`
- Raw evidence changed: no
- Preservation rows changed: 0 of 5
- Work items enqueued or rerun: 0

## Verification

Focused suite:

```text
python -m pytest framework/scripts/tests/test_q05_q07_verdicts.py \
  tools/strategy_farm/tests/test_verdict_taxonomy_ws2.py \
  tools/strategy_farm/tests/test_q07_zero_seed_outlier_reclassify.py -q
```

Result: `76 passed in 13.60s`.

This covers the aggregation contrast, two simultaneous zero outliers, ingestion
taxonomy, hash-bound compare-and-swap, evidence immutability, exact preservation
rows, backup creation, and the no-rerun invariant.
