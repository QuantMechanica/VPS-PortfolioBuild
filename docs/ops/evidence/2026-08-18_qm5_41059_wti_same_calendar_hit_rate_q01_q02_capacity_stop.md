# QM5_41059 WTI Same-Calendar Hit Rate - Q01 And Q02 Capacity Stop

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED - TESTER CAPACITY AND CPU CEILING`

## Candidate And Portfolio Boundary

`QM5_41059_wti-samecal-hit` is a low-frequency structural WTI candidate. On
the first executable normalized broker-month D1 boundary it reconstructs the
exact completed return of the same calendar month in each of years `Y-1`
through `Y-10`, requiring at least five valid observations. Each non-negative
return maps to one and each negative return to zero. It buys when the
equal-weight positive frequency is at least the source-defined fixed `q=0.40`
boundary and sells otherwise. Return magnitudes and current-month prices do
not enter the signal.

One durable `yyyymm` attempt is consumed before every fallible entry gate. The
baseline carries one slot-0 `XTIUSD.DWX` position to the next normalized month
boundary, with a frozen `3.5 * ATR(20,D1)` hard stop, no target, a 35-day stale
guard, 1,500-point spread ceiling, both news axes OFF, and framework Friday
close disabled. Risk is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

This is not the existing `QM5_41055` same-calendar median strategy. The fixed
`q=0.40` binary-frequency boundary can be long with two positive and three
negative observations even when both sample mean and median are negative.
It is also direct WTI exposure, outside the certified XAU/SP500/NDX/XNG book.
This handoff establishes no profitability, certification, portfolio
admission, CFD/futures equivalence, realized decorrelation, or correlation
waiver; Q09 alone may measure realized overlap with the certified book.

## Source And Governance

- Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
  Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`.
- Papailias, Liu, and Thomakos (2021), "Return Signal Momentum," *Journal of
  Banking & Finance* 124, 106063, DOI `10.1016/j.jbankfin.2021.106063`.
- source approval commit: `cd8ab88a1`
- deterministic EA reservation commit: `36a5d38ba`
- active slot-0 magic/resolver commit: `4c1f158e8`
- initial Strategy Card and G0 commit: `5e8d25cec`
- pre-build q40 identity amendment commit: `1312b9bd4`
- deterministic implementation and Q01 commit: `f871b0126`
- registered route: `XTIUSD.DWX`, D1, slot 0, magic `410590000`

The canonical dedup check was clean before allocation. A post-allocation probe
using the corrected q40 mechanic was also clean across 4,547 registry rows and
625 root cards. Manual family review rejected strict majority as
median-equivalent before implementation and separated the fixed asymmetric
q40 sign-frequency state from same-calendar mean, median, recent sign
momentum, and fixed-month systems.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 14 tests `PASS`. Coverage includes native and
  uniformly shifted energy labels, genuine month boundaries, inclusive
  three-hour grace, exact completed endpoints, year-skip behavior without
  substitution, five-observation floor, ten-year cap, non-negative binary
  mapping, inclusive q40 direction, the mean/median disagreement case,
  monthly renewal, and the 35-day repair guard.
- Both Strategy Card copies are byte-identical and pass schema, prohibited-ML,
  and G0 lint.
- Strict targeted MetaEditor compile: `PASS`, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260818_042436/QM5_41059_wti-samecal-hit.compile.log`.
- Targeted V5 build check: `PASS`, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260818_042436.json`.
- Static P1 artifact validation: `PASS`:
  `D:/QM/reports/pipeline/QM5_41059/P1/P1_QM5_41059_result.json`.
- Build guardrails: `PASS`, including `max_news_stale_hours=336`.
- MQ5 SHA-256:
  `EB2389D0B7BAD3FC20F3672844F502F0D0AEBF7BF3501A156BA7CF41F9743BE7`.
- compiled EX5 SHA-256:
  `8A410DB68451AB01263B5C059F0693B5EA2ECB13EC966A43DD7E2212130602D9`.
- backtest-set byte SHA-256:
  `816A23EEA8D1D73392FA4E9915DEAB428298826BC2BB19601C40B78B87CB065C`.
- backtest-set normalized-content build hash:
  `c48b06e90f4e7fbc61fe9340c0c79fc760e1c4c85ab96994d51299ee04154956`.

No manual tester, smoke test, pipeline-phase runner, dispatcher tick, or
backtest was invoked during Q01.

## Q02 Dry Run And Mandatory Capacity Stop

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded or recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41059 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only exact-path `farmctl.py mt5-slots` census at
`2026-08-18T04:28:17Z` found eight active governed research terminals: `T1`,
`T2`, `T3`, `T4`, `T6`, `T7`, `T8`, and `T10`. This exceeds the governed
seven-terminal ceiling. `T_Live` and an unrelated FTMO terminal were observed
only so they could be excluded; neither was touched.

The binding five-sample `GetSystemTimes` whole-host CPU reading ran from
`2026-08-18T04:28:57Z` through `04:29:07Z`. Two-second samples were `99.56`,
`97.62`, `100.00`, `100.00`, and `99.67` percent (average `99.37`, maximum
`100.00`). Every sample exceeded the explicit 97% hard host-CPU ceiling.

Per the mission's stop condition, the `--apply` command was not run. The
immediate read-only `farmctl.py work-items --ea QM5_41059` query returned
`count=0`, confirming that no Q02 row exists for this EA.

## Safety And Handoff

No Q02 enqueue, dispatcher tick, manual backtest, terminal or worker mutation,
AutoTrading action, live/demo/shadow/stress/optimization preset, `T_Live`
change, deploy or T_Live manifest, portfolio-gate edit, portfolio admission,
decorrelation claim, or correlation waiver occurred.

A later paced operator may repeat the exact target-only dry run and apply only
after fresh governed-terminal and host-CPU checks both pass. Q02 must retire
the identity on zero trades, fewer than five completed positions per full
post-warm-up year, nonpositive governed economics, wrong month endpoints,
current-month leakage, fewer than five valid observations, wrong binary map or
q40 inequality, repeated/late entry, wrong lifecycle, nondeterminism, or
invalid fixed-risk mode.
