---
strategy_id: SRC02_S10
ea_id: QM5_13119
slug: usdjpy-euraud
status: APPROVED
type: strategy
created: 2026-07-10
created_by: Research
last_updated: 2026-07-11
source_id: SRC02
source_citation: "QuantMechanica OWNER-requested all-sign reproduction of the 2026-06-09 66-pair FX cointegration scan on Darwinex .DWX D1 data; methodology grounded in Chan, Ernest P. (2009), Quantitative Trading, Wiley, Chapter 7 and Example 3.6."
strategy_type_flags:
  - cointegration-pair-trade
  - mean-reach-exit
  - atr-hard-stop
  - friday-close-flatten
  - symmetric-long-short
concepts:
  - cointegration-pair-trade
  - zscore-band-reversion
  - market-neutral-fx-basket
indicators:
  - rolling-zscore
  - atr-stop
target_symbols: [USDJPY.DWX, EURAUD.DWX]
logical_symbol: QM5_13119_USDJPY_EURAUD_COINTEGRATION_D1
period: D1
expected_trade_frequency: "D1 two-leg basket, approximately 6 logical spread packages/year from 23 OOS state changes over 2023-2024."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q04
expected_pf: 1.05
expected_dd_pct: 25.0
portfolio_scope: basket
g0_approval_reasoning: "R1 PASS Tier-A Chan method plus OWNER-requested reproducible 66-pair scan; R2 PASS deterministic fixed-beta D1 basket; R3 PASS USDJPY/EURAUD and USD conversion histories available; R4 PASS structural only, no ML/grid/martingale/adaptive refit; explicit forex-book mission approves QM5_13119."
---

# USDJPY/EURAUD Cointegration Basket

## 1. Source

```yaml
source_citations:
  - type: other
    citation: "QuantMechanica. (2026). Cross-Asset FX Edge Discovery — own-data, hypothesis-first; all-sign reproduction of the 66-pair D1 scan."
    location: "docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md, v3 systematic scan; framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py with the positive-hedge exclusion disabled"
    quality_tier: B
    role: primary
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading."
    location: "Example 3.6, pp. 55-59; Chapter 7 stationarity and cointegration, pp. 126-142"
    quality_tier: A
    role: supplement
```

The auditable Chan extraction is
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. The bounded
in-house scan was explicitly selected by the OWNER for this forex-sleeve
mission. It is reproducible from the checked-in script and read-only D1 exports
under `D:/QM/mt5/T_Export/MQL5/Files`.

The published positive-beta pass retained only the already-built
EURJPY/GBPJPY and AUDUSD/NZDUSD anchors. Reproducing the same 66-pair method
with `python framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
--include-negative-hedges` leaves USDJPY/EURAUD as the next strict row after
the already-built GBPUSD/USDCAD, EURJPY/GBPJPY, AUDUSD/NZDUSD,
USDCAD/NZDUSD, AUDUSD/EURGBP, and EURGBP/AUDJPY sleeves. The flag changes only the hedge-sign
screen; the DEV/OOS split, fixed-beta fit, thresholds, and cost model remain
unchanged.

| Scan measurement | Value |
|---|---:|
| DEV net Sharpe | 0.5059112597 |
| OOS net Sharpe | 0.8837435895 |
| OOS return | 16.014828283% |
| OOS state changes | 23 |
| Fixed DEV beta | -1.4182482312 |
| Half-life | 77.45654457 D1 bars |

These are approximate in-house screening measurements under the scan's
`0.8 bp/leg` cost model, not live or pipeline performance claims. Swap was not
modeled. Q02 onward remains the judge.

## 2. Concept

Trade temporary deviations in the fixed log-price combination
`ln(USDJPY) - beta * ln(EURAUD)` after the source scan found positive DEV and
OOS results with a 77.46-day mean-reversion half-life. The fitted beta is
negative, so a long spread is long both legs and a short spread is short both
legs.

USDJPY expresses the dollar-yen rate and carry complex while EURAUD expresses
relative European and Australian growth and rate pressure. Their relationship
is statistical rather than a shared-leg identity. The absolute beta above one
assigns more package risk to EURAUD, and the negative sign makes both legs
point in the same direction. "Market-neutral" therefore means neutral only to
the fitted regression spread; it does not imply currency, carry, directional,
or book neutrality.

## Hypothesis

A fixed-beta deviation beyond two trailing spread standard deviations should
mean-revert over a multi-week horizon because the all-sign DEV fit produced a
positive net result and the measured half-life is 77.46 D1 bars. Keeping the
beta and thresholds fixed preserves the source hypothesis; any failure under
real-tick costs, swap, or walk-forward folds rejects this sleeve rather than
authorizing an adaptive refit.

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - D1
primary_target_symbols:
  - USDJPY.DWX
  - EURAUD.DWX
host_symbol: USDJPY.DWX
tester_currency: USD
portfolio_scope: basket
```

Both traded legs and every tester-currency conversion dependency must be
declared in `basket_manifest.json` at build time. Backtests must use
`RISK_FIXED`; no live setfile is authorized by this draft.

## Rules

The rules below form one atomic two-leg package. All signal values come from
closed D1 bars, and all parameters are fixed before a test window begins.

## 4. Entry Rules

- Evaluate once per new closed D1 bar on the logical host.
- Require at least 60 aligned closed D1 bars for both legs.
- Use the fixed DEV beta `-1.4182482311707278`; never refit it at runtime.
- Compute `spread = ln(USDJPY) - beta * ln(EURAUD)`.
- Compute the spread z-score from the preceding 60 closed D1 observations.
- With no package open and `z > +2.0`, open a short-spread package: short
  USDJPY and short EURAUD.
- With no package open and `z < -2.0`, open a long-spread package: long USDJPY
  and long EURAUD.
- Split the fixed-risk budget across the legs in `1:abs(beta)` risk weight,
  normalized so the package consumes one `RISK_FIXED` budget.
- Attach a fixed `ATR(20, D1) * 2.0` protective stop to each leg.
- At most one logical package may be open; no averaging, grid, martingale,
  pyramiding, or partial entry is allowed.

## 5. Exit Rules

- Close both legs when `abs(z) < 0.5` on a closed D1 bar.
- Close the surviving leg immediately if the package becomes orphaned.
- A leg-level ATR hard stop may close one leg; orphan cleanup must then flatten
  the other leg without waiting for a new entry signal.
- Framework Friday close remains enabled.
- Framework kill-switch and hard-stop exits always take precedence.

## 6. Filters (No-Trade Module)

- Trade only from the declared logical host and only when both D1 histories are
  synchronized and warm.
- Use the standard framework kill-switch, news, Friday-close, weekend,
  holiday, and broker-connectivity gates.
- Do not add a correlation, volatility-regime, session, carry, or adaptive
  stationarity filter before the standard pipeline tests the source rule.

## 7. Trade Management Rules

- Treat the two positions as one package with deterministic leg magics.
- Do not trail, move to break-even, scale in, scale out, or rebalance beta.
- If either leg cannot be opened, immediately close any leg opened during the
  failed package transaction.
- If only one leg remains open for any reason, flatten it on the next
  management pass.

## 8. Parameters To Test

```yaml
- name: strategy_z_lookback_d1
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_beta
  default: -1.4182482311707278
  sweep_range: [-1.6, -1.4182482311707278, -1.2]
- name: strategy_entry_z
  default: 2.0
  sweep_range: [1.75, 2.0, 2.25]
- name: strategy_exit_z
  default: 0.5
  sweep_range: [0.25, 0.5, 0.75]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5]
```

## 9. Author Claims

Chan describes the method, not this pair: "The main method used to test for
cointegration is called the cointegrating augmented Dickey-Fuller test."
(Example 7.2, p. 128.)

No external author performance claim is imported for USDJPY/EURAUD. The scan
measurements above are explicitly provisional and net only of its approximate
transaction-cost model.

## Risk

Backtests must use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The eventual logical setfile must declare
`ENV=backtest`; this draft grants no demo, shadow, or live risk authorization.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.05
expected_dd_pct: 25.0
expected_trade_frequency: approximately 6 logical packages/year
risk_class: high
gridding: false
scalping: false
ml_required: false
```

The high-risk classification reflects the marginal OOS Sharpe, cross-bloc
economic link, negative beta, same-direction legs, and 77-day half-life. Multi-week swap,
conversion, spread, and real-tick costs are delegated to the pipeline.

## 11. Strategy Allowability Check

- [x] Mechanical fixed-beta, closed-D1 z-score entry and mean-reach exit.
- [x] No ML, online refit, external runtime data, banned indicator, grid, or
  martingale.
- [x] Low-frequency D1 design; no latency-sensitive premise.
- [x] `RISK_FIXED` backtest contract and one package per magic pair.
- [x] Friday Close compatible and enabled.
- [x] Tier-A Chan method source plus reproducible OWNER-approved in-house pair
  selection.
- [x] No existing card or EA folder names the USDJPY/EURAUD pair as of
  2026-07-10.
- [x] OWNER + Quality-Business approval supplied by the explicit forex-book
  mission; Development's atomic registry allocation reserved QM5_13119.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "Logical-host, synchronized-history, warmup, and standard framework gates."
  trade_entry:
    used: true
    notes: "Closed-D1 fixed-negative-beta spread z-score with atomic two-leg package entry."
  trade_management:
    used: true
    notes: "Broken-package and partial-entry cleanup only; hard stops are attached at entry."
  trade_close:
    used: true
    notes: "Close the package when abs(z) < 0.5; framework Friday close and kill-switch remain active."
hard_rules_at_risk:
  - friday_close
  - risk_mode_dual
  - dwx_suffix_discipline
  - magic_schema
  - one_position_per_magic_symbol
  - kill_switch_coverage
at_risk_explanation: |
  Multi-week holds make Friday flattening and swap material, but Friday close
  remains enabled. Build review must verify RISK_FIXED backtest mode,
  .DWX-only research symbols, ea_id*10000+slot magics, one position per leg,
  and package-wide kill-switch/orphan cleanup.
```

## 13. Implementation Notes

```yaml
target_modules:
  no_trade: "Logical host/slot guard, aligned closed-D1 history warmup, and standard framework gates."
  entry: "Fixed-beta 60-bar spread z-score and atomic sign-aware two-leg order package."
  management: "Broken-package and failed-partial-entry cleanup only."
  close: "Mean-reach package exit plus framework Friday close and kill switch."
estimated_complexity: medium
estimated_test_runtime: "basket Q02 approximately 60-120 minutes; use paced fleet only"
data_requirements: "USDJPY.DWX and EURAUD.DWX D1 plus AUDUSD.DWX risk-conversion and EURUSD.DWX account-P/L conversion history declared by basket manifest"
```

## 14. Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | next non-duplicate strict all-sign 66-pair candidate extraction | G0 | APPROVED |
| v2 | 2026-07-10 | explicit forex-book mission approval and atomic QM5_13119 allocation | Q01 | APPROVED_FOR_BUILD |
| v3 | 2026-07-10 | strict compile and one logical-basket enqueue; smoke deferred at seven-job CPU ceiling | Q02 | PENDING_CPU_CEILING |
| v4 | 2026-07-11 | align EA z-score with the card's strictly prior 60-bar calibration window; preserve the existing logical Q02 row | Q02 | PENDING_FACTORY_OFF |
| v5 | 2026-07-11 | preserve the pre-repair real-tick PASS as superseded, route the USDJPY host through the V5 trade manager, declare EURUSD conversion history, clean-build, and enqueue a distinct repaired-binary baseline | Q02 | PENDING_FACTORY_OFF |
| v6 | 2026-07-11 | repaired binary passed Q02 and deterministic Q03; one de-duplicated Q04 walk-forward row was enqueued | Q04 | PENDING_FACTORY_OFF |
| v7 | 2026-07-11 | complete the two-fold real-tick walk-forward; 2024 net PF fell below 1.0 | Q04 | FAIL |

## 15. Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED | explicit forex-book mission + this card + `docs/research/FX_COINTEGRATION_USDJPY_EURAUD_REVIEW_2026-07-10.md` |
| Q01 Build Validation | 2026-07-11 | PASS | repaired source: `D:/QM/reports/framework/21/build_check_20260711_050630.json`; strict compile `D:/QM/reports/compile/20260711_050605/summary.csv`, 0 errors/0 warnings |
| Q02 Baseline Screening (pre-repair binary) | 2026-07-11 | PASS_SUPERSEDED | 136 trades, PF 1.06, net +954.43, DD 2.91%; `D:/QM/reports/work_items/f8767f2f-4bcb-4b32-b857-cf9063b1c935/QM5_13119/20260711_043425/summary.json` |
| Q02 Baseline Screening (repaired binary) | 2026-07-11 | PASS | 136 trades, PF 1.06, net +966.39, DD 2.92%; work item `77ec9572-e064-44bd-a756-51647aa383b9` |
| Q03 Determinism | 2026-07-11 | PASS | two identical 136-trade runs; work item `e786ef7d-aaf8-4813-aae1-1e2f34f62ccb`; `artifacts/qm5_13119_fx_cointegration_q03_pass_20260711.json` |
| Q04 Walk-Forward | 2026-07-11 | FAIL | F1 net PF 1.437 (40 trades), F2 net PF 0.872 (30 trades); work item `addea337-31f5-4267-b002-1281eaf9f94c` |

## 16. Lessons Captured

- 2026-07-10: Sign-aware reproduction exposed USDJPY/EURAUD as the final strict
  row after the already-built EURGBP/AUDJPY sleeve.
- 2026-07-10: A negative hedge ratio creates same-direction legs; regression
  neutrality must not be described as currency or directional neutrality.
- 2026-07-10: Seven paced work items were active at handoff, so Q02 was left
  pending and no manual smoke, MT5 launch, or dispatch was attempted.
- 2026-07-11: The initial EA included the newest closed spread in its own
  60-bar calibration sample. The repair now scores that observation against
  60 strictly prior closed spreads, matching both the card and source scan.
- 2026-07-11: The pre-repair real-tick run completed without ONINIT or history
  failure, but mechanical review showed its USDJPY host order bypassed
  `QM_TM_OpenPosition`; that PASS is retained as superseded and cannot promote
  the EA.
- 2026-07-11: The tester requested EURUSD.DWX for account-currency P/L
  conversion even though AUDUSD.DWX covers the EA's EURAUD risk sizing. Both
  conversion-only histories are now declared and warmed for the repaired Q02.
- 2026-07-11: The repaired binary passed Q02 and deterministic Q03 without an
  ONINIT or history failure, but Q04 exposed year instability: 2023 net PF was
  1.437 while 2024 net PF was 0.872. This is a strategy FAIL, so no Q05 row was
  created.
