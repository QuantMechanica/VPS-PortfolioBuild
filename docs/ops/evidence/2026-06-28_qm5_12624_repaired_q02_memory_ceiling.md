# QM5_12624 Repaired Q02 Memory Ceiling - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

The strict 66-pair FX cointegration survivors from
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` are already built and no
longer Q02-blocked:

| Pair | EA | Logical-basket Q02 |
|---|---|---|
| AUDUSD/NZDUSD | `QM5_12532` | `PASS` (`e4890d77-b865-4a48-b946-315faefca920`) |
| EURJPY/GBPJPY | `QM5_12533` | `PASS` (`76cb11ee-7e9d-4d75-be9d-626c205bca62`) |

No allocated unbuilt FX-cointegration registry row exists after the already
built exploratory baskets through `QM5_12751`; `12752+` are WTI sleeves. I used
the fallback path and triaged the existing next-best FX basket `QM5_12624`
EURJPY/AUDJPY after its repaired Q02 row completed.

## Latest Q02 Evidence

| Field | Value |
|---|---|
| Work item | `f346f9e9-7dc9-4cff-be60-4dec96784e77` |
| EA | `QM5_12624` |
| Pair | `EURJPY.DWX` / `AUDJPY.DWX` |
| Logical symbol | `QM5_12624_EURJPY_AUDJPY_COINTEGRATION_D1` |
| Phase | `Q02` |
| Status / verdict | `done` / `INFRA_FAIL` |
| Evidence | `D:/QM/reports/work_items/f346f9e9-7dc9-4cff-be60-4dec96784e77/QM5_12624/20260628_154905/summary.json` |
| Result | `FAIL` |
| Reason classes | `REPORT_MISSING`, `METATESTER_HUNG`, `NO_HISTORY`, `INCOMPLETE_RUNS` |
| OnInit failure | `false` |
| Risk payload | `tester_currency=JPY`, `tester_deposit=15000000`, `risk_fixed=150000` |

The repaired row used the news-off fixed-risk setfile and durable basket
priority payload from the prior commits. The tester reached real EURJPY/AUDJPY
order execution, then failed in the tester/report layer. The log tail includes:

- `64 Mb not available`
- `not enough available memory, 28501 Mb used, 839 Mb available, maximal available block is 59 Mb`
- `EURJPY.DWX,Daily: 0 ticks, 0 bars generated`

This repeats the earlier `REPORT_MISSING` / `METATESTER_HUNG` pattern after a
valid EA start and real basket trading. The added `NO_HISTORY` class is a
post-memory-exhaustion artifact from the blank final report, not an OnInit or
missing-symbol preflight failure.

## Queue Decision

No replacement Q02 row was inserted. This satisfies the mission stop condition:
the repaired basket hit the backtest CPU/memory/report-export ceiling, so blind
requeueing is expected to burn another slot without producing a usable gate
verdict.

Useful next action before any future `QM5_12624` attempt: fix or reduce the
tester memory/report-export path for heavy JPY-cross basket Q02 runs.
