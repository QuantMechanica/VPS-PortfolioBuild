# FX cointegration GBPUSD/USDJPY — basket-lane containment stop

Date: 2026-08-15

Branch: `agents/board-advisor`

Sample window: `2026-08-15T20:48:49Z` through `2026-08-15T20:48:56Z`

## Outcome

No duplicate Card or EA was created. A fresh approved-card/build
reconciliation found 25 approved card filenames containing `coint` and zero
without a matching EA directory. The committed sign-aware reconciliation of
the frozen 66-pair scan remains the governing frontier, so no unbuilt scan
pair is available.

The two priority anchors remain beyond Q02, with no open ONINIT or NO_HISTORY
repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The non-duplicate fallback is frozen-scan rank 58, `GBPUSD.DWX` /
`USDJPY.DWX`, implemented as pair slot 8 in the approved and built
`QM5_1257_lemishko-fx-cointpair`. Its repaired logical Q02 work item remains
pending exactly once. Enqueueing or requeueing it would create duplicate
queue work, so neither action was taken.

## Exact fallback state

| Field | Value |
| --- | --- |
| Work item | `d4cd660c-c81a-41d3-8a4c-ad21d3319816` |
| Logical symbol | `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1` |
| Phase | Q02 |
| Status | `pending`, unclaimed |
| Attempt count | 2 |
| Verdict / evidence | none / none |
| Last update | `2026-08-15T13:03:04.898529Z` |
| Open exact-identity rows | 1 |

Fresh SHA-256 reads of the MQ5, EX5, logical backtest setfile, and basket
manifest match the bindings already stored in the row payload. The setfile
still declares `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No threshold, pair binding, source contract, or strategy
mechanic changed.

## Binding stop

At the current sample, one active multisymbol Q02 owns the fleet's serialized
basket lane:

- work item `a52d580e-bcef-42c7-8855-1b6be0fded0f`;
- `QM5_20206_XAU_XAG_MOMIVOL_D1` on T3;
- path-bound PID 17816 at `D:/QM/mt5/T3/terminal64.exe`;
- no orphaned factory terminal process.

The three-sample CPU average was 79.36%, physical-memory headroom was
42.23 GiB, and D: had 202.79 GiB free. Those soft resources have recovered,
but they do not release the single multisymbol backtest lane. Signed
Custom-history containment also remains enabled with reason
`custom_history_isolation_gate_failure`, mode SHA-256
`a7347f04df93de2d752f60e51ddeeb94a07c4912e0440664e96570379c1813bc`,
and authorization SHA-256
`61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e`.

Together these are the explicit backtest ceiling and fail-closed boundary.
No dispatch tick, tester launch, queue mutation, terminal reservation or
control, containment release, or manual bypass was attempted.

## Non-duplicate delta

The preceding `19:55Z` fallback record observed two active work items and only
56.30 GiB free on D:. The current post-cleanup sample has one active item and
202.79 GiB free. It therefore records the successful disk reclaim and active
set contraction while proving that the remaining multisymbol owner plus
signed containment still block the queued FX basket.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_basket_lane_stop_20260815T204850Z_board_advisor.json`.

## Safety

No portfolio-admission path, `_kpi`, `_q08_contribution`, T_Live manifest or
terminal, AutoTrading state, live-deployment artifact, Card, EA, registry,
setfile, basket manifest, external queue row, history archive, containment
state, factory process, or running terminal was changed. Concurrent unrelated
worktree changes were left unstaged and untouched.
