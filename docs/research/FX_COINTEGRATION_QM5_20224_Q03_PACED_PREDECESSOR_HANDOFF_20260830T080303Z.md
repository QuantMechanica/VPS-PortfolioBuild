# QM5_20224 FX cointegration Q03 paced-predecessor handoff

Date: 2026-08-30 UTC (`2026-08-30T08:03:03Z`); 10:03 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `196cbfebe18e6f4dca4959cfc43c932b5690c288`

Status: the preceding hard CPU ceiling has cleared. The exact existing FX
successor is already first in the governed pending-basket order, but the
single basket lane remains occupied by a healthy Q05 predecessor. No duplicate
Card, EA, work item, priority mutation, dispatch, or terminal action was
performed.

## Frontier decision

The reputable-source result in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` selected only two strict
survivors from the frozen 66-pair scan. Both anchors are built and past Q02:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Their later logical-basket Q02 PASS rows supersede the historical physical-leg
`ONINIT`, `NO_HISTORY`, and invalid attempts. The committed sign-aware audit
accounts for all 66 relationships, and the latest committed census found no
approved cointegration Card without a matching EA directory. Creating a new
Card or build would therefore duplicate governed coverage or weaken the
reputable-source criterion.

## Selected existing forex successor

The dependency-correct fallback remains frozen-scan rank 46,
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. It trades `EURUSD.DWX` and
`EURJPY.DWX` on D1 with fixed beta `-0.236324029`; `USDJPY.DWX` is
conversion-history-only.

The package is unchanged, structural, deterministic, and low-frequency. Its
logical backtest setfile seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Card schema/ML lint passed with no missing sections and
no ML hits. There is no adaptive refit, banned indicator, grid, martingale, or
portfolio feedback.

| Binding | SHA-256 |
|---|---|
| Approved Card | `3b2ab7bc3c1dea90a86b936b1bf0e352f69e5c9532724f78512a18b987d35580` |
| MQ5 | `7eda37af63f23e00dcb930d71eb07afe4bef97e30875ec7f83bf5d234f668129` |
| EX5 | `d534838d2c9c993db151500c836f4e38088d961b2fe90e820defb0d31a34ae5b` |
| Basket manifest | `f7207377d90fb4fb3447425597f4ec4b2c2709838e0bd44cf4d851f70bb97725` |
| Logical setfile | `397181311f649d5416044d36d6aa70023390ea8b14f97cb75e7fb8818b144254` |

Canonical lineage remains:

- Q02 `5d1cb89c-25ce-419c-869c-8c9f7afa10c1`: done / PASS.
- Q03 `3c74eb04-7e19-4aa0-8dcf-3f004faaa946`: pending, unclaimed,
  attempt zero, unique, `priority_track=true`, no active hold, and not
  superseded.
- Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e`: pending and deliberately not
  promoted ahead of Q03 PASS.

The production selector has top-down priority enabled and places this exact
Q03 row first among 491 pending multisymbol rows. Its queue identity and
priority are already correct; rewriting either would not advance the funnel.

## Healthy serialized predecessor

The single admitted basket remains `QM5_20294` Q05 work item
`c56df942-e7aa-4c7d-b855-402de608352f` on T10. It is making real forward
progress:

- the MT5 tester started at `2026-08-30T03:08:18Z`;
- `metatester64` had accumulated `17156.844` CPU seconds at the observation;
- terminal progress reached 63% at 09:58:29 Europe/Berlin, up from 22% in the
  preceding paced-predecessor receipt; and
- its governed inner timeout is 28,800 seconds.

Nine farm work items were active and exact factory paths showed terminals T3,
T6, T7, T9, and T10 testing. `T_Live` and the unrelated FTMO terminal were
observed only to exclude them and were not controlled.

## Capacity result and bounded action

Five fresh one-second whole-host CPU readings were `72.659083%`, `79.048114%`,
`69.241491%`, `76.680164%`, and `73.147247%`. Average CPU was `74.155220%`
and maximum CPU was `79.048114%`; both are below the explicit 97% ceiling.
This materially reverses the preceding receipt's hard CPU stop, but it does not
override the one-basket admission contract.

No Card, EA, EX5, setfile, basket manifest, registry, magic row, queue row,
priority, claim, status, verdict, reservation, worker, terminal, compile,
smoke, or backtest was created or changed. The new durable work is the fresh
selector, lineage, package, capacity, and forward-progress evidence in
`artifacts/qm5_20224_q03_paced_predecessor_handoff_20260830T080303Z_board_advisor.json`.

## Safety and continuation

The portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest, AutoTrading, and live/deploy manifests
were untouched. Existing unrelated shared-worktree changes were preserved.

After `QM5_20294` Q05 reaches a canonical terminal state, take a fresh
five-sample CPU window. Only if both average and maximum remain strictly below
97% may the resident paced worker claim the existing exact `QM5_20224` Q03
row. Never enqueue a duplicate or promote Q04 before Q03 PASS.
