# QM5_41387 WTI Eight-Month Momentum / Two-Month Hold — Build And Compile CPU Stop

## Outcome

`QM5_41387_wti-tsmom8-h2` is a newly approved and committed low-frequency
structural WTI sleeve. It follows the sign of the exact prior eight completed
broker-month return only at odd-month boundaries and holds a fixed,
non-overlapping two-month package. This creates direct crude-oil exposure
outside the incumbent XAU/SP500/NDX/XNG carriers. Realized decorrelation is
not claimed before Q09.

The card, deterministic identity/magic allocation, V5 source, fixed-risk
backtest preset, and reference vectors are committed. The mandatory PACER
input-pin audit passed with zero findings, and the governed compile row was
enqueued. Its activation hold was not released because the immediately
following five-sample host-CPU window hit the mission's binding 97% ceiling.
No compile worker or Q02 row was released.

## Source And Non-Duplicate Boundary

The complete-read, peer-reviewed source is Moskowitz, Ooi, and Pedersen
(2012), *Time Series Momentum*, Journal of Financial Economics 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`. It defines the own-return
formation/holding family and includes WTI; standalone WTI `k=8,h=2` efficacy
and continuous-CFD transfer remain explicitly unproven.

The corrected-root canonical checker covered 4,867 registry rows, 1,480
cards, and 45 Strategy Wiki nodes. It found no exact identity and only
expected family matches. Monthly-renewal WTI siblings use a different
lifecycle; `QM5_20281` uses the same two-month clock with a twelve-month
return; `QM5_41379` through `QM5_41386` use three-, one-, nine-, six-, four-,
two-, five-, and seven-month returns. This identity uniquely requires exact
eight-month endpoints and the fixed odd-month two-month lifecycle.

## Build And Guard Evidence

- Source approval commit: `8e43d31b39`.
- G0/card commit: `1086371346`.
- Allocation commit: `6ed10dc26d`.
- Source/build commit: `0f878466f4`.
- EA ID and magic: `QM5_41387`, slot 0, `413870000` on `XTIUSD.DWX`.
- Source SHA-256:
  `ac881fc759dc8e45f89beec0b567b8d5b8b7f93c2acca3d08154e7e04acd04d6`.
- Reference tests: 13/13 PASS.
- Card schema lint: PASS; prohibited-ML hits 0.
- PACER audit: exit 0, `ok=true`, `hit_count=0`, empty findings.
- Backtest set: D1, `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The locked-configuration guard pins only strategy inputs, `qm_ea_id`,
`qm_magic_slot_offset`, and fixed-risk mode. It does not compare RNG, news, or
Friday-close inputs. Stress rejection probability is checked only for
finiteness and the inclusive 0..1 range.

## Governed Compile State

- Work item: `3a5b117d-6d43-48a9-97fd-afb2e6f7adf5`.
- State: pending under `COMPILE_EA_WORKER_ROLLOUT_PENDING`.
- The exact release dry run authenticated current source SHA-256
  `ac881fc7...` against the enqueue payload and selected only this row.
- Release apply: not run.
- Compiler/tester activity caused by this mission: none.
- Q01 remains pending; no `.ex5` or compile verdict exists yet.

## Binding CPU Stop

The five one-second whole-host samples at
`2026-09-08T17:13:56.8337325Z` were `100.0%`, `99.0%`, `98.0%`, `100.0%`,
and `100.0%`. Average CPU was `99.4%`; maximum CPU was `100.0%`. Admission
requires both measures to remain strictly below `97%`, so the stop condition
bound. D: had 120.884 GiB free and was not the blocker.

No activation hold was released, no compile was claimed, no backtest was
launched, and no Q02 work item was created. A later paced wake may reuse the
same held compile row only after a fresh five-sample CPU window clears both
thresholds; after `COMPILE_OK`, it must recheck CPU before invoking the
canonical first-Q02 intake exactly once.

Machine-readable evidence:
`artifacts/qm5_41387_compile_cpu_stop_20260908.json` and
`artifacts/qm5_41387_compile_release_dry_run_20260908.json`.

## Safety Boundary

No terminal process was controlled. The portfolio gate, `T_Live`, the live
manifest, AutoTrading, deployment state, and live-use surfaces were not
touched.
