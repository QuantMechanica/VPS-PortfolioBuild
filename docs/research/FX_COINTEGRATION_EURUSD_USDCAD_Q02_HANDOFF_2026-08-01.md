# QM5_20193 EURUSD/USDCAD Cointegration Q02 Handoff

Date: 2026-08-01

Branch: `agents/board-advisor`

State: `Q02_PENDING` (logical-basket work item
`0610ebc5-fbb0-4658-8455-2574ee98b277`)

## Selection

The two proven anchor baskets are not blocked at Q02. Runtime history contains
a Q02 PASS for each: `QM5_12532` subsequently reached Q04 PASS and Q05 FAIL,
while `QM5_12533` subsequently reached Q04 FAIL. The appropriate action was
therefore a new non-duplicate relationship from the same fixed 66-pair scan,
not an ONINIT or NO_HISTORY repair.

All seven strict qualifiers from the sign-aware rerun already have dedicated
builds. `EURUSD.DWX` / `USDCAD.DWX` is the next unbuilt dedicated pair in the
complete OOS-net-Sharpe ordering (rank 11):

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURUSD / USDCAD | 0.006938 | 0.734143 | 4.351185% | 14 | -0.839757300 | 160.705 D1 bars |

The weak DEV result and sub-0.8 OOS Sharpe are retained as adverse evidence.
The card authorizes one low-frequency frontier test and requires retirement on
terminal economic Q02 failure or sub-floor cadence. It forbids refitting the
beta or adding a filter/parameter rescue.

The deterministic duplicate check found no exact match. Its single fuzzy hit,
`QM5_20191_eurusd-chf-coint`, is a distinct relationship with a different
companion, beta, residual, and logical basket identity. No existing dedicated
EURUSD/USDCAD D1 fixed-beta manifest was found.

Source lineage:

- `strategy-seeds/sources/SRC02/source.md`
- `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`

The primary method source is the OWNER-ratified Tier-A extraction of Ernest
Chan's *Quantitative Trading* (Wiley, 2009), not an unvetted web strategy.

## Build

- EA ID / label: `20193` / `QM5_20193_eurusd-cad-coint`
- Branch commits: `b671fd504` (reservation/registries/card), `43ca8cd8b`
  (compiled binary/setfiles/resolver), `380ab88c1` (source/spec/manifest/test)
- Logical symbol: `QM5_20193_EURUSD_USDCAD_COINTEGRATION_D1`
- Host / companion: `EURUSD.DWX` D1 / `USDCAD.DWX`
- Magic slots: `201930000`, `201930001`
- Fixed beta: `-0.839757300`; negative-beta long spread buys both legs and
  short spread sells both legs
- Entry / exit: `abs(z) > 2.0` / `abs(z) < 0.5`, using a strictly prior
  60-bar closed-D1 window
- Hard stops: `ATR(20, D1) * 2.0` on both legs
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- Basket manifest: USD tester currency, USD 100,000 deposit
- Live artifacts: none

Validation:

- Strategy Card schema and G0 lints: PASS
- Build authorization guard: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- Compile: PASS, zero errors and zero warnings
- SPEC validation: PASS
- Symbol-scope validator: `BASKET_OK`, zero violations
- Basket manifest regression suite: 24 PASS
- Build report:
  `D:\QM\reports\framework\21\build_check_20260801_100502.json`
- Compile summary:
  `D:\QM\reports\compile\20260801_100502\summary.csv`

One governed host-symbol smoke invocation produced two deterministic real-tick
runs on T9. Both passed with no ONINIT failure or log bomb and returned two
trades, PF 1.52, 0.19% drawdown, and USD 103.76 net profit. This is setup
evidence only, not a Q02 verdict:
`D:\QM\reports\smoke\QM5_20193\20260801_100659\summary.json`.

## Q02 Enqueue

Recording governed build task
`31d54db7-2160-451f-a324-cfb25c678dd5` auto-enqueued exactly one logical
basket row at `2026-08-01T10:13:09Z` and explicitly skipped the physical-host
setfile with reason `basket_manifest_logical_setfile_preferred`:

- Work item: `0610ebc5-fbb0-4658-8455-2574ee98b277`
- Phase / kind: `Q02` / `backtest`
- Symbol / timeframe:
  `QM5_20193_EURUSD_USDCAD_COINTEGRATION_D1` / D1
- Setfile:
  `framework/EAs/QM5_20193_eurusd-cad-coint/sets/QM5_20193_eurusd-cad-coint_QM5_20193_EURUSD_USDCAD_COINTEGRATION_D1_D1_backtest.set`
- Observed state: `pending`, attempt 0, unclaimed, no evidence or verdict
- Payload: host `EURUSD.DWX`, both declared basket symbols, USD tester
  currency, USD 100,000 deposit, 450-minute timeout, priority track

A path-aware observation at `2026-08-01T10:13:44Z` found three running factory
terminals (`T1`, `T10`, `T2`), below the seven-terminal ceiling. The separate
T_Live process was excluded, and `FACTORY_OFF.flag` was absent. No manual Q02
dispatch or tester launch was performed.

## Safety

- No portfolio admission, KPI, or Q08 contribution file changed.
- No T_Live manifest, terminal, AutoTrading state, or live setfile changed.
- No Q02 result is claimed; the only Q02 row remains queued for the governed
  worker fleet.
