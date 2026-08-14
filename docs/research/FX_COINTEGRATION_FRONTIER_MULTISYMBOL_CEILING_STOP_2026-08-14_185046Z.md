# FX cointegration frontier — multisymbol ceiling stop

Date: 2026-08-14

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; rank-58 logical Q02 remains
PENDING exactly once; the active basket lane and signed Custom-history
containment lease bind the effective backtest ceiling

## Outcome

No duplicate Strategy Card, EA, registry row, basket manifest, setfile, or Q02
row was created. The committed sign-aware reconciliation of
`analyze_cross_asset_v3.py --include-negative-hedges` accounts for all 66
relationships, so there is no unbuilt scan relationship left to mechanize.

The two requested anchors remain downstream of Q02 and do not have an open
ONINIT or NO_HISTORY repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The non-duplicate fallback therefore remains frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in the approved and
built `QM5_1257_lemishko-fx-cointpair` basket. Its exact logical Q02 row is
`d4cd660c-c81a-41d3-8a4c-ad21d3319816`.

At the `2026-08-14T18:50:46Z` database sample the row was PENDING, unclaimed,
at `attempt_count=1`, with no verdict or evidence path. It was rank 6 of 1,014
eligible pending rows under the canonical selector, remained priority-tracked,
had no active hold or quarantine, and was the only row for the exact logical
identity. The prior attempt remains infrastructure-incomplete rather than a
strategy verdict. No enqueue, requeue, timestamp, or priority mutation was
warranted.

## Existing-pair contract

The fallback is bound to the OWNER-approved Lemishko, Landi, and
Caicedo-Llano (2024) SSRN Card with R1-R4 PASS. It is a structural,
low-frequency residual-reversion package with a frozen hedge ratio and no ML,
grid, martingale, adaptive refit, or rescue filter. Its manifest declares
`GBPUSD.DWX` and `USDJPY.DWX`; the logical H1 setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The Card preserves the adverse frozen-scan evidence for this pair. Q02 remains
a one-shot cadence/economics falsification test, not a profitability claim.

Fresh non-mutating validation passed:

- Strategy Card schema lint: PASS, zero missing sections and zero ML hits.
- FX basket/work-item regression tests: 59 passed.
- Symbol-scope validation: `BASKET_OK`, zero violations.
- MQ5, EX5, Card, manifest, and fixed-risk setfile hashes match the prior
  committed Q02 handoff.

## Binding stop

The normal seven-item paced ceiling was not full, but the stricter basket
ceiling was. At `2026-08-14T18:50:46Z` the database contained two active work
items. One was the multisymbol Q02 basket
`QM5_20294_XAU_XAG_LOWMAX_D1`, work item
`be182dfd-bf33-4577-904c-761bf87c4ccc`, claimed by T8. The target
`QM5_1257` row is also multisymbol, and the canonical worker serializes heavy
basket backtests to one active item fleet-wide.

The signed Custom-history containment mode was also enabled. Its current
record was written at `2026-08-14T18:11:54.181584Z` with reason
`custom_history_gate_exception:OSError`, mode id
`7aa58d845a61ec05f27928ee7dc23f62f260a832268f293f205b0902b7ba43ac`,
and authorization id
`0089c8b613a1181ff4d2304a9b2d7102da5445e6f7e9970841739dd5533f3672`.
The global lease could not be opened because another process held it, so a
competing basket claim was not permitted.

A path-aware process sample at `2026-08-14T18:51:36Z` found two factory MT5
children on T5 and T6. Both were reported as orphaned relative to their work
item states; T8 had claimed the current basket but had not yet exposed an MT5
child in that process snapshot. The separately observed `T_Live` and FTMO
terminals were excluded and not controlled. The orphaned processes were also
left untouched.

This hits the mission's backtest-capacity stop through the one-at-a-time
multisymbol/containment lane. No dispatch tick, manual tester, enqueue,
requeue, terminal reservation, terminal control, archive repair, containment
release, or orphan cleanup was attempted.

## Non-duplicate delta

This record is distinct from the preceding `12:24:23Z` signed-containment
handoff. The factory has since resumed and rotated through new work; the
containment record was re-engaged at `18:11:54Z` for an OSError rather than the
earlier isolation-gate stop, the active owner is now a Q02 basket on T8, and
the FX fallback has advanced to canonical pending rank 6. Its strategy and
queue identity remain unchanged.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_multisymbol_ceiling_stop_20260814T185046Z_board_advisor.json`.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution path, T_Live
manifest or terminal, AutoTrading state, live-deployment artifact, registry,
Card, EA, basket manifest, setfile, external queue row, history archive, or
containment state was changed. The unrelated untracked XNG Q05 setfile was
left unstaged and untouched.
