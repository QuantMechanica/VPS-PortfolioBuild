# QM5_41254 WTI Chow-Break Source Build and CPU-Ceiling Stop

Recorded: 2026-08-31T19:59:04.2917929Z

## Outcome

`QM5_41254_wti-chow-break-tr` is a committed, non-duplicate source build for
the new direct-WTI commodity sleeve. Its governed compile row is source-fresh,
released, and pending. It has no EX5 and therefore no Q01 compile PASS. Q02 was
not enqueued because the compile prerequisite is absent and a fresh CPU sample
series hit the fleet's 97% backtest admission ceiling.

## Edge and non-duplicate boundary

The monthly D1 signal fits pooled OLS to 252 completed WTI log prices, scans
two-regression splits `k=63..189`, selects the latest exact maximum of
`((RSS0-RSSk)/2)/(RSSk/248)`, requires an inclusive score of 3.0, and follows
the selected recent slope. This is distinct from the one-line WTI OLS/R2,
monthly-return mean CUSUM, fixed-block Welch, squared-return CSS variance, and
certified XNG oscillator families documented in the approved card.

The reputable-source boundary is preserved: the governed AI packet owns the
exact synthesis; complete-read peer-reviewed evidence supports only WTI
membership, monthly cadence, and own-return continuation; the policy-deferred
Chow citation supplies bibliographic naming context only and no significance
claim.

## Committed evidence

- Source approval and corrected-root dedup: `08fb72d7bb`.
- Deterministic identity reservation: `bb95450bb5` (`QM5_41254`).
- Approved card and G0: `afe334d6b2`.
- Governed magic and exact card copy: `e40469c609` (`412540000`).
- Source, spec, deterministic fixtures, and sole fixed-risk backtest set:
  `0f0f61c55b`.
- Reference suite: 12/12 PASS.
- Risk preset: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- No live, demo, shadow, stress, or optimization setfile exists.

## Governed compile handoff

An ad-hoc strict compile was refused before terminal use because live factory
processes were present. The mandated `COMPILE_EA` route accepted work item
`bebecbbd-d69a-4c5d-97b9-d7aea07ce4d3`, bound to MQ5 SHA-256
`d1b70c0f9e53b1385b538f12ecda1de4f7c2750c6d02107f2a81f335cdd1f376`.
The target-only dry run and apply release receipts are:

- `artifacts/qm5_41254_compile_release_dry_run_20260831.json`
- `artifacts/qm5_41254_compile_release_apply_20260831.json`

The latest canonical status was `pending`, activation hold absent, attempt
count zero, no evidence path, and no EX5. No manual dispatch was forced.

## CPU stop

A fresh five-sample total-CPU series was
`99.41, 94.86, 90.43, 91.26, 99.62%`: average 95.12%, maximum 99.62%.
The maximum exceeded the governed 97% admission ceiling while pipeline
testers were active on T1, T3, and T8. Work stopped at that explicit mission
boundary. No Q02 row was created.

The next safe action is for a resident worker to complete the released compile
after CPU recovery, producing a source-hash-matched strict `COMPILE_OK` receipt
and EX5. Only then, and only below CPU admission, may one paced XTIUSD.DWX D1
Q02 row be enqueued.

## Safety attestation

No manual tester run, live/demo action, AutoTrading change, `T_Live` mutation,
portfolio-gate mutation, T_Live-manifest mutation, deployment, or portfolio
admission occurred.
