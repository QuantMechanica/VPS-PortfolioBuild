# QM5_12778 FX basket MAE-hook repair and governed compile handoff

Date: 2026-08-26 UTC

Branch: `agents/board-advisor`

Source commit: `904748f9cdca6f4dffec621d47dd628fad40a38d`

## Outcome

The frozen 66-pair scan has no uncovered reputable-source identity. Its two
admitted survivors, `QM5_12532` and `QM5_12533`, both have canonical logical
basket Q02 PASS rows, so neither requires an `ONINIT` or `NO_HISTORY` repair.
All 61 active scan-lineage registry identities queried in this run already
have at least one work item; adding another card or Q02 row would duplicate
governed work.

The selected existing-pair fallback is the AUDUSD/EURJPY D1 market-neutral
basket `QM5_12778_edgelab-audusd-eurjpy-cointegration`. Its 2026-08-22
`COMPILE_EA` predecessor `b4711c17-b3e8-4607-ac5e-82d771b1e1ba` compiled with
zero errors and zero warnings but failed the current build contract solely on
`EA_Q08_MAE_HOOK_MISSING`.

## Structural repair

`QM5_12778_edgelab-audusd-eurjpy-cointegration.mq5` now calls
`QM_FrameworkTrackOpenPositionMae()` as the first action in `OnTick()`, before
the kill-switch and every other early-return guard. No entry, exit, beta,
z-score, ATR stop, package sizing, risk, news, symbol, or timeframe rule
changed.

The repaired source SHA-256 is
`132a501d94685f013cc62a8b3c2de111d0a8b1e616a8656d2c61b061a754c146`.

## Verification

- Approved card: `g0_status: APPROVED`.
- EA registry: active row `12778,edgelab-audusd-eurjpy-cointegration`.
- Magic registry: active slot 0 `AUDUSD.DWX` and slot 1 `EURJPY.DWX`.
- Basket manifest: logical symbol
  `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`, host `AUDUSD.DWX`, D1.
- Logical backtest setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- `validate_build_guardrails.py`: PASS, 12 files, zero findings.
- `build_gate_hardening.py`: PASS, including D7 MAE hook, exact symbol scope,
  request initialization, and management reachability.
- `git diff --check`: PASS.

The live-factory include-mirror guard correctly refused an ad-hoc
`build_check.ps1`, even with `-SkipCompile`, while seven factory terminals
were running. No guard was bypassed and no direct compile was attempted.

## Governed compile successor

Exactly one append-only `COMPILE_EA` successor was enqueued:

- work item: `3cf75022-91f6-413f-aa0e-dfe24a738c05`
- status: `pending`
- activation state: `AWAITING_REVIEWED_WORKER_ROLLOUT`
- hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`
- owner authority: `OWNER_DECISION_2026-08-21_DL-089_LIVE_BOOK_REQUALIFICATION`
- bound MQ5 SHA-256:
  `132a501d94685f013cc62a8b3c2de111d0a8b1e616a8656d2c61b061a754c146`
- risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`

This receipt does not claim compile PASS. The governed worker must release the
existing rollout hold, compile the committed source, refresh the binary and
setfile hashes, and emit its normal build-check evidence.

## Capacity and safety

The pre-mutation five-sample whole-host CPU gate read 88.03% average and
96.29% maximum, below the binding 97% average-or-maximum ceiling. Seven
factory terminals were active, so no tester, dispatch tick, terminal
reservation, terminal control, smoke run, backtest, Q02 duplicate, or manual
compile was launched.

No portfolio-admission, portfolio-KPI, Q08-contribution, T_Live manifest,
T_Live terminal, AutoTrading state, or live-risk artifact was touched.
Concurrent unrelated worktree changes were preserved and excluded from both
commits.
