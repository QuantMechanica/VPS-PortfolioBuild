# QM5_41028 WTI Month-Boundary Gap Fade — Q01 PASS / Q02 CPU-Ceiling Stop

Date: 2026-08-16 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT_ENQUEUED`

## Candidate And Claim Boundary

`QM5_41028_wti-mgap-fade` is a new exact-`XTIUSD.DWX`, D1,
low-frequency structural calendar/gap-reversal strategy. On the first genuine
normalized broker-month session, it measures
`log(Open[0] / Close[1])` from the fixed current D1 open and the prior completed
D1 close. A negative gap selects BUY, a positive gap selects SELL, and an exact
zero remains flat. Entry is allowed only during the first 180 minutes, the
month attempt is consumed before fallible gates, the frozen hard stop is
`3.0 * ATR(20,D1)`, and a position exits at the next normalized D1 boundary
with a four-day stale-position guard. There is no profit target.

Hoelscher, Mbanga, and Nelson (2017) provide peer-reviewed WTI
weekend/calendar-return lineage. Yang, Goncu, and Pantelous (2017) provide
commodity short-horizon reversal lineage. Neither source tests this exact
month-boundary-gap conjunction, Darwinex broker-session normalization,
continuous CFD carrier, 180-minute attachment window, next-D1 lifecycle,
fixed cash risk, or ATR stop. Those are disclosed QM falsification choices;
no source performance transfers.

Direct WTI adds crude-oil exposure outside the certified XAU, SP500, NDX, and
XNG book and uses a boundary-gap fade rather than the existing XNG oscillator
pullback. This establishes carrier and mechanic novelty, not realized
decorrelation, certification, profitability, or portfolio admission. Q09
alone may establish correlation if the candidate survives earlier gates.

## Approval, Allocation, And Non-Duplicate Boundary

- Source approval:
  `50d77b36ad57670a3943a9e412d4202b42d03226`.
- Deterministic allocation of `QM5_41028`:
  `304417eb658a6d0382b2d7a1473c15168f81905e`.
- Strategy Card and OWNER G0 approval:
  `2898c7d3b2ded00edcfff15340c06d3aba4a05ec`.
- Magic registration and resolver regeneration:
  `a8206a74360cc935cb33c98cad5557f51f0f9873`.
- V5 implementation and Q01 seal:
  `8b226c5c4450b8842f028fdf1911000cc6d13974`.
- Magic tuple:
  `41028,wti-mgap-fade,0,XTIUSD.DWX,410280000`.
- The canonical pre-card checker scanned 4,515 registry rows and 611 root
  cards without an exact or fuzzy identity.
- Manual family review separated thresholded one-sided Friday/Monday gap
  fills (`QM5_12750`, `QM5_12779`), breakaway-gap continuation
  (`QM5_20217`, `QM5_20230`), second-session first-session-return fade
  (`QM5_41027`), five-session prior-month momentum (`QM5_41016`), and the XNG
  oscillator pullback (`QM5_12567`) from this first-session boundary-gap fade.
- Verdict:
  `CLEAN_WTI_FIRST_MONTH_SESSION_BOUNDARY_GAP_FADE_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Backtest preset:
  `framework/EAs/QM5_41028_wti-mgap-fade/sets/QM5_41028_wti-mgap-fade_XTIUSD.DWX_D1_backtest.set`.
- Locked risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; news axes OFF; Friday close enabled at broker hour 21.
- Reference suite: eight tests PASS for month/session identity, prior-close and
  current-open endpoints, contrarian direction, the exact-zero flat case,
  entry-window bounds, single monthly attempt, next-D1 exit, and stale guard.
- Strict MetaEditor compile: PASS, 0 errors, 0 warnings. Log:
  `framework/build/compile/20260816_180551/QM5_41028_wti-mgap-fade.compile.log`.
- Final targeted strict build check: PASS, 0 failures, 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260816_180900.json`.
- Static P1: PASS:
  `D:/QM/reports/pipeline/QM5_41028/P1/P1_QM5_41028_result.json`.
- Exact-symbol scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- All three Strategy Card copies are byte-identical and pass schema/ML lint.
- Target-specific resolver regeneration kept 16,077 active rows and dropped
  zero; the targeted strict build gate has no magic, compile, setfile,
  forbidden-code, performance, or schema finding.

## Binding Capacity Gate

The first path-anchored read-only sample at
`2026-08-16T18:10:13.7746534Z` counted only `terminal64.exe` processes whose
executable path matched exact `D:/QM/mt5/T1..T10/terminal64.exe` roots. It
explicitly excluded `T_Live` and every non-factory terminal:

| Terminal | PID |
|---|---:|
| T1 | 16444 |
| T2 | 9016 |
| T3 | 11772 |
| T4 | 20308 |
| T5 | 13944 |
| T7 | 3292 |
| T8 | 19092 |
| T9 | 16048 |

Eight factory terminals were running, exceeding the seven-terminal
paced-fleet ceiling. Per the mission stop condition, no target-only queue dry
run, enqueue/apply command, dispatcher tick, Q02 runner, or manual tester was
invoked. Q02 therefore remains `NOT_ENQUEUED`; this handoff created no Q02
work item.

## Artifact Integrity

| Artifact | SHA-256 |
|---|---|
| source approval | `abaa3569221e6d677e3fc62979c33335d09861949c98a3cbfa70959f58ce9401` |
| G0 decision | `7aa8f0c05f27a32d48a1c6b58778e8a0bf54e99906fa0e243c7565e7408bd597` |
| governed source packet | `0180532123869269ceea9df75757b0231af98fddb60b8eed496092dcfe2ed43c` |
| each of three synchronized cards | `130fa3d23848a33fcbb5470d1ab3abd61ed50b86ac23f372d38c2c66011cd49b` |
| MQ5 source | `c379b14dfb6d9922078a0e998feee34fb87ba8051e4a29d1cb9a45cc314f49b3` |
| compiled EX5 | `301e935d5bbc0b7aaf1ac14df83c84daaa85d908684e90395f51a2e78a59c81a` |
| fixed-risk setfile | `7c6a9a2e921c90d55c8c9f5db4743d86ae0912315e51a5df94e6b8c6a6da4098` |
| reference test | `6c1af480636591d95af190db063b5f1f56542b13cdb84c17c34eb1e0f6b001b3` |
| strict build-check report | `8353642367f15286df6d820631d100e7e97121600fe26238ce9f59ca403b6633` |
| static P1 result | `51b451b5198a99c0800a4a9078ac4c3f8314d8c306db8cb2eb9f2bcafea78dde` |

## Safety And Handoff

No queue command, Q02 backtest, worker reservation, terminal start/stop,
AutoTrading action, `T_Live` mutation, live/demo/shadow/stress preset,
portfolio-gate edit, portfolio admission, deploy manifest, or T_Live-manifest
edit occurred.

The next authorized action is one target-only paced Q02 enqueue only after a
fresh path-anchored T1-T10 sample is below seven. Q02 must retire on zero
trades, fewer than five completed positions per full post-warm-up year, wrong
month/session or gap endpoints/direction, current-bar leakage, late or
repeated entry, wrong lifecycle, nondeterminism, invalid risk mode, or
nonpositive governed economics. This receipt records a capacity stop, not a
Q02 verdict, certification, profitability result, decorrelation finding, or
portfolio admission.
