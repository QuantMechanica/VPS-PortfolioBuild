# QM5_41047 XNG Thursday Trend Pullback — Q01 PASS / Q02 Capacity Stop

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED — FACTORY AND HOST CPU CEILINGS REACHED`

## Candidate And Claim Boundary

`QM5_41047_xng-thu-trend-pb` is a new low-frequency single-symbol natural-gas
candidate on exact `XNGUSD.DWX`, D1. At the first executable Friday after an
exact completed Tuesday, Wednesday, and standard Thursday, it computes:

```text
event_return = ln(ThursdayClose / WednesdayClose)
slow_trend   = ln(WednesdayClose / Close252SessionsBeforeWednesday)
```

The slow state ends before Thursday, so the completed event move cannot vote
twice. The candidate trades only when both finite nonzero returns have strictly
opposite signs, follows the slow-trend sign, freezes a `3.5 * ATR(20,D1)` hard
stop, uses no target, and exits at the first later D1 boundary. The durable
Friday attempt is consumed before every fallible gate; Friday close is disabled
because the normal one-D1 lifecycle spans the weekend. A four-day stale guard
bounds malformed lifecycle state.

The only preset is backtest-only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. This build does not establish profitability,
certification, or realized decorrelation; Q09 alone may measure overlap with
the certified XAU/SP500/NDX/XNG book.

## Governance And Non-Duplicate Boundary

- Source approval commit:
  `25f6f54fb5991ca77b6313b7133d3cdab0b3437c`.
- EA-ID reservation commit:
  `1d204a2cebf41b615fce34cd3a49571c3b704138`.
- Strategy Card and OWNER G0 commit:
  `0e0901c50d6ee90c3f5ac9e2167cbfcf63c1bee9`.
- Pre-magic directory identity commit:
  `8318c7f9c285c0508e21513d36dc541808f3486b`.
- Magic registration/resolver commit:
  `63602b2334d15abd127efd69a282a961046b1e1f`.
- Q01 build commit:
  `e75c8d0efecdaf98f05ee008a3a5660401eb0a27`.
- Registered route: slot 0 `XNGUSD.DWX`, magic `410470000`.
- The reputable-source packet binds the official EIA Weekly Natural Gas
  Storage Report Thursday release clock to the completely reviewed,
  peer-reviewed Moskowitz-Ooi-Pedersen time-series-momentum paper, which
  explicitly includes natural gas. The exact cross-horizon opposition
  conjunction and continuous-CFD translation are declared QM hypotheses, not
  source-proven performance.
- Canonical pre-allocation dedup scanned 4,534 registry rows and 625 approved
  cards and found no exact slug, strategy-ID, or mechanic identity. Three fuzzy
  trend-family matches were manually cleared as different event clocks,
  horizons, carriers, and lifecycle rules.
- Exact gold/silver ratio z-score reversion was rejected before allocation
  because `QM5_20157_xau-xag-ratio` already implements it. The selected XNG
  identity is also distinct from certified `QM5_12567`: it is symmetric,
  event-clocked cross-horizon opposition followed in the slow-trend direction,
  rather than a long-only cumulative-RSI2 rule.
- Manual verdict:
  `CLEAN_XNG_STANDARD_THURSDAY_COUNTER_MOVE_PRE_EVENT_TREND_REENTRY_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 15 tests PASS. Coverage includes native and
  uniform `+1` energy labels, holiday rejection, exact calendar/gap identity,
  both opposition branches, agreement/zero/invalid rejection, the exact
  252-session endpoint and off-by-one guard, exclusion of Thursday from the
  slow state, Friday grace/attempt identity, and first-later-D1 exit.
- Both Strategy Card copies are byte-identical and pass schema/ML and G0 lint.
- Strict targeted MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_150047/QM5_41047_xng-thu-trend-pb.compile.log`.
- Targeted build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_150150.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41047/P1/P1_QM5_41047_result.json`.
- Factory symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- MQ5 SHA-256:
  `2D4A2C46181940B857AA044822A1B5BE31C87CE74D2BAF737B64427F16EEAAC1`.
- Compiled EX5 SHA-256:
  `E611CD422B5361D5B5F681E8A8B5BE2EA2BEACC9BD80B31CDF88B75F516BFDA0`.
- Backtest-set normalized-content build hash:
  `680d20c4c41ff2ba0d801b5484186b1f701fbd696d4351b66869dff454224296`.
- The exact fixed-risk setfile is marked `-text` to preserve its evidence bytes
  across checkout line-ending settings.

## Q02 Dry Run And Mandatory Capacity Stop

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded/recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41047 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only `farmctl.py mt5-slots` census at
`2026-08-17T15:06:28Z` found seven active exact-path research terminals:
`T1`, `T3`, `T4`, `T5`, `T8`, `T9`, and `T10`. This equals the documented
seven-terminal backtest ceiling. The configured
`D:/QM/strategy_farm/state/launch_gate_max.txt` value was `1`, so the paced
launch ceiling was also already exceeded.

A separate five-sample host reading beginning at
`2026-08-17T15:07:15Z` measured CPU percentages of `100.00`, `100.00`,
`99.90`, `99.66`, and `98.55` (average `99.62`, maximum `100.00`). The hard
host-CPU ceiling was binding independently of the terminal count.

Per the mission's explicit stop condition, the apply command was not run. A
read-only command immediately afterward returned `count=0` for `QM5_41047`:

```text
python tools/strategy_farm/farmctl.py work-items --ea QM5_41047
```

No Q02 row was created by this handoff.

## Safety And Handoff

No backtest, dispatcher tick, terminal start/stop/kill/attach, worker mutation,
reservation change, AutoTrading action, live/demo/shadow/stress/optimization
preset, deploy or T_Live manifest, portfolio-gate edit, portfolio admission,
decorrelation claim, or correlation waiver occurred. The capacity census
observed but excluded the non-research `T_Live` and FTMO terminal paths and did
not control either process.

The candidate is committed and Q01-clean but remains unqueued. A later paced
operator may repeat the exact target-only dry run and apply once both ceilings
permit. Q02 must then retire the identity on zero trades, fewer than eight
completed positions per full post-warm-up year, nonpositive governed economics,
wrong calendar/endpoints, slow-state leakage, invalid opposition or side,
late/repeated entry, wrong next-D1 lifecycle, nondeterminism, or invalid risk
mode.
