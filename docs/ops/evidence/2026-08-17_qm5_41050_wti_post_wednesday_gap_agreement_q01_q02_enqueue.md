# QM5_41050 WTI Post-Wednesday Gap Agreement - Q01 And Q02 Handoff

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; ONE PACED Q02 ITEM ENQUEUED`

## Candidate And Claim Boundary

`QM5_41050_wti-postwed-gap-agree` is a low-frequency single-carrier WTI
candidate on exact `XTIUSD.DWX`, D1. At the first executable broker Thursday
after exact completed Monday, Tuesday, and standard-Wednesday sessions, it
computes:

```text
event_session_flow = ln(WednesdayClose / WednesdayOpen)
post_event_gap      = ln(ThursdayOpen / WednesdayClose)
confirmed_path      = ln(ThursdayOpen / WednesdayOpen)
total_flow          = event_session_flow + post_event_gap
```

It trades only when the two finite nonzero components strictly agree in sign
and `total_flow` reconciles to `confirmed_path` within `1e-10`. Positive
agreement buys and negative agreement sells at the first executable Thursday
tick. The Thursday D1 open is frozen; later current-bar prices cannot enter the
signal. The EA freezes a `3.0 * ATR(20,D1)` hard stop, uses no target, and exits
at the first later D1 boundary. A durable Thursday attempt is consumed before
every fallible entry gate. Friday close remains enabled at broker hour 21 as a
fail-safe, and a three-day stale guard bounds malformed lifecycle state.

The sole preset is backtest-only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. This handoff does not establish profitability,
certification, portfolio admission, or realized decorrelation. Q09 alone may
measure overlap with the certified XAU/SP500/NDX/XNG book.

## Governance And Non-Duplicate Boundary

- source approval commit: `8ee045854`
- EA-ID reservation commit: `ecf6d8322`
- pre-magic directory identity commit: `ca5616059`
- active magic row/resolver durable in commit: `484039aea`
- Strategy Card and OWNER G0 commit: `9668116bb`
- source implementation commit: `e21902eb7`
- Q01 binary/status commit: `185c2142a`
- registered route: slot 0 `XTIUSD.DWX`, magic `410500000`
- source lineage: official EIA ordinary-Wednesday petroleum clock, complete
  OWNER-supplied Williams price-flow extraction, and complete-read
  peer-reviewed Moskowitz-Ooi-Pedersen own-return continuation evidence
  explicitly including WTI
- source boundary: no source tests the exact conjunction, continuous CFD,
  one-D1 horizon, risk, stop, or portfolio relationship

The canonical pre-allocation checker scanned 4,537 EA rows and 625 root cards
and found no exact slug, strategy-ID, or fuzzy mechanic identity. Manual family
review separated this candidate from:

- `QM5_41042`, whose two agreement components are both complete by Wednesday
  close and do not use the later Thursday-open confirmation;
- `QM5_41049`, which requires opposed internal-Wednesday components and strict
  overnight dominance;
- `QM5_41041`, which fades opposed, session-dominant internal-Wednesday flow;
- `QM5_41043`, which uses XNG's completed Thursday and enters Friday;
- `QM5_12579`, which requires a large event bar;
- `QM5_12988`, which uses two events plus moving-average/channel confirmation;
  and
- certified `QM5_12567`, a long-only two-day XNG oscillator pullback.

Manual verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_EVENT_SESSION_POST_EVENT_GAP_STRICT_AGREEMENT_CONTINUATION_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 14 tests PASS. Coverage includes native and
  uniform `+1` energy labels, missing-session rejection, exact weekday
  sequence, Thursday grace, both continuation sides, opposition/zero/invalid
  rejection, reconciliation, authorized endpoints, frozen-open behavior,
  stable attempt identity, and first-later-D1 exit.
- Both Strategy Card copies are byte-identical and pass the card schema and
  prohibited-ML lint.
- Strict targeted MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_192000/QM5_41050_wti-postwed-gap-agree.compile.log`.
- Targeted build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_192000.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41050/P1/P1_QM5_41050_result.json`.
- Factory symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- MQ5 SHA-256:
  `85BD29D5E75C21CB7F257357490F7D4FE7E6700B1D0531C747E9A1DF5D40699B`.
- Compiled EX5 SHA-256:
  `46494FD5A802F66AD0B1FB3140CF7AF3486515B545CD0C20A4B40E18D5A070B7`.
- Backtest-set normalized-content build hash:
  `617a59b0f68487f9cfdbf20b3097a3f87ae9c5bea6ce970ea5fea8c433bb6ae7`.

## Q02 Capacity Gate And Enqueue

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded/recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41050 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only `farmctl.py mt5-slots` census at
`2026-08-17T19:22:24Z` found three active exact-path research terminals:
`T1`, `T4`, and `T6`. This was below the governed seven-terminal ceiling. The
census observed `T_Live` and an unrelated FTMO terminal only to exclude them;
neither was touched. The configured
`D:/QM/strategy_farm/state/launch_gate_max.txt` value was `1`.

A five-sample whole-host CPU reading through `2026-08-17T19:23:02Z` measured
`68.42`, `65.42`, `70.66`, `53.71`, and `80.06` percent (average `67.65`,
maximum `80.06`). The maximum remained below the explicit `97%` hard CPU stop.

The target-only apply therefore created exactly one work item:

- ID: `5e9a6e73-0155-497a-b61b-ff6b1b77ab09`
- phase: `Q02`
- created: `2026-08-17T19:23:16+00:00`
- route: exact `XTIUSD.DWX`, D1
- setfile:
  `framework/EAs/QM5_41050_wti-postwed-gap-agree/sets/QM5_41050_wti-postwed-gap-agree_XTIUSD.DWX_D1_backtest.set`
- initial state: `pending`, attempt count 0, unclaimed
- priority track: true

The immediate read-only work-item query confirmed that single pending row. The
post-apply target-only dry run selected zero rows, proving no duplicate queue
candidate remained. The operator did not invoke a dispatcher tick or start,
stop, kill, attach to, or otherwise control any terminal, worker, tester, or
backtest process.

## Safety And Handoff

The Q02 action used the canonical de-duplicating paced queue. No manual
backtest, terminal or worker mutation, AutoTrading action,
live/demo/shadow/stress/optimization preset, `T_Live` change, deploy/T_Live
manifest, portfolio-gate edit, portfolio admission, decorrelation claim, or
correlation waiver occurred.

The paced fleet owns the pending Q02 item. Q02 must retire the identity on zero
trades, fewer than five completed positions per full post-warm-up year,
nonpositive governed economics, wrong weekday/endpoints, absent strict
agreement, wrong continuation side, failed reconciliation, current-price
leakage beyond frozen Thursday open, late/repeated entry, wrong next-D1
lifecycle, nondeterminism, invalid risk mode, or an unusable standard-
Wednesday proxy.
