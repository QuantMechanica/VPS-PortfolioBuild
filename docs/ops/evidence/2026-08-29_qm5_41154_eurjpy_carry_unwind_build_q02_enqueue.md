# QM5_41154 EURJPY carry-unwind build and Q02 enqueue

Date: 2026-08-29

Branch: `agents/board-advisor`

Outcome: `BUILT_COMPILE_OK_Q02_ENQUEUED`

## Diversity selection

`QM5_41154_eurjpy-carry-unwind-crisis-momentum` was the deterministic
lower-EA-ID tie-break among the two remaining approved Wave-2 FX carry-unwind
cards. It adds a forex carrier outside the user-stated seven-survivor Q08
concentration in indices, metals, and energy. This is an instrument-diversity
candidate, not a certification or decorrelation claim.

The approved Tier-A lineage is Brunnermeier, Nagel, and Pedersen, *Carry
Trades and Currency Crashes* (NBER Working Paper 14473; later NBER
Macroeconomics Annual 23). The runtime card is G0 `APPROVED` and has SHA-256
`8ce741d028be29cfc55f43074c26c154b6a44287038fc49d48b2c8ab98b977e0`.

The D1 rule is structural and short-only:

- require the equal-weight five-session return across AUDJPY, NZDJPY, CADJPY,
  and EURJPY to be at or below `-1%`;
- require EURJPY to close below the prior 20-bar low;
- require 10-session realized volatility to exceed the median of the prior
  60 rolling observations;
- freeze a `2.0 * ATR(14)` hard stop at entry;
- exit after ten completed D1 bars or above the prior-channel midpoint.

AUDJPY, NZDJPY, and CADJPY are synchronized read-only signal inputs. Only
`EURJPY.DWX` receives orders, magic `411540000`, or risk allocation. The
baseline setfiles bind `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No ML, adaptive parameter, grid, martingale, or banned
indicator is present.

## Non-duplicate farm continuation

Implementation commit `e265084b6` created the source/spec/basket package and
the sole build task `baf614cf-9fd2-462f-ac4a-f8f56a018916`. That wake honored
the 97% CPU stop when one sample reached `97.95%`; its durable receipt is
`artifacts/qm5_41154_fx_build_compile_cpu_stop_20260829T194208Z_board_advisor.json`.

This continuation reused the exact task and SHA-bound compile item
`a05b9483-e45a-46ed-9fc9-c672723fec02`. Before recording the build, the farm
contained no QM5_41154 Q02 row. No duplicate EA ID, build task, compile item,
or queue row was created.

## Governed compile

A target-only dry run and apply released only the existing compile rollout
hold after expected and actual MQ5 SHA-256 both matched
`df7e2e57aaa974d7936e58d6c236d80b51a22cd5b2130fb6de2c8f2d001e9159`.
The resident T7 worker returned:

- verdict `COMPILE_OK`;
- strict compile: 0 errors, 0 warnings;
- build check: PASS, 0 failures;
- EX5 SHA-256
  `cba704f222a88334b190b573c12196bc52ba9048d2113d33c4e41ef423d6bf50`;
- evidence SHA-256
  `99e4936e5dc5fc5b0b5ba7088a66dfc94044d351df658e8a9f5068cb8896dba3`.

The static gate emitted one review advisory because the source retrieves swap
metadata. Inspection confirms it checks only retrieval and numeric validity;
it never requires a positive, negative, or non-zero swap. Zero-swap `.DWX`
tests therefore remain eligible. No ad-hoc compiler or tester was launched.

## Capacity and Q02 handoff

The fresh five-sample window immediately before compile release averaged
`72.90%` and peaked at `76.37%`. The pre-Q02 window averaged `49.15%` and
peaked at `60.47%`. The post-enqueue confirmation averaged `60.46%` and
peaked at `62.21%`. None bound the hard 97% ceiling.

Recording the successful build atomically created exactly one basket-aware
Q02 item:

- work item `039fc14e-75e5-44a0-89db-494ef110c76f`;
- logical symbol `QM5_41154_EURJPY_CARRY_UNWIND_CRISIS_MOMENTUM_D1`;
- host `EURJPY.DWX`, D1;
- basket inputs AUDJPY/NZDJPY/CADJPY/EURJPY, with EURJPY solely traded;
- custom-history archive admission `ACTIVE` with 432 selected rows;
- first readback `pending`, attempt 0, unclaimed.

The physical-host setfile was correctly skipped in favor of the logical
basket setfile, so the enqueue cohort size is one. The item was enqueued only;
this mission did not dispatch or backtest it.

## Safety boundary

No AutoTrading state, terminal process, T_Live environment or deploy manifest,
portfolio gate, live preset, or portfolio admission was touched. Downstream
Q02-Q09 evidence remains authoritative for frequency, robustness, and sleeve
diversification.

Machine-readable receipt:
`artifacts/qm5_41154_build_q02_enqueue_20260829.json`.
