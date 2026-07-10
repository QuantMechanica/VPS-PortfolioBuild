# QM5_1058 FX Pair Q07 Priority Handoff

Date: 2026-07-10
Branch: `agents/board-advisor`

## Outcome

The existing unique Q07 row for the `QM5_1058_gatev-fx-pairs-zscore`
EURUSD/GBPUSD D1 market-neutral basket was promoted to the priority lane. The
guarded mutation updated only queue priority/audit metadata; it did not insert
a work item, claim a terminal, dispatch a worker, or launch MT5.

| Field | Value |
|---|---|
| Work item | `82c0189f-f4a7-4e3f-ac76-79b38037bacb` |
| Logical symbol | `QM5_1058_EURUSD_GBPUSD_GGR_D1` |
| State | `pending`, unclaimed, attempt 1 |
| Prior release | infrastructure `summary_missing` |
| Priority | `priority_track=true` |
| Open matching Q07 rows | 1 |
| Work-item count before / after | 95,616 / 95,616 |

Database backup:
`D:/QM/strategy_farm/state/backups/farm_state_pre_qm5_1058_q07_priority_20260710T134828+0000.sqlite`.

## Selection

The controlling strict 66-pair scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` has no unbuilt honest
survivor. Its only two qualifiers are already built and no longer blocked at
Q02:

| EA | Pair | Current frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

The mission fallback therefore applies. `QM5_1058` is the strongest existing
low-frequency FX pair with a legitimate open next gate: its EURUSD/GBPUSD
logical sleeve has passed Q02, Q03, Q04, Q05, and Q06. The sole Q07 row had
returned to pending after an infrastructure-only `summary_missing` release,
so promoting that row advances the funnel without weakening a gate or
duplicating work.

## Structural, Source, And Risk Checks

- APPROVED card:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1058_gatev-fx-pairs-zscore.md`.
- Reputable-source criterion: Gatev, Goetzmann, and Rouwenhorst (2006),
  *Review of Financial Studies* 19(3), 797-827, via the approved Quantpedia
  source packet; card frontmatter records R1-R4 PASS.
- Mechanics: deterministic rolling OLS spread and fixed z-score thresholds;
  no ML, PnL adaptation, grid, martingale, or pyramiding.
- Cadence: D1, expected two trades per year per symbol.
- Traded legs: `EURUSD.DWX` and `GBPUSD.DWX`.
- Basket manifest:
  `framework/EAs/QM5_1058_gatev-fx-pairs-zscore/basket_manifest.json`.
- Canonical setfile is `environment=backtest`, `risk_mode=FIXED`,
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## CPU Ceiling

The farm had 7 active work items at the guarded mutation, equal to the paced
controller ceiling. No dispatch, tester, smoke run, or manual backtest was
started. The priority row remains pending for paced pickup.

## Safety

No `T_Live`, AutoTrading, deploy/live manifest, portfolio gate,
`portfolio_admission`, portfolio KPI, or Q08-contribution path was touched.
Existing unrelated dirty worktree files were left untouched.

Machine-readable evidence:
`artifacts/fx_cointegration_qm5_1058_q07_priority_20260710T134828Z.json`.
