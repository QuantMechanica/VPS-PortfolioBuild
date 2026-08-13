# QM5_13205 market-neutral calendar rework — Q01 PASS, Q02 deferred at CPU ceiling

Date: 2026-08-13

Branch: `agents/board-advisor`

EA: `QM5_13205_xau-xag-qc`

Farm claim: `2604259a-7840-4bee-afad-40ead7cd366e`

Build task: `2774ef4d-0a43-47e6-b5ff-abf01a614630`

## Status

The low-frequency XAU/XAG conditional-quantile basket was rebuilt in place and
passes Q01's target checks and strict compilation. The review finding that
blocked the pending build row is removed: monthly and weekly cadence now use
the V5 framework's D1-derived `QM_CalendarPeriodKey` contract, with no raw EA
`iTime`, `Strategy_MonthKey`, `Strategy_WeekKey`, or hand-rolled year/month/week
key remaining.

No smoke test, Q02 row, dispatcher tick, worker tick, or manual backtest was
started. The host was at the backtest CPU ceiling immediately after the build,
so the OWNER-paced stop rule was applied. The build task remains pending and
actively marked `backtest_cpu_ceiling_after_q01_pass`; no build-result JSON was
materialized for the pump to auto-record.

## Selection and collision control

This was the highest-diversity eligible row in the approved `build_ea`
backlog: a peer-reviewed-source, approximately 6–12 package/year,
market-neutral-intent precious-metals pair. The rates and lumber rows require
unapproved/non-DWX inputs, while the remaining FX alternatives are primarily
intraday or high-frequency. Before claim, the farm had no active agent claim
or open work item for `QM5_13205`, and the target EA path plus its registry
files were clean.

- Claim key:
  `manual:codex:agents/board-advisor:QM5_13205:q01-build-rework-q02-handoff:20260813T075236Z`.
- Pre-claim DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_13205_build_claim_20260813T075236Z.sqlite`.
- SQLite `PRAGMA quick_check`: `ok` after claim and at final pre-commit readback.
- Approved-card guard: one active EA-registry row, two active magic rows,
  existing EA directory, and `g0_status: APPROVED` — PASS.
- Slot identities: `XAUUSD.DWX` / 0 / `132050000` and
  `XAGUSD.DWX` / 1 / `132050001`; both symbols are verified in the DWX matrix.

## Scoped implementation

- Bumped the EA/set identity from v5.0 to v5.1.
- Replaced the custom timestamp-to-month and timestamp-to-week functions with
  `QM_CalendarPeriodKey(PERIOD_MN1|PERIOD_W1, symbol, shift)`.
- Reconstructed the first host bar of the current month by scanning bounded D1
  shifts with framework calendar keys and `QM_ReadBar`.
- Reconstructed the active weekly history boundary from the same framework key
  before checking position/deal history, retaining restart-safe one-attempt
  suppression without converting arbitrary timestamps in EA code.
- Replaced the remaining direct `iTime` reads with `QM_ReadBar`; bounded
  `iBarShift` anchors and synchronized `CopyRates` history loads remain the
  approved structural data path.
- Preserved the exact 504-pair held-out estimator, constrained 10/50/90
  asymmetric check-loss solver, beta-span/envelope gates, paired directions,
  joint fixed-risk sizing, frozen ATR stops, median/time/orphan exits, and all
  authorized parameters.

The framework weekly bucket is now load-bearing, so the rebuilt binary requires
a fresh full Q02. No prior efficacy result transfers to v5.1.

## Q01 evidence

| Check | Result |
|---|---|
| `skill_build_ea_guard.py` | PASS |
| `validate_spec_doc.py` | PASS, 1/1 |
| `validate_build_guardrails.py` | PASS for MQ5 and setfile |
| `validate_symbol_scope.py --fail-on-leak` | `BASKET_OK`, 0 violations |
| Target `build_check.ps1` | PASS, 0 failures, 0 warnings |
| Explicit `compile_one.ps1 -Strict` | PASS, 0 errors, 0 warnings |
| Static calendar check | no raw `iTime`, custom month/week key, year-key arithmetic, or `day_of_year` in the EA |
| Risk contract | `environment=backtest`, `RISK_FIXED=1000`, `RISK_PERCENT=0`, no live setfile |

- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260813_080310.json`.
- Strict compile summary:
  `D:\QM\reports\compile\20260813_080419\summary.csv`.
- Strict compile log:
  `C:\QM\repo\framework\build\compile\20260813_080419\QM5_13205_xau-xag-qc.compile.log`.

| Artifact | SHA-256 |
|---|---|
| MQ5 | `99343273123A9BD47EFAC8098AA36D57A8A3F7CD5E82AE145F88D43D689575B7` |
| EX5 | `5DBD7C9EE266F7E6A898B7C4E055B006D66D7AB62BF23901D2940DBC348D5D9D` |
| SPEC | `845D49E8D9C7742B12E66D22AF943C0A3F7FBAD028C42413B3923E38220E3D27` |
| Backtest setfile | `F323403E1F50BDA4D1A50754BCE6B2A08F17709686F94F54C96EE4FD878A26AC` |
| Basket manifest | `6587999491EEC4290CF4681DE3BAF60731D9DD99F5991B04987C25DAE1D97EE5` |

## Prior Q02 evidence retained

Both historical v5.0 rows remain immutable and terminal `FAIL` with
`MIN_TRADES_NOT_MET`. Each bound run completed normally with Model 4, no
initialization failure, and two trades over `2018-07-02` through `2022-12-31`:

- `be5ffa78-fdfb-4718-af89-5f7fc7e8dee3`;
- `d7f3de72-d870-441a-88b1-d18562c0863f`.

Those are economic frequency failures, not infrastructure failures. The
framework-calendar correction changes the cadence contract and therefore
requires a fresh Q02, but it is not represented as evidence that density or
edge improved.

## CPU-ceiling stop evidence

At `2026-08-13T08:05:10Z`, exact path-anchored factory inspection found four
running T1–T10 terminals (`T1`, `T2`, `T9`, `T10`) and five active farm work
items. `T_Live` and an FTMO terminal were observed but excluded from the
factory count and were not controlled. Three one-second host CPU samples were
`100.0%`, `100.0%`, and `99.9%` on 16 logical processors (average `100.0%`).

That is the backtest CPU ceiling. The operation stopped before smoke or Q02
enqueue even though the terminal-count ceiling was not reached. No process,
terminal, reservation, or work item was stopped, released, dispatched, or
modified.

## Next deterministic action

When host CPU and governed terminal capacity are below the paced ceiling:

1. Verify the MQ5, EX5, and setfile hashes above and confirm no open
   `QM5_13205` work item or competing agent claim.
2. Clear only the build task's capacity block under an exact DB preimage.
3. Materialize the build result for task
   `2774ef4d-0a43-47e6-b5ff-abf01a614630`, record the Q01 PASS, and enqueue
   exactly one append-only logical-basket Q02 row through the canonical farm
   path.
4. Do not dispatch manually; the paced fleet owns execution.

## Safety boundary

- No `T_Live` file, AutoTrading setting, live setfile, deploy manifest, or
  T_Live manifest was touched.
- No portfolio gate, portfolio admission, or portfolio KPI path was touched.
- No Q02 or later efficacy, certification, decorrelation, or portfolio result
  is claimed.
