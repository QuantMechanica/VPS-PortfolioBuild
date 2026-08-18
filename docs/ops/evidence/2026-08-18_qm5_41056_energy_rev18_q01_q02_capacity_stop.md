# QM5_41056 XTI/XNG 18-Month Reversal - Q01 And Q02 Capacity Stop

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED - TESTER AND CPU CEILINGS`

## Candidate And Claim Boundary

`QM5_41056_energy-rev18` is a low-frequency structural energy-relative-value
candidate. On the first genuine normalized broker-month D1 boundary it reads
synchronized, strictly completed XTI and XNG closes immediately before that
boundary and exactly 18 completed months earlier:

```text
r_xti = ln(XTI_end / XTI_start18)
r_xng = ln(XNG_end / XNG_start18)

r_xti < r_xng - 1e-12 => BUY XTI, SELL XNG
r_xti > r_xng + 1e-12 => SELL XTI, BUY XNG
otherwise              => consume month flat
```

The EA accepts native same-day energy labels or one uniform `+1` day offset,
requires identical normalized endpoint timestamps across the two legs, and
forbids current-month prices and the sibling 12-month state. It persists the
broker `yyyymm` attempt before every fallible entry gate and never retries the
month.

One aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1` package is split into equal stop-risk halves. Each leg
has a frozen `3.5 * ATR(20,D1)` hard stop and no target. The package renews at
the next broker month, compensates a failed second leg, repairs an orphan
immediately, and has a 35-calendar-day survivor guard. Both news axes and
framework Friday close are OFF.

Simultaneous opposite legs do not establish dollar, beta, volatility, factor,
market, or portfolio neutrality. This handoff establishes no profitability,
certification, portfolio admission, CFD/futures equivalence, realized
decorrelation, or correlation waiver. Q09 alone may measure overlap with the
certified XAU/SP500/NDX/XNG book.

## Source, Governance, And Non-Duplicate Boundary

- source: Bianchi, Drew, and Fan (2015), *Journal of Banking & Finance* 59,
  423-444, DOI `10.1016/j.jbankfin.2015.07.006`
- source approval commit: `72bf6148c`
- deterministic EA allocation commit: `0ceacf790`
- active slot-0/slot-1 magic allocation commit: `11cabe252`
- Strategy Card and OWNER G0 commit: `e5952719b`
- source implementation and binary commit: `3817b1177`
- registered routes: `XTIUSD.DWX` slot 0 magic `410560000` and
  `XNGUSD.DWX` slot 1 magic `410560001`

The canonical pre-allocation checker scanned 4,543 EA rows and 625 root-card
files and found no exact identity. The manual family review fixed the
load-bearing separation:

- `QM5_13120_energy-momrev` requires 12-month momentum and 18-month reversal
  rank disagreement; this EA never reads 12-month state and trades every
  valid non-tied 18-month rank;
- `QM5_20202_xauxag-rev18` carries the isolated state on metals, not the
  XTI/XNG energy carrier;
- `QM5_12733_xti-xng-xmom` follows a shorter relative winner;
- `QM5_12840_xti-xng-rspread` uses a short-window standardized spread; and
- weekday, event, carry, calendar, inventory, and standalone XNG systems use
  different state variables, clocks, or package structures.

Manual verdict:
`CLEAN_XTI_XNG_PURE_SYNCHRONIZED_18_MONTH_REVERSAL_MONTHLY_BASKET_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 14 tests `PASS`. Coverage includes native and
  uniform `+1` labels, genuine versus mid-month boundaries, strictly completed
  18-month endpoints, current-month exclusion, endpoint freshness and exact
  cross-leg synchronization, both reversal directions, the inclusive tie
  band, one durable `yyyymm` attempt, equal risk halves, malformed/orphan
  package rejection, next-month renewal, and the 35-day repair.
- Both Strategy Card copies are byte-identical and pass schema, prohibited-ML,
  and G0 lint.
- Strict targeted MetaEditor compile: `PASS`, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260818_014607/QM5_41056_energy-rev18.compile.log`.
- Targeted V5 build check: `PASS`, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260818_014607.json`.
- Static P1 artifact validation: `PASS`:
  `D:/QM/reports/pipeline/QM5_41056/P1/P1_QM5_41056_result.json`.
- Factory symbol-scope validation: `BASKET_OK`, zero violations, with both
  manifest members declared.
- MQ5 SHA-256:
  `060DD37F4C1771F2CFFBB88528DF069E00214FC02BB8FB8C69F11849EF5C3E84`.
- Compiled EX5 SHA-256:
  `DACD84FBD72E49CA1BCEC4EDE0C04FB712715F74F523A7DA2A4694FF7E25C441`.
- Backtest-set byte SHA-256:
  `FF1C155818E812602A74FEC303592BB309E67A7A307F0432C482F26DB20D86D4`.
- Backtest-set normalized-content build hash:
  `b8dbf1cfae2940c7eb7d893b00a719a7ee93a1637f6fbf036678d2bd647cbe09`.

No manual tester, smoke test, pipeline phase runner, dispatcher tick, or
backtest was invoked during Q01.

## Q02 Dry Run And Mandatory Capacity Stop

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded or recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41056 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only exact-path `farmctl.py mt5-slots` census at
`2026-08-18T01:49:27Z` found nine active governed research terminals: `T1`,
`T2`, `T3`, `T4`, `T5`, `T6`, `T7`, `T8`, and `T10`. This exceeded the hard
seven-terminal ceiling. `T_Live` and an unrelated FTMO terminal were observed
only so they could be excluded; neither was touched. The configured
`D:/QM/strategy_farm/state/launch_gate_max.txt` value was `1`.

The binding five-sample `GetSystemTimes` whole-host CPU reading completed at
`2026-08-18T01:50:05Z`: `99.81`, `100.00`, `100.00`, `100.00`, and `100.00`
percent (average `99.96`, maximum `100.00`). The maximum exceeded the explicit
97% hard host-CPU ceiling.

Per the mission's stop condition, the `--apply` command was not run. The
immediate read-only work-item query returned `count=0`, confirming that no Q02
row exists for this EA.

## Safety And Handoff

No Q02 enqueue, dispatcher tick, manual backtest, terminal or worker mutation,
AutoTrading action, live/demo/shadow/stress/optimization preset, `T_Live`
change, deploy or T_Live manifest, portfolio-gate edit, portfolio admission,
decorrelation or neutrality claim, or correlation waiver occurred.

A later paced operator may repeat the exact target-only dry run and apply only
after fresh terminal and CPU checks both pass. Q02 must retire the identity on
zero trades, fewer than five completed packages per full post-warm-up year,
nonpositive governed economics, wrong or stale endpoints, current-month
leakage, inconsistent labels, hidden 12-month state, wrong direction, repeated
entry, orphan persistence, nondeterminism, invalid fixed-risk mode, or
insufficient synchronized history.
