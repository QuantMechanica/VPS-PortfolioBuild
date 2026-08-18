# QM5_41058 XNG Weekly Flow Agreement - Q01 And Q02 Capacity Stop

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED - TESTER CAPACITY AND CPU CEILING`

## Candidate And Portfolio Boundary

`QM5_41058_xng-wflow-agree` is a low-frequency structural natural-gas
candidate. On the first eligible normalized Monday D1 tick it reconstructs the
exact completed prior Monday-through-Friday week plus the preceding-Friday
close anchor. It sums five close-to-open log returns separately from five
open-to-close log returns, reconciles their total to the completed weekly
endpoint within `1e-10`, and follows the week only when both component signs
strictly agree:

```text
overnight_flow > 0 and session_flow > 0 => BUY XNG
overnight_flow < 0 and session_flow < 0 => SELL XNG
otherwise                               => consume Monday flat
```

The exact broker Monday owns one durable attempt before every fallible entry
gate. The baseline uses one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1` position, a frozen `3.0 * ATR(20,D1)` hard stop, no
target, a 3,000-point spread ceiling, both news axes OFF, framework Friday
close at broker hour 21, and later-week/eight-day stale repair.

This is not a duplicate of the certified `QM5_12567` commodity logic, which
is a long-only two-day cumulative-RSI pullback. This EA is symmetric weekly
continuation, admits only completed close/open component agreement, has no
oscillator, and holds on a Monday-to-Friday clock. It is a disclosed XNG
carrier port of `QM5_41029_wti-flow-agree`; no WTI result transfers. This
handoff establishes no profitability, certification, portfolio admission,
CFD/futures equivalence, realized decorrelation, or correlation waiver. Q09
alone may measure overlap with the certified book.

## Source And Governance

- Williams, Larry R. (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
  Trading: complete OWNER-supplied Tier-A close/open-flow extraction.
- Moskowitz, Tobias J., Ooi, Yao Hua, and Pedersen, Lasse Heje (2012), "Time
  Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
  `10.1016/j.jfineco.2011.11.003`: complete-paper governed record and explicit
  natural-gas membership, without transfer of pooled results.
- source approval commit: `929a14cae`
- deterministic EA reservation commit: `c32cc25b8`
- active slot-0 magic/resolver commit: `b2ae5243b`
- Strategy Card and G0 commit: `8a82c7968`
- source implementation and binary commit: `33a18a4e6`
- registered route: `XNGUSD.DWX`, D1, slot 0, magic `410580000`

The canonical pre-card checker scanned 4,545 registry rows and 625 root cards,
found no exact identity, and raised only expected source-family neighbors.
Manual review returned
`CLEAN_XNG_WEEKLY_OVERNIGHT_SESSION_FLOW_AGREEMENT_CARRIER_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 13 tests `PASS`. Coverage includes native and
  governed energy labels, exact Monday-Friday calendar identity, holiday
  rejection, inclusive three-hour grace, both agreement directions,
  opposition/zero rejection, endpoint reconciliation and its locked
  tolerance, invalid prices, later-week repair, and exact attempt identity.
- Both Strategy Card copies are byte-identical and pass schema, prohibited-ML,
  and G0 lint.
- Strict targeted MetaEditor compile: `PASS`, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260818_033249/QM5_41058_xng-wflow-agree.compile.log`.
- Targeted V5 build check: `PASS`, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260818_033248.json`.
- Static P1 artifact validation: `PASS`:
  `D:/QM/reports/pipeline/QM5_41058/P1/P1_QM5_41058_result.json`.
- MQ5 SHA-256:
  `E19BFAF552111C90C7DB8B04F9B721DC786B55C1147C35E777002F608CCC768D`.
- compiled EX5 SHA-256:
  `0F7417BA89355ECBA1374CFE9621AFF5475A643E7E491BBCC141BF932AD73C40`.
- backtest-set byte SHA-256:
  `A29BAD4DBF97B00B643D1AB009E803C5B3F643B47AB6404E51D8D942872558D1`.
- backtest-set normalized-content build hash:
  `fd0bac5af28a781d0800eb46ee8a44ad33066520dde9d1b4d7f8e9180d92740a`.

No manual tester, smoke test, pipeline-phase runner, dispatcher tick, or
backtest was invoked during Q01.

## Q02 Dry Run And Mandatory Capacity Stop

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded or recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41058 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only exact-path `farmctl.py mt5-slots` census at
`2026-08-18T03:34:48Z` found seven active governed research terminals: `T1`,
`T2`, `T4`, `T5`, `T6`, `T7`, and `T8`. This is the governed seven-terminal
ceiling, so the precondition that capacity remain below the ceiling was not
met. `T_Live` and an unrelated FTMO terminal were observed only so they could
be excluded; neither was touched.

The binding five-sample `GetSystemTimes` whole-host CPU reading completed at
`2026-08-18T03:36:22Z`. Two-second samples were `100.00`, `99.85`, `99.90`,
`99.66`, and `99.81` percent (average `99.84`, maximum `100.00`). Every sample
exceeded the explicit 97% hard host-CPU ceiling.

Per the mission's stop condition, the `--apply` command was not run. The
immediate read-only `farmctl.py work-items --ea QM5_41058` query returned
`count=0`, confirming that no Q02 row exists for this EA.

## Safety And Handoff

No Q02 enqueue, dispatcher tick, manual backtest, terminal or worker mutation,
AutoTrading action, live/demo/shadow/stress/optimization preset, `T_Live`
change, deploy or T_Live manifest, portfolio-gate edit, portfolio admission,
decorrelation claim, or correlation waiver occurred.

A later paced operator may repeat the exact target-only dry run and apply only
after fresh terminal and CPU checks both pass. Q02 must retire the identity on
zero trades, fewer than five completed positions per full post-warm-up year,
nonpositive governed economics, wrong week identity or endpoint arithmetic,
current-bar leakage, component opposition, failed reconciliation, wrong
direction, late/repeated entry, wrong lifecycle, nondeterminism, invalid fixed-
risk mode, or insufficient XNG history.
