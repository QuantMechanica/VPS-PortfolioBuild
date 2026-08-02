# QM5_20203 EURUSD/AUDJPY Cointegration — Q02 Handoff

Date: 2026-08-02
Branch: `agents/board-advisor`

## Outcome

`QM5_20203_eurusd-audjpy` is a new, non-duplicate, low-frequency D1 FX
basket. Its approved card, deterministic registry allocation, two traded
magic rows, EA, RISK_FIXED setfiles, basket manifest, and Q01 evidence are
complete. One logical Q02 work item is pending:

- Logical symbol: `QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1`
- Work item: `803cfaaa-d1e4-4d5c-a599-4d33b536ea9f`
- Queue state at handoff: `pending`, attempt 0, unclaimed
- Physical host setfile: deliberately skipped in favor of the logical basket

The anchor baskets did not need repair. `QM5_12532` has canonical Q02 PASS
followed by Q05 FAIL, while `QM5_12533` has canonical Q02 PASS followed by
Q04 FAIL.

## Selection and Source Boundary

The checked-in sign-aware reproduction of the fixed 66-pair scan ranks
EURUSD/AUDJPY twenty-first by OOS net Sharpe. Ranks 19 and 20,
EURGBP/EURAUD and NZDUSD/GBPJPY, are already represented by dedicated legacy
baskets `QM5_12712` and `QM5_12728`. Exact-pair and registry searches found no
dedicated fixed-beta EURUSD/AUDJPY D1 card, EA, allocation, or logical basket
manifest before this build.

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURUSD / AUDJPY | 0.215987 | 0.588463 | 4.556684% | 21 | -0.160071209 | 152.384 D1 bars |

The sub-0.8 OOS Sharpe, small companion hedge weight, and very slow estimated
half-life are adverse evidence. The card authorizes one frontier test and
requires retirement on terminal economic failure, sub-floor cadence, or
broker-minimum-volume rejection. It forbids beta refitting, rescue filters,
and parameter rescue.

Source lineage:

- `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`

Chan supplies the reputable structural pair-trading method and makes no
performance claim for EURUSD/AUDJPY.

## Mechanization

- Host/traded leg: `EURUSD.DWX`, magic `202030000`
- Companion/traded leg: `AUDJPY.DWX`, magic `202030001`
- Conversion-history only: `AUDUSD.DWX`, `USDJPY.DWX`
- Fixed spread: `ln(EURUSD) - (-0.160071209) * ln(AUDJPY)`
- Signal: strictly prior 60-bar closed-D1 z-score
- Entry/exit: `abs(z) > 2.0` / `abs(z) < 0.5`
- Negative-beta direction: long spread buys both legs; short spread sells both
- Hard stop: `ATR(20, D1) * 2.0` per traded leg
- Package safety: both normalized volumes are preflighted; partial entries and
  orphan states are flattened
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

"Market-neutral" is limited to the fitted two-series residual. The package
retains EUR, USD, AUD, JPY, carry, and risk-sentiment exposure.

## Q01 Evidence

- Strategy Card schema/ML lint: PASS
- G0 card lint: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- MetaEditor compile: PASS, zero errors and zero warnings
- SPEC validation: PASS
- Symbol-scope validation: `BASKET_OK`, zero violations
- Targeted basket-manifest regression: PASS
- Magic resolver: 15,403 rows kept, zero dropped with `--keep-obsolete`
- EX5 SHA-256:
  `4d57f2bc03a14ce0be3f7f18245adfff280955287cda5af1119d502d33d96270`
- Build report:
  `D:\QM\reports\framework\21\build_check_20260802_132127.json`
- Compile summary:
  `D:\QM\reports\compile\20260802_132128\summary.csv`

No manual smoke, tester, or backtest run was launched.

## Q02 Queue Contract

The final path-aware precheck at `2026-08-02T13:28:11Z` found five factory
terminals running (`T1`, `T5`, `T6`, `T8`, `T9`) against the seven-terminal
ceiling. `T_Live` was observed separately in the total process count and
excluded; it was not controlled.

The canonical factory mutation lock was acquired after a 13.828-second wait,
held for the final ceiling check and transactional enqueue, and released
normally. The targeted, idempotent sweep created exactly one logical row with
all four histories, USD 100,000 tester account, 450-minute basket timeout, and
`priority_track` enabled. The physical host setfile was skipped with
`basket_manifest_logical_setfile_preferred`. No tester was manually
dispatched and no Q02 verdict is claimed.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live setfile changed.
- No manual tester launch, terminal control, live action, or portfolio-gate
  mutation occurred.
