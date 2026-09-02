# QM5_37003 diverse compile and Q02 recovery — 2026-09-02

## Outcome

`QM5_37003_hurst-exponent-dynamic-regime-switch` is now a governed, compile-PASS V5 build and its EURUSD H1 canary is pending at Q02. The existing source was unchanged; this unit recovered a prior infrastructure-only build failure, regenerated three fixed-risk setfiles, produced the missing EX5, and advanced the diverse FX/cross-asset cohort into the funnel.

The approved H1 card targets `EURUSD.DWX`, `GBPJPY.DWX`, and `SP500.DWX`. Its closed-form R/S Hurst regime classifier selects Donchian trend-following above the trend threshold and Bollinger mean reversion below the reversion threshold, with ATR risk controls. The card records Mandelbrot (1997), *Fractals and Scaling in Finance*, plus its VectorBT implementation lineage; `g0_status: APPROVED`, R1-R4 PASS, and `ml_required: false` were verified before the claim.

## Selection and collision guard

- Farm diversity rank used for selection: `23.88`, the highest available non-colliding candidate with an approved card, allocated identity, active magics, no EX5, and a low-frequency diverse universe.
- Existing build task: `10fc0415-d492-4f6d-aec3-744819207eb9`.
- Prior terminal reason: `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no source-level compile failure had occurred.
- Claimant: `codex:agents/board-advisor` on branch `agents/board-advisor` at `2026-09-02T02:16:56.955648Z`.
- The atomic claim proved zero other open build tasks and zero open work items for this EA.
- Pre-claim SQLite backup: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_37003_claim_20260902T021600Z.sqlite`.
- Active registry rows were already allocated and were not changed:
  - EA ID `37003`, slug `hurst-exponent-dynamic-regime-switch`.
  - slot 0 `EURUSD.DWX` / magic `370030000`.
  - slot 1 `GBPJPY.DWX` / magic `370030001`.
  - slot 2 `SP500.DWX` / magic `370030002`.

## Governed compile recovery

The prior build had generated hash-bound setfiles before the missing compile. The ordinary enqueue therefore refused with `BOUND_SETFILE_HASH_EXISTS`. The headers were explicitly put into `PENDING_STRICT_Q01` state so the canonical compile worker could perform candidate recheck first and then regenerate authoritative bindings.

Compile work item `8fbb6f77-13e5-4f00-9b5b-15ac8507a760` was enqueued against the exact open build task and released through the one-item governed compile-wave ceremony. An early candidate-recheck refusal caused by restoring the bindings too soon was preserved at:

`D:\QM\reports\work_items\8fbb6f77-13e5-4f00-9b5b-15ac8507a760\QM5_37003\COMPILE_EA\compile_evidence.attempt_0.bound_setfile_recheck_refused.json`

Its SHA-256 is `26dc3c5c1601c0eacaf81a62bc6687ce54822f623b7b9cb4423274c216ef4537`. The exact row was requeued once with the original preimage and evidence hash retained in `compile_attempt_history` and `work_item_transition_ledger`. Recovery is bound to backup:

`D:\QM\strategy_farm\state\backups\farm_state_before_compile_wave_20260902T022005Z_6ef09aeb.sqlite`

Backup SHA-256: `84b150b13eafad352d79581900ef6d92754a01cac8bfae2ff49155d85fe2597b`.

Final governed result:

- Work-item status/verdict: `done / COMPILE_OK`.
- `build_check.result=PASS`, failures `0`, warnings `0`.
- `compile_one.result=PASS`, errors `0`, warnings `0`.
- MQ5 SHA-256: `2c1537a3fd3b9102c9d4c55fc7a032bca7df94b6b1f9f260a2a75f7d4f9e8bfc`.
- EX5 SHA-256: `efc149365bd2f8df0a7bdb7dd5f8fe73940bfeb2b297f3952438773a698a9af7`.
- Compile evidence: `D:\QM\reports\work_items\8fbb6f77-13e5-4f00-9b5b-15ac8507a760\QM5_37003\COMPILE_EA\compile_evidence.json`.
- Compile-evidence SHA-256: `9dce2cfa32daecf531cddca56a0fe7cd0af767dd4d211e9b53018e064530111d`.
- SPEC validator: `PASS`.

The regenerated backtest setfiles retain `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`:

| Symbol | Setfile SHA-256 |
|---|---|
| `EURUSD.DWX` | `46e4e4c361cef76595c335a632e70240a88579b626f7441153451e644288a010` |
| `GBPJPY.DWX` | `16eedf810aab4a4b1f6493f93fdcf76f651a19c118bebd0b6e12c0a618605364` |
| `SP500.DWX` | `32dedd976f33ea91ddf58a3d15a46721d0fd03161d64aed7e4cbcd98c1cfe48e` |

## Bounded smoke and Q02 handoff

The pre-smoke CPU sample was average `71.75%`, maximum `80.10%`, below the `97%` stop ceiling. Exactly one EURUSD H1 smoke invocation was made. Resolver selected T8, but the custom-history admission gate returned `REFUSED` before MT5 launch because another active worker-bound `OPT_CENSUS` item owned the isolation window. No smoke terminal process or report was created, and no second attempt was made. The build result therefore records `deferred_p2_smoke` with `status=no_capacity_equivalent` and the exact admission evidence.

`record-build` accepted artifact:

`D:\QM\strategy_farm\artifacts\builds\10fc0415-d492-4f6d-aec3-744819207eb9.diversity_recovery.json`

Artifact SHA-256: `26e93bc48724f304d7d046c1ad096177b993a583df9cfb233ad86e6041c397e6`.

The build task is `done`. Automatic staged fanout created Q02 canary `3c748fc3-07ce-47c5-b5fe-e78756422379` for `EURUSD.DWX` H1 with `priority_track: true`, cohort size 3, and the active custom-history archive binding. `GBPJPY.DWX` and `SP500.DWX` are recorded as `staged_deferred_symbol` for promotion under `qm-q02-canary-fanout/v1`.

## Safety boundary

No portfolio gate, T_Live manifest, T_Live configuration, or AutoTrading state was changed. T_Live was never used as a compile or test target. No backtest was launched during the bounded smoke attempt.
