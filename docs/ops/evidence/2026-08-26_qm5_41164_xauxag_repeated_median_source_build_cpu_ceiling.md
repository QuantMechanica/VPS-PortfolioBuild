# QM5_41164 XAU/XAG Repeated-Median Source Build — CPU-Ceiling Handoff

Date: 2026-08-26

Branch: `agents/board-advisor`

Outcome: `SOURCE_BUILD_COMMITTED_COMPILE_HELD_Q02_NOT_ENQUEUED_CPU_CEILING`

## Delivered Non-Duplicate Edge

`QM5_41164_xauxag-mrepmedian-rv` is a new low-frequency, market-neutral-style
gold/silver basket. Once per broker month it reconstructs thirteen consecutive
exactly synchronized completed-month XAU/XAG close pairs, forms the
gold-minus-silver log-ratio path, gives each endpoint a group of twelve
forward-oriented slopes, takes an even median inside every pivot, then takes
the median of the thirteen pivot medians. It fades the strict sign with equal
target absolute USD notionals and one aggregate fixed-risk budget.

The canonical fail-closed scan was clean across 4,663 registry identities,
1,314 cards, and 45 Strategy Wiki nodes. A fixed valid path produces repeated
median `-0.0045`, while the closest existing XAU/XAG Theil-Sen and LAD systems
produce positive slopes `+0.00155555555555556` and `+0.00375`. Under the common
fade mapping, the new system opens the opposite package. The durable receipt
is `artifacts/qm5_xauxag_mrepmedian_rv_preallocation_dedup_20260826.json`.

Research/source approval is commit `12d432f58`; G0 card and deterministic EA
identity are commit `1da626c79`; the source build and governed magic allocation
are commit `c7bd5e8d5`.

## Source Build State

- approved card and byte-identical build-time copy are present;
- card schema and ML-ban lint: PASS;
- deterministic reference suite: 7/7 PASS;
- V5 EA source, SPEC, logical-basket manifest, and three backtest-only D1
  setfiles are committed;
- every setfile locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`;
- no live/demo/shadow/stress/optimization setfile exists;
- governed slot 0 is `XAUUSD.DWX` / `411640000`;
- governed slot 1 is `XAGUSD.DWX` / `411640001`;
- allocation added exactly two resolver rows and zero active magic collisions;
- `.mq5` SHA-256 is
  `B61DE8CC33CD1A0387698A2451D87480812FB3C76E076E0F2215F729C856854C`;
  and
- no `.ex5` exists, so Q01 remains pending.

## Compile Handoff

The direct strict compile was refused before compilation with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` / `INCLUDE_MIRROR_REFUSED` because
factory `terminal64` processes were alive. No retry or terminal control was
attempted. The exact source was submitted to the governed compile lane:

- work item: `6dd83b82-1f24-448c-862d-956677219498`;
- state: `pending`;
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- compiled: false;
- failed: false; and
- build-check verdict / EX5 hash: absent.

Future continuation must use `farmctl compile-status
QM5_41164_xauxag-mrepmedian-rv`; it must not bypass the hold with an ad-hoc
terminal compile while factory terminals are active.

## Binding CPU Stop

At `2026-08-26T09:06:34Z`, `farmctl mt5-slots` found active factory terminals
`T1`, `T3`, `T4`, `T6`, `T7`, `T8`, and `T9`. `T_Live` was observed only to
exclude it and was not controlled.

The fresh five-sample whole-host series completed at
`2026-08-26T09:06:48.0852737Z`:

```text
100.0, 100.0, 100.0, 100.0, 100.0
average = 100.0%
maximum = 100.0%
hard ceiling = 97.0%
metatester64 processes = 5
```

Both the average and maximum bind the explicit ceiling. Pipeline work stopped
immediately after this observation. No Q02 row was enqueued because strict
compile/Q01 has no PASS and the capacity guard independently forbids adding
backtest work.

## Safety And Continuation Boundary

No tester/backtest, Q02 dispatch, terminal reservation, terminal stop/restart,
AutoTrading action, `T_Live` or deploy-manifest edit, portfolio-gate edit,
portfolio admission, or correlation waiver occurred. Existing unrelated
worktree modifications were preserved and excluded from every commit.

Continuation is bounded to: wait for non-binding CPU capacity and the governed
compile worker; verify an exact-source strict compile and build-check PASS;
then, and only then, enqueue one logical-basket Q02 row from the committed
`RISK_FIXED` preset. Q09 alone may decide realized portfolio correlation.

Machine-readable receipt:
`artifacts/qm5_41164_xauxag_repeated_median_source_build_cpu_ceiling_20260826T090648Z.json`.
