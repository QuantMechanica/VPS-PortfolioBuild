# FX cointegration — QM5_20228 Q04 hard CPU stop

Date: 2026-08-30 UTC (`2026-08-30T13:50:27.7834506Z`); 15:50 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `da38c3f2963b03e879bba7fc23910b98534840fa`

Status: stopped at the explicit backtest CPU ceiling before the guarded queue
mutation, journal creation, dispatch, or backtest.

## Frontier decision

The controlling reputable research remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published 66-pair
criterion selected only `QM5_12532` and `QM5_12533`. Both anchors have
canonical logical-basket Q02 PASS evidence, so neither has a current
`ONINIT`/`NO_HISTORY` repair to perform.

A fresh approved-card/build census found 120 cointegration-or-coint Card files,
120 unique EA IDs, and a matching EA directory for every ID. There is no
approved unbuilt FX cointegration Card. Creating another scan-derived Card or
EA would be duplicate or weaker work, so the card-extraction and EA-build gates
remain closed.

The dependency-complete existing fallback selected by the preceding receipt is
scan-rank 50 `QM5_20228_USDCAD_GBPJPY_COINTEGRATION_D1`. It is a structural,
fixed-beta D1 basket trading `USDCAD.DWX` and `GBPJPY.DWX`, with `USDJPY.DWX`
used only for conversion history. Its canonical lineage remains:

- Q02 `41722d88-1113-4e08-ac39-832b4708ee2d`: PASS.
- Q03 `1a395c0b-73ea-4bb3-9160-6fb55c4d6777`: PASS.
- Q04 `eb453b94-6031-4c40-b761-4f8005871751`: pending, unclaimed, attempt 0,
  unprioritized, and unique.

The Q04 payload is unchanged at
`41251ed85448a7fd864492ecac44a2c6bacdb66b3d476f3fb88e42aa8451273d`.
It has no active hold, quarantine, supersede relation, or prior FX priority
event. The already-prioritized rank-46 `QM5_20224` Q04 row was preserved.

## Structural and risk bindings

The approved Card lint is clean (`ml_hits=[]`, `missing_sections=[]`). The
sealed package hashes are:

| Binding | SHA-256 |
|---|---|
| Approved Card | `aa4f33324676659a7b2a97cc0f9590309c57451dde309c441d6319dc771ec123` |
| MQ5 | `1675651b00aa75803cda7e581a55d5bfb2ff2d7e3140557a942b4c98428ff948` |
| EX5 | `5c96776ebdd0d30db739774946b1d53bb36374ac795e3de90413c04ad10f54a2` |
| Basket manifest | `8d8a4d7c94efc2d373caa9f8c97fe1fd4ee493cd0fde9d4b440d265aec341bb8` |
| Logical backtest setfile | `17ffc468871accae43ead206bdf97f5a32c3aa8bc314e608e666c46c154c67e7` |

The backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No ML, adaptive refit, banned indicator, grid,
martingale, or portfolio-feedback change was introduced.

## Binding capacity result

Five one-second whole-host CPU samples were `96.569012%`, `94.241761%`,
`86.440794%`, `93.851384%`, and `97.310399%`. Average CPU was `93.682670%`;
maximum CPU was `97.310399%`. The governed ceiling binds if either value is at
least 97%, so the maximum triggered the required stop.

The capacity guard exited with code 97 before entering the Python mutation
body. Therefore it acquired no factory mutation lock, began no database
transaction, wrote no row journal, changed no payload or event, and started no
terminal or backtest. The active serialized basket lane remained
`QM5_20233` Q03 on T2 and was not controlled.

## Safety and continuation

This is a fresh capacity decision relative to
`artifacts/qm5_20228_q04_hard_cpu_stop_20260830T124013Z_board_advisor.json`:
the exact row was revalidated more than one hour later against a newer branch
head, and the ceiling still bound. No duplicate work item or stale queue
mutation was created.

The portfolio gate, `portfolio_admission`, `_kpi`, `_q08_contribution`,
T_Live, AutoTrading, and all live/deploy manifests were untouched. Existing
unrelated shared-worktree changes were preserved and excluded from this
commit.

Resume only after a new five-sample CPU window has both average and maximum
strictly below 97%. Then re-read the rank-46 predecessor and exact QM5_20228
Q04 row. If it is still pending, unclaimed, attempt zero, unprioritized,
guard-clean, and dependency-complete, priority-bind that row in place. Do not
enqueue or dispatch a duplicate.

Machine-readable evidence is in
`artifacts/qm5_20228_q04_hard_cpu_stop_20260830T135027Z_board_advisor.json`.
