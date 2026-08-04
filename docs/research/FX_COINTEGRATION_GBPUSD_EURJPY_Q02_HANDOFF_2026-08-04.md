# QM5_20212 GBPUSD/EURJPY Cointegration — Q02 Handoff

Date: 2026-08-04
Branch: `agents/board-advisor`

## Outcome

`QM5_20212_gbpusd-eurjpy` is a new, non-duplicate, low-frequency D1 FX
basket. Its approved card, deterministic registry allocation, two traded
magic rows, EA, RISK_FIXED setfiles, basket manifest, and Q01 evidence are
complete. One logical Q02 work item is pending:

- Logical symbol: `QM5_20212_GBPUSD_EURJPY_COINTEGRATION_D1`
- Work item: `d87a25e0-c67b-48d4-a5ca-effe04cdd009`
- Queue state at handoff: `pending`, attempt 0, unclaimed
- Physical host setfile: deliberately skipped in favor of the logical basket

The anchor baskets did not need Q02 repair. `QM5_12532` has canonical Q02
PASS followed by Q05 FAIL, while `QM5_12533` has canonical Q02 PASS followed
by Q04 FAIL.

## Selection and Source Boundary

The checked-in sign-aware reproduction of the frozen 66-pair scan ranks
GBPUSD/EURJPY thirty-second by OOS net Sharpe. Rank 31, GBPJPY/EURAUD, is
already represented by `QM5_20211`. Exact strategy/slug checks, card and
registry searches, and an unordered traded-symbol manifest reconciliation
found no dedicated fixed-beta GBPUSD/EURJPY D1 sleeve before this build.

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| GBPUSD / EURJPY | -0.215933 | 0.221108 | 2.097281% | 17 | -0.080732288 | 103.753 D1 bars |

Negative DEV performance, a sub-0.8 OOS score, and the slow fitted half-life
are adverse evidence. The approved card authorizes one frontier test and
requires retirement on terminal economic failure or sub-floor cadence. It
forbids beta refitting, filters, pair substitution, parameter rescue, and ML.

Source lineage:

- `strategy-seeds/sources/SRC02/source.md`
- `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`

Chan supplies the reputable structural pair-trading method and makes no
performance claim for GBPUSD/EURJPY.

## Mechanization

- Host/traded leg: `GBPUSD.DWX`, magic `202120000`
- Companion/traded leg: `EURJPY.DWX`, magic `202120001`
- Conversion-history only: `EURUSD.DWX` and `USDJPY.DWX`
- Fixed spread: `ln(GBPUSD) - (-0.080732288) * ln(EURJPY)`
- Signal: strictly prior 60-bar closed-D1 z-score
- Entry/exit: `abs(z) > 2.0` / `abs(z) < 0.5`
- Negative-beta direction: long spread buys both legs; short spread sells both
- Hard stop: `ATR(20, D1) * 2.0` per traded leg
- Package safety: both normalized volumes are preflighted; partial entries and
  orphan states are flattened
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

“Market-neutral” is limited to the fitted residual. The package retains GBP,
USD, EUR, JPY, carry, and risk-sentiment exposure.

## Q01 Evidence

- Strategy Card schema/ML lint: PASS
- G0 card lint and build authorization guard: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- MetaEditor compile: PASS, zero errors and zero warnings
- SPEC validation: PASS
- Symbol-scope validation: `BASKET_OK`, zero violations
- Basket-manifest regression suite: 36 PASS
- Magic resolver regression suite: 5 PASS
- Magic resolver: 15,475 rows kept, zero dropped with `--keep-obsolete`
- Magic registry SHA-256:
  `00c29d7eb920f9e7f8e39aae7cce1dde59f4d360dd9a78bfd86db027131f3bff`
- Card SHA-256:
  `aed5d910b99c8919496b8753bb486800303ee2b85a12b1d145d41ab63c4c36fb`
- MQ5 SHA-256:
  `d441265712b3a6a74620a126a672b394685d6cbb4c31016c96dc8a568b6838f8`
- EX5 SHA-256:
  `d8f40d241a62f3c5abd96614d010136ac6cc875f6fa249efe60e238d6b8cb73b`
- Build report:
  `D:\QM\reports\framework\21\build_check_20260804_094332.json`
- Compile summary:
  `D:\QM\reports\compile\20260804_094332\summary.csv`

The targeted registry/build checks pass. The repository-wide legacy registry
validator still reports its pre-existing historical ID/slug debt; it reports
no `QM5_20212` issue. No manual smoke, tester, or backtest run was launched.

## Q02 Queue Contract

The enqueue precheck found three factory terminals running (`T7`, `T8`, and
`T9`) against the seven-terminal ceiling. The final read-only observation
found four (`T3`, `T5`, `T7`, and `T8`), still below the ceiling. `T_Live` and
an unrelated FTMO terminal were observed separately and excluded; neither was
controlled.

The no-mutation dry run selected exactly one logical row. Initial apply
attempts made no change while the canonical factory mutation lock was busy.
A bounded retry acquired that same lock normally after 4.9 seconds, created
exactly one logical row with all four histories, USD 100,000 tester account,
450-minute basket timeout, and `priority_track` enabled, then released the
lock normally. The physical host setfile was skipped with
`basket_manifest_logical_setfile_preferred`. No tester was manually dispatched
and no Q02 verdict is claimed.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live setfile changed.
- No manual tester launch, terminal control, live action, or portfolio-gate
  mutation occurred.
