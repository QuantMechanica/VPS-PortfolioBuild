# QM5_20224 FX cointegration Q03 hard-CPU handoff

Date: 2026-08-30 UTC (`2026-08-30T00:05:08Z`); 02:05 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `bc654954d27eb17a80b6fb067b2284b9554754f1`

Status: the existing EURUSD/EURJPY fallback is now second in the serialized
basket queue, but the explicit 97% CPU ceiling bound before any queue or
terminal mutation.

## Outcome

No new Strategy Card or EA was created. The reputable-source result in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` selected only the two
published survivors from the original 66-pair scan, and the durable sign-aware
coverage audit accounts for all 66 relationships with zero uncovered. A fresh
filename census found 25 approved `cointegration`/`coint` Cards, 25 unique EA
IDs, and a matching EA directory for every ID. Creating another scan-derived
identity would duplicate governed work.

Neither preferred anchor needs Q02 repair:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Their historical per-leg `ONINIT` or `NO_HISTORY` attempts do not supersede
the later logical-basket Q02 PASS verdicts. The strategy-card extraction gate
therefore remains closed for lack of a non-duplicate qualifying relationship,
and the EA-build gate remains closed for lack of an approved unbuilt identity.

## Selected existing forex sleeve

The mission fallback remains scan rank 46,
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. It trades `EURUSD.DWX` and
`EURJPY.DWX` on D1 with frozen beta `-0.236324029`; `USDJPY.DWX` is
conversion-history-only. Its contract remains structural and deterministic,
with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. It has no
ML, adaptive refit, banned indicator, grid, martingale, or portfolio feedback.

The sealed package hashes remain unchanged:

| Binding | SHA-256 |
|---|---|
| Approved Card | `3b2ab7bc3c1dea90a86b936b1bf0e352f69e5c9532724f78512a18b987d35580` |
| MQ5 | `7eda37af63f23e00dcb930d71eb07afe4bef97e30875ec7f83bf5d234f668129` |
| EX5 | `d534838d2c9c993db151500c836f4e38088d961b2fe90e820defb0d31a34ae5b` |
| Basket manifest | `f7207377d90fb4fb3447425597f4ec4b2c2709838e0bd44cf4d851f70bb97725` |
| Logical backtest setfile | `397181311f649d5416044d36d6aa70023390ea8b14f97cb75e7fb8818b144254` |

Canonical lineage remains dependency-correct:

- Q02 `5d1cb89c-25ce-419c-869c-8c9f7afa10c1`: done / PASS.
- Q03 `3c74eb04-7e19-4aa0-8dcf-3f004faaa946`: pending, unclaimed,
  attempt zero, uniquely open, and already `priority_track=true`.
- Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e`: pending and deliberately not
  prioritized before Q03 PASS.

No active hold or supersede relation blocks the Q03 row.

## New serialized-lane progress

The lane has made material forward progress since the prior receipt. The
previously active `QM5_41079` row and the listed `QM5_41085`/`QM5_41086`
predecessors drained. The current exact order is:

| Lane position | EA / phase | Work item | State |
|---:|---|---|---|
| active | `QM5_20294` Q04 | `a34ee5cd-39b0-4655-9b02-1bf8e389f440` | active on T4 |
| pending 1 | `QM5_20206` Q04 | `ddad91a7-f1d1-4a06-a9bf-e82e1ec9558a` | priority, unclaimed |
| pending 2 | `QM5_20224` Q03 | `3c74eb04-7e19-4aa0-8dcf-3f004faaa946` | priority, unclaimed |

Forcing the FX row ahead of the active basket or the older downstream row
would violate the one-basket pacing contract. A second Q03 row would be a
duplicate, and advancing Q04 now would violate the selected sleeve's own
dependency.

## Binding capacity stop

Five fresh one-second whole-host CPU readings were `67.014613%`, `60.630581%`,
`70.901062%`, `66.253056%`, and `98.221967%`. Average CPU was `72.604256%`,
but maximum CPU was `98.221967%`. The mission's explicit ceiling binds when
either measure reaches 97%, so the maximum triggered the requested stop.

The supported terminal scan observed T4, T7, and T9 factory terminals and all
ten terminal-worker daemons, with no duplicate worker or orphaned factory
terminal. `T_Live` was observed only to exclude it and was not controlled.

Per the stop rule, no Card, EA, source, EX5, setfile, basket manifest, registry,
magic row, queue row, priority, claim, status, verdict, dispatch tick, tester,
reservation, terminal, or worker was created or changed. No smoke, compile, or
backtest was started.

Machine-readable evidence is in
`artifacts/qm5_20224_q03_hard_cpu_stop_20260830T000508Z_board_advisor.json`.

## Safety and continuation

The portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest, AutoTrading, and live/deploy manifests
were untouched. Existing unrelated shared-worktree changes were preserved.

After `QM5_20294` and `QM5_20206` reach canonical terminal states, take a
fresh five-sample CPU window. Advance only the existing exact QM5_20224 Q03 row
when both CPU measures are strictly below 97%; never enqueue a duplicate or
promote Q04 before Q03 PASS.
