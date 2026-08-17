# QM5_41052 XNG Post-Thursday Gap Agreement - Q01 PASS / Q02 Capacity Stop

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED - HOST CPU CEILING REACHED`

## Candidate And Claim Boundary

`QM5_41052_xng-postthu-gap-agree` is a new low-frequency natural-gas
candidate on exact `XNGUSD.DWX`, D1. At the first executable broker-Friday
tick within 180 minutes of the D1 open, it requires exact completed Tuesday,
Wednesday, and Thursday sessions under one uniform native or `+1` energy
label convention. It computes only:

```text
event_session_flow = ln(ThursdayClose / ThursdayOpen)
post_event_gap      = ln(FridayOpen / ThursdayClose)
confirmed_path      = ln(FridayOpen / ThursdayOpen)
total_flow          = event_session_flow + post_event_gap
```

It trades only when both finite nonzero components strictly agree in sign and
`total_flow` reconciles to `confirmed_path` within `1e-10`. Positive agreement
buys and negative agreement sells through Friday. The Friday D1 open is
frozen; later current-bar prices cannot enter the signal. The EA freezes a
`3.5 * ATR(20,D1)` hard stop, uses no target, and normally exits through the
framework Friday close at broker hour 21. A first-later-D1 close and four-day
stale repair bound any survivor. The durable Friday attempt is written before
all fallible signal, history, execution, and order gates.

The sole preset is backtest-only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. This handoff does not establish profitability,
certification, portfolio admission, or realized decorrelation. Q09 alone may
measure overlap with the certified XAU/SP500/NDX/XNG book.

## Governance And Non-Duplicate Boundary

- source approval commit: `2b81789707606bb37399353cb1fcf2d3dbad6f4c`
- EA-ID reservation commit: `d33a6d11f02494169882e1ab413f5052cc04e903`
- pre-magic directory identity commit: `3e7da4f45d147530fb59e80773b02b73e3096fbb`
- active magic row/resolver commit: `0e149bab760e95ae0cb38fc180e3e6243177c5ef`
- Strategy Card and G0 commit: `66c51c7e8c877ac6814e2fb5ccb9b6c4f1b3d6b4`
- source implementation commit: `bb237c29a1d61046f7c3ec8121fdb0dce584e95c`
- Q01 binary/status commit: `f2a6d573f1db40eae9855ea97504e479c7aaa879`
- registered route: slot 0 `XNGUSD.DWX`, magic `410520000`
- source lineage: the official EIA ordinary-Thursday natural-gas information
  clock, Williams's price-flow decomposition, and Moskowitz, Ooi, and
  Pedersen's peer-reviewed own-return continuation evidence including natural
  gas
- claim boundary: no source tests this exact completed-Thursday/session-gap
  conjunction, continuous CFD, Friday horizon, stop, lifecycle, or portfolio
  relationship; those translations remain explicitly falsifiable QM choices

The canonical pre-allocation checker scanned 4,539 EA rows and 625 root cards
and returned `CLEAN`. Manual review separated this mechanic from completed-
Thursday internal-flow agreement/fade `QM5_41043` and `QM5_41044`, Thursday/
252-D1 conjunctions `QM5_41047` and `QM5_41048`, multiday storage drift
`QM5_12898`, Friday slow-trend short `QM5_20160`, and certified long-only
cumulative-RSI pullback `QM5_12567`.

Manual verdict:
`CLEAN_XNG_STANDARD_THURSDAY_EVENT_SESSION_POST_EVENT_GAP_STRICT_AGREEMENT_CONTINUATION_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 15 tests PASS. Coverage includes native and
  uniform `+1` labels, exact Tuesday-through-Friday identity, missing-session
  rejection, Friday grace, both continuation sides, opposition/zero/invalid
  rejection, reconciliation, frozen endpoints, no intrabar signal input,
  Friday-hour-21 close, later-D1 repair, and stable attempt identity.
- Both Strategy Card copies are byte-identical and pass schema, prohibited-ML,
  and G0 lint.
- Strict targeted MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_213650/QM5_41052_xng-postthu-gap-agree.compile.log`.
- Targeted V5 build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_213650.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41052/P1/P1_QM5_41052_result.json`.
- Factory symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- MQ5 SHA-256:
  `905F54511D3BA63229CF3E2897473A3D838161021DBE22715A6DE448FAD9A24D`.
- Compiled EX5 SHA-256:
  `80018AD7F73532448A3CFD352221FBACEC3D9580DB4C6760CC302637362B1948`.
- Backtest-set normalized-content build hash:
  `91314cd276b27972a9a158a4a50cd520e8cebe2ed4e2ce8af379b450c39f2078`.

## Q02 Dry Run And Mandatory Capacity Stop

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded/recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41052 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only `farmctl.py mt5-slots` census at
`2026-08-17T21:40:58Z` found two active exact-path research terminals: `T2`
and `T3`. This was below the documented seven-terminal ceiling. The census
observed `T_Live` and an unrelated FTMO terminal only to exclude them; neither
was touched. The configured
`D:/QM/strategy_farm/state/launch_gate_max.txt` value was `1`.

The separate five-sample whole-host CPU reading from
`2026-08-17T21:41:12Z` through `21:41:20Z` measured `97.51`, `90.16`,
`84.49`, `79.84`, and `80.83` percent (average `86.57`, maximum `97.51`).
The maximum exceeded the explicit 97% hard host-CPU ceiling.

Per the mission's stop condition, the `--apply` command was not run. The
immediate read-only command below returned `count=0`, confirming that no Q02
row exists for this EA:

```text
python tools/strategy_farm/farmctl.py work-items --ea QM5_41052
```

## Safety And Handoff

No Q02 enqueue, dispatcher tick, manual backtest, terminal or worker mutation,
AutoTrading action, live/demo/shadow/stress/optimization preset, `T_Live`
change, deploy/T_Live manifest, portfolio-gate edit, portfolio admission,
decorrelation claim, or correlation waiver occurred.

The candidate is committed and Q01-clean but remains unqueued. A later paced
operator may repeat the exact target-only dry run and apply only after fresh
terminal and CPU checks both pass. Q02 must retire the identity on zero trades,
fewer than five completed positions per full post-warm-up year, nonpositive
governed economics, wrong calendar/endpoints/sign/side, current-Friday signal
leakage, late or repeated entry, wrong Friday lifecycle, nondeterminism, or
invalid fixed-risk state.
