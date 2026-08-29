# QM5_20224 FX cointegration Q03 serialized-lane handoff

Date: 2026-08-29 UTC (`2026-08-29T20:55:45Z`); 22:55 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `4eceb928d162f042eb39ffaadbab5b66e57b3489`

Status: no non-duplicate relationship remains unbuilt from the frozen 66-pair
FX scan, and neither preferred anchor has a current Q02 initialization or
history blocker. The exact existing EURUSD/EURJPY fallback remains
priority-bound at Q03. The repaired worker generation has now activated a
legitimate predecessor in the one-basket lane, so forcing the FX row would
violate paced admission. No duplicate Card, EA, work item, manual dispatch,
terminal action, or portfolio mutation was performed.

## Frontier decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3 hard
criterion selected only two relationships from the original 66-pair scan:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Historical per-leg `ONINIT` or `NO_HISTORY` rows do not supersede those later
logical-basket Q02 PASS verdicts. The committed sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships. The strategy-card extraction gate is
therefore closed for lack of a new qualified relationship, and the EA-build
gate is closed for lack of an approved unbuilt identity. Creating another
Card or EA would duplicate governed coverage or weaken the source criterion.

## Selected existing sleeve

The concrete fallback remains scan rank 46,
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. It trades `EURUSD.DWX` and
`EURJPY.DWX` on D1 with frozen beta `-0.236324029`; `USDJPY.DWX` is
conversion-history-only. DEV net Sharpe was `0.473267` and OOS net Sharpe was
`-0.118543`, so the approved contract permits one pipeline falsification and
no refit, filter, or rescue.

Fresh deterministic verification passed:

- Card schema and ML lint: `ok`, zero ML hits, zero missing sections.
- EA registry row: active.
- Magic slot 0: `EURUSD.DWX`; magic slot 1: `EURJPY.DWX`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Basket manifest: both traded legs plus the order-free USDJPY conversion
  history.

| Binding | SHA-256 |
|---|---|
| Approved Card | `3b2ab7bc3c1dea90a86b936b1bf0e352f69e5c9532724f78512a18b987d35580` |
| MQ5 | `7eda37af63f23e00dcb930d71eb07afe4bef97e30875ec7f83bf5d234f668129` |
| EX5 | `d534838d2c9c993db151500c836f4e38088d961b2fe90e820defb0d31a34ae5b` |
| Basket manifest | `f7207377d90fb4fb3447425597f4ec4b2c2709838e0bd44cf4d851f70bb97725` |
| Logical setfile | `397181311f649d5416044d36d6aa70023390ea8b14f97cb75e7fb8818b144254` |

Canonical lineage is unchanged:

- Q02 `5d1cb89c-25ce-419c-869c-8c9f7afa10c1`: done / PASS.
- Q03 `3c74eb04-7e19-4aa0-8dcf-3f004faaa946`: pending, unclaimed,
  attempt zero, `priority_track=true`, payload SHA-256
  `b9e8294d644b5d450601ea7eb7456e83165716f52e6b4a5cabf4e8f95eb484b4`.
- Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e`: pending and not promoted ahead
  of Q03.

## Paced lane state

At `2026-08-29T20:55:45.704811Z`, the target ranked eighth among pending
multisymbol work. Seven legitimate downstream rows precede it: QM5_41077 and
QM5_41078 at Q05, then QM5_41079, QM5_41085, QM5_41086, QM5_20294, and
QM5_20206 at Q04.

The single active basket is QM5_41076 Q05 work item
`34176377-51a0-4eea-a97d-86420a022a52`, claimed by T3. Its real
`q05_stress_medium.py` runner started at `2026-08-29T20:49:59Z` under PID
6136 with the governed 44 GB heavy-multisymbol reservation. This is a healthy
post-fix activation, not a stale or missing claim. A second basket, a manual
promotion, or a direct run of QM5_20224 would violate the serialized admission
contract.

This is a real frontier delta from the preceding handoff: QM5_41076 and
QM5_41077 have both completed Q04 and generated Q05 successors, and the
post-fix worker generation has activated QM5_41076 Q05. The target remains the
first pending FX basket, with exactly one open Q03 identity.

## Capacity and safety boundary

Three five-sample whole-host CPU windows were non-binding:

| UTC | Average | Maximum | 97% ceiling |
|---|---:|---:|---|
| 20:45:27 | 79.915659% | 94.635012% | clear |
| 20:49:29 | 62.843592% | 65.628527% | clear |
| 20:54:07 | 76.280252% | 82.034895% | clear |

The stop condition was not CPU in this observation. The binding condition is
the legitimate active predecessor plus canonical downstream ordering. Existing
resident workers own its progress; no dispatch tick or terminal control was
needed or authorized.

The portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live, AutoTrading, live/deploy manifests, Cards, EA
sources, EX5 files, setfiles, basket manifests, registries, magic rows, queue
rows, priorities, claims, statuses, and verdicts were untouched. Existing
unrelated shared-worktree changes were preserved and excluded from this
commit.

Machine-readable evidence is in
`artifacts/qm5_20224_q03_serialized_lane_handoff_20260829T205545Z_board_advisor.json`.

## Continuation condition

Let the active basket and seven older pending downstream baskets drain in
canonical order. Before any later action, take a fresh five-sample CPU window
and re-read the exact QM5_20224 Q03 row. Never enqueue a duplicate, force a
second basket, or promote Q04 before a canonical Q03 PASS.
