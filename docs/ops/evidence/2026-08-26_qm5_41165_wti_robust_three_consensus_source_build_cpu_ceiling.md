# QM5_41165 WTI Robust-Three Consensus Source Build — CPU-Ceiling Handoff

Date: 2026-08-26

Branch: `agents/board-advisor`

Outcome: `SOURCE_BUILD_COMMITTED_COMPILE_HELD_Q02_NOT_ENQUEUED_CPU_CEILING`

## Delivered Non-Duplicate Edge

`QM5_41165_wti-mrobust3-agree-tr` is a new low-frequency structural WTI
trend sleeve. On the first executable D1 tick of each broker month it takes the
latest close from each of the prior thirteen consecutive completed months,
converts them to log prices, and calculates three fully specified robust trend
slopes: Theil-Sen, an exact least-absolute-deviation profile over all pair-slope
candidates, and Siegel's repeated median. It buys only when all three slopes
are strictly positive, sells only when all three are strictly negative, and
otherwise remains flat for the month.

This direct crude-oil exposure is structurally different from the current
index, precious-metal, and natural-gas book. No ex-ante uncorrelation claim is
made; realized portfolio correlation remains exclusively a Q09 decision.

The canonical fail-closed duplicate scan covered 4,664 registry identities,
1,315 cards, and 45 Strategy Wiki nodes. The closest fuzzy match was the
expected single-estimator WTI Theil-Sen edge at `0.5833333333333334`. Two fixed
paths prove functional divergence: one produces positive Theil-Sen and LAD
slopes but a negative repeated median; another produces positive Theil-Sen and
repeated-median slopes but a negative LAD slope. The new three-way strategy is
flat in both cases while its single-estimator constituents trade. The durable
receipt is
`artifacts/qm5_wti_mrobust3_agree_tr_preallocation_dedup_20260826.json`.

Research/source approval is commit `17565d58d`; the approved G0 card and
deterministic EA identity are commit `0221a60f8`; the source build and governed
magic allocation are commit `89c88b3a6`.

## Source Build State

- reputable peer-reviewed source criteria are durably approved;
- the approved card and byte-identical build-time copy are present;
- card schema and ML-ban lint: PASS;
- deterministic reference suite: 11/11 PASS;
- the V5 EA source, SPEC, and one backtest-only XTIUSD.DWX D1 setfile are
  committed;
- the setfile locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`;
- no live/demo/shadow/stress/optimization setfile exists;
- governed slot 0 is `XTIUSD.DWX` / `411650000`;
- allocation added exactly one resolver row and zero active magic collisions;
- `.mq5` SHA-256 is
  `D44BE224E18B5C068DDFAE44D7B79261DBE5956FD3F6EE7BAF2CB5DACFC863BA`;
  and
- no `.ex5` exists, so Q01 remains pending.

## Compile Handoff

The direct build-check preflight was refused before compilation with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because factory `terminal64` processes
were alive. No retry, bypass, or terminal control was attempted. The exact
source was submitted to the governed compile lane:

- work item: `373eb9be-7366-4902-aa05-ec703892849f`;
- state: `pending`;
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- compiled: false;
- failed: false; and
- build-check verdict / EX5 hash: absent.

Continuation must use `farmctl compile-status
QM5_41165_wti-mrobust3-agree-tr`; it must not bypass the hold with an ad-hoc
terminal compile while factory terminals are active.

## Binding CPU Stop

At `2026-08-26T09:56:14Z`, `farmctl mt5-slots` found active governed tests on
T1 (Q03) and T6 (Q10_NEWS). `T_Live` was observed only to exclude it and was
not controlled.

The fresh five-sample whole-host series completed at
`2026-08-26T09:56:23.7490528Z`:

```text
97.27, 94.74, 93.47, 74.80, 94.75
average = 91.01%
maximum = 97.27%
hard ceiling = 97.0%
```

The maximum binds the repository's average-or-maximum ceiling rule. Pipeline
work stopped immediately after this observation. No Q02 row was enqueued
because strict compile/Q01 has no PASS and the capacity guard independently
forbids adding backtest work.

## Safety And Continuation Boundary

No tester/backtest, Q02 dispatch, terminal reservation, terminal stop/restart,
AutoTrading action, `T_Live` or deploy-manifest edit, portfolio-gate edit,
portfolio admission, or correlation waiver occurred. Existing unrelated
worktree modifications were preserved and excluded from every commit.

Continuation is bounded to: wait for non-binding CPU capacity and the governed
compile worker; verify an exact-source strict compile and build-check PASS;
then, and only then, enqueue the XTIUSD.DWX D1 Q02 row from the committed
`RISK_FIXED` preset. Q09 alone may decide realized portfolio correlation.

Machine-readable receipt:
`artifacts/qm5_41165_wti_robust_three_consensus_source_build_cpu_ceiling_20260826T095623Z.json`.
