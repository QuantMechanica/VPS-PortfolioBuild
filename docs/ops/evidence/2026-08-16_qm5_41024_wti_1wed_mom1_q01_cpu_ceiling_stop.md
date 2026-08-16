# QM5_41024 WTI First-Wednesday Momentum — Q01 PASS / Q02 CPU-Ceiling Stop

Date: 2026-08-16 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT_ENQUEUED`

## Candidate And Non-Duplicate Boundary

`QM5_41024_wti-1wed-mom1` is a new exact-`XTIUSD.DWX`, D1,
low-frequency calendar/trend interaction. Only the first genuine Wednesday
of a normalized broker month may decide. It follows the sign of WTI's
immediately completed broker-calendar-month log return, consumes the month
before fallible entry gates, and closes at the next D1 boundary. A frozen
`3.0 * ATR(20,D1)` stop protects the one-session package.

The canonical dedup checker scanned 4,511 registry rows and 607 root cards
without an exact or fuzzy identity. Manual review separated the candidate
from every-Wednesday 252-day WTI trend/bear variants and full-month one-month
momentum builds by its first-Wednesday clock and one-D1 lifecycle. The source
packet combines two reputable peer-reviewed lineages: Li et al. (2022),
*Energy Economics* 106, 105817 for the WTI Wednesday information clock, and
Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
228-250 for instrument-own return-sign continuation and explicit WTI
coverage. Their conjunction and one-session hold are disclosed QM hypotheses,
not source-tested performance claims.

WTI supplies a direct crude-oil carrier outside the certified XAU, SP500,
NDX, and XNG book. That is exposure novelty, not proof of realized
decorrelation; unchanged Q09 owns that conclusion if the candidate survives
earlier gates.

## Approval, Allocation, And Build

- Source approval: `01d4b0d454e532e2c6ba384a7de56d52d693f610`.
- Deterministic allocation of `QM5_41024`: `9ee451dab125c3ac4f8950d6df2bc54919c407d1`.
- Strategy Card and OWNER G0 approval: `4c14a301919a5f2f69b55c6921bf4cf454f1cae9`.
- V5 implementation and Q01 seal: `10baad7103bab873b32781aa2b06c325a2837a72`.
- Magic tuple: `41024,wti-1wed-mom1,0,XTIUSD.DWX,410240000`.
- All three Strategy Card copies were byte-identical and passed schema/ML and
  G0 lint.

## Fixed-Risk Q01 Evidence

- Backtest preset:
  `framework/EAs/QM5_41024_wti-1wed-mom1/sets/QM5_41024_wti-1wed-mom1_XTIUSD.DWX_D1_backtest.set`.
- Locked risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; news axes OFF; Friday close enabled at broker hour 21.
- Reference suite: 7 tests PASS for exact first-Wednesday identity, missing-
  Tuesday no-shift behavior, completed-month endpoint orientation, symmetric
  sign direction, and next-D1 lifecycle.
- Strict MetaEditor compile: PASS, 0 errors, 0 warnings. Log:
  `framework/build/compile/20260816_135849/QM5_41024_wti-1wed-mom1.compile.log`.
- Strict targeted build check: PASS, 0 failures, 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260816_135723.json`.
- Static P1: PASS:
  `D:/QM/reports/pipeline/QM5_41024/P1/P1_QM5_41024_result.json`.

Artifact integrity after the capacity-status update:

| Artifact | SHA-256 |
|---|---|
| governed source packet | `1c38d4e5ce79d9fdcdd053b185abe4c10812bc0b1d978e8e93f03f6287560309` |
| each of three synchronized cards | `b49492dcfd57d21ba3b1d0b803d994930cd4f43548372a6e24db07315107d06e` |
| MQ5 source | `047d5e60314c5ce5bd6c72ba33d0440ce476784a3bac782ff5b8b50683d39882` |
| compiled EX5 | `3dde5eccbb98dbfb264e91f765325868d03217c230975626d525bbfbedbaf457` |
| fixed-risk setfile | `5b704f06900110e338b64024da8fb9a2073af4a89cd9ff07b5fdb7f8a7b361ff` |
| reference test | `fd87de3d88fa97d41caa7335410d97ccba36e9190102399a9620436b9252f4f9` |
| strict build-check report | `a47e5dc24b8fefb721aed0bc3034032ed63d97c3dced25aea6e57a851f4d34f2` |
| static P1 result | `f363cf4a5c6f63fc75803c511ce795bc6e3afa9d6d4f7bf237f7132adc310fad` |

## Binding Capacity Gate

The first path-anchored read-only sample at
`2026-08-16T14:05:08.3191733Z` counted only `terminal64.exe` processes under
exact `D:/QM/mt5/T1..T10/` roots and explicitly excluded `T_Live`:

| Terminal | PID |
|---|---:|
| T2 | 11100 |
| T3 | 13212 |
| T4 | 11424 |
| T5 | 14720 |
| T6 | 13064 |
| T7 | 13764 |
| T8 | 8712 |

That is the binding ceiling of 7/7. Per the mission stop condition, neither
the target-only queue dry run nor the apply command was invoked. Read-only
`farmctl work-items --ea QM5_41024` returned `count=0` immediately afterward.
No Q02 work item exists from this handoff.

## Safety And Handoff

No queue apply, dispatcher tick, manual tester run, pipeline phase runner,
terminal start/stop, reservation, worker mutation, AutoTrading action,
`T_Live` access, live/demo/shadow/stress preset, portfolio-gate edit,
portfolio admission, deploy manifest, or T_Live-manifest edit occurred.

The next authorized action is a target-only paced Q02 enqueue only after a
fresh path-anchored T1-T10 sample is below seven. This receipt records a
capacity stop, not a Q02 verdict, certification, profitability result,
decorrelation finding, or portfolio admission.
