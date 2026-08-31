# QM5_20246 FX cointegration Q03 run-2 active / hard-CPU stop

Date: 2026-08-31 UTC (`2026-08-31T09:57:15Z`); 11:57 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `6bda905d5deb9e3582b2d1c45767c6c2b4e2fe1c`

Status: the unique existing forex fallback advanced from priority-pending to
an authenticated governed Q03 run on T6. Run 1 completed and run 2 is making
forward progress under the same work-item identity. A final five-sample host
window averaged `98.656243%` and peaked at `99.708235%`, so the explicit 97%
backtest CPU ceiling stopped this wake before any further queue, terminal, or
pipeline action.

## Governed frontier decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen v3 study
tested all 66 FX relationships and published only two strict survivors. Both
anchors have logical-basket Q02 PASS and no current Q02 `ONINIT` or
`NO_HISTORY` repair:

| EA | Pair | Canonical chain |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

The durable sign-aware audit already accounts for all 66 relationships. A
fresh approved-card census found 120 cointegration/coint Cards, 120 unique EA
IDs, 120 matching EA directories, and zero unbuilt IDs. Creating a Card, EA,
basket manifest, magic allocation, or Q02 row would therefore duplicate
governed work. The existing-forex fallback remains the only valid mission
path.

## Existing forex fallback advanced

The selected concrete pair is frozen-scan rank 60,
`QM5_20246_USDJPY_EURGBP_COINTEGRATION_D1`. It trades `USDJPY.DWX` and
`EURGBP.DWX`; `GBPUSD.DWX` and `EURUSD.DWX` are conversion-history-only. The
sealed implementation remains structural, fixed-beta, D1, low-frequency, and
free of learned models, adaptive refits, banned indicators, grid, and
martingale. Card schema/ML lint passed with no missing sections or ML hits.

The logical backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Package hashes are unchanged:

| Binding | SHA-256 |
|---|---|
| Approved Card | `02dc1de067052e3bf4570f9a8ad65df75c0a0463a18b2bef897fa2149f943e0f` |
| MQ5 | `4ee9db9b746599413e00af5f01583252bd8ec9b8440d0509ca25207ea483ec6a` |
| EX5 | `f2384173fdd41e914b48b3098467c9b02a7648494f937f5f027f4e8b45aa6eab` |
| Basket manifest | `63b4084a8522588bb3c3629b12430b4b27efd133472ea24dc5adafff250a66f5` |
| Logical setfile (checkout bytes) | `4a4f23b23b969e3b6b189806be924a901f341212167a3500f590a7f81a1c4416` |

The exact canonical chain is:

| Phase | Work item | State |
|---|---|---|
| Q02 | `d8619249-7764-4d80-a714-6b7922b73b4b` | done / PASS |
| Q03 | `46c97cb3-45f9-475d-8e6b-aa7bdd40df0e` | active, attempt zero, claimed by T6 |
| Q04 | `1a269ff4-cbef-429b-afa4-47a3cc692916` | pending and untouched behind Q03 |

No work-item identity, priority payload, claim, status, or attempt was created
or changed by this wake. The resident paced worker made the dependency-correct
claim at `2026-08-31T09:14:04Z` from the prior in-place priority handoff.

## Authenticated two-run progress

Q03 invokes two identical D1 runs from 2018-07-02 through 2022-12-31. Run 1
finished normally and emitted a 319,010-byte MT5 report plus a 615,182-byte
structured event log. The log contains 68 accepted host entries, 68 accepted
basket-leg orders, a final `DEINIT` at simulated `2022-12-30T23:54:59`, and
zero case-insensitive `ONINIT`/`NO_HISTORY` markers.

The runner then launched run 2 under the same Q03 claim. Two bounded
checkpoints prove forward progress:

| Sample UTC | Simulated event time | Event | Log bytes | Metatester CPU seconds |
|---|---|---|---:|---:|
| 09:55:40 | 2019-01-29 00:01:01 | `EQUITY_SNAPSHOT` | 75,763 | 143.859 |
| 09:56:25 | 2019-05-10 00:04:04 | `EQUITY_SNAPSHOT` | 106,735 | 185.078 |

Simulated time, log size, and metatester CPU all advanced. This is not an
initialization/history stall and no second basket was launched.

## Binding CPU stop

The final five one-second whole-host CPU samples were `96.878456%`,
`97.953542%`, `99.326276%`, `99.414708%`, and `99.708235%`. Average CPU was
`98.656243%` and maximum CPU was `99.708235%`; both breach the strictly-below
97% admission rule. Free D: space was `91.467 GiB`, so CPU alone bound.

The supported slot snapshot observed exact-path factory terminals T1, T3, T4,
T6, and T10, all ten terminal workers, no duplicate worker, and no orphaned
factory process. T6 owned this exact Q03 run. `T_Live` and the unrelated FTMO
terminal were observed only for attribution and were not controlled.

Per the mission stop condition, no new Card, EA, manifest, setfile, registry
row, magic row, queue row, priority, dispatch, compile, smoke run, tester
launch, reservation, terminal control, or downstream phase action followed.
The already-active resident run was not interrupted.

## Safety and continuation

The portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest and terminal, AutoTrading, and all
live/deploy manifests were untouched. Concurrent unrelated worktree changes
were preserved and excluded from this commit.

Machine-readable evidence is
`artifacts/qm5_20246_q03_run2_active_hard_cpu_stop_20260831T095715Z_board_advisor.json`.

On the next paced wake, reconcile this exact Q03 row first. If it has a
terminal PASS, the already-existing Q04 row is the only valid successor; if it
has a terminal economic or cadence failure, retire the sleeve without a beta
refit or rescue filter. If Q03 remains active, do not start another basket.
Any new action still requires a fresh five-sample CPU window with both average
and maximum strictly below 97%.
