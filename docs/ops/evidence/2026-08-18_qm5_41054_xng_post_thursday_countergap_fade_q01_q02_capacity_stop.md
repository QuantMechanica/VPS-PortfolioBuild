# QM5_41054 XNG Post-Thursday Counter-Gap Fade - Q01 And Q02 Capacity Stop

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED - CPU CEILING`

## Candidate And Claim Boundary

`QM5_41054_xng-postthu-gap-fade` is a low-frequency, symmetric natural-gas
candidate on exact `XNGUSD.DWX`, D1. At the first executable broker Friday
after exact completed Tuesday, Wednesday, and standard-Thursday sessions, it
computes:

```text
event_session_flow = ln(ThursdayClose / ThursdayOpen)
post_event_gap      = ln(FridayOpen / ThursdayClose)
confirmed_path      = ln(FridayOpen / ThursdayOpen)
total_flow          = event_session_flow + post_event_gap
```

It trades only when the two finite nonzero components strictly oppose, the
completed Thursday event-session component is strictly larger in absolute
magnitude, and `total_flow` reconciles to `confirmed_path` within `1e-10`.
The EA trades in the event-session sign, fading the smaller later counter-gap.
The Friday D1 open is frozen; later current-bar prices cannot enter the signal.
A durable Friday attempt is consumed before every fallible gate.

The EA freezes a `3.5 * ATR(20,D1)` hard stop, uses no target, and ordinarily
exits through framework Friday close at broker hour 21. A first-later-D1 exit
repairs a survivor and a four-day stale guard bounds malformed lifecycle state.
The sole preset is backtest-only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

This handoff establishes no profitability, certification, portfolio admission,
correlation result, or correlation waiver. Q09 alone may measure realized
overlap with the certified XAU/SP500/NDX/XNG book.

## Governance And Non-Duplicate Boundary

- source approval commit: `860798f0a`
- EA-ID reservation commit: `bd394ac36`
- pre-magic directory identity commit: `d6be617ec`
- active slot-0 magic allocation commit: `061ebd1a4`
- Strategy Card and OWNER G0 commit: `2e38149e8`
- source implementation commit: `5da73787d`
- Q01 binary/status commit: `538a37230`
- registered route: slot 0 `XNGUSD.DWX`, magic `410540000`
- source lineage: official EIA ordinary-Thursday natural-gas information
  clock, complete OWNER-supplied Williams price-flow extraction, and named
  peer-reviewed Yang-Goncu-Pantelous commodity-reversal evidence
- translation boundary: no source tests this exact conjunction, continuous
  CFD, same-Friday horizon, stop, lifecycle, or portfolio relationship

The canonical pre-allocation checker scanned 4,541 EA rows and 625 root cards
and returned `CLEAN`. This card admits only strict opposition plus event-
session dominance. Its eligible states are disjoint from the same-endpoint
agreement/continuation sibling `QM5_41052`. Manual review also separated it
from the earlier internal-Thursday flow fade `QM5_41044`, exact-clock M30
storage systems, multiday drift, the WTI carrier `QM5_41053`, and certified
`QM5_12567`, a long-only XNG cumulative-RSI pullback.

Manual verdict:
`CLEAN_XNG_STANDARD_THURSDAY_EVENT_SESSION_POST_EVENT_COUNTERGAP_STRICT_OPPOSITION_EVENT_DOMINANCE_FADE_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 16 tests PASS. Coverage includes native and
  uniform `+1` labels, exact Tuesday-through-Thursday identity, missing-
  session rejection, Friday grace, both trade sides, agreement/zero/equality/
  counter-gap-dominance rejection, reconciliation, invalid endpoints, frozen
  Friday open, stable attempt identity, Friday cutoff, and later-D1 repair.
- Both Strategy Card copies are byte-identical and pass schema, prohibited-ML,
  and G0 lint.
- Strict targeted MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_232251/QM5_41054_xng-postthu-gap-fade.compile.log`.
- Targeted V5 build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_232353.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41054/P1/P1_QM5_41054_result.json`.
- Factory symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- MQ5 SHA-256:
  `3AFCD561CE4E07DBA7A74D092FC1EBA0D5FFB25131465D3DF962CCBBC588B2C3`.
- Compiled EX5 SHA-256:
  `3EE020E8D2EA13D1A065FC4F171DC8694DD6C7E5DF414C966FB8CDA7D7C1E0D5`.
- Backtest-set byte SHA-256:
  `4D1370C247782C7574B30A6EFAD3F08BF4042889E71E80E44B479046E7455028`.
- Backtest-set normalized-content build hash:
  `5622b155b402d72b7b5cb699262d0ac2f2ad87aa0da9224b9dd4170ab527c277`.

No manual tester, smoke test, phase runner, dispatcher tick, or backtest was
invoked during Q01.

## Q02 Dry Run And Mandatory Capacity Stop

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded or recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41054 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only `farmctl.py mt5-slots` census at
`2026-08-17T23:25:37Z` found five active exact-path research terminals:
`T1`, `T3`, `T5`, `T6`, and `T8`. This was below the governed seven-terminal
ceiling. The census observed `T_Live` and an unrelated FTMO terminal only to
exclude them; neither was touched. The configured
`D:/QM/strategy_farm/state/launch_gate_max.txt` value was `1`.

The binding five-sample whole-host CPU reading from
`2026-08-17T23:25:43Z` through `23:25:52Z` measured `98`, `91`, `100`, `99`,
and `91` percent (average `95.80`, maximum `100.00`). The maximum exceeded the
explicit 97% hard host-CPU ceiling.

Per the mission's stop condition, the `--apply` command was not run. The
immediate read-only work-item query returned `count=0`, confirming no Q02 row
exists for this EA.

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
current-price leakage beyond frozen Friday open, late or repeated entry, wrong
Friday lifecycle, nondeterminism, invalid fixed-risk state, or an unusable
standard-Thursday proxy.
