# QM5_20216 AUDUSD/EURAUD Cointegration — Q02 Handoff

Date: 2026-08-05
Branch: `agents/board-advisor`

## Outcome

`QM5_20216_audusd-euraud` is a new, non-duplicate, low-frequency D1 FX
basket. Its approved card, deterministic registry allocation, two traded
magic rows, compiled EA, RISK_FIXED setfiles, basket manifest, and Q01
evidence are complete. One logical Q02 work item is pending:

- Logical symbol: `QM5_20216_AUDUSD_EURAUD_COINTEGRATION_D1`
- Work item: `214ac1b6-a810-456f-801a-97e3673bc953`
- Queue state at handoff: `pending`, attempt 0, unclaimed
- Physical host setfile: skipped in favor of the logical basket

The anchor baskets did not need repair. `QM5_12532` has canonical Q02 PASS
followed by Q05 FAIL, while `QM5_12533` has canonical Q02 PASS followed by
Q04 FAIL.

## Selection and Source Boundary

The checked-in sign-aware reproduction of the frozen 66-pair scan ranks
AUDUSD/EURAUD thirty-third by OOS net Sharpe. Rank 32, GBPUSD/EURJPY, is
already represented by `QM5_20212`. Exact pair searches and an unordered
traded-symbol manifest reconciliation found no dedicated fixed-beta
AUDUSD/EURAUD D1 sleeve before this build.

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| AUDUSD / EURAUD | -0.025549 | 0.160430 | 1.290977% | 15 | -0.655175398 | 171.485 D1 bars |

Negative DEV performance, a sub-0.8 OOS score, and the very slow fitted
half-life are adverse evidence. The approved card authorizes one frontier
test and requires retirement on terminal economic failure or sub-floor
cadence. It forbids beta refitting, filters, pair substitution, parameter
rescue, and ML.

Source lineage:

- `strategy-seeds/sources/SRC02/source.md`
- `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`

Chan supplies the reputable structural pair-trading method and makes no
performance claim for AUDUSD/EURAUD.

## Mechanization

- Host/traded leg: `AUDUSD.DWX`, magic `202160000`
- Companion/traded leg: `EURAUD.DWX`, magic `202160001`
- Conversion-history only: `EURUSD.DWX`
- Fixed spread: `ln(AUDUSD) - (-0.655175398) * ln(EURAUD)`
- Signal: strictly prior 60-bar closed-D1 z-score
- Entry/exit: `abs(z) > 2.0` / `abs(z) < 0.5`
- Negative-beta direction: long spread buys both legs; short spread sells both
- Hard stop: `ATR(20, D1) * 2.0` per traded leg
- Package safety: both normalized volumes are preflighted; partial entries and
  orphan states are flattened
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

“Market-neutral” is limited to the fitted residual. The package retains AUD,
USD, EUR, carry, and risk-sentiment exposure.

## Q01 Evidence

- Strategy Card schema/ML lint: PASS
- G0 card lint and build authorization guard: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- MetaEditor compile: PASS, zero errors and zero warnings
- SPEC validation: PASS
- Symbol-scope validation: `BASKET_OK`, zero violations
- Basket-manifest regression suite: 37 PASS
- Magic resolver regression suite: 5 PASS
- Magic resolver: 15,485 rows kept, zero dropped with `--keep-obsolete`
- Magic registry SHA-256:
  `fcba5d0bfd2d1ca3d64de65a23499eac1916a9b031953ce546f737bdd090fc99`
- Card SHA-256:
  `45586d4ec787bd3185e6707e450f8358aa1b2dbc6a4619b640b97a31a3cfbcac`
- MQ5 SHA-256:
  `8a7beac6dad3787a9920b658da87262b44f5fd371f39260c954a41a240477e72`
- EX5 SHA-256:
  `8191c96f3509ae24b6f8015b633edb5c9eaa6e7e5ff209080629106f384954e5`
- Build report:
  `D:/QM/reports/framework/21/build_check_20260804_224845.json`
- Compile summary:
  `D:/QM/reports/compile/20260804_224845/summary.csv`

No manual smoke, tester, or backtest run was launched.

## Q02 Queue Contract

The path-aware precheck found four factory terminals running (`T1`, `T2`,
`T4`, and `T8`) against the seven-terminal ceiling. The guarded enqueue
rechecked capacity while holding the canonical mutation lock and found three
(`T1`, `T2`, and `T8`). `T_Live` and an unrelated FTMO terminal were observed
separately and excluded; neither was controlled.

The no-mutation dry run selected exactly one logical row. Initial apply
attempts made no change while the canonical lock was busy. A bounded in-process
retry acquired the same lock normally, created exactly one logical row with
all three histories, USD 100,000 tester account, 450-minute basket timeout,
and `priority_track` enabled, then released the lock normally. The physical
host setfile was skipped with
`basket_manifest_logical_setfile_preferred`. No tester was manually dispatched
and no Q02 verdict is claimed.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live setfile changed.
- No manual tester launch, terminal control, live action, or portfolio-gate
  mutation occurred.
