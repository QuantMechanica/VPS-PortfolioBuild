# QM5_20207 USDCAD/AUDUSD Cointegration — Q02 Handoff

Date: 2026-08-03
Branch: `agents/board-advisor`

## Outcome

`QM5_20207_usdcad-audusd` is a new, non-duplicate, low-frequency D1 FX
basket. Its approved card, deterministic registry allocation, two traded
magic rows, EA, RISK_FIXED setfiles, basket manifest, and Q01 evidence are
complete. One logical Q02 work item is pending:

- Logical symbol: `QM5_20207_USDCAD_AUDUSD_COINTEGRATION_D1`
- Work item: `232f5aeb-0435-4762-bb06-6bc6225c1675`
- Queue state at handoff: `pending`, attempt 0, unclaimed
- Physical host setfile: deliberately skipped in favor of the logical basket

The anchor baskets did not need repair. `QM5_12532` has canonical Q02 PASS
followed by Q05 FAIL, while `QM5_12533` has canonical Q02 PASS followed by
Q04 FAIL.

## Selection and Source Boundary

The checked-in sign-aware reproduction of the fixed 66-pair scan ranks
USDCAD/AUDUSD twenty-fifth by OOS net Sharpe. Ranks 22 through 24 are already
represented by dedicated D1 baskets `QM5_12624`, `QM5_12731`, and
`QM5_12732`. Exact-pair and registry searches found no dedicated fixed-beta
USDCAD/AUDUSD D1 card, allocation, EA, or logical manifest before this build.

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| USDCAD / AUDUSD | 0.610821 | 0.485169 | 2.072809% | 20 | -0.460267756 | 50.048 D1 bars |

The sub-0.8 OOS Sharpe and modest return are adverse evidence. The card
authorizes one frontier test and requires retirement on terminal economic
failure, sub-floor cadence, or broker-minimum-volume rejection. It forbids
beta refitting, rescue filters, and parameter rescue.

The broad `QM5_1257` adaptive H1 pair engine contains an AUDUSD/USDCAD
universe slot. It is not this frozen-beta, closed-D1, dedicated logical
package and is recorded explicitly as the known overlap.

Source lineage:

- `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`

Chan supplies the reputable structural pair-trading method and makes no
performance claim for USDCAD/AUDUSD.

## Mechanization

- Host/traded leg: `USDCAD.DWX`, magic `202070000`
- Companion/traded leg: `AUDUSD.DWX`, magic `202070001`
- Fixed spread: `ln(USDCAD) - (-0.460267756) * ln(AUDUSD)`
- Signal: strictly prior 60-bar closed-D1 z-score
- Entry/exit: `abs(z) > 2.0` / `abs(z) < 0.5`
- Negative-beta direction: long spread buys both legs; short spread sells both
- Hard stop: `ATR(20, D1) * 2.0` per traded leg
- Package safety: both normalized volumes are preflighted; partial entries and
  orphan states are flattened
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

"Market-neutral" is limited to the fitted common-USD residual. The package
retains CAD, AUD, USD, carry, commodity-cycle, and risk-sentiment exposure.

## Q01 Evidence

- Strategy Card schema/ML lint: PASS
- G0 card lint: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- MetaEditor compile: PASS, zero errors and zero warnings
- SPEC validation: PASS
- Symbol-scope validation: `BASKET_OK`, zero violations
- Basket-manifest regression suite: 32 PASS
- Magic resolver: 15,466 rows kept, zero dropped with `--keep-obsolete`
- MQ5 SHA-256:
  `6e2f5898809ccb285646fb80eda38061e366366f7a256ebd2887e690019ca91a`
- EX5 SHA-256:
  `1d2e698b653dde254a5635699a99b96eeb0498feb329f34b933d7942724938f3`
- Build report:
  `D:\QM\reports\framework\21\build_check_20260803_124806.json`
- Compile summary:
  `D:\QM\reports\compile\20260803_124739\summary.csv`

No manual smoke, tester, or backtest run was launched.

## Q02 Queue Contract

The successful final path-aware precheck found three factory terminals
running (`T2`, `T3`, and `T8`) against the seven-terminal ceiling. `T_Live`
and an unrelated FTMO terminal were observed separately and excluded; neither
was controlled.

An earlier guarded attempt found four factory terminals but made no change
because the canonical factory mutation lock was busy. The retry acquired the
lock normally after the capacity recheck, and the targeted idempotent sweep created
exactly one logical row with both histories, USD 100,000 tester account,
450-minute basket timeout, and `priority_track` enabled. The physical host
setfile was skipped with `basket_manifest_logical_setfile_preferred`. No
tester was manually dispatched and no Q02 verdict is claimed.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live setfile changed.
- No manual tester launch, terminal control, live action, or portfolio-gate
  mutation occurred.
