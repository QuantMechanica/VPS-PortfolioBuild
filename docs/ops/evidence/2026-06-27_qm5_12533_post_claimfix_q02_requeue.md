# QM5_12533 Post-Claim-Fix Q02 Requeue - 2026-06-27

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan. It documents only two strict-threshold
market-neutral FX cointegration survivors:

- `QM5_12533` EURJPY/GBPJPY D1 basket, strongest survivor.
- `QM5_12532` AUDUSD/NZDUSD D1 basket, already logical-basket Q02 `PASS` and
  later Q04 `FAIL` for low pooled fold trades.

There is no third unbuilt strict-threshold FX cointegration pair from that scan.
The non-duplicate action was to advance the existing blocked `QM5_12533`
logical-basket Q02 lane.

## Prior Failure

Latest completed `QM5_12533` logical-basket Q02 row before this requeue:

| Field | Value |
|---|---|
| Work item | `433bf1fd-c82f-4d3f-934c-21b772eea5fc` |
| Status / verdict | `done` / `INFRA_FAIL` |
| Evidence | `D:/QM/reports/work_items/433bf1fd-c82f-4d3f-934c-21b772eea5fc/QM5_12533/20260627_070554/summary.json` |
| Summary reason | `NO_HISTORY`, `INCOMPLETE_RUNS` |

That zero-bar report was traced to the pre-fix terminal claim race documented in
`docs/ops/evidence/2026-06-27_qm5_12533_terminal_claim_race_fix.md`.
The fix landed in commit `f2611fbf0` at `2026-06-27 09:37:37 +0200`.

## Worker State

Before inserting a replacement, the terminal workers were verified to have recycled
after the claim-race fix:

- Worker processes for enabled `T1` through `T7` were created around
  `2026-06-27T10:35:23+02:00`.
- `T8`, `T9`, and `T10` remain disabled in
  `D:/QM/strategy_farm/state/disabled_terminals.txt`.
- Duplicate guard found zero pending/active rows for
  `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`.

## Queue Mutation

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12533_post_claimfix_q02_requeue_20260627_083635Z.sqlite`

Inserted one replacement logical-basket Q02 work item:

| Field | Value |
|---|---|
| Work item | `76cb11ee-7e9d-4d75-be9d-626c205bca62` |
| Parent task | `qm5-12533-post-claimfix-q02-requeue-20260627_083635-76cb11ee` |
| EA | `QM5_12533` |
| Symbol | `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` |
| Setfile | `C:/QM/repo/framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/sets/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration_QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1_D1_backtest.set` |
| Basket manifest | `C:/QM/repo/framework/EAs/QM5_12533_edgelab-eurjpy-gbpjpy-cointegration/basket_manifest.json` |
| Risk payload | `tester_currency=JPY`, `tester_deposit=15000000`, `risk_fixed=150000` |
| Timeout | `120` minutes |
| Supersedes | `433bf1fd-c82f-4d3f-934c-21b772eea5fc` |
| Created | `2026-06-27T08:37:07+00:00` |

No manual MT5 backtest was launched. The paced terminal workers own execution.

## Post-Insert State

At verification, the row was still `pending` and duplicate count was exactly one:
the inserted replacement row. This is expected because the worker serialization guard
allows at most one multisymbol/basket EA active farm-wide, and `QM5_11240` was active
at the time of the check.

The next useful action is to let the patched worker fleet claim
`76cb11ee-7e9d-4d75-be9d-626c205bca62` after the active multisymbol job clears, then
classify the resulting Q02 evidence.
