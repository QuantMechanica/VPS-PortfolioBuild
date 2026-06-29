# QM5_12768 Priority Q02 Payload Repair

Scope: branch `agents/board-advisor`; no `T_Live`, AutoTrading, or portfolio
gate files touched.

## Decision

The controlling FX cointegration artifact remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its strict survivors,
`QM5_12532` and `QM5_12533`, already have logical-basket Q02 PASS rows in
`D:/QM/strategy_farm/state/farm_state.sqlite`. The currently carded FX
cointegration frontier through `QM5_12768` is already built, so this pass used
the mission fallback: advance an existing forex card without adding a duplicate
work item.

Chosen basket: `QM5_12768` USDJPY/EURJPY, a rank-21 exploratory tail candidate
from the same 66-pair scan rerun. Its pending logical-basket Q02 row existed but
had only the minimal `record_build_result.auto_q02` payload.

## Validation

Build validation before queue mutation:

```text
powershell -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12768_edgelab-usdjpy-eurjpy-cointegration -RepoRoot C:/QM/repo -SkipCompile
```

Result:

| Field | Value |
|---|---|
| Report | `D:/QM/reports/framework/21/build_check_20260629_074622.json` |
| Result | `PASS` |
| Failures | `0` |
| Warnings | `16` existing shared include advisories |
| EX5 SHA256 | `78D1D5AB9D4CF59E116D6982818C795BE3A903331091A2EF33A0F3FC5241149C` |

## Queue Mutation

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12768_priority_payload_20260629_074741Z.sqlite`

Updated the existing pending Q02 row in place:

| Field | Value |
|---|---|
| Work item | `93909a80-8ce6-4e95-be28-889f8dc17a7d` |
| EA | `QM5_12768` |
| Symbol | `QM5_12768_USDJPY_EURJPY_COINTEGRATION_D1` |
| Setfile | `framework/EAs/QM5_12768_edgelab-usdjpy-eurjpy-cointegration/sets/QM5_12768_edgelab-usdjpy-eurjpy-cointegration_QM5_12768_USDJPY_EURJPY_COINTEGRATION_D1_D1_backtest.set` |
| Host symbol/timeframe | `USDJPY.DWX`, `D1` |
| Basket symbols | `USDJPY.DWX`, `EURJPY.DWX` |
| Payload scope | `portfolio_scope=basket` |
| Risk | `RISK_FIXED=1000`, `tester_currency=USD`, `tester_deposit=100000` |
| Timeout | `120` minutes |
| Priority | `priority_track=true` |
| Status immediately after update | `pending`, `claimed_by=NULL` |

Duplicate guard after update: exactly one pending/active Q02 row for
`QM5_12768` / `QM5_12768_USDJPY_EURJPY_COINTEGRATION_D1`.

Follow-up verification after the paced worker loop: the same row was briefly
claimed by `T5` at `2026-06-29T07:48:03+00:00`, then returned to `pending`,
`claimed_by=NULL`, at `2026-06-29T07:49:19+00:00` after the worker launch
retry. The repaired payload remained intact and the duplicate guard remained
exactly one pending/active logical Q02 row.

No manual MT5 launch was created. Execution is owned by the paced worker under
the backtest CPU-ceiling discipline.
