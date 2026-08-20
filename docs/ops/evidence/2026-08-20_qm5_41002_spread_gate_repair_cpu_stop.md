# QM5_41002 diverse-FX spread-gate repair — CPU ceiling stop

Date: 2026-08-20

Branch: `agents/board-advisor`

Farm task: `5d5cc9f6-e096-44a3-af78-99abc2d9e7ed`

Outcome: `REPAIR + STRICT BUILD PASS; SMOKE AND Q02 DEFERRED AT CAPACITY CEILING`

## Selection and collision control

The farm router assigned this priority-1000 `build_ea` recycle task to
`codex:agents/board-advisor`. Its payload identifies `QM5_41002` as the
highest-diversity unclaimed low-frequency approved build candidate: an H4
forex basket on `EURUSD.DWX`, `GBPUSD.DWX`, and `USDJPY.DWX`. A transactional
router update moved only this task from `RECYCLE` to `IN_PROGRESS`.

Before mutation, the live farm database had no `QM5_41002` traditional task or
work item and no sibling claim. The approved card has `g0_status: APPROVED`,
cites Robert Pardo, *The Evaluation and Optimization of Trading Strategies*
(Wiley, 2008), and retains the exact active registry/magic routes:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | `EURUSD.DWX` | `410020000` |
| 1 | `GBPUSD.DWX` | `410020001` |
| 2 | `USDJPY.DWX` | `410020002` |

## Reviewed defect and bounded repair

Review evidence `ec59206e-c92e-44ce-96e0-89f52d539ca1` recycled the prior
build for `ENTRY_SPREAD_GATE_FIRST_SIGNAL_BYPASS`. The per-tick no-trade hook
ran before `AdvanceState_OnNewBar()`, so its spread test was conditional on
stale `g_state_ready`; the first post-init signal could refresh the ATR cache
and enter without rechecking the card-required current-spread ceiling.

`Strategy_EntrySignal()` now reads valid current ask/bid after the closed-bar
cache is ready and refuses an entry when current spread exceeds
`1.8 * ATR(14)[1]`. The same prices are reused for the entry request. This
closes only the reviewed permission bypass: Donchian length, ATR expansion,
signal cadence, stop, target, trailing, rollover, and risk thresholds are
unchanged. Zero modelled DWX spread remains valid.

`SPEC.md` records the fresh-cache spread recheck and its no-threshold-change
revision.

## Static and build evidence

- `validate_spec_doc.py`: `PASS` (1/1).
- `validate_build_guardrails.py`: `PASS`, no findings across source, spec, and
  three setfiles.
- Magic resolver dry run: 17,547 rows kept, 0 dropped; no resolver or registry
  file was written.
- Strict MetaEditor compile: `PASS`, 0 errors, 0 warnings.
- Final compile log:
  `framework/build/compile/20260820_173353/QM5_41002_robert-pardo-checkmate-breakout-engine.compile.log`.
- Final compile summary: `D:/QM/reports/compile/20260820_173353/summary.csv`.
- Build check (compile skipped because the strict compile had already passed):
  `PASS`, 0 failures, 0 warnings at
  `D:/QM/reports/framework/21/build_check_20260820_172859.json`.
- Final staged MQ5 SHA-256:
  `0C6FD9A192081FE1EEC51FD8D868C14735195535C801045EF261634A79749B2D`.
- Final staged EX5 SHA-256:
  `5B59FDE0D35C3B791C7FC9C20198F8D416B027685A52DF736014394F2D6DEB96`.

Compilation ran with an isolated process-local `APPDATA`. The compiler's
reported include-sync targets were only `D:/QM/mt5/T1/MQL5/Include` and the
T1-origin terminal-data hash
`AE0A37E2EC2BC870ED414E4143BA21BF/MQL5/Include`; neither T_Live terminal-data
hash was a target.

At 17:30:21Z, after the first successful compile, the tracked EX5 was restored
to its pre-repair hash at the scheduled half-hour boundary. This matches the
documented worktree-janitor behavior in the prior `QM5_9926` paced repair. The
established recovery was followed: one final strict compile after that event,
then immediate staging of the 399,200-byte binary (Git blob
`5ec9691372672027da7dd2a3a20218c6fb927c48`). No strategy edit occurred between
the two successful compiles.

All three H4 backtest presets remain fixed-risk and single-weight:
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

| Preset | SHA-256 |
|---|---|
| EURUSD slot 0 | `9363FE55DBFD33463BF9F9224293A06EC83CFE9E8A38EB908746295BBFD9895E` |
| GBPUSD slot 1 | `7BF03A55C71BF8F93C0CA396A2D0930996DD2912AE476EDA1FCA85955BE7E2D6` |
| USDJPY slot 2 | `DA03D35A0F442FB988F84DFA047C44112A156AE4C78688AD285369D5BA219433` |

## Capacity stop and Q02 handoff

Five whole-host CPU samples at 17:29:30Z through 17:29:42Z were
`100, 100, 100, 100, 99%`: average 99.8%, peak 100%, above the governed 97%
ceiling. The simultaneous `farmctl mt5-slots` census found every governed
research terminal `T1` through `T10` active and reserved. The separately
visible T_Live and FTMO processes were observed only.

Per the mission's explicit ceiling stop, no smoke command, tester launch,
Q02 enqueue, dispatcher tick, or pipeline phase was attempted. A closing DB
query still found zero `QM5_41002` work items. The structured build result at
`artifacts/builds/5d5cc9f6-e096-44a3-af78-99abc2d9e7ed.json` records the
sanctioned `deferred_p2_smoke` result. A later capacity-aware wake may perform
the single smoke and enqueue the three exact fixed-risk H4 presets to Q02
after a fresh collision and capacity check.

No AutoTrading action, T_Live mutation, deploy/T_Live manifest change,
portfolio-gate edit, portfolio admission, or live-use authorization occurred.
