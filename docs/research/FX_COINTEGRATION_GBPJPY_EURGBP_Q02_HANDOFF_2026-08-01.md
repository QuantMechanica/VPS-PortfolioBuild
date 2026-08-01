# QM5_20201 GBPJPY/EURGBP Cointegration — Q02 Handoff

Date: 2026-08-01
Branch: `agents/board-advisor`

## Outcome

`QM5_20201_gbpjpy-eurgbp` is a new, non-duplicate, low-frequency D1 FX
basket. Its approved card, deterministic registry allocation, two traded
magic rows, EA, RISK_FIXED setfiles, basket manifest, and Q01 evidence are
complete. One logical Q02 work item is pending:

- Logical symbol: `QM5_20201_GBPJPY_EURGBP_COINTEGRATION_D1`
- Work item: `3de84ccb-ded5-4289-9283-a52df4e3551e`
- Queue state at handoff: `pending`, attempt 0, unclaimed
- Physical host setfile: deliberately skipped in favor of the logical basket

The anchor baskets did not need repair. `QM5_12532` has canonical Q02 PASS
followed by Q05 FAIL, while `QM5_12533` has canonical Q02 PASS followed by
Q04 FAIL.

## Selection and Source Boundary

The checked-in sign-aware reproduction of the fixed 66-pair scan ranks
GBPJPY/EURGBP eighteenth by OOS net Sharpe. Rank 17 AUDJPY/EURAUD is already
built as `QM5_20200`. The deterministic dedup check and exact-pair searches
found no dedicated fixed-beta GBPJPY/EURGBP D1 card, EA, registry allocation,
or logical manifest before this build.

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| GBPJPY / EURGBP | 0.676373 | 0.619982 | 7.697720% | 20 | -1.681438352 | 82.785 D1 bars |

The sub-0.8 OOS Sharpe and very slow estimated half-life are adverse
evidence. The card authorizes one frontier test and requires retirement on
terminal economic failure or sub-floor cadence; it forbids beta refitting,
filters, and parameter rescue.

Source lineage:

- `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`

Chan supplies the reputable structural pair-trading method and makes no
performance claim for GBPJPY/EURGBP.

## Mechanization

- Host/traded leg: `GBPJPY.DWX`, magic `202010000`
- Companion/traded leg: `EURGBP.DWX`, magic `202010001`
- Conversion-history only: `USDJPY.DWX`, `GBPUSD.DWX`, `EURUSD.DWX`
- Fixed spread: `ln(GBPJPY) - (-1.681438352) * ln(EURGBP)`
- Signal: strictly prior 60-bar closed-D1 z-score
- Entry/exit: `abs(z) > 2.0` / `abs(z) < 0.5`
- Negative-beta direction: long spread buys both legs; short spread sells both
- Hard stop: `ATR(20, D1) * 2.0` per traded leg
- Package safety: both normalized volumes are preflighted; partial entries and
  orphan states are flattened
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

"Market-neutral" is limited to the fitted two-series residual. GBP appears in
opposite quotation positions, but the package retains EUR, JPY, carry, and
risk-sentiment exposure.

## Q01 Evidence

- Strategy Card schema/ML lint: PASS
- G0 approval and build-authorization guard: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- MetaEditor compile: PASS, zero errors and zero warnings
- SPEC validation: PASS
- Symbol-scope validation: `BASKET_OK`, zero violations
- Targeted rank-15 through rank-18 basket regression: PASS
- Magic resolver: 15,389 rows kept, zero dropped with `--keep-obsolete`
- EX5 SHA-256:
  `ac8f37ae78472ddd9e37e4bd954cafc9c077a63aae78e5986205d5436ae51f88`
- Build report:
  `D:\QM\reports\framework\21\build_check_20260801_205745.json`
- Compile summary:
  `D:\QM\reports\compile\20260801_205746\summary.csv`

No manual smoke, tester, or backtest run was launched.

## Q02 Queue Contract

The final path-aware precheck at `2026-08-01T21:02Z` found six factory
terminals running (`T1`, `T2`, `T6`, `T7`, `T8`, `T10`) against the
seven-terminal ceiling. `T_Live` was observed separately and excluded; it was
not controlled.

The targeted, idempotent sweep created exactly one logical row with all five
histories, USD 100,000 tester account, 450-minute basket timeout, and
`priority_track` enabled. The physical host setfile was skipped with
`basket_manifest_logical_setfile_preferred`. No tester was manually
dispatched and no Q02 verdict is claimed.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live setfile changed.
- No manual tester launch, terminal control, live action, or portfolio-gate
  mutation occurred.
