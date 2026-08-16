# QM5_41027 WTI Month-Opening Reversal — Q01 PASS / Q02 CPU-Ceiling Stop

Date: 2026-08-16 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT_ENQUEUED`

## Candidate And Claim Boundary

`QM5_41027_wti-mopen-rev1` is a new exact-`XTIUSD.DWX`, D1,
low-frequency structural calendar/reversal strategy. On exactly the second
genuine normalized broker-month session, it fades the completed first
session's `log(Close[1]/Open[1])` sign and exits at the first later normalized
D1 boundary. The broker month is consumed before fallible gates, both long and
short paths use a frozen `3.0 * ATR(20,D1)` hard stop, and framework Friday
close remains enabled as a fail-safe.

Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
supply own-return-sign and explicit WTI lineage. Yang, Goncu, and Pantelous,
SSRN 3069253, supply fixed-horizon commodity-reversal lineage. Neither source
tests this exact first-session/second-session conjunction, Darwinex broker-
month mapping, continuous CFD carrier, one-session lifecycle, fixed cash risk,
or ATR stop. Those are disclosed QM falsification choices; no source
performance transfers.

Direct WTI adds crude-oil exposure outside the certified XAU, SP500, NDX, and
XNG book. That establishes carrier and mechanic novelty, not realized
decorrelation, certification, profitability, or portfolio admission. Q09
alone may establish correlation if the candidate survives earlier gates.

## Approval, Allocation, And Non-Duplicate Boundary

- Source approval:
  `664785e3f86c8da33f77b926895210be0aebff40`.
- Deterministic allocation of `QM5_41027`:
  `f23679b06190019f2b364af92b76f45773a61498`.
- Strategy Card and OWNER G0 approval:
  `ca9b50d6766fd5ae5dc9f7a072eb4d150d7db1a0`.
- Magic registration and resolver regeneration:
  `55a58b5c9b5a1d699563e43a8968f8a40bb05670`.
- V5 implementation and Q01 seal:
  `6a0fe8f90d831416793936e6a60b3e963108a6cd`.
- Magic tuple:
  `41027,wti-mopen-rev1,0,XTIUSD.DWX,410270000`.
- The canonical pre-card checker scanned 4,514 registry rows and 610 root
  cards without an exact identity. Manual review separated the sole fuzzy
  sibling `QM5_41013_wti-mopen-mom`, which follows five opening sessions from
  session six through month end, from this one-session fade.
- Verdict:
  `CLEAN_WTI_SECOND_SESSION_FIRST_SESSION_REVERSAL_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Backtest preset:
  `framework/EAs/QM5_41027_wti-mopen-rev1/sets/QM5_41027_wti-mopen-rev1_XTIUSD.DWX_D1_backtest.set`.
- Locked risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; news axes OFF; Friday close enabled at broker hour 21.
- Reference suite: eight tests PASS for exact ordinal-session identity,
  holiday gaps, zero-or-one-day energy-label normalization, the 180-minute
  attachment boundary, consecutive months, completed first-session endpoints,
  contrarian direction, and later-D1/stale exits.
- Strict MetaEditor compile: PASS, 0 errors, 0 warnings. Log:
  `framework/build/compile/20260816_171720/QM5_41027_wti-mopen-rev1.compile.log`.
- Targeted strict build check: PASS, 0 failures, 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260816_171720.json`.
- Static P1: PASS:
  `D:/QM/reports/pipeline/QM5_41027/P1/P1_QM5_41027_result.json`.
- All three Strategy Card copies are byte-identical and pass schema/ML lint.
- The repo-wide historical registry audit still reports unrelated legacy
  missing/mismatched rows. The target-specific resolver generation kept
  16,076 active rows, dropped zero, and the targeted strict build gate has no
  magic, compile, setfile, forbidden-code, performance, or schema finding.

## Binding Capacity Gate

The first path-anchored read-only sample at
`2026-08-16T17:21:07.7097700Z` counted only `terminal64.exe` processes whose
executable path matched exact `D:/QM/mt5/T1..T10/terminal64.exe` roots. It
explicitly excluded `T_Live` and every non-factory terminal:

| Terminal | PID |
|---|---:|
| T1 | 1236 |
| T2 | 9016 |
| T3 | 11772 |
| T4 | 7740 |
| T7 | 3292 |
| T8 | 20200 |
| T10 | 17908 |

Seven factory terminals were running, exactly the seven-terminal paced-fleet
ceiling. Per the mission stop condition, neither a target-only queue dry run
nor any apply/enqueue command was invoked. Read-only
`farmctl work-items --ea QM5_41027` returned `count=0` immediately after the
sample. No Q02 work item exists from this handoff.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `a6deeb6f252264940deea1fe05890cf843c1baccf5918543c7e3a69a7fa1f704` |
| G0 decision | `8e826c808a1d87779efe42a825a5faef4f2de219fd1c8f9aa61f506dc4e5277a` |
| governed source packet | `0a97b5164570deaf0eb64e37b611450f551b61b259df81f7eacf2de3cd35ccba` |
| each of three synchronized cards | `0f2793973f72aafe382d3f7a238eb86c441c6a2b7099a2950b292f352728708c` |
| MQ5 source | `db44ddbc6799212620278bc5e9ef541530e1734b782c45df54c5d0d0995a586e` |
| compiled EX5 | `0baa61f782e5e43c297ecd42cbea1add129a5f88fc275eb3c5bb61ec172f2081` |
| fixed-risk setfile | `0739d646c74c7200af3937d08881c2e09e638a6de3e7193b07c4bb5a962fb956` |
| reference test | `f1d142a3113400041580728ba2709b882fb7487313f1d6bc9f4109a1bbac420d` |
| strict build-check report | `4d3ac7f8ac01cd75f8e9470aaaddb22af87632573bac8b3cd2ce3ee40c009036` |
| static P1 result | `085d8268ee53c1ab4ab08bdd40737b56530e34655a0cef0ab59e5b806ecb0e5b` |

## Safety And Handoff

No queue dry run, queue apply, dispatcher tick, manual tester run, pipeline
phase runner, terminal start/stop, reservation, worker mutation, AutoTrading
action, `T_Live` access, live/demo/shadow/stress preset, portfolio-gate edit,
portfolio admission, deploy manifest, or T_Live-manifest edit occurred.

The next authorized action is one target-only paced Q02 enqueue only after a
fresh path-anchored T1-T10 sample is below seven. Q02 must retire on zero
trades, fewer than five completed positions per full post-warm-up year, wrong
session/endpoints/direction, current-bar leakage, late or repeated entry,
wrong lifecycle, nondeterminism, invalid risk mode, or nonpositive governed
economics. This receipt records a capacity stop, not a Q02 verdict,
certification, profitability result, decorrelation finding, or portfolio
admission.
