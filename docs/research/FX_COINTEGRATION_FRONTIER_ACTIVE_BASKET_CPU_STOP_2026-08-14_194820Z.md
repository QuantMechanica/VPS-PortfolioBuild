# FX cointegration frontier — active-basket CPU stop

Date: 2026-08-14

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; the exact fallback Q02 remains
PENDING once; a path-bound multisymbol Q02 owns the fleet's single basket lane

## Outcome

No duplicate Strategy Card, EA, registry row, basket manifest, setfile, or Q02
row was created. The committed sign-aware reconciliation of
`analyze_cross_asset_v3.py --include-negative-hedges` covers all 66 frozen
relationships, so there is no unbuilt scan pair left to mechanize.

The two requested anchors remain beyond Q02 and have no open ONINIT or
NO_HISTORY repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The non-duplicate fallback is therefore frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in approved and built
`QM5_1257_lemishko-fx-cointpair`. Its exact logical Q02 row is
`d4cd660c-c81a-41d3-8a4c-ad21d3319816`.

At the `2026-08-14T19:48:20.469Z` read-only database sample the row was PENDING,
unclaimed, at `attempt_count=1`, with no verdict or evidence path. It was rank 7
of 1,017 eligible pending rows under the canonical selector, had no active hold
or quarantine, and remained the only row for that exact logical identity. The
prior attempt remains infrastructure-incomplete (`summary_missing`), not a
strategy verdict. Enqueueing, requeueing, restamping, or reprioritising it would
have been duplicate mutation.

## Existing-pair contract

The fallback remains bound to the OWNER-approved Lemishko, Landi, and
Caicedo-Llano (2024) SSRN Card with R1-R4 PASS. It is a structural,
low-frequency residual-reversion basket with a frozen hedge ratio and no ML,
grid, martingale, adaptive refit, or rescue filter. Its manifest declares
`GBPUSD.DWX` and `USDJPY.DWX`; the logical H1 backtest setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Fresh SHA-256 reads confirmed that its MQ5, EX5, Card, manifest, and fixed-risk
setfile are unchanged from the prior committed handoff.

## Binding CPU stop

At the current sample the database had exactly one active work item:
multisymbol Q02 `QM5_20294_XAU_XAG_LOWMAX_D1`, work item
`be182dfd-bf33-4577-904c-761bf87c4ccc`, claimed by T8. The path-anchored process
scan showed its live child, PID 14584, running from
`D:\QM\mt5\T8\terminal64.exe` with a tester configuration rooted under that
exact work-item UUID. The T8 reservation remains bound to the same run. There
were no orphaned factory terminal processes in the canonical `mt5-slots`
snapshot.

The normal seven-item paced ceiling was not full and 54.34 GiB of 63.12 GiB
physical RAM was free. The stricter backtest ceiling nevertheless binds: the
canonical worker serializes heavy multisymbol tests to one active item
fleet-wide, and the selected FX fallback is itself multisymbol. Signed
Custom-history containment also remains enabled with reason
`custom_history_gate_exception:OSError`. A competing claim or manual tester
would violate both the paced basket lane and containment boundary.

This meets the mission's backtest CPU-ceiling stop. No dispatch tick, tester,
enqueue, requeue, terminal reservation/control, containment mutation, factory
recovery, or orphan cleanup was attempted. The separately observed `T_Live`
and FTMO terminals were excluded and untouched.

## Non-duplicate delta

This snapshot is materially distinct from the `18:50:46Z` handoff. At that
sample T8 had claimed the basket but had not yet exposed an MT5 child, while T5
and T6 appeared orphaned. The current snapshot proves the claimed T8 basket is
now executing through a path- and UUID-bound terminal child and reports zero
orphaned factory terminals. The exact FX fallback remains unchanged and
pending; its canonical rank moved from 6 to 7 as the surrounding queue changed.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_active_basket_cpu_stop_20260814T194820Z_board_advisor.json`.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution path, T_Live manifest
or terminal, AutoTrading state, live-deployment artifact, registry, Card, EA,
basket manifest, setfile, external queue row, history archive, or containment
state was changed. Unrelated in-progress `QM5_21523` worktree changes were left
unstaged and untouched.
