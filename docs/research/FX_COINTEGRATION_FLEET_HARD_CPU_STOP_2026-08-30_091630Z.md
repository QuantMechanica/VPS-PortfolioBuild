# FX cointegration fleet — hard CPU ceiling stop

Date: 2026-08-30 UTC (`2026-08-30T09:16:30.0142976Z`); 11:16
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `13d39b4703fc2a37e10ede1251a86d40de9b1621`

Status: stopped at the explicit backtest CPU ceiling before any claim, queue
mutation, dispatch, compile, smoke test, or backtest.

## Governed frontier decision

The reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen v3 scan
tested all 66 relationships and selected only two pairs under the published
criterion (positive DEV Sharpe, OOS net Sharpe above 0.8, and at least four
OOS trades):

| EA | Pair | Canonical state |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Both are built and neither remains blocked at Q02 by `ONINIT` or
`NO_HISTORY`. The committed sign-aware coverage receipt
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships, and the latest committed approved-card
census has no unbuilt FX-cointegration Card. Creating a new Card would
therefore duplicate governed coverage or weaken the reputable-source
criterion. The Strategy Card extraction and EA build gates stayed closed.

## Existing forex fallback

The dependency-correct fallback remains the existing rank-46 D1 basket
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`:

- Q02 `5d1cb89c-25ce-419c-869c-8c9f7afa10c1`: done / PASS.
- Q03 `3c74eb04-7e19-4aa0-8dcf-3f004faaa946`: pending, unclaimed,
  attempt zero.
- Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e`: pending and deliberately not
  advanced ahead of Q03.

The active serialized-basket predecessor is still `QM5_20294` Q05 work item
`c56df942-e7aa-4c7d-b855-402de608352f` on T10. Its governed tester process was
present and its row remained active. The exact QM5_20224 successor was not
duplicated, rewritten, claimed, or dispatched.

The sealed package remains the structural, low-frequency fixed-beta basket
described in
`artifacts/qm5_20224_q03_paced_predecessor_handoff_20260830T080303Z_board_advisor.json`:
two traded FX legs, one conversion-history-only symbol, and a D1 logical
backtest setfile with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No adaptive refit, machine learning, banned indicator,
grid, martingale, or portfolio feedback was introduced.

## Binding capacity result

Five fresh one-second whole-host CPU samples were `99.023541%`, `92.306353%`,
`97.954559%`, `92.202304%`, and `82.157557%`. Average CPU was `92.728863%`
and maximum CPU was `99.023541%`. The mission ceiling binds when either
measure reaches 97%; the maximum triggered the stop.

At the same observation boundary, the farm contained nine active rows. The
supported path-anchored terminal scan found factory testers on T1, T2, T4,
T9, and T10, six active reservations, all ten terminal workers alive, no
duplicate worker, and no orphaned factory terminal. T_Live and the unrelated
FTMO terminal were observed only to exclude them and were not controlled.

## Non-duplicate delta

Relative to the preceding QM5_20224 receipt at `2026-08-30T08:03:03Z`, the
visible factory tester roster rotated from T3/T6/T7/T9/T10 to
T1/T2/T4/T9/T10. Two fresh Q02 jobs were active on T1 and T4, while the same
healthy T10 basket predecessor continued to own the serialized lane. The
fresh capacity maximum rose from `79.048114%` to `99.023541%` and became
binding. This changed roster and capacity state is new evidence; no duplicate
strategy or work item was created.

## Safety boundary and continuation

No Card, EA, EX5, setfile, basket manifest, registry, magic row, queue row,
payload, priority, claim, status, verdict, reservation, worker, terminal,
compile, smoke test, or backtest was created or changed. The portfolio gate,
`portfolio_admission`, portfolio `_kpi`, `_q08_contribution`, T_Live manifest,
AutoTrading, and all live/deploy manifests were untouched. Unrelated shared
worktree changes were preserved and excluded from this commit.

Machine-readable evidence is in
`artifacts/fx_cointegration_fleet_hard_cpu_stop_20260830T091630Z_board_advisor.json`.

On the next paced wake, take a fresh five-sample whole-host CPU window. Only
when both average and maximum are strictly below 97%, and after the active
QM5_20294 basket reaches a canonical terminal state, may the resident paced
worker advance the unique existing QM5_20224 Q03 row. Never enqueue a
duplicate or promote Q04 before Q03 PASS.
