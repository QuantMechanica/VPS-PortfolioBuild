# QM5_21525 WTI/Copper CADF Build And Q02 Enqueue

Date: 2026-08-15 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; exactly one logical-basket Q02 item enqueued and initially
pending

## Outcome

One new structural, low-frequency commodity relative-value candidate was
researched, approved, allocated, built, strictly validated, and handed to the
paced Q02 fleet:

- EA: `QM5_21525_wti-xcu-cadf`.
- Logical carrier: `QM5_21525_WTI_XCU_CADF_D1`, hosted on `XTIUSD.DWX` D1
  and trading registered WTI and copper legs.
- Mechanic: fit `log(WTI) = alpha + beta*log(copper) + residual` over exactly
  252 synchronized completed D1 observations. Admit the state only when a
  simple one-lag residual CADF proxy has `rho<0`, `t_rho<=-3.043`,
  `0<1+rho<1`, and implied half-life in `[2,60]`.
- Entry: fade only a fresh standardized residual crossing outside `+/-1.0`.
  A positive cross sells WTI and buys copper; a negative cross buys WTI and
  sells copper.
- Exit: close at `abs(z)<=0.5`, model/data/package failure, or sixty calendar
  days.
- Risk: one aggregate `RISK_FIXED=1000` package, `RISK_PERCENT=0`, with
  normalized stop-risk weights `1.0` for WTI and `abs(beta)` for copper. Each
  leg receives a frozen `3.5 * ATR(20,D1)` hard stop and no target.
- Lifecycle: WTI-first ordered open, explicit direction validation, failed-
  order rollback, orphan/duplicate/same-side/missing-stop repair, and no
  entry while a package exists.

Opposite legs and beta-weighted stop risk are a construction, not proof of
dollar, beta, factor, market, volatility, or portfolio neutrality. Q02 owns
density and economics; the unchanged later portfolio gate alone may measure
realized book correlation.

## Source And Non-Duplicate Boundary

The governed packet is
`strategy-seeds/sources/CHAN-EIA-USGS-WTI-XCU-CADF-2026/source.md`. Chan
(Wiley, 2009) supplies the OLS/CADF pair-trading method, standardized
residual fade, mean-band exit, and half-life discipline. Official U.S. EIA,
CME Group, and U.S. Geological Survey references establish the distinct WTI
and copper carrier contexts.

Chan tests GLD/GDX, not WTI/copper. The official carrier sources do not test
a trading rule or prove cointegration. No source coefficient, efficacy,
density, cost, neutrality, correlation, or portfolio result transfers to the
Darwinex CFDs.

The pre-allocation deterministic check returned `CLEAN` across 4,397 EA
registry rows and 493 root cards. Manual review separated this price-level,
CADF-qualified residual fade from same-pair return-spread reversion
(`QM5_13090`), channel continuation (`QM5_13094`), twelve-month relative
momentum (`QM5_21524`), oil/gas trend-augmented ECM (`QM5_20237`), precious-
metal OLS (`QM5_20161`), and the incumbent XNG oscillator (`QM5_12567`).

## Allocation And Commit Chain

- Durable source approval and governed source packet: `a16a01823`.
- G0 decision, canonical/approved cards, and EA-ID allocation: `9e0e0c10f`.
- Two magic rows, basket manifest, and regenerated resolver: `623d6ed61`.
- EA source/binary, SPEC, reference suite, fixed-risk setfile, and Q01 state:
  `0003a22a8`.

Magic `215250000` binds WTI slot 0; magic `215250001` binds copper slot 1.
Resolver regeneration retained 15,962 rows, dropped zero, and reproduced its
declared canonical registry hash.

## Q01 Evidence

- G0 lint and all three synchronized card-schema lints: PASS, with no missing
  sections or prohibited-model hits.
- Approved-card build authorization guard: PASS for EA ID 21525, both magic
  rows, and the exact EA directory.
- Seven-section SPEC validation: PASS.
- Final strict MetaEditor compile: PASS, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260815_091815/QM5_21525_wti-xcu-cadf.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260815_091815/summary.csv`.
- Final-source V5 static/set/build check with compile skipped after the
  independent strict compile: PASS, zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260815_092001.json`.
- Independent arithmetic suite: 10 tests PASS, covering OLS/CADF values and
  degrees of freedom, crossing directions, strict boundaries, aggregate risk
  split, timestamp synchronization, staleness, and invalid prices.
- P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_21525/P1/P1_QM5_21525_result.json`.
- EX5 size: 384,308 bytes.

Artifact SHA-256 values at enqueue:

| Artifact | SHA-256 |
|---|---|
| Source packet | `06F347AF17EF32AEF3ADEEA83F9244822FE74B4B734F15E767F4D0BADB9EB9DC` |
| Source approval | `EDAB659F72EB5F0DDCA8078F3D040F931EAFF5F61B9ACD9E77E91BA73E1F8DA4` |
| G0 decision | `276372BA56A0F45FAA470D0937FA4BADCB6CE5411A66B06E5F1DCEF29D31348D` |
| Canonical/approved/build card | `E309B9B9D7749995573F5500050B051E24BBB8F5FA71F22BC72B9CA24B67D165` |
| MQ5 | `678BC80F6FA143EDEDA323E0894BD100388EAF85C9167F3D323F10A66AF51390` |
| EX5 | `A3E8586FC05232652D834DFE517421C352DCE627DD7762096AC90B9BDD6AD372` |
| SPEC | `2FE88905A629B23ABF6011A282A1B837342250C3DB68EA71B08515A5A5BB66A9` |
| Basket manifest | `6AB2C62E2CD58C6D16B769F68BDF17429618D6DC539EC8649C971D9B17BD57F0` |
| Backtest set | `A51B1FCCC51819793924BA5F42486314E7BFADD4AE19EC45BFF732167BB104D9` |
| Magic resolver | `A98703C032EE02C7C6A2FE0104AD47F66ED9C0B1EF1CF4C51971F26C6548C222` |

## Q02 Enqueue Evidence

The exact scoped no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_21525 --symbols QM5_21525_WTI_XCU_CADF_D1 --max-part2-per-run 0

It reported `APPLY=False`, one selected never-tested item, zero skipped, zero
stranded retries, zero deferred promotions, and one priority-track item.

Immediately before apply, a read-only process scan anchored to
`D:/QM/mt5/T1..T10/terminal64.exe` and excluding every other path found five
factory terminals: T2, T3, T6, T7, and T8. Five was below the binding ceiling
of seven. `FACTORY_OFF.flag` was absent, the mutation lock was free, and the
dry run observed 1,018 pending rows against the separate 7,000-row queue
ceiling.

The exact apply command was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_21525 --symbols QM5_21525_WTI_XCU_CADF_D1 --max-part2-per-run 0

It reported exactly one never-tested enqueue and no other work. Direct
read-only SQLite verification then found exactly one row for `QM5_21525`:

| Field | Value |
|---|---|
| work item | `4a6d441f-89b7-4e95-b492-b28f5aba3a12` |
| phase / kind | `Q02` / `backtest` |
| logical symbol | `QM5_21525_WTI_XCU_CADF_D1` |
| host | `XTIUSD.DWX` D1 |
| basket symbols | `XTIUSD.DWX`, `XCUUSD.DWX` |
| status at verification | `pending` |
| attempt count | `0` |
| claimed by | none |
| created UTC | `2026-08-15T09:25:28+00:00` |
| priority track | `true` |

The helper uses one shared rotating sweep-evidence filename. A concurrent
unscoped dry run later overwrote that file, so this task does not cite its
mutable contents as task-specific proof. The unique queue row above and the
captured scoped command results are the durable enqueue identity. No dispatch
tick was called.

## Safety Boundary

- No manual backtest, smoke run, dispatch tick, terminal reservation, tester
  launch, process mutation, or factory-lock removal was performed.
- No live, demo, shadow, optimization, or stress setfile was created.
- No terminal was started, stopped, reserved, reaped, or altered.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
- Q02 enqueue is not certification, profitability evidence, decorrelation
  evidence, portfolio admission, or live-use authorization.
