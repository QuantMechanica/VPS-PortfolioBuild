# QM5_41386 WTI Seven-Month Momentum / Two-Month Hold — Build And Compile CPU Stop

## Outcome

`QM5_41386_wti-tsmom7-h2` is a newly approved and committed low-frequency
structural WTI sleeve. It follows the sign of the exact prior seven completed
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
formation/holding family and includes WTI; standalone WTI `k=7,h=2` efficacy
and continuous-CFD transfer remain explicitly unproven.

The corrected-root canonical checker covered 4,866 registry rows, 1,479
cards, and 45 Strategy Wiki nodes. It found no exact identity and only
expected family matches. Monthly-renewal WTI siblings use a different
lifecycle; `QM5_20281` uses the same two-month clock with a twelve-month
return; `QM5_41379` through `QM5_41385` use three-, one-, nine-, six-, four-,
two-, and five-month returns. This identity uniquely requires exact
seven-month endpoints and the fixed odd-month two-month lifecycle.

## Build And Guard Evidence

- Source approval commit: `b1746a68ae`.
- G0/card commit: `bc84402f3f`.
- Allocation commit: `488d1086b4` (the identity row was separately captured
  by the deterministic pump commit `474a883653`).
- Source/build commit: `26250059c9`.
- EA ID and magic: `QM5_41386`, slot 0, `413860000` on `XTIUSD.DWX`.
- Source SHA-256:
  `cd95d72de470bc44c848b92ed73609d683a98145f3f1fe4b27f66669e1421ce8`.
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

- Work item: `6544472e-c255-42f2-adc5-8d47c4b5c1f9`.
- State: pending under `COMPILE_EA_WORKER_ROLLOUT_PENDING`.
- The exact release dry run authenticated current source SHA-256
  `cd95d72d...` against the enqueue payload and selected only this row.
- Release apply: not run.
- Compiler/tester activity caused by this mission: none.
- Q01 remains pending; no `.ex5` or compile verdict exists yet.

## Binding CPU Stop

The five one-second whole-host samples at
`2026-09-08T15:35:12.3480087Z` were `100.0%`, `100.0%`, `100.0%`, `100.0%`,
and `99.812591%`. Average CPU was `99.962518%`; maximum CPU was `100.0%`.
Admission requires both measures to remain strictly below `97%`, so the stop
condition bound. D: had 118.379 GiB free and was not the blocker.

No activation hold was released, no compile was claimed, no backtest was
launched, and no Q02 work item was created. A later paced wake may reuse the
same held compile row only after a fresh five-sample CPU window clears both
thresholds; after `COMPILE_OK`, it must recheck CPU before invoking the
canonical first-Q02 intake exactly once.

Machine-readable evidence:
`artifacts/qm5_41386_compile_cpu_stop_20260908.json` and
`artifacts/qm5_41386_compile_release_dry_run_20260908.json`.

## Safety Boundary

No terminal process was controlled. The portfolio gate, `T_Live`, the live
manifest, AutoTrading, deployment state, and live-use surfaces were not
touched.
