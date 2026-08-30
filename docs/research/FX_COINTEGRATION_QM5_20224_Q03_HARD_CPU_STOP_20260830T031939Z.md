# QM5_20224 FX cointegration Q03 hard-CPU stop

Date: 2026-08-30 UTC (`2026-08-30T03:19:39Z`); 05:19 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `51501e6c05ff77a0e98249b8f0423027edb02994`

Status: the existing EURUSD/EURJPY fallback has reached the head of the
pending basket lane, but the explicit 97% backtest CPU ceiling bound before
any queue, worker, terminal, compile, smoke, or backtest mutation.

## Frontier decision

The controlling reputable-source result remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3
criterion selected only two relationships from the original 66-pair scan,
and both are already built with later logical-basket Q02 PASS evidence:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Historical per-leg `ONINIT`, `NO_HISTORY`, or invalid attempts do not
supersede those later logical-basket PASS rows. Neither anchor has a current
Q02 repair.

The committed sign-aware audit accounts for all 66 relationships with zero
uncovered. A fresh approved-card filename census found 25
`cointegration`/`coint` Cards, 25 unique EA IDs, and a matching EA directory
for every ID. The card-extraction gate is therefore closed for lack of a
non-duplicate scan-qualified pair, and the EA-build gate is closed for lack
of an approved unbuilt identity.

## Existing forex fallback

The valid fallback remains scan rank 46,
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. It trades `EURUSD.DWX` and
`EURJPY.DWX` on D1 with frozen beta `-0.236324029`; `USDJPY.DWX` is
conversion-history-only. Its sealed contract is structural and
low-frequency, with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. It contains no ML, adaptive refit, banned indicator,
grid, martingale, or portfolio feedback.

The package remains hash-stable:

| Binding | SHA-256 |
|---|---|
| Approved Card | `3b2ab7bc3c1dea90a86b936b1bf0e352f69e5c9532724f78512a18b987d35580` |
| MQ5 | `7eda37af63f23e00dcb930d71eb07afe4bef97e30875ec7f83bf5d234f668129` |
| EX5 | `d534838d2c9c993db151500c836f4e38088d961b2fe90e820defb0d31a34ae5b` |
| Basket manifest | `f7207377d90fb4fb3447425597f4ec4b2c2709838e0bd44cf4d851f70bb97725` |
| Logical backtest setfile | `397181311f649d5416044d36d6aa70023390ea8b14f97cb75e7fb8818b144254` |

Canonical lineage is dependency-correct:

- Q02 `5d1cb89c-25ce-419c-869c-8c9f7afa10c1`: done / PASS.
- Q03 `3c74eb04-7e19-4aa0-8dcf-3f004faaa946`: pending, unclaimed,
  attempt zero, unique, and already `priority_track=true`. Its retained
  `EVIDENCE_UNAVAILABLE:active_timeout:NO_FORWARD_PROGRESS` marker records
  the earlier false-progress recovery; it is not a terminal verdict.
- Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e`: pending and deliberately not
  prioritized before Q03 PASS.

No active hold or supersede relation blocks the exact Q03 row.

## New serialized-lane state

This is material forward progress from the preceding committed receipt, where
`QM5_20224` was second behind pending `QM5_20206` Q04 and active
`QM5_20294` Q04. The current manifest-backed basket order is:

| Lane position | EA / phase | Work item | State |
|---:|---|---|---|
| active | `QM5_20294` Q05 | `c56df942-e7aa-4c7d-b855-402de608352f` | active on T10 |
| pending 1 | `QM5_20224` Q03 | `3c74eb04-7e19-4aa0-8dcf-3f004faaa946` | priority, unclaimed |

The selected FX row is now the first pending basket, with canonical global
pending rank 1824 at observation time. The farm had 8,310 claim-order pending
rows. Letting the resident paced worker claim this existing identity after the
active basket clears is the only non-duplicate continuation; forcing a second
basket, inserting another Q02/Q03 row, or promoting Q04 now would violate the
pacing or dependency contracts.

## Binding CPU stop

Five fresh one-second whole-host CPU readings were `94.337019%`,
`91.212659%`, `97.471474%`, `95.900307%`, and `96.781074%`. Average CPU was
`95.140507%` and maximum CPU was `97.471474%`. The mission ceiling binds when
either measure reaches 97%, so the maximum triggered the required stop.

The supported terminal scan at `2026-08-30T03:17:53Z` observed factory
terminals T3, T5, T9, and T10 plus all ten resident terminal-worker daemons,
with no duplicate worker or orphaned factory process. T_Live and an unrelated
FTMO terminal were observed only to exclude them and were not controlled.

Per the stop rule, no Card, EA, EX5, setfile, basket manifest, registry, magic
row, queue row, priority, claim, status, verdict, reservation, worker, or
terminal was created or changed. No dispatch tick, compile, smoke, or
backtest was started.

Machine-readable evidence is in
`artifacts/qm5_20224_q03_hard_cpu_stop_20260830T031939Z_board_advisor.json`.

## Safety and continuation

The portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest, AutoTrading, and live/deploy manifests
were untouched. Existing unrelated shared-worktree changes were preserved.

After active `QM5_20294` Q05 reaches a canonical terminal state, take a fresh
five-sample CPU window. Only when both average and maximum are strictly below
97% may the resident paced lane claim the existing exact `QM5_20224` Q03 row.
Never enqueue a duplicate or promote Q04 before Q03 PASS.
