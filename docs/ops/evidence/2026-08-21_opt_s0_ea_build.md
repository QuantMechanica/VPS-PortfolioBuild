# OPT-S0 DL-089 EA build evidence — 2026-08-21

## Scope

- Router task: `68f6d518-a28d-4198-ba86-1f06e29212f5`
- Priority: 88
- Decision: DL-089
- Parent: `QM5_21501_balke-gmt3-range-breakout-ppcensus`
- Allocated identity: `QM5_41097_balke-gmt3-range-breakout-opt`
- Branch: `agents/board-advisor`

This artifact records the research build only. It is not a pipeline verdict and
does not authorize T_Live or AutoTrading.

## Implementation

The new EA retains the parent's A1-fixed, side-effect-free straddle mechanics.
Its phase-1 profile is constructed from exactly six integer inputs:

- `opt_pp_buy1`, `opt_pp_buy2`, `opt_pp_buy3`
- `opt_pp_sell1`, `opt_pp_sell2`, `opt_pp_sell3`

Zero leaves a profile slot empty. Negative or unimplemented predicate IDs fail
closed in `OnInit`. The all-zero profile is the baseline.

The following phase-2 inputs are present but deliberately inert in this pilot:

- `opt_stop_distance_range_mult=1.0`
- `opt_take_profit_r_multiple=0.0`
- `opt_range_window_hours=3`

They preserve the concrete parent behavior: one-range stop distance, no fixed
take-profit, and a three-hour range. They are declarations only and have no
mechanical use site.

The backtest setfile fixes `RISK_FIXED=1000` and `RISK_PERCENT=0`. The source
keeps `qm_news_stale_max_hours=336` and the mandatory DXZ news compliance mode.

## Registries

- EA registry: one active row for EA 41097 and strategy ID
  `6e967762-b26d-59a3-b076-35c17f2e7c36`.
- Magic registry: one active `USDJPY.DWX` slot-0 row, magic `410970000`.
- Resolver regenerated from the canonical magic registry: 17,599 rows, zero
  dropped, registry SHA prefix `03B83CBFFD1DB572`.

## Verification

Passed checks:

- `validate_spec_doc.py`: PASS (1/1).
- `validate_build_guardrails.py`: PASS, no findings, stale-news ceiling 336.
- Static contract assertion: PASS for six declarations, six profile-builder use
  sites, absence of the old single-predicate inputs, declaration-only phase-2
  placeholders, fixed-risk setfile, and unique EA/magic registry rows.
- Magic resolver focused tests: 8 passed.
- Resolver dry-run: 17,599 rows kept, zero dropped.
- Enqueued source SHA matches current source SHA:
  `dc3840c1e99f4d96e2deca2495b1689277af37edcf06249189fb934b5d21ddd2`.

## Outstanding governed gates

Compilation and `build_check` do not yet have a PASS. An ad-hoc compile was
correctly refused with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because T1-T10
terminal processes were active; no terminal was interrupted. The governed
compile row is:

- work item `d646713d-c8ba-41ef-98f4-9b544780e714`
- state `pending`
- activation hold `COMPILE_EA_WORKER_ROLLOUT_PENDING`
- `no_gate_verdict=true`

The required pattern fixture is also not green:

- work item `83b89730-bb86-4c18-955a-efefe3039cc5`
- state `failed`, verdict `INFRA_FAIL`
- reason `ea_dir_missing`

Consequently no OPT_CENSUS setfile matrix or run rows were created. Review must
retain the build until the governed compiler reports 0 errors / 0 warnings,
`build_check` is PASS, setfiles are hash-bound, and the fixture harness is PASS.

## Review verdict

`SOURCE_READY_COMPILE_PENDING`: implementation and static governance checks are
ready for review; compile/build acceptance remains explicitly unmet under a
governed infrastructure hold. No pipeline or profitability claim is made.
