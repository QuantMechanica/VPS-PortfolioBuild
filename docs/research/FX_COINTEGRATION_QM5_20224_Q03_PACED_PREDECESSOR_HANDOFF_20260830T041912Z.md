# QM5_20224 FX cointegration Q03 paced-predecessor handoff

Date: 2026-08-30 UTC (`2026-08-30T04:19:12Z`); 06:19 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `cee90ce80c36d1af6a8afd8c158722a922fcd519`

Status: the previous hard CPU ceiling has cleared, but the one admitted basket
lane is occupied by a healthy, progressing Q05 run. The selected existing FX
Q03 row remains the exact first pending basket, so no duplicate queue or
terminal mutation is admissible yet.

## Frontier decision

The reputable-source result in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` selected only two strict
survivors from the frozen 66-pair scan. Both anchors are already built and past
Q02:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Later logical-basket Q02 PASS evidence supersedes their historical per-leg
`ONINIT`/`NO_HISTORY` attempts. The committed sign-aware coverage audit
accounts for all 66 relationships, with no reputable, non-duplicate unbuilt
pair remaining. The card-extraction gate is therefore closed for lack of a new
qualified identity, and the EA-build gate is closed for lack of an approved
unbuilt Card.

## Selected existing forex successor

The dependency-correct fallback remains frozen-scan rank 46,
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. It trades `EURUSD.DWX` and
`EURJPY.DWX` on D1 with fixed beta `-0.236324029`; `USDJPY.DWX` is
conversion-history-only.

The package remains structural and low-frequency. Its logical backtest setfile
seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. It has no
ML, adaptive refit, banned indicator, grid, martingale, or portfolio feedback.
Its Card, MQ5, EX5, basket manifest, and logical setfile hashes are unchanged
from the preceding receipt.

Canonical lineage remains:

- Q02 `5d1cb89c-25ce-419c-869c-8c9f7afa10c1`: done / PASS.
- Q03 `3c74eb04-7e19-4aa0-8dcf-3f004faaa946`: pending, unclaimed, attempt
  zero, unique, and already `priority_track=true`.
- Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e`: pending and deliberately not
  prioritized before Q03 PASS.

## Healthy serialized predecessor

The single admitted basket remains `QM5_20294` Q05 work item
`c56df942-e7aa-4c7d-b855-402de608352f` on T10. This is not a stale-active row:

- `metatester64` has accumulated `4145.406` CPU seconds since
  `2026-08-30T03:08:18Z`.
- Its EA log was still growing at `2026-08-30T04:17:57Z`.
- The terminal reported `processing 22 %` at 06:18:20 Europe/Berlin.
- The governed run timeout is 28,800 seconds.

`QM5_20224` remains first in manifest-backed basket pending order. Launching it
in parallel, creating another Q03 identity, or advancing Q04 would violate the
paced single-basket and dependency contracts.

## Capacity result and bounded action

Five fresh one-second whole-host CPU samples were `79.214795%`, `76.460737%`,
`71.296236%`, `80.387139%`, and `80.388154%`. Average CPU was `77.549412%`
and maximum CPU was `80.388154%`; neither reaches the explicit 97% ceiling.
Capacity has therefore changed materially from the preceding hard-stop
receipt, but lane occupancy still prevents a safe dispatch.

No Card, EA, EX5, setfile, basket manifest, registry, magic row, queue row,
priority, claim, status, verdict, reservation, worker, terminal, compile,
smoke, or backtest was created or changed. This preserves the exact existing
FX identity while the healthy predecessor drains.

Machine-readable evidence is in
`artifacts/qm5_20224_q03_paced_predecessor_handoff_20260830T041912Z_board_advisor.json`.

## Safety and continuation

The portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest, AutoTrading, and live/deploy manifests
were untouched. Existing unrelated shared-worktree changes were preserved.

After `QM5_20294` Q05 reaches a canonical terminal state, take a new
five-sample CPU window. Only if both average and maximum remain strictly below
97% may the resident paced worker claim the existing exact `QM5_20224` Q03
row. Never enqueue a duplicate or prioritize Q04 before Q03 PASS.
