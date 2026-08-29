# QM5_20224 FX cointegration Q03 active-predecessor handoff

Date: 2026-08-29 UTC (`2026-08-29T22:49:37Z`); 00:49 Europe/Berlin on
2026-08-30

Branch: `agents/board-advisor`

Observation base: `4acdc74606a874a22e92c9c4599d7c32cb8de827`

Status: the exact EURUSD/EURJPY fallback remains priority-bound at Q03, but a
legitimate older multisymbol row owns the serialized basket lane. No duplicate
Card, EA, work item, queue mutation, manual dispatch, terminal action, or
portfolio mutation was performed.

## Frontier decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. The durable coverage
audit accounts for all 66 relationships, and all 119 approved cointegration or
coint cards have matching EA directories. There is no eligible unbuilt scan
pair.

Neither preferred anchor has a current Q02 infrastructure block:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Historical per-leg `ONINIT` or `NO_HISTORY` rows do not supersede the later
logical-basket Q02 PASS verdicts. The strategy-card extraction gate is closed
for lack of a non-duplicate qualified relationship, and the EA-build gate is
closed for lack of an approved unbuilt identity.

## Selected existing forex sleeve

The concrete fallback remains scan rank 46,
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. It trades `EURUSD.DWX` and
`EURJPY.DWX` on D1 with frozen beta `-0.236324029`; `USDJPY.DWX` is
conversion-history-only. The backtest contract remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, with no ML, adaptive refit, banned
indicator, grid, martingale, or portfolio feedback.

Canonical lineage was re-read from the farm:

- Q02 `5d1cb89c-25ce-419c-869c-8c9f7afa10c1`: done / PASS.
- Q03 `3c74eb04-7e19-4aa0-8dcf-3f004faaa946`: pending, unclaimed,
  attempt zero, `priority_track=true`, payload SHA-256
  `b9e8294d644b5d450601ea7eb7456e83165716f52e6b4a5cabf4e8f95eb484b4`.
- Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e`: pending, not priority-bound,
  and not promoted ahead of Q03.

No second Q02 or Q03 row is valid.

## New serialized-lane progress

Since the committed `2026-08-29T21:46:51Z` stop, the preceding queue made a
real forward transition:

| EA | Phase | Work item | New state |
|---|---|---|---|
| `QM5_41078` | Q05 | `0aa74af1-c6c4-423e-9ad4-19e0222e024f` | PASS at 22:26:32Z |
| `QM5_41078` | Q06 | `f2839978-e5af-4c42-8ec2-ede1eac65591` | INFRA_FAIL at 22:32:20Z |
| `QM5_41079` | Q04 | `ffa3fbf3-7447-4cae-8ad5-f70a0751c2dc` | active on T4 from 22:34:54Z |

The governed `q04_walkforward.py` runner for QM5_41079 remained alive as PID
5760 under T4 worker PID 17432 at the bounded post-check. An instantaneous
`mt5-slots` scan landed between visible tester processes, but the database row,
phase runner, 44 GB heavy-multisymbol reservation, and live process lineage all
remained active. That snapshot is not evidence of a free basket lane.

Four known downstream baskets still precede the FX target after the active
row: QM5_41085, QM5_41086, QM5_20294, and QM5_20206 at Q04. Forcing the FX row
now would violate one-basket pacing.

## Capacity and safety boundary

Two fresh five-sample whole-host CPU windows were non-binding:

| UTC | Average | Maximum | 97% ceiling |
|---|---:|---:|---|
| 22:46:13 | 90.525551% | 95.135761% | clear |
| 22:48:20 | 92.456074% | 94.744090% | clear |

The binding condition in this observation is the legitimate active predecessor,
not CPU. The resident workers own progress; no dispatch tick or terminal control
was needed or authorized.

The portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live, AutoTrading, live/deploy manifests, Cards, EA
sources, EX5 files, setfiles, basket manifests, registries, magic rows, queue
rows, priorities, claims, statuses, and verdicts were untouched. Existing
unrelated shared-worktree changes were preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/qm5_20224_q03_active_predecessor_handoff_20260829T224820Z_board_advisor.json`.

## Continuation condition

Let QM5_41079 and the four older downstream basket rows drain. Before any later
action, take a fresh five-sample CPU window and re-read the exact QM5_20224 Q03
row. Never enqueue a duplicate, force a second basket, or promote Q04 before a
canonical Q03 PASS.
