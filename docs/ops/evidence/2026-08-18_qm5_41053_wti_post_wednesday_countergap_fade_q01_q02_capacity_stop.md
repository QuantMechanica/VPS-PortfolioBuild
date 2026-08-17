# QM5_41053 WTI Post-Wednesday Counter-Gap Fade - Q01 And Q02 Capacity Stop

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED - CPU CEILING`

## Candidate And Claim Boundary

`QM5_41053_wti-postwed-gap-fade` is a low-frequency, symmetric WTI candidate
on exact `XTIUSD.DWX`, D1. At the first executable broker Thursday after exact
completed Monday, Tuesday, and standard-Wednesday sessions, it computes:

```text
event_session_flow = ln(WednesdayClose / WednesdayOpen)
post_event_gap      = ln(ThursdayOpen / WednesdayClose)
confirmed_path      = ln(ThursdayOpen / WednesdayOpen)
total_flow          = event_session_flow + post_event_gap
```

It trades only when the two finite nonzero components strictly oppose, the
completed Wednesday event-session component is strictly larger in absolute
magnitude, and `total_flow` reconciles to `confirmed_path` within `1e-10`.
The EA trades in the event-session sign, fading the smaller later counter-gap.
The Thursday D1 open is frozen; later current-bar prices cannot enter the
signal. A durable Thursday attempt is consumed before every fallible gate.

The EA freezes a `3.0 * ATR(20,D1)` hard stop, uses no target, and exits at the
first later D1 boundary. Friday close at broker hour 21 is a fail-safe and a
three-day stale guard bounds malformed lifecycle state. The sole preset is
backtest-only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

This handoff establishes no profitability, certification, portfolio
admission, correlation result, or correlation waiver. Q09 alone may measure
realized overlap with the certified XAU/SP500/NDX/XNG book.

## Governance And Non-Duplicate Boundary

- source approval commit: `afdedce04`
- EA-ID reservation commit: `2cd8ff7a9`
- pre-magic directory identity commit: `3d26b62a5`
- active slot-0 magic allocation commit: `b702a0069`
- Strategy Card and OWNER G0 commit: `9cad8ec58`
- source implementation commit: `f9e45b783`
- Q01 binary/status commit: `f73bf2a83`
- registered route: slot 0 `XTIUSD.DWX`, magic `410530000`
- source lineage: official EIA ordinary-Wednesday petroleum information
  clock, complete OWNER-supplied Williams price-flow extraction, and named
  peer-reviewed Yang-Goncu-Pantelous commodity-reversal evidence
- translation boundary: no source tests this exact conjunction, continuous
  CFD, one-D1 horizon, stop, lifecycle, or portfolio relationship

The canonical pre-allocation checker scanned 4,540 EA rows and 625 root cards
and returned `CLEAN`. Formula search found the event-session/post-event-gap
endpoint pair only in strict-agreement carriers `QM5_41050` and `QM5_41052`.
This card admits the disjoint strict-opposition plus event-dominance state.
Manual review also separated it from internal-Wednesday flow fade/agreement/
dominance (`QM5_41041`, `QM5_41042`, `QM5_41049`), magnitude/body/mean WPSR
systems, exact-clock M30 systems, and certified `QM5_12567`, a long-only XNG
cumulative-RSI pullback.

Manual verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_EVENT_SESSION_POST_EVENT_GAP_STRICT_OPPOSITION_EVENT_DOMINANCE_COUNTERGAP_FADE_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 15 tests PASS. Coverage includes native and
  uniform `+1` labels, exact Monday-through-Wednesday identity, missing-session
  rejection, Thursday grace, both trade sides, agreement/zero/equality/
  counter-gap-dominance rejection, reconciliation, invalid endpoints, frozen
  Thursday open, stable attempt identity, and first-later-D1 exit.
- Both Strategy Card copies are byte-identical and pass schema, prohibited-ML,
  and G0 lint.
- Strict targeted MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_223209/QM5_41053_wti-postwed-gap-fade.compile.log`.
- Targeted V5 build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_223209.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41053/P1/P1_QM5_41053_result.json`.
- Factory symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- MQ5 SHA-256:
  `0055E2028530E7A36B24F5A71C52C0E92213A84DABC729EB3363FC3E357ACCC8`.
- Compiled EX5 SHA-256:
  `AEB352DEF9B96FE01D68D53A9999249336C11C70A2B9202413F03D2073A9B6FB`.
- Backtest-set byte SHA-256:
  `0C6CC9D24FA860C61891EB891DA0B590AD6BB95F961268AFD6B215B91DCC3F71`.
- Backtest-set normalized-content build hash:
  `8ed823391c720cd73d6ddb3f55ce5e0e597ffaa3440331afd3a182971851a97f`.

No manual tester, smoke test, phase runner, dispatcher tick, or backtest was
invoked during Q01.

## Q02 Dry Run And Mandatory Capacity Stop

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded or recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41053 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only `farmctl.py mt5-slots` census at
`2026-08-17T22:34:36Z` found three active exact-path research terminals:
`T1`, `T4`, and `T7`. This was below the governed seven-terminal ceiling. The
census observed `T_Live` and an unrelated FTMO terminal only to exclude them;
neither was touched. The configured
`D:/QM/strategy_farm/state/launch_gate_max.txt` value was `1`.

The separate five-sample whole-host CPU reading from
`2026-08-17T22:34:56Z` through `22:35:04Z` measured `86.87`, `91.14`,
`82.38`, `97.31`, and `100.00` percent (average `91.54`, maximum `100.00`).
The maximum exceeded the explicit 97% hard host-CPU ceiling.

Per the mission's stop condition, the `--apply` command was not run. The
immediate read-only work-item query returned `count=0`, confirming no Q02 row
exists for this EA. A second target-only dry run still selected exactly one
fresh row, confirming the candidate remains eligible and unmutated.

## Safety And Handoff

No Q02 enqueue, dispatcher tick, manual backtest, terminal or worker mutation,
AutoTrading action, live/demo/shadow/stress/optimization preset, `T_Live`
change, deploy/T_Live manifest, portfolio-gate edit, portfolio admission,
decorrelation claim, or correlation waiver occurred.

The candidate is committed and Q01-clean but remains unqueued. A later paced
operator may repeat the exact target-only dry run and apply only after fresh
terminal and CPU checks both pass. Q02 must retire the identity on zero trades,
fewer than five completed positions per full post-warm-up year, nonpositive
governed economics, wrong weekday/endpoints/sign/side, failed reconciliation,
current-price leakage beyond frozen Thursday open, late or repeated entry,
wrong next-D1 lifecycle, nondeterminism, invalid fixed-risk state, or an
unusable standard-Wednesday proxy.
