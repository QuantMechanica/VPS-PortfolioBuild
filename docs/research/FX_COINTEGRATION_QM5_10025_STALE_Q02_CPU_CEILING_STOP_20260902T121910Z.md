# FX basket fleet: QM5_10025 stale-Q02 CPU-ceiling stop

Date: 2026-09-02 UTC (`2026-09-02T12:19:10.666960Z`); 14:19
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `6965a87a9ac8dc46d3a016a3e40a55e3621ac9c1`

Status: the frozen 66-pair frontier has no reputable unbuilt identity, both
preferred anchors are past Q02, and one real stale execution binding was found
on the selected existing FX fallback. The explicit CPU ceiling fired before
any supersession or enqueue, so the stale row was preserved and no backtest was
started.

## Non-duplicate frontier decision

The controlling source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its fixed v3 study
tested all 66 unordered FX relationships and admitted only the two positive
DEV/OOS survivors. The latest complete census records all 66 relationships as
covered, with 123 approved cointegration/coint identities, 123 matching EA
directories, and no unbuilt approved identity. Creating another Card, EA,
manifest, registry allocation, or Q02 row from that scan would duplicate
governed work.

The two preferred anchors have no current Q02 `ONINIT` or `NO_HISTORY`
blocker:

| EA | Relationship | Governed chain |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS; Q04 FAIL |

The existing-card fallback therefore remains
`QM5_10025_rw-fx-broad-pairs`: an approved, structural H4 market-neutral FX
basket sourced to Robot Wealth. It selects one partner monthly from seven
major FX symbols, freezes the OLS hedge ratio for the month, and trades a
beta-weighted two-leg package. It has no ML, banned indicator, grid,
martingale, or intramonth coefficient adaptation. Its USDJPY evidence preset
still binds `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Concrete stale-Q02 finding

The only unsuperseded open USDJPY/H4 Q02 identity is work item
`e49888a1-6dbe-45b7-bb4f-29461bbcfb0c`. It is pending, unclaimed, attempt
zero, priority-tracked, and preserves the terminal zero-trade predecessor
`050dd2ea-e9d0-475f-b5ad-40c2206867ff` append-only. It was created at
`2026-09-01T23:44:14Z` with these immutable bindings:

| Artifact | Pending row SHA-256 |
| --- | --- |
| MQ5 | `49e0c78c0e45fa39b05580216003ee523839b664844a82e3a7d3d943030e069a` |
| EX5 | `030e7acc63a735a514c5490000eed4d4bf062bf8f6ee8e4da34a601da8f9ba1e` |
| USDJPY H4 set | `9567e0f91b1e6892eadc822a2f6ee4f06482a80ba30c50ccfbf4a205d2acda70` |

Governed compile work item `21c7d995-2fd6-44f6-b624-8c5f097c0961` completed
later, at `2026-09-02T00:27:56Z`, as `COMPILE_OK`. The current files are:

| Artifact | Current SHA-256 |
| --- | --- |
| MQ5 | `db7424efcba0a8df90184240e277e1a7546e8030672eec88a4c72a89c32a5a61` |
| EX5 | `49fcc59b5232531f5fd2e3ba7a0c71f0bac703f54e17f7c92c911e31944d91f1` |
| USDJPY H4 set | `4ca9d75bdb2274888ab9afc339034e7f1dc2af93ada2ff62b5672bb2976b92a5` |

All three bindings changed. The pending row therefore must not dispatch the
current binary. A direct database check found no existing canonical
`work_item_supersedes` edge for it. The row and its source artifacts were not
mutated in this wake.

## Capacity stop

The mandatory five one-second whole-host CPU samples were `97.2%`, `99.5%`,
`93.2%`, `83.0%`, and `90.7%`. Average CPU was `92.72%`; maximum CPU was
`99.5%`. Because the maximum met or exceeded the explicit 97 percent ceiling,
the mission stopped before any database write, supersession, enqueue, dispatch,
tester, terminal reservation, or backtest.

## Governed continuation

On a later wake, proceed only after a fresh five-sample window has both average
and maximum strictly below 97 percent and after confirming the target files
are stable. Then:

1. Preserve `e49888a1-6dbe-45b7-bb4f-29461bbcfb0c` and record one canonical
   `work_item_supersedes` edge explaining that its execution binding predates
   the later governed compile and set refresh.
2. Use the authenticated append-only Q02 rerun path from terminal predecessor
   `050dd2ea-e9d0-475f-b5ad-40c2206867ff`, requiring the then-current EX5
   SHA-256.
3. Verify exactly one unsuperseded open USDJPY/H4 Q02 row remains and leave
   dispatch to the paced farm. Do not create per-symbol duplicates or manually
   launch MT5.

No portfolio-admission/KPI/Q08-contribution surface, portfolio gate, T_Live
manifest or terminal, AutoTrading state, live setfile, registry, or magic row
was touched. Pre-existing unrelated shared-worktree changes were preserved and
excluded from this commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_10025_stale_q02_cpu_ceiling_stop_20260902T121910Z_board_advisor.json`.
