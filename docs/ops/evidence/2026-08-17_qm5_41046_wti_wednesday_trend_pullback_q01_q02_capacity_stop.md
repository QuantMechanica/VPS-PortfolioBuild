# QM5_41046 WTI Wednesday Trend Pullback — Q01 PASS / Q02 Capacity Stop

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; Q02 NOT ENQUEUED — FACTORY CEILING REACHED`

## Candidate And Claim Boundary

`QM5_41046_wti-wed-trend-pb` is a new low-frequency single-symbol energy
candidate on exact `XTIUSD.DWX`, D1. At the first executable Thursday after an
exact completed Monday, Tuesday, and standard Wednesday, it computes:

```text
event_return = ln(WednesdayClose / TuesdayClose)
slow_trend   = ln(TuesdayClose / Close252SessionsBeforeTuesday)
```

The slow state ends before Wednesday, so the completed event move cannot vote
twice. The candidate trades only when both finite, nonzero returns have
strictly opposite signs, follows the slow-trend sign, and exits on the first
later D1 boundary. Each Thursday is durably consumed before fallible history,
spread, ATR, sizing, news, or order gates. A frozen `3.0 * ATR(20,D1)` stop,
no target, a three-day stale guard, and the framework Friday-hour-21 fail-safe
bound the lifecycle.

The only preset is backtest-only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. This build does not establish profitability,
certification, or realized decorrelation; Q09 alone may measure overlap with
the certified XAU/SP500/NDX/XNG book.

## Governance And Non-Duplicate Boundary

- Source approval commit: `96f02558c`.
- Deterministic EA-ID reservation commit: `33dda3a60`.
- Strategy Card and OWNER G0 commit: `db3baa034`.
- Pre-magic directory identity commit: `ba92caa23`.
- Magic registration/resolver commit: `3dc8f589b`.
- Q01 build commit: `0388eb9a0`.
- Registered route: slot 0 `XTIUSD.DWX`, magic `410460000`.
- The reputable-source packet binds the official EIA weekly petroleum release
  clock to the completely reviewed, peer-reviewed Moskowitz-Ooi-Pedersen
  time-series-momentum paper, which explicitly includes WTI. The exact
  conjunction and continuous-CFD translation are declared QM hypotheses, not
  source-proven performance.
- Canonical pre-allocation dedup scanned 4,533 registry rows and 625 cards and
  found no exact slug, strategy-ID, or mechanic identity. Its three fuzzy
  matches (`wti-dom-trend`, `wti-lr-trend`, and `xng-lr-trend`) were manually
  cleared as different clocks, horizons, carriers, and lifecycle rules.
- Manual family review also separated the mechanic from completed-event trend
  agreement, Wednesday intraday-flow fade, monthly WTI pullback, pre-event
  Wednesday trend entry, WPSR aftershock/range logic, M30 WPSR sequences, and
  the incumbent XNG RSI system. This identity uniquely requires opposition
  between one completed Wednesday event return and a separate pre-event
  252-session WTI trend, followed in the slow-trend direction on Thursday for
  one D1 interval.
- Manual verdict:
  `CLEAN_WTI_STANDARD_WEDNESDAY_COUNTER_MOVE_PRE_EVENT_TREND_REENTRY_AFTER_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 14 tests PASS. Coverage includes native and
  uniform `+1` energy labels, exact calendar/gap identity, both opposition
  branches and correct slow-trend side, agreement/zero/invalid rejection, the
  exact 252-session endpoint and off-by-one guard, exclusion of Wednesday from
  the slow state, Thursday grace/attempt identity, and first-later-D1 exit.
- Both Strategy Card copies are byte-identical and pass schema/ML and G0 lint.
- Strict targeted MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_140351/QM5_41046_wti-wed-trend-pb.compile.log`.
- Targeted build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_140351.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41046/P1/P1_QM5_41046_result.json`.
- Factory symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- Compiled EX5 SHA-256:
  `F1A2EC46D0CB6E8904AB22C7C199406A7C323953E0CE2E02C7A1B3FC1343C267`.
- Backtest-set normalized-content build hash:
  `c3855a0d11a2e01c5a75bea3c1d420219dc60998ee20423417bf52eaf7bd7a8c`.
- The exact fixed-risk setfile is marked `-text` to preserve its evidence bytes
  across checkout line-ending settings.

## Q02 Dry Run And Mandatory Capacity Stop

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded/recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41046 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only `farmctl.py mt5-slots` census at
`2026-08-17T14:06:54Z` found five active exact-path research terminals:
`T1`, `T3`, `T5`, `T6`, and `T8`. The configured
`D:/QM/strategy_farm/state/launch_gate_max.txt` value was `1`, so the paced
launch ceiling was already exceeded. A separate five-sample host reading at
`2026-08-17T14:07:23Z` measured CPU percentages of `91.32`, `85.86`, `94.65`,
`85.75`, and `74.82` (average `86.48`, maximum `94.65`).

Per the mission's explicit stop condition, the apply command was not run. A
read-only work-item query immediately afterward returned count 0 for
`QM5_41046`; no Q02 row was created by this handoff.

## Safety And Handoff

No backtest, dispatcher tick, terminal start/stop/kill/attach, worker mutation,
reservation change, AutoTrading action, live/demo/shadow/stress/optimization
preset, deploy or T_Live manifest, portfolio-gate edit, portfolio admission,
decorrelation claim, or correlation waiver occurred. The capacity census
observed but excluded the non-research `T_Live` and FTMO terminal paths and did
not control either process.

The candidate is committed and Q01-clean but remains unqueued. A later paced
operator may repeat the exact target-only dry run and apply once the configured
factory ceiling permits. Q02 must then retire the identity on zero trades,
fewer than eight completed positions per full post-warm-up year, nonpositive
governed economics, wrong calendar/endpoints, slow-state leakage, invalid
opposition or side, late/repeated entry, wrong next-D1 lifecycle,
nondeterminism, or invalid risk mode.
