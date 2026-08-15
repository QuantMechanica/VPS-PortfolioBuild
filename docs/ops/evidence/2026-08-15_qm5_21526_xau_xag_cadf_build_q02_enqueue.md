# QM5_21526 XAU/XAG Annual CADF Build And Q02 Enqueue

Date: 2026-08-15 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; exactly one logical-basket Q02 item enqueued and initially
pending

## Outcome

One new structural, low-frequency commodity relative-value candidate was
researched, approved, allocated, built, strictly validated, and handed to the
paced Q02 fleet:

- EA: `QM5_21526_xau-xag-cadf`.
- Logical carrier: `QM5_21526_XAU_XAG_CADF_D1`, hosted on `XAUUSD.DWX` D1
  and trading registered gold and silver legs.
- Formation: at the first host D1 bar of each broker year, select exactly 252
  synchronized completed observations strictly before the anchor and fit
  `log(XAU)=alpha+beta*log(XAG)+residual` with an intercept.
- Admission: freeze the annual model only as tradable when beta is in
  `[0.10,3.00]`, the governed one-lag CADF level t-statistic is `<= -3.343`,
  OU adjustment is negative, and fitted half-life is in `[2,30]`.
- Entry: fade only a fresh frozen-model residual crossing outside `+/-1.0`.
  A positive cross sells gold and buys silver; a negative cross buys gold and
  sells silver.
- Exit: close at `abs(z)<=0.5`, `ceil(fitted_half_life)` calendar days,
  annual rollover, or invalid synchronized model/data/package state.
- Risk: one aggregate `RISK_FIXED=1000` package, `RISK_PERCENT=0`, with
  normalized stop-risk weights `1.0` for gold and `abs(beta)` for silver.
  Both legs receive frozen `3.5*ATR(20,D1)` hard stops and no target.
- Lifecycle: persist the completed signal before fallible entry gates, open
  gold first, open silver second, validate exact directions/stops/magics, and
  flatten all owned legs after any partial or malformed result.

The paired construction removes some common precious-metal direction but
does not prove dollar, beta, volatility, factor, market, or portfolio
neutrality. Q02 owns density and economics; the unchanged later portfolio
gate alone may measure realized book correlation.

## Source And Non-Duplicate Boundary

The governed composite packet is
`strategy-seeds/sources/CHAN-SCHWEIKERT-XAUXAG-CADF-2026/source.md`. Chan
(Wiley, 2009) supplies the OLS/CADF train-test pair method, standardized
residual fade, convergence exit, and fitted half-life discipline.
Schweikert (2018) and Yaya, Vo, and Olayinka (2021) supply bounded
peer-reviewed gold/silver long-run-relation context. CME Group establishes
the gold/silver intermarket carrier.

No source tests this Darwinex CFD pair, annual broker-calendar translation,
locked critical value, risk controls, costs, density, neutrality, or QM book.
No coefficient, performance statistic, or decorrelation claim transfers.

The deterministic pre-allocation scan covered 4,398 EA registry rows and 534
root cards. It returned no exact identity and one expected CADF-family fuzzy
match, `QM5_21525_wti-xcu-cadf`. Manual family review separated this annual
precious-metal equilibrium from rolling 120-D1 XAU/XAG OLS without CADF or
half-life (`QM5_20161`), fixed-ratio XAU/XAG (`QM5_12577`), monthly
conditional-quantile XAU/XAG (`QM5_13205`), the AUDUSD/NZDUSD Chan carrier
(`QM5_1017`), and rolling WTI/copper CADF (`QM5_21525`). Verdict:
`CLEAN_XAU_XAG_ANNUAL_CADF_HALFLIFE_RESIDUAL_REVERSION_AFTER_FAMILY_REVIEW`.

## Allocation And Commit Chain

- Durable source approval and governed composite packet: `622acfccc`.
- G0 decision, canonical/approved cards, and EA-ID allocation: `9a3995c4f`.
- Two active magic rows, basket manifest, and regenerated resolver:
  `b56d8f9fe`.
- EA source/binary, SPEC, reference suite, fixed-risk setfile, and Q01 state:
  `ab3f1da0b`.

Magic `215260000` binds gold slot 0; magic `215260001` binds silver slot 1.
Resolver regeneration retained 15,964 active rows, dropped zero, and included
both allocated magics.

## Q01 Evidence

- G0/card schema lints: PASS, with no missing sections and no prohibited-model
  hits. Canonical, approved, and build-time cards were byte-identical before
  enqueue-state sealing.
- Card-v2 source/QM/override/precedence/runtime/falsification sections were
  added explicitly; the repository-wide execution-contract audit remained
  contaminated only by pre-existing DXZ book/calendar findings outside EA
  21526.
- Approved-card build authorization guard: PASS for EA ID 21526, registered
  magics, and the exact EA directory.
- Seven-section SPEC validation: PASS.
- Final strict MetaEditor compile: PASS, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260815_113410/QM5_21526_xau-xag-cadf.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260815_113410/summary.csv`.
- Final-source scoped V5 static/set/build check with compile skipped after the
  independent strict compile: PASS, zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260815_113445.json`.
- Independent arithmetic/lifecycle suite: 14 tests PASS, covering exact
  pre-anchor formation, no formation/signal overlap, restart invariance,
  synchronized missing-day handling, OLS/CADF/OU admission, locked 247 CADF
  degrees of freedom, crossing directions and boundaries, convergence,
  aggregate fixed-risk split, frozen z-score arithmetic, fitted time-stop
  ceiling, and consumed-attempt gate order.
- P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_21526/P1/P1_QM5_21526_result.json`.
- EX5 size: 388,402 bytes.

Artifact SHA-256 values at enqueue:

| Artifact | SHA-256 |
|---|---|
| Source packet | `5FE6C4DCCFA3AC871CDA7B09734AA97586407584AB21C42EB5EB67DB0E9EFF95` |
| Source approval | `ADDE2DA1D22E08FB538352FC95E4E7835061A6DEAB519AB5F36E343BE40C3694` |
| G0 decision | `4ABC1904EE5475D28CA7C939F67B2F5097BA2A010F20E98F887199DDC4421DF0` |
| Canonical/approved/build card after enqueue seal | `B4A441E9E5C31F5EFF949CFBA863E8A7D9CE6D6F0526C0CF54FACA97BF802922` |
| MQ5 | `091C8FA1580489F27AF302662DF46C352E376CCFC0A0A42EF5E08C3A3E556A73` |
| EX5 | `39C9BA37E024BCC74784043759D6606943ABD815981C43ED12528986021EC298` |
| SPEC | `19F470321BA2EBD5BA6057ED36F8F2E14EC5DE547194739D28BF48EEDBC09616` |
| Basket manifest | `BD6893571572C576FF226E8364ED010F5E32B6044C7883323B7BFB295B0A95E3` |
| Backtest set | `A1B5B8EEE2EAFFDF37912F9B87DBD9D9C20A5D83A5F9F2D5A23B311982E6272A` |
| Reference suite | `98D948EB9916951D1DF120F1DCAF79430540B1B591CB496184A5180E947F0D0A` |
| Current magic resolver | `42677C5B78B51CE6E704DC137F8D437D14E4C239F3B30227B821A0B506058485` |

## Q02 Enqueue Evidence

The exact scoped no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_21526 --symbols QM5_21526_XAU_XAG_CADF_D1 --max-part2-per-run 0

It reported `APPLY=False`, one selected never-tested item, zero scoped skips,
zero stranded retries, zero deferred promotions, and one priority-track item.

Immediately before apply, a read-only process scan anchored exclusively to
`D:/QM/mt5/T1..T10/terminal64.exe` found four factory terminals: T5, T7, T9,
and T10. Four was below the binding seven-terminal backtest ceiling.
`FACTORY_OFF.flag` was absent, the mutation lock was free, the database held
1,019 pending rows against the separate 7,000-row queue ceiling, and EA 21526
had zero pre-existing rows. A supplementary three-second host CPU sample was
high (89.6% average, 96.7% maximum), so this task performed only the
non-compute enqueue and did not call dispatch or start a tester.

The exact apply command was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_21526 --symbols QM5_21526_XAU_XAG_CADF_D1 --max-part2-per-run 0

It reported exactly one never-tested enqueue and no other work. Direct
read-only SQLite verification immediately afterward found exactly one row:

| Field | Value |
|---|---|
| work item | `427f21c5-ac7f-4948-9f38-f5df4e8bb63f` |
| phase / kind | `Q02` / `backtest` |
| logical symbol | `QM5_21526_XAU_XAG_CADF_D1` |
| host | `XAUUSD.DWX` D1 |
| basket symbols | `XAUUSD.DWX`, `XAGUSD.DWX` |
| setfile | canonical logical-basket D1 backtest set |
| status at verification | `pending` |
| attempt count | `0` |
| claimed by | none |
| created UTC | `2026-08-15T11:38:00+00:00` |
| priority track | `true` |

The helper uses one shared rotating sweep-evidence filename; concurrent sweeps
can overwrite it. This record therefore relies on the captured scoped command
results and unique database row rather than treating that mutable file as
task-specific proof.

## Safety Boundary

- No manual backtest, smoke run, phase runner, dispatch tick, terminal
  reservation, tester launch, process mutation, or factory-lock removal was
  performed.
- No live, demo, shadow, stress, or optimization setfile was created.
- No terminal was started, stopped, reserved, reaped, or altered.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
- Q02 enqueue is not certification, profitability evidence, decorrelation
  evidence, portfolio admission, or live-use authorization.
