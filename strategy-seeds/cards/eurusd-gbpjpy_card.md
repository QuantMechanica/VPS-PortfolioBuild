---
strategy_id: AI-CODEX-FX-COINT66-20260609-EURUSD-GBPJPY
ea_id: TBD
slug: eurusd-gbpjpy
type: strategy
status: APPROVED
g0_status: APPROVED
force_build: true
created: 2026-08-05
created_by: Research
last_updated: 2026-08-05
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
primary_target_symbols: [EURUSD.DWX, GBPJPY.DWX]
target_symbols: [EURUSD.DWX, GBPJPY.DWX]
logical_symbol: QM5_TBD_EURUSD_GBPJPY_COINTEGRATION_D1
period: D1
expected_trade_frequency: "Approximately 5 completed two-leg packages per year per traded symbol, inferred from 19 OOS basket state changes across 2023-2024; Q02 must retire the sleeve if realized frequency is below the binding floor."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.0
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
pipeline_phase: G0_APPROVED
g0_approval_reasoning: "R1 PASS: OWNER-requested fixed FX scan plus CEO-ratified Tier-A Chan SRC02; R2 PASS: fixed low-frequency two-leg D1 beta/z/ATR package; R3 PASS: traded and conversion histories are Darwinex-native; R4 PASS: structural, deterministic, and learned-model-free."
---

# QM5_TBD EURUSD/GBPJPY D1 Cointegration Basket

## 1. Source

The pair-trading method comes from the OWNER-ratified Tier-A SRC02 extraction
of Ernest Chan's *Quantitative Trading* at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. The source
specifies a fitted two-instrument spread, standardized-deviation entry,
mean-reach exit, cointegration-versus-correlation discipline, and a
low-frequency daily implementation. Chan makes no claim for EURUSD/GBPJPY.

Pair selection comes from QuantMechanica's OWNER-requested fixed 66-pair FX
scan in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced from
the frozen Darwinex `.DWX` D1 export by
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
--include-negative-hedges`.

EURUSD/GBPJPY ranks forty-seventh of 66 by OOS net Sharpe. Rank 45 is already represented by `QM5_12768`, and rank 46 by
`QM5_20224`. The deterministic research dedup check scanned 4,282 registry
rows and 398 cards with no exact collision. Its sole fuzzy hit was the
rank-46 EURUSD/EURJPY sibling, manually resolved as a different second leg,
residual, and logical basket. Exact-pair, registry, and all 246 unordered
traded-symbol manifest checks found no dedicated fixed-beta EURUSD/GBPJPY D1
card, EA, allocation, or logical basket.

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | Fixed DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURUSD / GBPJPY | 0.005490 | -0.128824 | -1.095531% | 19 | -0.242481866 | 135.604 D1 bars |

The negative OOS Sharpe and return are adverse evidence. The approximately
136-bar half-life also implies long holds with material swap and regime risk.
This card authorizes one low-frequency frontier test, not a certified edge. A
terminal economic failure retires the sleeve; it does not authorize a filter,
beta refit, or parameter rescue.

## Non-Duplicate Boundary

Broad multi-symbol or cross-region FX systems and conversion-history
declarations may mention either symbol, but they do not trade this fixed pair,
beta, daily residual, and logical package. Sibling fixed-scan sleeves use
different instruments, residuals, magics, and logical identities.

## 2. Concept

Trade temporary deviations in the fixed log-price residual
`ln(EURUSD) - (-0.242481866) * ln(GBPJPY)`. The negative fitted coefficient
means a long spread buys both pairs and a short spread sells both pairs.

"Market-neutral" here means neutral only to the fitted two-series residual.
The package retains USD, EUR, GBP, JPY, carry, and broad risk-sentiment exposure.
That sign-sensitive structure and the negative OOS result are explicit
high-risk caveats rather than permission to add a filter or refit.

## Hypothesis

The fixed scan found a positive DEV score but a negative OOS result. This card
tests whether large residual deviations can nevertheless survive real tick
costs and swap in the canonical D1 implementation. The hypothesis is weak and
falsifiable: economic, cadence, history, or execution failure retires this
exact sleeve.

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
  - GBPJPY.DWX
host_symbol: EURUSD.DWX
logical_symbol: QM5_TBD_EURUSD_GBPJPY_COINTEGRATION_D1
tester_currency: USD
conversion_only_symbols:
  - USDJPY.DWX
```

`EURUSD.DWX` is the tester host and first traded leg. `GBPJPY.DWX` is the
companion traded leg. `USDJPY.DWX` is selected and warmed only for
JPY-to-USD profit conversion; it receives no order and no magic slot.

## 4. Entry Rules

- On a newly closed D1 bar, load the newest closed price for both traded
  symbols plus the preceding 60 time-aligned closed observations.
- Compute `spread = ln(EURUSD) - strategy_beta * ln(GBPJPY)`, with frozen
  `strategy_beta = -0.242481866`.
- Score the newest closed spread against the mean and sample standard
  deviation of the strictly preceding 60 spreads. The scored observation must
  not enter its own calibration window.
- If no package is open and `z > +2.0`, enter a short-spread package: short
  EURUSD and short GBPJPY.
- If no package is open and `z < -2.0`, enter a long-spread package: long
  EURUSD and long GBPJPY.
- Split the fixed package-risk budget by absolute hedge weights `1.0` and
  `0.242481866`, normalized across the package.
- Attach a hard `ATR(20, D1) * 2.0` stop loss to each traded leg at entry.
- If either normalized leg is below broker minimum volume, reject the complete
  package; never open only one leg or inflate a leg independently.

## 5. Exit Rules

- Close both traded legs when the closed-bar residual reaches `abs(z) < 0.5`.
- If either protective stop leaves one traded leg open, flatten the orphan leg
  immediately with a strategy exit reason.
- Framework Friday Close remains enabled and flattens both legs at the
  configured broker hour.
- No profit target, partial close, break-even move, trailing stop, or adaptive
  time stop is authorized.

## 6. Filters (No-Trade module)

- Permit entry only when the host is `EURUSD.DWX`, the configured period is D1
  or the supported H1 tester wrapper, and the host magic slot is 0.
- Require both traded symbols and the conversion-only symbol to be selected
  and warm.
- Require the two D1 traded histories to align exactly by timestamp for every
  residual sample.
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
- The conversion-only symbol receives neither an order nor a magic allocation.
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

Chan supplies the pair-trading method but reports no EURUSD/GBPJPY result.
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
- RETIRE on terminal economic Q02/Q04 failure; do not add a rescue filter.
- RETIRE if either normalized leg cannot meet broker minimum volume within the
  fixed package budget rather than distorting the fitted hedge.
- RETIRE if declared history remains unavailable after normal cold-cache retry
  behavior; never substitute or strip `.DWX`.
- RETIRE or return to Research if negative-beta direction is not long-long for
  a long spread and short-short for a short spread.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.00
expected_dd_pct: 30.0
expected_trade_frequency: approximately 5 completed packages/year per traded symbol
risk_class: high
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS | Durable OWNER-requested scan lineage plus OWNER-ratified Tier-A Chan SRC02 method evidence. |
| R2 | PASS | Fixed symbols, beta, closed-D1 z-score entry/exit, ATR stops, package sizing, and orphan cleanup are deterministic. |
| R3 | PASS | Traded and conversion-only `.DWX` histories are native factory symbols. |
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
  no_trade: "Select and warm both traded histories plus USDJPY conversion history; reject wrong host, timeframe, slot, unaligned history, or invalid normalized volume."
  entry: "Use the strictly prior 60-bar residual window and sign-aware two-leg QM_BasketOrder requests."
  management: "Rollback partial entry and flatten any orphan traded leg."
  close: "Close both registered legs at abs(z)<0.5 or framework Friday close."
estimated_complexity: medium
estimated_test_runtime: "one low-frequency logical-basket D1 Q02 run"
data_requirements: "EURUSD.DWX, GBPJPY.DWX, and USDJPY.DWX D1 histories"
```

## 14. Pipeline History

| Version | Date | Rebuild reason | Phase reached | Verdict |
|---|---|---|---|---|
| v1 | 2026-08-05 | next-ranked non-duplicate fixed-scan FX basket | G0 | APPROVED |

## 15. Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-05 | APPROVED | `decisions/2026-08-05_eurusd_eurjpy_cointegration_g0.md` |
| Q01 Build Validation | - | NOT_RUN | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |

## 16. Lessons Captured

- 2026-08-05: Rank 47 is OOS-negative and below the expected Q02 cadence
  floor; it is admitted only as the explicitly requested next-best one-shot
  sleeve, with retirement rather than rescue after economic failure.
