# QM5_20224 FX cointegration Q03 active handoff

Date: 2026-08-29 UTC (`2026-08-29T16:35:11Z`); 18:35 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `616c614420af8a7b5359d412ccd9e3de4db490ce`

Status: the existing exact EURUSD/EURJPY logical-basket row has advanced from
priority-bound Q03 pending to an active, hash-bound Q03 run on T4. No duplicate
Card, EA, work item, priority mutation, manual dispatch, tester launch, or
terminal action was performed by this observation.

## Frontier reconciliation

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3 hard
criterion selected only two relationships from the original 66-pair scan:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Historical per-leg `ONINIT` or `NO_HISTORY` rows do not supersede the later
logical-basket Q02 PASS rows, so neither anchor has a current Q02 repair.

The committed sign-aware coverage artifact
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships with zero uncovered. The preceding fresh
broader census also found a matching EA directory for every approved
cointegration Card. Creating a new Card or build would therefore duplicate
governed coverage, leaving the card-extraction and EA-build skill gates closed.

## Concrete existing sleeve

The selected fallback remains scan rank 46,
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. It trades `EURUSD.DWX` and
`EURJPY.DWX` on D1 with frozen beta `-0.236324029`; `USDJPY.DWX` is
conversion-history-only.

The scan evidence is deliberately adverse: DEV net Sharpe `0.473267`, OOS net
Sharpe `-0.118543`, OOS return `-1.026394%`, 17 OOS state changes, and a
`137.788`-D1-bar half-life. This is a one-shot falsification with no refit,
filter, parameter rescue, or portfolio feedback.

The sealed package remains unchanged:

| Binding | SHA-256 |
|---|---|
| Approved Card | `3b2ab7bc3c1dea90a86b936b1bf0e352f69e5c9532724f78512a18b987d35580` |
| MQ5 | `7eda37af63f23e00dcb930d71eb07afe4bef97e30875ec7f83bf5d234f668129` |
| EX5 | `d534838d2c9c993db151500c836f4e38088d961b2fe90e820defb0d31a34ae5b` |
| Basket manifest | `f7207377d90fb4fb3447425597f4ec4b2c2709838e0bd44cf4d851f70bb97725` |
| Logical setfile | `397181311f649d5416044d36d6aa70023390ea8b14f97cb75e7fb8818b144254` |

Card schema/ML lint passed with no ML hits. The logical backtest setfile still
uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; the Card
and EA remain structural, deterministic, D1, and free of adaptive refit, banned
indicators, grid, martingale, or learned components.

## Exact Q03 advancement

The canonical chain is now:

- Q02 `5d1cb89c-25ce-419c-869c-8c9f7afa10c1`: done / PASS.
- Q03 `3c74eb04-7e19-4aa0-8dcf-3f004faaa946`: active on T4, attempt zero,
  no verdict.
- Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e`: pending and not promoted ahead
  of Q03.

The resident T4 worker claimed Q03 at `2026-08-29T16:19:38Z` and started the
runner at `16:21:16Z`. Its terminal process began at `16:22:02Z` from the exact
factory path `D:/QM/mt5/T4/terminal64.exe`, using the work-item-owned tester
configuration under
`D:/QM/reports/work_items/3c74eb04-7e19-4aa0-8dcf-3f004faaa946/`.

Dispatch admission privatized all 324 required history files for
`EURUSD.DWX`, `EURJPY.DWX`, and `USDJPY.DWX` and returned
`PASS_PRIVATIZED`. The staged EX5 matched the sealed SHA-256 before launch.
The governed run covers `2018.07.02` through `2022.12.31`, uses model 4, two
runs, an effective 25-trade floor, and a 25,200-second timeout. Its 32 GB
commit reservation is classified as `multi_leg_fx_basket`.

This transition is the requested non-duplicate advancement of an existing FX
Card. Re-enqueueing Q02 or Q03, rewriting the already durable priority payload,
or promoting Q04 now would duplicate or bypass governed lineage.

## Paced-fleet capacity and safety

Five whole-host CPU observations were `87.806460%`, `72.479164%`,
`62.344833%`, `83.799338%`, and `70.899523%`. Average CPU was `75.465864%`
and maximum CPU was `87.806460%`, both below the explicit `97%` ceiling.

Worker-observed free physical RAM was `25.816 GB`, above the 12 GB
multisymbol floor. Commit headroom was `74.248 GB`, above the 48 GB
multisymbol floor. The target Q03 run itself legitimately owns the serialized
basket lane; there is no safe additional action until it reaches a canonical
terminal state.

`T_Live` was observed only through the path-aware read-only slot census and
excluded. Neither it nor AutoTrading was controlled. The portfolio gate,
`portfolio_admission`, `_kpi`, `_q08_contribution`, live/deploy manifests, and
all unrelated shared-worktree changes were untouched.

Machine-readable evidence:
`artifacts/qm5_20224_q03_active_handoff_20260829T163511Z_board_advisor.json`.

## Continuation condition

Allow Q03 to finish without interference. Only a canonical Q03 PASS permits
advancing the existing exact Q04 row. A Q03 economic failure retires this
one-shot sleeve; it does not authorize a refit, rescue filter, duplicate work
item, or manual terminal action.
