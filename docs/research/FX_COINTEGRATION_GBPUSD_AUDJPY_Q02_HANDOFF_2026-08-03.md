# QM5_20210 GBPUSD/AUDJPY Cointegration — Q02 Handoff

Date: 2026-08-03
Branch: `agents/board-advisor`

## Outcome

`QM5_20210_gbpusd-audjpy` is a new, non-duplicate, low-frequency D1 FX
basket. Its approved card, deterministic registry allocation, two traded
magic rows, EA, RISK_FIXED setfiles, basket manifest, and Q01 evidence are
complete. One logical Q02 work item is pending:

- Logical symbol: `QM5_20210_GBPUSD_AUDJPY_COINTEGRATION_D1`
- Work item: `7890c8f1-7df4-41ab-90cd-4f0183a5cda4`
- Queue state at handoff: `pending`, attempt 0, unclaimed
- Physical host setfile: deliberately skipped in favor of the logical basket

The anchor baskets did not need repair. `QM5_12532` has canonical Q02 PASS
followed by Q05 FAIL, while `QM5_12533` has canonical Q02 PASS followed by
Q04 FAIL.

## Selection and Source Boundary

The checked-in sign-aware reproduction of the frozen 66-pair scan ranks
GBPUSD/AUDJPY twenty-ninth by OOS net Sharpe. Rank 28, EURUSD/NZDUSD, is
already represented by dedicated D1 basket `QM5_12735`. Exact strategy/slug
checks, exact-pair card and registry searches, and an unordered traded-symbol
manifest reconciliation found no dedicated fixed-beta GBPUSD/AUDJPY D1 card,
allocation, EA, or logical basket before this build.

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| GBPUSD / AUDJPY | -0.166819 | 0.304341 | 2.906184% | 17 | -0.038239845 | 104.649 D1 bars |

Negative DEV Sharpe, sub-0.8 OOS Sharpe, the small companion weight, and the
slow half-life are adverse evidence. The card authorizes one frontier test and
requires retirement on terminal economic failure, sub-floor cadence, or
broker-minimum-volume rejection. It forbids beta refitting, filters, pair
substitution, and parameter rescue.

Source lineage:

- `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- `strategy-seeds/sources/SRC02/source.md`
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`

Chan supplies the reputable structural pair-trading method and makes no
performance claim for GBPUSD/AUDJPY.

## Mechanization

- Host/traded leg: `GBPUSD.DWX`, magic `202100000`
- Companion/traded leg: `AUDJPY.DWX`, magic `202100001`
- Conversion-history only: `AUDUSD.DWX`, `USDJPY.DWX`
- Fixed spread: `ln(GBPUSD) - (-0.038239845) * ln(AUDJPY)`
- Signal: strictly prior 60-bar closed-D1 z-score
- Entry/exit: `abs(z) > 2.0` / `abs(z) < 0.5`
- Negative-beta direction: long spread buys both legs; short spread sells both
- Hard stop: `ATR(20, D1) * 2.0` per traded leg
- Package safety: both normalized volumes are preflighted; partial entries and
  orphan states are flattened
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

“Market-neutral” is limited to the fitted residual. The package retains GBP,
USD, AUD, JPY, carry, and risk-sentiment exposure.

## Q01 Evidence

- Strategy Card schema/ML lint: PASS
- G0 card lint: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- MetaEditor compile: PASS, zero errors and zero warnings
- SPEC validation: PASS
- Symbol-scope validation: `BASKET_OK`, zero violations
- Basket-manifest regression suite: 34 PASS
- Magic resolver: 15,471 rows kept, zero dropped with `--keep-obsolete`
- Magic registry SHA-256:
  `a928a4391fe6a3728c60eab95ba0d2b369e6b93215809b0709a92502e8a91d24`
- MQ5 SHA-256:
  `7ae820b372d8afb787a8eb6a1e89d015a74cd2a80e24567b683bcbe597c37c69`
- EX5 SHA-256:
  `6152449cdf43df0856902a4651d59ce4a7b83cdfd8593f5651b852a1556f5b57`
- Build report:
  `D:\QM\reports\framework\21\build_check_20260803_163209.json`
- Compile summary:
  `D:\QM\reports\compile\20260803_163209\summary.csv`

No manual smoke, tester, or backtest run was launched.

## Q02 Queue Contract

The final path-aware precheck at `2026-08-03T16:27:30Z` found four factory
terminals running (`T3`, `T7`, `T9`, and `T10`) against the seven-terminal
ceiling. `T_Live` and an unrelated FTMO terminal were observed separately and
excluded; neither was controlled.

The first guarded apply made no change because the canonical factory mutation
lock was busy. The retry acquired the lock normally, created exactly one
logical row with all four histories, USD 100,000 tester account, 450-minute
basket timeout, and `priority_track` enabled, then released the lock normally.
The physical host setfile was skipped with
`basket_manifest_logical_setfile_preferred`. No tester was manually dispatched
and no Q02 verdict is claimed.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live setfile changed.
- No manual tester launch, terminal control, live action, or portfolio-gate
  mutation occurred.
