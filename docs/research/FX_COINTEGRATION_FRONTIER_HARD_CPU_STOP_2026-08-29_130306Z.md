# FX cointegration frontier — rank-46 fallback / hard CPU ceiling stop

Date: 2026-08-29 UTC (`2026-08-29T13:03:06Z`); 15:03 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `70a15854621891c1d3b078a89bdbd4b537d0ba30`

Status: stopped at the explicit backtest CPU ceiling before Card, build,
compile, smoke, queue mutation, dispatch, or backtest. The next exact existing
FX successor was identified without creating a duplicate.

## Frontier reconciliation

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published v3
criterion selected only two relationships from the original 66-pair scan.
Both anchors are past Q02:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Their historical per-leg `ONINIT`/`NO_HISTORY`/invalid rows do not supersede
the later logical-basket Q02 PASS rows. Neither anchor has a current Q02 repair
to perform.

The committed sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships. A fresh broader census found 119 approved
Card files containing `cointegration` or `coint`, 119 unique allocated EA IDs,
and a matching EA directory for all 119. There is no approved unbuilt FX
cointegration Card. The card-extraction and EA-build skill gates therefore
remain closed, preventing a weaker or duplicate build.

## Rotated existing fallback

Several priority-tracked fallback rows have now reached terminal economic
verdicts:

| Scan rank | EA | Pair | Current frontier |
|---:|---|---|---|
| 40 | `QM5_20219` | USDJPY/NZDUSD | Q02 PASS, Q03 PASS, Q04 FAIL |
| 42 | `QM5_20220` | USDCAD/AUDJPY | Q02 PASS, Q03 PASS, Q04 FAIL |
| 44 | `QM5_20223` | GBPUSD/EURGBP | Q02 PASS, Q03 PASS, Q04 FAIL |
| 64 | `QM5_20255` | USDCHF/EURJPY | Q02 PASS, Q03 PASS, Q04 FAIL |

Ranks 41 `QM5_12765`, 43 `QM5_12766`, and 45 `QM5_12768` also already have
terminal Q04 failures. The highest-ranked nonterminal relationship is now
rank 46, `QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`.

`QM5_20224` is an OWNER-approved, fixed-beta D1 two-leg basket. It trades
`EURUSD.DWX` and `EURJPY.DWX`; `USDJPY.DWX` is conversion-history-only. The
frozen scan evidence is adverse (DEV net Sharpe `0.473`, OOS net Sharpe
`-0.119`, beta `-0.236324029`, half-life `137.788` D1 bars), so its contract
permits only a one-shot pipeline test with no refit, filter, or rescue.

Its canonical chain is:

- Q02 `5d1cb89c-25ce-419c-869c-8c9f7afa10c1`: PASS.
- Q03 `3c74eb04-7e19-4aa0-8dcf-3f004faaa946`: pending, unclaimed, attempt 0,
  and not priority-bound.
- Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e`: pending, unclaimed, attempt 0,
  and not priority-bound.

Q03 is the next dependency. A later run may advance that existing exact row in
place; it must not create another Q02 row or bypass Q03 by prioritizing Q04.

The sealed package remains structural and low-frequency. Its backtest setfile
uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; the basket
manifest names both traded legs plus the USDJPY conversion history. No ML,
adaptive refit, banned indicator, grid, martingale, or portfolio feedback is
present.

| Binding | SHA-256 |
|---|---|
| Approved Card | `3b2ab7bc3c1dea90a86b936b1bf0e352f69e5c9532724f78512a18b987d35580` |
| MQ5 | `7eda37af63f23e00dcb930d71eb07afe4bef97e30875ec7f83bf5d234f668129` |
| EX5 | `d534838d2c9c993db151500c836f4e38088d961b2fe90e820defb0d31a34ae5b` |
| Basket manifest | `f7207377d90fb4fb3447425597f4ec4b2c2709838e0bd44cf4d851f70bb97725` |
| Logical setfile | `397181311f649d5416044d36d6aa70023390ea8b14f97cb75e7fb8818b144254` |

## Binding capacity result

Five one-second whole-host CPU samples were `97.560092%`, `92.602277%`,
`92.393774%`, `98.540860%`, and `90.842297%`. Average CPU was `94.387860%`
and maximum CPU was `98.540860%`. The governed ceiling binds when either
measure reaches `97%`; the maximum triggered the requested hard stop.

The contemporaneous `farmctl mt5-slots` snapshot found factory terminals on
T1, T2, T3, T4, T5, and T9, seven live factory reservations, all ten terminal
worker daemons, and no duplicate worker. A bounded follow-up found ten active
work items and no active multisymbol/basket row. The absence of an active
basket does not override the binding host CPU ceiling.

T_Live and an unrelated FTMO terminal were observed only to exclude them.
Neither was controlled.

## Non-duplicate delta and safety boundary

This is new frontier state relative to the preceding rank-44 handoff: its
`QM5_20223` Q04 row has since failed, rank 40 has also terminalized, and rank
46 is now the first nonterminal existing relationship. No Card, EA, source,
EX5, setfile, basket manifest, registry, magic row, resolver, queue row,
priority, claim, status, verdict, reservation, worker, terminal, smoke, or
backtest was created or changed by this run.

The portfolio gate, `portfolio_admission`, `_kpi`, `_q08_contribution`,
T_Live, AutoTrading, and live/deploy manifests were untouched. Existing
unrelated shared-worktree changes were preserved and excluded from this
commit.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260829T130306Z_board_advisor.json`.

## Continuation condition

Take a fresh five-sample CPU window. Only if both average and maximum are
strictly below 97%, re-read `QM5_20224` and advance its existing exact Q03 row
in place if it remains pending, unclaimed, attempt zero, and unprioritized.
Do not enqueue a duplicate.
