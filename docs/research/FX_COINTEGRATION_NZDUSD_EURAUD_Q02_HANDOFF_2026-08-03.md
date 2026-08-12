# QM5_20208 NZDUSD/EURAUD Cointegration — Q02 Handoff

Date: 2026-08-03
Branch: `agents/board-advisor`

## Outcome

`QM5_20208_nzdusd-euraud` is a new, non-duplicate, low-frequency D1 FX
basket. Its approved card, deterministic registry allocation, two traded
magic rows, EA, RISK_FIXED setfiles, basket manifest, and Q01 evidence are
complete. One logical Q02 work item is pending:

- Logical symbol: `QM5_20208_NZDUSD_EURAUD_COINTEGRATION_D1`
- Work item: `1935fc01-6eaa-4db1-8397-660d22ebdfbb`
- Queue state at handoff: `pending`, attempt 0, unclaimed
- Physical host setfile: deliberately skipped in favor of the logical basket

The anchor baskets did not need repair. `QM5_12532` has canonical Q02 PASS
followed by Q05 FAIL, while `QM5_12533` has canonical Q02 PASS followed by
Q04 FAIL.

## Selection and Source Boundary

The checked-in sign-aware reproduction of the fixed 66-pair scan ranks
NZDUSD/EURAUD twenty-seventh by OOS net Sharpe. Rank 26, NZDUSD/AUDJPY, is
already the dedicated D1 basket `QM5_12749`. An unordered traded-symbol
manifest reconciliation plus exact card and registry searches found no
dedicated fixed-beta NZDUSD/EURAUD D1 card, allocation, EA, or logical
manifest before this build.

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| NZDUSD / EURAUD | -0.091704 | 0.474703 | 4.877699% | 19 | -0.286008035 | 138.333 D1 bars |

Negative DEV Sharpe, sub-0.8 OOS Sharpe, and the very slow half-life are
adverse evidence. The card authorizes one frontier test and requires
retirement on terminal economic failure, sub-floor cadence, or
broker-minimum-volume rejection. It forbids beta refitting, filters, pair
substitution, and parameter rescue.

Source lineage:

- `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`

Chan supplies the reputable structural pair-trading method and makes no
performance claim for NZDUSD/EURAUD.

## Mechanization

- Host/traded leg: `NZDUSD.DWX`, magic `202080000`
- Companion/traded leg: `EURAUD.DWX`, magic `202080001`
- Conversion-history only: `AUDUSD.DWX`, `EURUSD.DWX`
- Fixed spread: `ln(NZDUSD) - (-0.286008035) * ln(EURAUD)`
- Signal: strictly prior 60-bar closed-D1 z-score
- Entry/exit: `abs(z) > 2.0` / `abs(z) < 0.5`
- Negative-beta direction: long spread buys both legs; short spread sells both
- Hard stop: `ATR(20, D1) * 2.0` per traded leg
- Package safety: both normalized volumes are preflighted; host-first partial
  entry and orphan states are flattened
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

“Market-neutral” is limited to the fitted residual. The package retains NZD,
EUR, AUD, USD, carry, and risk-sentiment exposure.

## Q01 Evidence

- Strategy Card schema/ML lint: PASS
- G0 card lint: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- MetaEditor compile: PASS, zero errors and zero warnings
- SPEC validation: PASS
- Symbol-scope validation: `BASKET_OK`, zero violations
- Basket-manifest regression suite: 33 PASS
- Magic resolver: 15,468 rows kept, zero dropped with `--keep-obsolete`
- Magic registry SHA-256:
  `6035d864c9749d3cb9ac2247907cfa9bff28bf33f9e6799f51041d911f2da6c0`
- MQ5 SHA-256:
  `ac7d3deba42aed2db1bf4fca01a6aac34f28ccfa6e496a6b64d93b3def0db8d3`
- EX5 SHA-256:
  `31d4460df6cd3e9ef579d8ed4e3849e62b3423ef0e942f6703122e2245988bc4`
- Build report:
  `D:\QM\reports\framework\21\build_check_20260803_152910.json`
- Compile summary:
  `D:\QM\reports\compile\20260803_152739\summary.csv`

No manual smoke, tester, or backtest run was launched.

## Q02 Queue Contract

The final path-aware precheck at `2026-08-03T15:30:54Z` found four factory
terminals running (`T1`, `T2`, `T3`, and `T5`) against the seven-terminal
ceiling. `T_Live` and an unrelated FTMO terminal were observed separately and
excluded; neither was controlled.

The targeted idempotent sweep acquired the canonical factory mutation lock,
created exactly one logical row with all four histories, USD 100,000 tester
account, 450-minute basket timeout, and `priority_track` enabled, then released
the lock normally. The physical host setfile was skipped with
`basket_manifest_logical_setfile_preferred`. No tester was manually dispatched
and no Q02 verdict is claimed.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live setfile changed.
- No manual tester launch, terminal control, live action, or portfolio-gate
  mutation occurred.
