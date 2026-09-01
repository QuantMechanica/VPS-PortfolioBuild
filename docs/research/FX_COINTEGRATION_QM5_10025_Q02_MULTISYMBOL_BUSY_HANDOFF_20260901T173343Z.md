# FX basket fleet — QM5_10025 Q02 serialized-lane handoff

Date: 2026-09-01 UTC (`2026-09-01T17:33:43.3122311Z`); 19:33
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `101c5d45928e09c9f126277cd7d5d2dfa730dce4`

Status: the frozen FX cointegration frontier has no unbuilt identity, both
requested anchors remain past Q02, and the selected existing FX basket remains
queued exactly once. The previous multisymbol predecessor completed Q03 PASS
and a new FX cointegration successor is advancing in the single serialized
basket lane. CPU is currently below the hard ceiling, but concurrent basket
admission remains closed.

## Frontier and anchor decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen v3 scan
tested all 66 FX relationships and admitted only the two positive DEV/OOS
survivors. The durable sign-aware coverage census in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships: 66 covered and zero uncovered. A new
scan-derived Card, EA, registry identity, basket manifest, or Q02 row would be
duplicate work or would weaken the source's published admission criterion.

The preferred anchors do not have the Q02 infrastructure blocker named by the
mission:

| EA | Relationship | Canonical state |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS; Q04 FAIL |

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. The new-card
extraction and new-EA build gates therefore remain closed.

## Existing-card fallback remains ready exactly once

The non-duplicate fallback remains `QM5_10025_rw-fx-broad-pairs`, an approved,
built H4 market-neutral FX sleeve sourced to Robot Wealth's FX Broad Pairs
Trading material. At each monthly formation event, a real FX host selects one
partner from seven registered majors, freezes the OLS hedge ratio for the
month, and trades one beta-weighted two-leg package. It is structural and
contains no machine learning, banned indicator, grid, martingale, or adaptive
intramonth refit.

Its selected USDJPY-host Q02 row is unchanged:

| Field | Value |
| --- | --- |
| Work item | `050dd2ea-e9d0-475f-b5ad-40c2206867ff` |
| Host / timeframe | `USDJPY.DWX` / H4 |
| State | pending, unclaimed, attempt 0, no verdict |
| Open exact rows | 1 |
| `priority_track` | `true` |
| Priority reason | `board_advisor_fx_existing_market_neutral_q02_after_exhausted_66_pair_frontier` |
| Payload SHA-256 | `bca99985bb4989d96c0537c81640333870793f2958843797d5357fb6c319a2f8` |

The sealed MQ5, EX5, basket manifest, and USDJPY backtest setfile remain
hash-stable. The setfile still binds `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The exact selected row remains open once, so no duplicate
enqueue or repeated priority mutation was attempted.

## The serialized basket lane advanced materially

The predecessor recorded at 79 percent in the prior receipt, work item
`c8edc2dc-43f4-4896-a5b0-9047815b0564` (`QM5_20206_XAU_XAG_MOMIVOL_D1`
Q03), reached canonical `done/PASS` at `2026-09-01T16:48:10Z`.

The farm then admitted the next existing FX cointegration sleeve into that
same lane. T7 now owns work item
`eb3993b7-e477-4236-9cb6-385c1a8e7392`, `QM5_20203` EURUSD/AUDJPY Q03. Run 1
of 2 advanced to 43 percent at `2026-09-01T17:30:53.824Z`. The terminal and
tester were responsive and accumulated 0.438 and 4.922 CPU seconds,
respectively, over a fresh five-second interval. This is a healthy active run,
not a stale claim or infrastructure blocker.

The canonical active-row snapshot contained seven `OPT_CENSUS` rows and this
one Q03 row. The paced launch limit remains one multisymbol basket. Claiming
QM5_10025 concurrently or manually launching another tester would violate that
serialized admission contract.

## Capacity decision

The final five one-second whole-host CPU samples were `94.535659%`,
`85.015076%`, `86.064562%`, `86.837665%`, and `87.599049%`. Average CPU was
`88.010402%` and maximum CPU was `94.535659%`; both are below the explicit 97
percent ceiling. CPU therefore does not bind this handoff. The occupied,
healthy multisymbol lane does.

The non-duplicate continuation is precise: wait for QM5_20203 to reach a
canonical terminal state, then require a fresh five-sample CPU window with
both average and maximum strictly below 97 percent. Only then may a resident
worker claim the existing QM5_10025 USDJPY Q02 row. Do not enqueue a second
row or manually launch a second basket tester.

Machine-readable evidence is
`artifacts/fx_cointegration_qm5_10025_q02_multisymbol_busy_20260901T173343Z_board_advisor.json`.

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, Q08 state, T_Live manifest or terminal, AutoTrading
state, live setfile, or deploy manifest was touched. Concurrent unrelated
worktree changes were preserved and excluded from this handoff.
