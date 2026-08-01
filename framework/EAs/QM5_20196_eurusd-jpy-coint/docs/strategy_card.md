---
strategy_id: AI-CLAUDE-FX-COINT66-20260609-EURUSD-USDJPY
ea_id: QM5_20196
slug: eurusd-jpy-coint
type: strategy
status: APPROVED
g0_status: APPROVED
created: 2026-08-01
created_by: Research+Development
last_updated: 2026-08-01
source_id: claude_cross_asset_discovery_2026-06-09
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley, Examples 3.6, 7.2, 7.3, and 7.5."
    location: "pp. 55-59, 126-133, and 140-142; OWNER-ratified Tier-A extraction strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md"
    quality_tier: A
    role: primary
research_evidence: "docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md; framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges"
strategy_type_flags: [cointegration-pair-trade, zscore-band-reversion, mean-reversion]
concepts: [cointegration-pair-trade, zscore-band-reversion, market-neutral-fx-basket]
indicators: [rolling-zscore, atr-stop]
markets: [forex]
timeframes: [D1]
primary_target_symbols: [EURUSD.DWX, USDJPY.DWX]
target_symbols: [EURUSD.DWX, USDJPY.DWX]
logical_symbol: QM5_20196_EURUSD_USDJPY_COINTEGRATION_D1
period: D1
expected_trade_frequency: "Approximately 5 completed two-leg packages per year per traded symbol, inferred from 20 OOS basket state changes across 2023-2024; Q02 must retire the sleeve if realized frequency is below the binding floor."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.02
expected_dd_pct: 30.0
risk_class: high
portfolio_scope: basket
gridding: false
scalping: false
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01_BUILD
g0_approval_reasoning: "R1 PASS: OWNER-requested fixed FX scan plus OWNER-ratified Tier-A Chan SRC02; R2 PASS: fixed low-frequency two-leg D1 beta/z/ATR package; R3 PASS: both traded histories are Darwinex-native and self-sufficient for USD tester accounting; R4 PASS: structural, deterministic, and learned-model-free."
---

# QM5_20196 EURUSD/USDJPY D1 Cointegration Basket

## 1. Source

The pair-trading method comes from the OWNER-ratified Tier-A SRC02 extraction
of Ernest Chan's *Quantitative Trading* at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. The source
specifies a fitted two-instrument spread, standardized-deviation entry,
mean-reach exit, cointegration-versus-correlation discipline, and a
low-frequency daily implementation. Chan makes no claim for EURUSD/USDJPY.

Pair selection comes from QuantMechanica's OWNER-requested fixed 66-pair FX
scan in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced from
the frozen Darwinex `.DWX` D1 export by
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
--include-negative-hedges`.

EURUSD/USDJPY ranks thirteenth of 66 by OOS net Sharpe and is the first ranked
relationship after `QM5_20195` without a dedicated fixed-pair D1 card, EA, or
logical basket manifest:

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | Fixed DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURUSD / USDJPY | 0.661899 | 0.686450 | 4.994192% | 20 | -0.505485905 | 87.404 D1 bars |

The sub-0.8 OOS Sharpe and long half-life are adverse evidence. The negative
beta also makes the residual economically close to a synthetic EUR/JPY
relationship rather than proof of broad currency-factor neutrality. This card
authorizes one frontier test, not a certified edge. A terminal economic
failure retires the sleeve; it does not authorize a filter, refit, or parameter
rescue.

## Non-Duplicate Boundary

The older `QM5_1156` M30 umbrella enumerates EURUSD/USDJPY as one of 15
adaptive universe slots, but it has no dedicated EURUSD/USDJPY D1 logical
manifest. Its rolling selection, adaptive relationship, and M30 execution are
not this frozen-beta, fixed-pair, closed-D1 sleeve. Broad FX universe lists and
conversion-history declarations likewise do not trade this exact package.

The sibling fixed-scan sleeves share a method family but use different
instruments, fitted residuals, magics, and logical identities. Repository-wide
unordered-pair checks found no other dedicated fixed-beta EURUSD/USDJPY D1
card, EA, or basket manifest.

## 2. Concept

Trade temporary deviations in the fixed log-price residual
`ln(EURUSD) - (-0.505485905) * ln(USDJPY)`. The negative fitted coefficient
means a long spread buys both pairs and a short spread sells both pairs.

"Market-neutral" here means neutral only to the fitted two-series residual.
It does not imply currency-factor, USD, carry, triangular, or portfolio
neutrality. That limitation is an explicit high-risk caveat for Q02 rather
than permission to add a filter.

## Hypothesis

The fixed scan suggests that large deviations in the EURUSD/USDJPY residual
may mean-revert slowly enough for a D1 two-leg implementation to survive
transaction costs. Because OOS performance missed the original survivor bar,
the hypothesis is deliberately weak and falsifiable: real-tick cost, swap,
cadence, or profitability failure retires this exact sleeve.

## Rules

- Evaluate only after a newly closed D1 bar.
- Use the frozen DEV beta and a strictly prior rolling calibration window.
- Open and close both traded legs as one logical package.
- Never average, pyramid, grid, martingale, trail, or refit the relationship.
- Keep framework risk, news, kill-switch, symbol, and Friday-close guards on.

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - D1
primary_target_symbols:
  - EURUSD.DWX
  - USDJPY.DWX
host_symbol: EURUSD.DWX
logical_symbol: QM5_20196_EURUSD_USDJPY_COINTEGRATION_D1
tester_currency: USD
conversion_only_symbols: []
```

The tester host is `EURUSD.DWX` D1 and `USDJPY.DWX` is the companion traded
leg. With a USD tester account, these two histories also provide the required
profit and margin conversion paths; no conversion-only symbol is declared.

## 4. Entry Rules

- On a newly closed D1 bar, load the newest closed price for both traded
  symbols plus the preceding 60 time-aligned closed observations.
- Compute `spread = ln(EURUSD) - strategy_beta * ln(USDJPY)`, with the frozen
  `strategy_beta = -0.505485905`.
- Score the newest closed spread against the mean and sample standard
  deviation of the strictly preceding 60 spreads. The scored observation must
  not enter its own calibration window.
- If no package is open and `z > +2.0`, enter a short-spread package: short
  EURUSD and short USDJPY.
- If no package is open and `z < -2.0`, enter a long-spread package: long
  EURUSD and long USDJPY.
- Split the single fixed-risk budget by absolute hedge weights `1.0` and
  `0.505485905`, normalized across the package.
- Attach a hard `ATR(20, D1) * 2.0` stop loss to each leg at entry.
- If either normalized leg is below broker minimum volume, reject the complete
  package; never open only one leg or inflate a leg independently.

## 5. Exit Rules

- Close both legs when the closed-bar residual reaches `abs(z) < 0.5`.
- If either protective stop leaves one traded leg open, flatten the orphan leg
  immediately with a strategy exit reason.
- Framework Friday Close remains enabled and flattens both legs at the
  configured broker hour.
- No profit target, partial close, break-even move, trailing stop, or adaptive
  time stop is authorized.

## 6. Filters (No-Trade module)

- Permit entry only when the host is `EURUSD.DWX`, the configured period is D1
  or the supported H1 tester wrapper, and the host magic slot is 0.
- Require both manifest symbols to be selected and warm, with their D1
  histories exactly timestamp-aligned for every residual sample.
- Require both normalized leg sizes to meet broker volume rules before sending
  either order.
- Inherit framework news, kill-switch, Friday-close, weekend, broker
  disconnect, and symbol guards without a strategy waiver.
- Do not add a carry, trend, correlation, volatility-regime, triangular, or
  stationarity rescue filter.

## 7. Trade Management Rules

- Treat the two traded positions as one package with separate registered
  magic slots.
- If package entry is partly successful, close the opened leg immediately.
- If an open package contains other than exactly two valid traded legs,
  flatten every surviving package leg.
- Pyramiding, averaging, grid placement, martingale sizing, partial closes,
  and discretionary intervention are prohibited.

## 8. Parameters To Test

Q02 uses every default unchanged. The fitted beta is structural and frozen;
it is not a Q03 neighborhood parameter. Only these predeclared dimensions may
be swept after a valid profitable baseline:

```yaml
- name: strategy_z_lookback_d1
  default: 60
  sweep_range: [40, 60, 90]
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

Chan supplies the pair-trading method but reports no EURUSD/USDJPY result.
The pair-specific table is QuantMechanica in-house research evidence net only
of the scan's approximate `0.8 bp/leg` cost assumption. Swap was unmodeled;
the deterministic pipeline is the economic judge.

## Risk

Backtests must use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each traded leg receives its own ATR hard stop, while
partial-entry and orphan states are flattened. No live setfile or live risk
setting is authorized.

Kill criteria:

- RETIRE at Q02 if realized cadence is below the binding frequency floor.
- RETIRE on a terminal economic Q02/Q04 failure; do not add a rescue filter.
- RETIRE if either normalized leg cannot meet broker minimum volume within the
  fixed package budget, rather than distorting the fitted hedge.
- RETIRE if aligned D1 history remains unavailable after normal cold-cache
  retry behavior; never substitute or strip `.DWX`.
- RETIRE or return to Research if negative-beta direction is not long-long for
  a long spread and short-short for a short spread.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.02
expected_dd_pct: 30.0
expected_trade_frequency: approximately 5 completed packages/year per traded symbol
risk_class: high
gridding: false
scalping: false
ml_required: false
```

The estimate is conservative because OOS Sharpe missed the original survivor
bar and the half-life is long. Multi-day swap, Friday flattening, quote
orientation, and minimum volume are material risks.

## 11. Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS | Durable OWNER-requested scan lineage plus OWNER-ratified Tier-A Chan SRC02 method evidence. |
| R2 | PASS | Fixed symbols, beta, closed-D1 z-score entry/exit, ATR stops, package sizing, and orphan cleanup are deterministic. |
| R3 | PASS | EURUSD.DWX and USDJPY.DWX are native factory symbols represented in the fixed export and registry lineage. |
| R4 | PASS | No learned component, online refit, banned indicator, grid, martingale, or randomness is used. |

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "Fixed host, timeframe, symbol selection, aligned-history, volume, and framework guard checks."
  trade_entry:
    used: true
    notes: "Closed-D1 fixed-beta residual z-score and atomic sign-aware two-leg package entry."
  trade_management:
    used: true
    notes: "Partial-entry rollback and orphan-leg cleanup only."
  trade_close:
    used: true
    notes: "Mean-reach package exit plus protective stops and framework Friday close."
hard_rules_at_risk:
  - risk_mode_dual
  - dwx_suffix_discipline
  - magic_schema
  - friday_close
  - one_position_per_magic_symbol
at_risk_explanation: |
  The logical basket must preserve RISK_FIXED backtest mode, exact .DWX
  symbols, ea_id*10000+slot magic resolution, one position per traded leg, and
  package-level Friday flattening. No exception or live artifact is requested.
```

## 13. Implementation Notes

```yaml
target_modules:
  no_trade: "Select and warm EURUSD.DWX/USDJPY.DWX; reject wrong host, timeframe, slot, unaligned history, or invalid normalized leg volume."
  entry: "Use the strictly prior 60-bar residual window and sign-aware two-leg QM_BasketOrder requests."
  management: "Rollback partial entry and flatten any orphan traded leg."
  close: "Close both registered legs at abs(z)<0.5 or framework Friday close."
estimated_complexity: medium
estimated_test_runtime: "one low-frequency logical-basket D1 Q02 run"
data_requirements: "EURUSD.DWX and USDJPY.DWX D1 histories"
```

## 14. Pipeline History

| Version | Date | Rebuild reason | Phase reached | Verdict |
|---|---|---|---|---|
| v1 | 2026-08-01 | next-ranked non-duplicate fixed-scan FX basket | G0 | APPROVED |
| v2 | 2026-08-01 | initial V5 two-leg implementation | Q01 | PASS |

## 15. Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-01 | APPROVED | this card |
| Q01 Build Validation | 2026-08-01 | PASS | `D:\QM\reports\framework\21\build_check_20260801_145920.json` |
| Q02 Baseline Screening | 2026-08-01 | QUEUED | work item `a34c39c1-7ef6-43e2-b1b4-eb6a717271b2` |

## 16. Lessons Captured

- 2026-08-01: Rank 13 is below the original survivor bar; it is admitted only
  as the explicitly requested next-best one-shot sleeve, with retirement rather
  than rescue after economic failure.
