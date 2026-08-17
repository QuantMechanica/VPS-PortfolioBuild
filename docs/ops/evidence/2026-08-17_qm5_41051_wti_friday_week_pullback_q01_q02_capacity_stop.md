# QM5_41051 WTI Friday Week Pullback - Q01 PASS / Q02 Capacity Stop

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED - HOST CPU CEILING REACHED`

## Candidate And Claim Boundary

`QM5_41051_wti-fri-weekfade` is a new low-frequency WTI candidate on exact
`XTIUSD.DWX`, D1. At the first executable tick of a genuine broker Friday it
requires exact completed Monday, Tuesday, Wednesday, and Thursday sessions
under one uniform native or `+1` energy-label convention. It computes only:

```text
formation_return = ln(ThursdayClose / MondayOpen)
```

The strategy buys only when that completed formation is strictly negative.
Positive, zero, invalid, late, or broken-calendar states consume Friday flat.
No current-Friday price enters the signal. The EA freezes a
`3.0 * ATR(20,D1)` hard stop, uses no target, and normally exits through the
framework Friday close at broker hour 21. A first-later-D1 close and three-day
stale close repair any survivor. The durable Friday attempt is written before
all fallible signal, history, execution, and order gates.

The sole preset is backtest-only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. This handoff does not establish profitability,
certification, portfolio admission, or realized decorrelation. Q09 alone may
measure overlap with the certified XAU/SP500/NDX/XNG book.

## Governance And Non-Duplicate Boundary

- source approval commit: `286fd512d04099cda196e416fb30f11919ee33f6`
- EA-ID reservation commit: `5ec8bb0972b8ebf73848704c4d43cc236b6736fd`
- pre-magic directory identity commit: `d0585138e323f167fe56cf8fe10f7e8b58ed6e5b`
- active magic row/resolver commit: `b52124e1b523bf851c364df7dd8e61b9fc648541`
- Strategy Card and G0 commit: `fe6282c2f4ac23ad8de8402866af69abf7a5416d`
- Q01 implementation/binary commit: `bc8f8ccce9e7ae6db8e73231292214aaf464106b`
- registered route: slot 0 `XTIUSD.DWX`, magic `410510000`
- source lineage: Gorska and Krawiec's academic WTI Friday calendar evidence
  plus Yang, Goncu, and Pantelous's fixed-horizon commodity-reversal working
  paper
- claim boundary: neither source tests this exact Monday-open through
  Thursday-close conjunction, continuous CFD, stop, lifecycle, or portfolio
  relationship; those translations remain explicitly falsifiable QM choices

The canonical pre-allocation checker scanned 4,538 EA rows and 625 root cards
and returned `CLEAN`. Manual review separated this mechanic from thresholded
Thursday-only bounce `QM5_12753`, Thursday-surge short `QM5_20117`,
unconditional Friday premium `QM5_12597`, 252-D1 Friday states `QM5_20145`
and `QM5_20172`, first-Friday prior-month reversal `QM5_41026`, and the
earlier/prior-week momentum family `QM5_41019` through `QM5_41022`.

Manual verdict:
`CLEAN_WTI_EXACT_MONDAY_THURSDAY_LOSS_FRIDAY_BOUNCE_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 13 tests PASS. Coverage includes native and
  uniform `+1` labels, exact Monday-through-Friday identity, missing and mixed
  sequence rejection, Friday grace, negative-only BUY mapping, zero/positive/
  invalid rejection, frozen Monday-open/Thursday-close endpoints, stable
  attempt identity, and later-D1 repair.
- Both Strategy Card copies are byte-identical and pass schema, prohibited-ML,
  and G0 lint.
- Strict targeted MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_203603/QM5_41051_wti-fri-weekfade.compile.log`.
- Targeted V5 build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_203603.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41051/P1/P1_QM5_41051_result.json`.
- Factory symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- MQ5 SHA-256:
  `9FA1214EF6332556FB2F12D240DC3BA2BD0D844BF8C2E823F79A4B8AE0D3A6D4`.
- Compiled EX5 SHA-256:
  `CACEBC636E57BA1A4543710E3156F0E913EBA00FEA51AE747C8315B36D47311D`.
- Backtest-set normalized-content build hash:
  `4fac4f85c290c83e9b54ab5521dea3509eec3237ea8d1db18ce69fa8438dbb85`.

## Q02 Dry Run And Mandatory Capacity Stop

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded/recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41051 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only `farmctl.py mt5-slots` census at
`2026-08-17T20:37:51Z` found four active exact-path research terminals:
`T1`, `T5`, `T6`, and `T8`. This was below the documented seven-terminal
ceiling. The census observed `T_Live` and an unrelated FTMO terminal only to
exclude them; neither was touched. The configured
`D:/QM/strategy_farm/state/launch_gate_max.txt` value was `1`.

The separate five-sample whole-host reading from
`2026-08-17T20:38:44Z` through `20:38:54Z` measured `97.19`, `99.81`,
`100.00`, `98.11`, and `99.23` percent (average `98.87`, maximum `100.00`).
The maximum exceeded the explicit 97% hard host-CPU ceiling.

Per the mission's stop condition, the `--apply` command was not run. The
immediate read-only command below returned `count=0`, confirming that no Q02
row exists for this EA:

```text
python tools/strategy_farm/farmctl.py work-items --ea QM5_41051
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
