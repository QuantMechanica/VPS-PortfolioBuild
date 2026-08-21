# QM5_37007 diversity build and Q02 enqueue

Date: 2026-08-21 UTC

Branch: `agents/board-advisor`

## Outcome

One approved, non-duplicate diversity sleeve was advanced through the standard
Q01 build contract. `QM5_37007_cross-sectional-momentum-factor-dispersion` is
a structural H4 relative-momentum sleeve over the seven registered `.DWX` USD
majors. It had no farm task or work item before this run.

Farm build task `db2bc1b4-040b-4649-a1ae-ebb5eeff2307` is `done`. The standard
record-build router created the priority-track Q02 canary
`ce0fde12-1f21-4dab-a31e-9c59c3bff557` for `EURUSD.DWX`; its status at handoff
was `pending`. The other six registered symbols are retained by the governed
`qm-q02-canary-fanout/v1` sidecar for release after canary success.

## Mechanical card alignment

The pre-existing scaffold did not implement the approved lifecycle: it used an
invented fixed 2R take-profit and never closed at the card's weekly rebalance.
The in-place build now:

- ranks closed-bar 60-H4 returns across EURUSD, GBPUSD, AUDUSD, NZDUSD,
  USDCAD, USDCHF, and USDJPY;
- permits at most one entry request per symbol and calendar week;
- uses the card's two-ATR protective stop and no fixed profit target;
- exits carried exposure at the next framework-derived weekly boundary;
- wires the card's 2% daily realized-loss entry halt, 2.5% daily equity hard
  stop, 5% total drawdown hard stop, and three-tick entry deviation; and
- retains fixed-risk backtest inputs (`RISK_FIXED=1000`, `RISK_PERCENT=0`) in
  all seven generated H4 setfiles.

The card prose calls the lookback "three-month" while its explicit formula and
parameter specify 60 H4 bars. The implementation follows the deterministic
60-bar rule and records this ambiguity in the build result for review.

## Build evidence

- Skill prerequisite guard: PASS for numeric registry ID `37007` and canonical
  EA label.
- Strategy spec validation: PASS.
- Build-gate hardening: PASS, zero failures and zero warnings.
- Strict build check: PASS, zero failures and zero warnings;
  `D:\QM\reports\framework\21\build_check_20260821_161831.json`.
- Compile: PASS, zero errors and zero warnings;
  `C:\QM\repo\framework\build\compile\20260821_161843\QM5_37007_cross-sectional-momentum-factor-dispersion.compile.log`.
- Build result: `D:\QM\strategy_farm\artifacts\builds\db2bc1b4-040b-4649-a1ae-ebb5eeff2307.json`.
- Registry rows were already active and collision-free: magic base `370070000`,
  slots 0 through 6. No registry or resolver mutation was required.

## Smoke and capacity

Five two-second whole-host CPU samples before smoke were 69.9745%, 62.0947%,
54.9680%, 62.9037%, and 51.2769% (average 60.2436%, maximum 69.9745%). Both
were below the explicit 97% hard ceiling; three governed backtests were active.

Exactly one smoke was requested. The custom-history isolation gate refused T8
before launching MT5 because a build smoke is not worker-bound. It was not
retried. `record-build` normalized this honest infrastructure result to
`deferred_p2_smoke`, marked `needs_p2_smoke_via_pump=true`, and admitted the
worker-bound Q02 canary where the approved archive can be privatized safely.

## Safety and isolation

No pipeline phase was run manually. No portfolio gate, T_Live manifest,
AutoTrading state, or live terminal state was read-modified-written. Concurrent
unrelated working-tree changes were left unstaged and untouched; the commit for
this unit contains only the QM5_37007 EA directory and this evidence file.
