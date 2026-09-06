# FX cointegration QM5_12507 governed RAM-ceiling stop

Recorded: 2026-09-06T05:21:05Z (07:21 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `5341ebc636dd06cb387c37a6759481ad11015ec3`

## Outcome

The frozen 66-pair FX scan has no reputable unbuilt identity, and both preferred
anchors remain beyond Q02. The concrete existing-card fallback is the
`QM5_12507` EURUSD/GBPUSD H1 logical cointegration basket. Its one canonical
Q02 row is already pending, unclaimed, attempt zero, priority-bound, and
unheld. A duplicate enqueue or priority rewrite would not advance it.

The explicit CPU preflight cleared: five one-second whole-host samples were
`78.236%`, `76.332%`, `77.345%`, `71.097%`, and `77.265%` (average `76.055%`,
maximum `78.236%`) against the `97%` hard ceiling. The resident workers'
governed long-run RAM admission did not clear. The active drain-window head
requires `51.0 GiB` available (`44.0 GiB` reservation plus `14.0 GiB` floor,
net of releasable short-run memory), while a fresh host reading exposed only
`30.658 GiB` free of `63.120 GiB`. The drain-window state therefore remains
not winnable, and lower-ranked multisymbol baskets must not bypass it.

No card, EA, registry, setfile, manifest, work-item payload, terminal, or tester
was changed. The standard `dispatch-tick` was run once after the CPU-clear
sample and correctly made no direct work-item claims because resident terminal
workers own UUID claims; manually claiming around that ownership would violate
the paced-fleet contract.

## Frontier and anchor reconciliation

The controlling study is
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its original positive-
beta threshold selected only the two already-built baskets:

- `QM5_12532` AUDUSD/NZDUSD: logical Q02 PASS, Q04 PASS, later Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY: logical Q02 PASS, later Q04 FAIL.

Neither anchor has a current Q02 `ONINIT` or `NO_HISTORY` blocker. The durable
sign-aware expansion and subsequent next-best cards are likewise already
mechanized; minting another identity from the fixed scan would duplicate
governed coverage.

## Preserved continuation

| Field | Value |
| --- | --- |
| EA | `QM5_12507_pair-coint-z` |
| Pair | `EURUSD.DWX` / `GBPUSD.DWX` |
| Logical symbol | `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` |
| Work item | `547c4fd3-f3fd-4c59-b9dc-654e96521251` |
| Phase | Q02 |
| State | pending, unclaimed, attempt 0, no verdict, no active hold |
| Queue contract | `priority_track=true` |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |
| Manifest | `framework/EAs/QM5_12507_pair-coint-z/basket_manifest.json` |
| Setfile | `framework/EAs/QM5_12507_pair-coint-z/sets/QM5_12507_pair-coint-z_QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1_H1_backtest.set` |

The canonical claim-order snapshot placed this row at rank 143 of 9,041
pending claim candidates. Higher-ranked long-run FX basket rows remain behind
the same governed RAM drain window, so changing this row's timestamp or adding
another successor would be both ineffective and non-canonical.

## Safety and resume contract

No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
`T_Live` manifest, live/deploy, or AutoTrading surface was touched. `T_Live`
was only observed as excluded by the supported slot census.

On the next paced wake, re-read the exact `QM5_12507` row and the active
drain-window head. Continue only through the resident worker's canonical claim
path after both CPU and RAM admission clear. Never append a second logical Q02
row.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_ram_ceiling_stop_20260906T052105Z_board_advisor.json`.
