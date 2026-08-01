# QM5_20196 EURUSD/USDJPY Cointegration — Q02 Handoff

Date: 2026-08-01
Branch: `agents/board-advisor`

## Outcome

`QM5_20196_eurusd-jpy-coint` is a new, non-duplicate, low-frequency D1 FX
basket and is queued for Q02 as one logical package:

- Logical symbol: `QM5_20196_EURUSD_USDJPY_COINTEGRATION_D1`
- Q02 work item: `a34c39c1-7ef6-43e2-b1b4-eb6a717271b2`
- Queue state at handoff: `pending`, attempt 0, unclaimed
- Physical-host setfile: deliberately skipped by the targeted auto-enqueue
- Live artifacts: none

The two anchor baskets were not Q02-blocked. `QM5_12532` has a canonical Q02
PASS followed by Q05 FAIL, and `QM5_12533` has a canonical Q02 PASS followed
by Q04 FAIL. This work therefore selected a new pair rather than changing
either anchor.

## Selection and Source Boundary

The checked-in sign-aware reproduction of the fixed 66-pair scan ranked
EURUSD/USDJPY thirteenth by OOS net Sharpe. Ranks 10 through 12 were already
built as `QM5_20191`, `QM5_20193`, and `QM5_20195`.

Frozen scan row:

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURUSD / USDJPY | 0.661899 | 0.686450 | 4.994192% | 20 | -0.505485905 | 87.404 D1 bars |

The sub-0.8 OOS Sharpe and long half-life are adverse evidence. The approved
card authorizes one low-frequency frontier test and requires retirement on
terminal economic Q02 failure or sub-floor cadence. It forbids a filter,
beta refit, or parameter rescue.

The older `QM5_1156` umbrella contains an adaptive EURUSD/USDJPY universe
slot, but it executes on M30 and has no dedicated fixed-beta D1 logical
manifest. That overlap is not this fixed-pair sleeve. Repository-wide
unordered-pair checks found no other dedicated EURUSD/USDJPY D1 card, EA, or
basket manifest.

Source lineage:

- `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`

Chan supplies the reputable structural pair-trading method and makes no
performance claim for EURUSD/USDJPY.

## Mechanization

- Host/traded leg: `EURUSD.DWX`, magic `201960000`
- Companion/traded leg: `USDJPY.DWX`, magic `201960001`
- Fixed spread: `ln(EURUSD) - (-0.505485905) * ln(USDJPY)`
- Signal: strictly prior 60-bar closed-D1 z-score
- Entry/exit: `abs(z) > 2.0` / `abs(z) < 0.5`
- Negative-beta direction: long spread buys both legs; short spread sells both
- Risk stop: `ATR(20, D1) * 2.0` per traded leg
- Package safety: both normalized volumes are preflighted; partial entry and
  orphan states are flattened
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- Basket manifest: two traded histories, USD tester currency, USD 100,000
  deposit, no conversion-only route

## Q01 Evidence

- Strategy Card schema lint: PASS, no ML hits
- G0 structural lint: PASS; card status `APPROVED`
- Build authorization guard: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- Strict MetaEditor compile: PASS, zero errors and zero warnings
- SPEC validation: PASS
- Symbol-scope validation: `BASKET_OK`, zero violations
- Basket manifest regression suite: 26 PASS
- Magic resolver: 15,380 rows kept, zero dropped under `--keep-obsolete`
- Final EX5 SHA-256:
  `b8b268676f8cd3e8312e1e30ea71abf65efc2e8970eb618c75db281ae7947bb2`
- Build report:
  `D:\QM\reports\framework\21\build_check_20260801_145920.json`
- Strict compile summary:
  `D:\QM\reports\compile\20260801_150618\summary.csv`

No manual smoke or tester run was launched. Q02 remains the deterministic
economic judge.

## Q02 Queue Contract

The final path-aware precheck at `2026-08-01T15:01Z` found three running
factory terminals (`T2`, `T4`, and `T7`) against the seven-terminal ceiling.
The separate `T_Live` process was explicitly excluded, and
`FACTORY_OFF.flag` was absent.

The targeted sweep created exactly one row at
`2026-08-01T15:01:21Z`:

- Work item: `a34c39c1-7ef6-43e2-b1b4-eb6a717271b2`
- Phase / kind: `Q02` / `backtest`
- Symbol / timeframe:
  `QM5_20196_EURUSD_USDJPY_COINTEGRATION_D1` / D1
- Host: `EURUSD.DWX`
- Basket symbols: `EURUSD.DWX`, `USDJPY.DWX`
- Setfile:
  `framework/EAs/QM5_20196_eurusd-jpy-coint/sets/QM5_20196_eurusd-jpy-coint_QM5_20196_EURUSD_USDJPY_COINTEGRATION_D1_D1_backtest.set`
- Timeout: 450 minutes
- Priority track: true

No tester was manually dispatched and no Q02 verdict is claimed.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No T_Live manifest, terminal, AutoTrading state, or live setfile changed.
- No manual backtest, terminal launch, process control, or live action occurred.
