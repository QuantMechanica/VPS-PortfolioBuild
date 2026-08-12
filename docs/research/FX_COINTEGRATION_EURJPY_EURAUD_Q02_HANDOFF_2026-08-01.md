# QM5_20199 EURJPY/EURAUD Cointegration — Q02 Handoff

Date: 2026-08-01
Branch: `agents/board-advisor`

## Outcome

`QM5_20199_eurjpy-euraud` is a new, non-duplicate, low-frequency D1 FX
basket. Its approved card, deterministic registry allocation, two traded
magic rows, EA, RISK_FIXED setfiles, basket manifest, and Q01 evidence are
complete. One logical Q02 work item is pending:

- Logical symbol: `QM5_20199_EURJPY_EURAUD_COINTEGRATION_D1`
- Work item: `40bb7cc0-05f8-453a-a03e-515e7a916b13`
- Queue state: `pending`, attempt 0, unclaimed
- Physical host setfile: deliberately skipped in favor of the logical basket

The anchor baskets did not need repair. `QM5_12532` has canonical Q02 PASS
followed by Q05 FAIL, while `QM5_12533` has canonical Q02 PASS followed by
Q04 FAIL.

## Selection and Source Boundary

The checked-in sign-aware reproduction of the fixed 66-pair scan ranks
EURJPY/EURAUD sixteenth by OOS net Sharpe. Rank 15 EURJPY/EURGBP is already
built as `QM5_20197`. Exact-pair searches found no dedicated fixed-beta
EURJPY/EURAUD D1 card, EA, registry allocation, or logical manifest before
this build.

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURJPY / EURAUD | 0.843337 | 0.646172 | 10.514307% | 21 | -1.073345776 | 27.755 D1 bars |

The sub-0.8 OOS Sharpe and multi-week holding horizon are adverse evidence.
The card authorizes one frontier test and requires retirement on terminal
economic failure or sub-floor cadence; it forbids beta refitting, filters, and
parameter rescue.

Source lineage:

- `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`

Chan supplies the reputable structural pair-trading method and makes no
performance claim for EURJPY/EURAUD.

## Mechanization

- Host/traded leg: `EURJPY.DWX`, magic `201990000`
- Companion/traded leg: `EURAUD.DWX`, magic `201990001`
- Conversion-history only: `USDJPY.DWX`, `AUDUSD.DWX`, `EURUSD.DWX`
- Fixed spread: `ln(EURJPY) - (-1.073345776) * ln(EURAUD)`
- Signal: strictly prior 60-bar closed-D1 z-score
- Entry/exit: `abs(z) > 2.0` / `abs(z) < 0.5`
- Negative-beta direction: long spread buys both legs; short spread sells both
- Hard stop: `ATR(20, D1) * 2.0` per traded leg
- Package safety: both normalized volumes are preflighted; partial entries and
  orphan states are flattened
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

"Market-neutral" is limited to the fitted two-series residual. The shared EUR
base retains AUD, JPY, carry, and risk-sentiment exposure.

## Q01 Evidence

- Strategy Card schema/ML lint: PASS
- G0 approval and build-authorization guard: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- MetaEditor compile: PASS, zero errors and zero warnings
- SPEC validation: PASS
- Symbol-scope validation: `BASKET_OK`, zero violations
- Targeted basket regression: PASS
- Magic resolver: 15,385 rows kept, zero dropped with `--keep-obsolete`
- EX5 SHA-256:
  `3e15db9a246dffd7f162ae35769a68bdd36d9f27733d50a0a3b85f7f74adcb25`
- Build report:
  `D:\QM\reports\framework\21\build_check_20260801_192533.json`
- Compile summary:
  `D:\QM\reports\compile\20260801_192533\summary.csv`

No manual smoke, tester, or backtest run was launched.

## Q02 Queue Contract

The final precheck at `2026-08-01T19:27Z` found two factory terminals running
(`T7`, `T8`) against the seven-terminal ceiling. `T_Live` was observed
separately and excluded; it was not controlled.

The targeted enqueue created exactly one logical row with all five histories,
USD 100,000 tester account, 450-minute basket timeout, and `priority_track`
enabled. The physical-host setfile was skipped with
`basket_manifest_logical_setfile_preferred`. No tester was manually dispatched
and no Q02 verdict is claimed.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live setfile changed.
- No manual tester launch, terminal control, live action, or portfolio-gate
  mutation occurred.
