# QM5_41236 WTI Delete-One Sign-Stability Source Build — CPU Stop

Recorded: 2026-08-31 (Europe/Berlin)  
Branch: `agents/board-advisor`  
EA: `QM5_41236_wti-samecal-jack6`

## Outcome

The new direct-WTI structural sleeve is approved, allocated, implemented, and
covered by deterministic reference tests. The fresh capacity sample crossed
the explicit 97% hard CPU ceiling, so the governed strict compile and Q02
enqueue were not attempted.

This is a source-complete, compile-pending handoff. It is not Q01 PASS and it
does not claim performance, decorrelation, certification, or portfolio
admission.

## Concrete Edge

At the first genuine normalized broker-month transition into `(Y,M)`, the EA
reconstructs exact completed WTI matching-calendar-month log returns for
`Y-6..Y-1`. It deletes each observation once, computes all six five-year
arithmetic means with divisor five, and trades only when all six means have the
same strict sign beyond `1e-12`. Sign disagreement or an epsilon touch is flat.

The sole preset is `XTIUSD.DWX` D1 with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop,
40-day survivor repair, and a 1,500-point spread ceiling. News axes, legacy
news, and Friday close are locked OFF.

## Committed Work

- Source approval: `2e2bdf203`
- Governed source extraction: `a3750fa20`
- Deterministic EA identity: `040d7e37b`
- APPROVED G0 card: `bf0d39c4b`
- Governed magic allocation: `4561e1213`
- MQ5, SPEC, and sole backtest setfile: `981d76ccd`
- Independent reference fixtures: `64d37c1ed`

The factory's deterministic auto-commit `981d76ccd` also included one
concurrently produced, unrelated Q06 setfile; no attempt was made to rewrite
or discard that factory-owned artifact.

## Verification

- Independent reference suite: PASS, 11/11.
- Direct build guardrails: PASS, no findings.
- Approved-card schema lint: PASS, no missing sections and no ML hits.
- Governed allocator/resolver focused tests: PASS, 17/17.
- Approved card and EA-local build reference: byte-identical.
- Registered identity: `41236,wti-samecal-jack6`.
- Registered slot: `XTIUSD.DWX`, slot 0, magic `412360000`.
- Source SHA-256:
  `b05c20f7860516407c91f8e009d94e00de9cdffe9179f84fa20a0e6eb3cfc8e8`.
- Setfile SHA-256:
  `1a6b7f76e46c14ca8b73e101a7f1358a99f0618bd63058ca62fd3fac5c46863a`.
- Reference-test SHA-256:
  `c96de4d68798d81229b9b3d166cbda48baf02c76ef2d5f854571de57c1bf8e04`.

An ad hoc compile-skipped `build_check.ps1` invocation failed closed before
validation with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`, because active factory
terminals require the governed `COMPILE_EA` path. The separate non-compiling
guardrail validator passed. No bypass or retry was attempted.

## Capacity Gate

Five one-second `Processor(_Total)\\% Processor Time` samples were:

`96.201327, 97.962717, 90.821328, 88.483558, 92.098775`

- average: `93.113541%`
- maximum: `97.962717%`
- hard ceiling: `97.0%`
- verdict: `CEILING_HIT`

## Exact Remaining Work

When a fresh capacity window is below the hard ceiling:

1. Create/bind the governed build task for the committed approved card.
2. Enqueue and release exactly one hash-bound `COMPILE_EA` item.
3. Require a current `.ex5`, zero errors, zero warnings, and strict Q01 PASS.
4. Only then enqueue one governed Q02 baseline for the sole RISK_FIXED setfile.

No compile item or Q02 item was enqueued in this run. No terminal process was
started, stopped, or altered. No backtest ran. AutoTrading, `T_Live`, its
manifest, and the portfolio gate were untouched.
