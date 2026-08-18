# QM5_41057 XAU/XAG Weekly Flow Agreement Fade - Q01 And Q02 Capacity Stop

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED - TESTER CAPACITY AND CPU CEILING`

## Candidate And Claim Boundary

`QM5_41057_xauxag-wflow-agree-fade` is a low-frequency structural precious-
metals relative-value candidate. On the first eligible synchronized Monday D1
tick it reconstructs the exact completed prior Monday-through-Friday week plus
the preceding Friday close anchor. For each metal it separates five
close-to-open returns from five open-to-close returns and then subtracts silver
from gold:

```text
overnight_relative = xau_overnight - xag_overnight
session_relative   = xau_session - xag_session
week_relative      = overnight_relative + session_relative

require overnight_relative * session_relative > 0

week_relative > 0 => SELL XAU, BUY XAG
week_relative < 0 => BUY XAU, SELL XAG
otherwise         => consume Monday flat
```

All endpoints are completed before the decision Monday and reconcile to the
frozen weekly close-to-close returns within `1e-10`. Component opposition,
exact zero, a broken calendar week, cross-symbol timestamp mismatch, or failed
reconciliation consumes the attempt.

One aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1` package targets equal absolute USD notionals, rejects
more than 20% post-rounding mismatch, and uses per-leg frozen
`3.0 * ATR(20,D1)` hard stops with no target. It compensates a failed second
leg, repairs malformed or orphaned exposure, closes both legs Friday at broker
hour 21, and retains later-week and eight-day stale guards. Both news axes are
OFF.

Opposite legs suppress some common precious-metal direction but do not prove
dollar, beta, volatility, factor, market, or portfolio neutrality. This
handoff establishes no profitability, certification, portfolio admission,
CFD/futures equivalence, realized decorrelation, or correlation waiver. Q09
alone may measure overlap with the certified XAU/SP500/NDX/XNG book.

## Source, Governance, And Non-Duplicate Boundary

- Williams, Larry R. (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
  Trading: complete OWNER-supplied Tier-A close/open flow extraction
- Schweikert, Karsten (2018), "Are gold and silver cointegrated? New evidence
  from quantile cointegrating regressions," *Journal of Banking & Finance* 88,
  44-51, DOI `10.1016/j.jbankfin.2017.11.010`
- CME Group, "Gold & Silver Ratio Spread": governed exchange carrier packet
- source approval commit: `d50ca2929`
- deterministic EA allocation commit: `a87119911`
- active slot-0/slot-1 magic allocation commit: `cdb44e1a0`
- Strategy Card and OWNER G0 commit: `026531ee6`
- source implementation and binary commit: `d6995881f`
- registered routes: `XAUUSD.DWX` slot 0 magic `410570000` and
  `XAGUSD.DWX` slot 1 magic `410570001`

The canonical pre-allocation checker found no exact identity. The manual
family review fixes the load-bearing separation:

- `QM5_41030_xauxag-flowdiv` requires strict component opposition and follows
  session flow, while this EA requires strict agreement and fades the total;
- `QM5_41040_xauxag-wflow-fade` requires session-dominant opposition before
  fading, while this EA cannot admit any opposition state;
- `QM5_41039_xauxag-mflow-div` consumes a complete month, follows session
  flow, and holds to the next month;
- ratio, z-score, regression, quantile, tail, failed-break, and seasonal
  systems estimate states this EA never reads; and
- `QM5_12567_cum-rsi2-commodity` is a standalone long-only XNG daily
  oscillator pullback rather than a synchronized metals package.

Manual verdict:
`CLEAN_XAUXAG_WEEKLY_RELATIVE_FLOW_AGREEMENT_COMPLETED_WEEK_FADE_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 14 tests `PASS`. Coverage includes exact
  Monday-Friday calendar identity, cross-symbol synchronization, no holiday
  substitution, inclusive three-hour grace, both agreement-fade directions,
  mutual exclusion of all component-opposition states, exact-zero rejection,
  endpoint reconciliation, invalid-price rejection, aggregate package risk,
  notional rounding, Friday/later-week boundaries, and the durable attempt
  key.
- Both Strategy Card copies are byte-identical and pass schema, prohibited-ML,
  and G0 lint.
- Strict targeted MetaEditor compile: `PASS`, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260818_023902/QM5_41057_xauxag-wflow-agree-fade.compile.log`.
- Targeted V5 build check: `PASS`, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260818_023902.json`.
- Static P1 artifact validation: `PASS`:
  `D:/QM/reports/pipeline/QM5_41057/P1/P1_QM5_41057_result.json`.
- Factory symbol-scope validation: `BASKET_OK`, zero violations, with both
  manifest members declared.
- MQ5 SHA-256:
  `264504AAFFCDF458DF264FBE8DA54E2C4AFC6386AA7D371E96EB97D80D3ACDB9`.
- Compiled EX5 SHA-256:
  `6A33FB2BB5386572695E15E02067D353F29E8EB3DFE7BFAFC3346A90412979E0`.
- Backtest-set byte SHA-256:
  `2E168B0CEE09CBB1E4D28ED0C4B1ED423C17579B4BA23BB6F73C155AC2F3C2E1`.
- Backtest-set normalized-content build hash:
  `047fc3b81c93c9d3631f96ecad030f97739d20ac6d425de4537c4c08fb5ab916`.

No manual tester, smoke test, pipeline phase runner, dispatcher tick, or
backtest was invoked during Q01.

## Q02 Dry Run And Mandatory Capacity Stop

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded or recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41057 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only exact-path `farmctl.py mt5-slots` census at
`2026-08-18T02:42:43Z` found seven active governed research terminals: `T1`,
`T2`, `T3`, `T4`, `T6`, `T8`, and `T10`. This was already at the governed
seven-terminal ceiling, so the precondition that capacity remain below the
ceiling was not met. `T_Live` and an unrelated FTMO terminal were observed
only so they could be excluded; neither was touched. The configured
`D:/QM/strategy_farm/state/launch_gate_max.txt` value was `1`.

The binding five-sample `GetSystemTimes` whole-host CPU reading completed at
`2026-08-18T02:43:38Z`: `99.85`, `97.53`, `99.11`, `98.13`, and `97.83`
percent (average `98.49`, maximum `99.85`). Every sample exceeded the explicit
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
nonpositive governed economics, wrong week identity or endpoints, current-bar
leakage, component opposition, wrong fade sides, failed reconciliation, late
or repeated entry, excess notional mismatch, orphan survival, wrong lifecycle,
nondeterminism, invalid fixed-risk mode, or insufficient synchronized history.
