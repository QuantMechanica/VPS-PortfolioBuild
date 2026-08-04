# QM5_20211 GBPJPY/EURAUD Cointegration — Q02 Handoff

Date: 2026-08-04
Branch: `agents/board-advisor`

## Outcome

`QM5_20211_gbpjpy-euraud` is a new, non-duplicate, low-frequency D1 FX
basket. Its approved card, deterministic registry allocation, two traded
magic rows, EA, RISK_FIXED setfiles, basket manifest, and Q01 evidence are
complete. One logical Q02 work item is pending:

- Logical symbol: `QM5_20211_GBPJPY_EURAUD_COINTEGRATION_D1`
- Work item: `21db772c-c974-4a05-8e21-5ec78659e988`
- Queue state at handoff: `pending`, attempt 0, unclaimed
- Physical host setfile: deliberately skipped in favor of the logical basket

The anchor baskets did not need repair. `QM5_12532` has canonical Q02 PASS
followed by Q05 FAIL, while `QM5_12533` has canonical Q02 PASS followed by
Q04 FAIL.

## Selection and Source Boundary

The checked-in sign-aware reproduction of the frozen 66-pair scan ranks
GBPJPY/EURAUD thirty-first by OOS net Sharpe. Rank 30, GBPUSD/AUDUSD, is
already represented by dedicated D1 basket `QM5_12739`. Exact strategy/slug
checks, card and registry searches, and an unordered traded-symbol manifest
reconciliation found no dedicated fixed-beta GBPJPY/EURAUD D1 sleeve before
this build.

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| GBPJPY / EURAUD | 0.430254 | 0.273190 | 4.833998% | 19 | -1.386054145 | 33.694 D1 bars |

The sub-0.8 OOS score is adverse evidence. Positive DEV performance and the
moderate half-life do not establish an edge. The approved card authorizes one
frontier test and requires retirement on terminal economic failure or
sub-floor cadence. It forbids beta refitting, filters, pair substitution, and
parameter rescue.

Source lineage:

- `strategy-seeds/sources/SRC02/source.md`
- `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`

Chan supplies the reputable structural pair-trading method and makes no
performance claim for GBPJPY/EURAUD.

## Mechanization

- Host/traded leg: `GBPJPY.DWX`, magic `202110000`
- Companion/traded leg: `EURAUD.DWX`, magic `202110001`
- Conversion-history only: `USDJPY.DWX`, `GBPUSD.DWX`, `EURUSD.DWX`, and
  `AUDUSD.DWX`
- Fixed spread: `ln(GBPJPY) - (-1.386054145) * ln(EURAUD)`
- Signal: strictly prior 60-bar closed-D1 z-score
- Entry/exit: `abs(z) > 2.0` / `abs(z) < 0.5`
- Negative-beta direction: long spread buys both legs; short spread sells both
- Hard stop: `ATR(20, D1) * 2.0` per traded leg
- Package safety: both normalized volumes are preflighted; partial entries and
  orphan states are flattened
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

“Market-neutral” is limited to the fitted residual. The package retains GBP,
JPY, EUR, AUD, carry, and risk-sentiment exposure.

## Q01 Evidence

- Strategy Card schema/ML lint: PASS
- G0 card lint and build authorization guard: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- MetaEditor compile: PASS, zero errors and zero warnings
- SPEC validation: PASS
- Symbol-scope validation: `BASKET_OK`, zero violations
- Basket-manifest regression suite: 35 PASS
- Magic resolver regression suite: 5 PASS
- Magic resolver: 15,473 rows kept, zero dropped with `--keep-obsolete`
- Magic registry SHA-256:
  `7a5b4cd2fbb9874973946072ed65a7fa01a3231bb686d4649c5403d0291c6fcc`
- MQ5 SHA-256:
  `b93fee38cc15e3a72eecb1ae189f6fabfe9a793221bf1f683d1414a5fafd43df`
- EX5 SHA-256:
  `54ddb7987359f0f5a8ad8806c0f6ea5582b23979c8b6814ea6610e3547bcdc56`
- Build report:
  `D:\QM\reports\framework\21\build_check_20260804_023205.json`
- Compile summary:
  `D:\QM\reports\compile\20260804_023205\summary.csv`

The targeted registry/build checks pass. The repository-wide legacy registry
validator still reports its pre-existing historical ID/slug debt; it reports
no `QM5_20211` issue. No manual smoke, tester, or backtest run was launched.

## Q02 Queue Contract

The final path-aware precheck found three factory terminals running (`T10`,
`T6`, and `T9`) against the seven-terminal ceiling. `T_Live` and an unrelated
FTMO terminal were observed separately and excluded; neither was controlled.

The no-mutation dry run selected exactly one logical row. Two apply attempts
made no change because the canonical factory mutation lock was busy. The
bounded retry acquired the same lock normally, created exactly one logical
row with all six histories, USD 100,000 tester account, 450-minute basket
timeout, and `priority_track` enabled, then released the lock normally. The
physical host setfile was skipped with
`basket_manifest_logical_setfile_preferred`. No tester was manually dispatched
and no Q02 verdict is claimed.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live setfile changed.
- No manual tester launch, terminal control, live action, or portfolio-gate
  mutation occurred.
