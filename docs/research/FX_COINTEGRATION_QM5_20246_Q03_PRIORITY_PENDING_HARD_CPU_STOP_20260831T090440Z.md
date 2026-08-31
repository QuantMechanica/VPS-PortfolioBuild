# QM5_20246 FX cointegration Q03 priority-pending hard CPU stop

Date: 2026-08-31 UTC (`2026-08-31T09:04:40Z`); 11:04 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `8c95a219e069e32a8c10a4eee755f2f9cde8bbd2`

Status: the frozen 66-pair scan still has no unbuilt relationship, both
preferred anchors remain beyond Q02, and the unique rank-60 USDJPY/EURGBP
fallback remains queued exactly once at Q03 with its prior priority binding.
A fresh five-sample host window averaged `99.785616%` and peaked at `100%`, so
the mission's explicit 97% CPU ceiling stopped this wake before any queue,
worker, terminal, compile, smoke, or tester mutation.

## Frontier and anchor reconciliation

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 study tested all
66 FX relationships and admitted only `QM5_12533` EURJPY/GBPJPY and
`QM5_12532` AUDUSD/NZDUSD under the published positive-DEV, OOS-net-Sharpe
above 0.8, and at-least-four-trades criterion.

Neither anchor has the Q02 infrastructure blocker named by the mission:

| EA | Pair | Canonical chain |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

The durable sign-aware audit still accounts for all 66 relationships. A fresh
content-based census found 120 approved cointegration/coint card identities,
120 matching EA directories, and no unbuilt identity. Creating a Card, EA,
basket manifest, magic allocation, or Q02 row would therefore duplicate
governed work. The card-extraction and EA-build skill gates remained closed.

## Existing forex fallback remains dependency-correct

The selected concrete pair remains frozen-scan rank 60,
`QM5_20246_USDJPY_EURGBP_COINTEGRATION_D1`. It trades `USDJPY.DWX` and
`EURGBP.DWX`; `GBPUSD.DWX` and `EURUSD.DWX` are conversion-history-only
dependencies. The sealed implementation remains structural fixed-beta D1
residual reversion, low-frequency, and free of learned models, adaptive refits,
grid, martingale, or banned indicators.

Its exact current chain is:

| Phase | Work item | State |
|---|---|---|
| Q02 | `d8619249-7764-4d80-a714-6b7922b73b4b` | done / PASS |
| Q03 | `46c97cb3-45f9-475d-8e6b-aa7bdd40df0e` | pending, priority-bound, unclaimed, attempt 0 |
| Q04 | `1a269ff4-cbef-429b-afa4-47a3cc692916` | pending and deliberately untouched behind Q03 |

The Q03 row is still unique and carries
`priority_reason=board_advisor_fx_fallback_rank60_q03_after_q02_pass`. The
package hashes are unchanged from the priority handoff: card
`02dc1de067052e3bf4570f9a8ad65df75c0a0463a18b2bef897fa2149f943e0f`,
MQ5 `4ee9db9b746599413e00af5f01583252bd8ec9b8440d0509ca25207ea483ec6a`,
EX5 `f2384173fdd41e914b48b3098467c9b02a7648494f937f5f027f4e8b45aa6eab`,
and basket manifest
`63b4084a8522588bb3c3629b12430b4b27efd133472ea24dc5adafff250a66f5`.
The logical backtest contract remains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`.

## Binding CPU result

The five one-second whole-host samples were `99.806456%`, `100%`,
`99.316620%`, `100%`, and `99.805004%`. Average CPU was `99.785616%` and
maximum CPU was `100%`; both violate the strictly-below-97% admission rule.
Free D: capacity was `97.669 GiB`, so CPU alone bound.

The supported slot scan at `09:03:21Z` observed factory terminals T1, T3, T4,
T7, T8, and T10, with no duplicate worker or orphaned factory-terminal
process. The paced farm continued claiming unrelated work during the
read-only observation; a later database snapshot contained eight active rows.
This wake did not stop, start, reserve, release, claim, or dispatch any of
them. `T_Live` and the unrelated FTMO terminal were observed only for process
attribution and were not controlled.

## Stop and continuation contract

No Card, EA, EX5, setfile, basket manifest, registry row, magic row, queue row,
payload, priority, claim, status, verdict, audit event, dispatch tick, compile,
smoke test, or backtest was created or mutated. The portfolio gate and its
admission/KPI/Q08-contribution surfaces, the T_Live manifest and terminal,
AutoTrading, and all live/deploy manifests were untouched. Pre-existing
unrelated worktree changes were preserved.

On a later paced wake, first take a fresh five-sample CPU window. Only when
both average and maximum are strictly below 97% should the resident paced
worker claim exact priority-bound Q03 row
`46c97cb3-45f9-475d-8e6b-aa7bdd40df0e`. Do not create a duplicate Q02/Q03
row, manually force another basket, or advance Q04 before authenticated Q03
PASS.

Machine-readable evidence is
`artifacts/qm5_20246_q03_priority_pending_hard_cpu_stop_20260831T090440Z_board_advisor.json`.
