---
strategy_id: AI-CODEX-FX-COINT66-20260609-AUDUSD-EURAUD
ea_id: QM5_20216
slug: audusd-euraud
type: strategy
status: APPROVED
g0_status: APPROVED
force_build: true
created: 2026-08-05
created_by: Research+Development
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
primary_target_symbols: [AUDUSD.DWX, EURAUD.DWX]
target_symbols: [AUDUSD.DWX, EURAUD.DWX]
logical_symbol: QM5_20216_AUDUSD_EURAUD_COINTEGRATION_D1
period: D1
expected_trade_frequency: "Approximately 3 completed two-leg packages per year per traded symbol, inferred from 15 OOS basket state changes across 2023-2024; Q02 must retire the sleeve if realized frequency is below the binding floor."
expected_trades_per_year_per_symbol: 3
expected_pf: 1.01
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
pipeline_phase: Q02_PENDING
g0_approval_reasoning: "R1 PASS: OWNER-requested fixed FX scan plus OWNER-ratified Tier-A Chan SRC02; R2 PASS: fixed low-frequency two-leg D1 beta/z/ATR package; R3 PASS: traded and conversion histories are Darwinex-native; R4 PASS: structural, deterministic, and learned-model-free."
---

# QM5_20216 AUDUSD/EURAUD D1 Cointegration Basket

## 1. Source

The pair-trading method comes from the OWNER-ratified Tier-A SRC02 extraction
of Ernest Chan's *Quantitative Trading* at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. The source
specifies a fitted two-instrument spread, standardized-deviation entry,
mean-reach exit, cointegration-versus-correlation discipline, and a
low-frequency daily implementation. Chan makes no claim for AUDUSD/EURAUD.

Pair selection comes from QuantMechanica's OWNER-requested fixed 66-pair FX
scan in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced from
the frozen Darwinex `.DWX` D1 export by
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
--include-negative-hedges`.

AUDUSD/EURAUD ranks thirty-third of 66 by OOS net Sharpe. Rank 32,
GBPUSD/EURJPY, is already represented by dedicated fixed-D1 basket
`QM5_20212`. The deterministic repository dedup check, exact-pair searches,
and an unordered traded-symbol manifest reconciliation found no dedicated
fixed-beta AUDUSD/EURAUD D1 card, EA, registry allocation, or logical basket
manifest before this card.

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | Fixed DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| AUDUSD / EURAUD | -0.025549 | 0.160430 | 1.290977% | 15 | -0.655175398 | 171.485 D1 bars |

The sub-0.8 OOS Sharpe is adverse evidence, and the approximately 171-bar
half-life implies a very long holding horizon with material swap and regime risk.
This card authorizes one low-frequency frontier test, not a certified edge. A
terminal economic failure retires the sleeve; it does not authorize a filter,
beta refit, or parameter rescue.

## Non-Duplicate Boundary

Broad multi-symbol or cross-region FX systems and conversion-history
declarations may mention both symbols, but they do not trade this fixed pair,
beta, daily residual, and logical package. Sibling fixed-scan sleeves use
different instruments, residuals, magics, and logical identities.

## 2. Concept

Trade temporary deviations in the fixed log-price residual
`ln(AUDUSD) - (-0.655175398) * ln(EURAUD)`. The negative fitted coefficient
means a long spread buys both pairs and a short spread sells both pairs.

"Market-neutral" here means neutral only to the fitted two-series residual.
The package retains AUD, USD, EUR, carry, and risk-sentiment exposure. That
sign-sensitive structure, negative beta, and very slow half-life are explicit
high-risk caveats rather than permission to add a filter or refit the spread.

## Hypothesis

The fixed scan suggests large deviations in the AUDUSD/EURAUD residual may
mean-revert slowly enough for a D1 two-leg implementation to survive costs.
Because OOS performance missed the original survivor bar and the estimated
half-life is slow, the hypothesis is deliberately weak and falsifiable:
real-tick cost, swap, cadence, or profitability failure retires this exact
sleeve.

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
  - AUDUSD.DWX
  - EURAUD.DWX
host_symbol: AUDUSD.DWX
logical_symbol: QM5_20216_AUDUSD_EURAUD_COINTEGRATION_D1
tester_currency: USD
conversion_only_symbols:
  - EURUSD.DWX
```

`AUDUSD.DWX` is the tester host and first traded leg. `EURAUD.DWX` is the
companion traded leg. `EURUSD.DWX` is conversion-only history for EUR margin
accounting under the USD tester account; it receives no order and no magic
slot. The traded AUDUSD history supplies EURAUD's AUD/USD P/L conversion path.

## 4. Entry Rules

- On a newly closed D1 bar, load the newest closed price for both traded
  symbols plus the preceding 60 time-aligned closed observations.
- Compute `spread = ln(AUDUSD) - strategy_beta * ln(EURAUD)`, with frozen
  `strategy_beta = -0.655175398`.
- Score the newest closed spread against the mean and sample standard
  deviation of the strictly preceding 60 spreads. The scored observation must
  not enter its own calibration window.
- If no package is open and `z > +2.0`, enter a short-spread package: short
  AUDUSD and short EURAUD.
- If no package is open and `z < -2.0`, enter a long-spread package: long
  AUDUSD and long EURAUD.
- Split the fixed package-risk budget by absolute hedge weights `1.0` and
  `0.655175398`, normalized across the package.
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

- Permit entry only when the host is `AUDUSD.DWX`, the configured period is D1
  or the supported H1 tester wrapper, and the host magic slot is 0.
- Require both traded symbols and all manifest conversion histories to be
  selected and warm.
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
- Conversion-only symbols must never receive an order.
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

Chan supplies the pair-trading method but reports no AUDUSD/EURAUD result.
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
expected_pf: 1.01
expected_dd_pct: 30.0
expected_trade_frequency: approximately 3 completed packages/year per traded symbol
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
  no_trade: "Select and warm three declared histories; reject wrong host, timeframe, slot, unaligned traded history, or invalid normalized volume."
  entry: "Use the strictly prior 60-bar residual window and sign-aware two-leg QM_BasketOrder requests."
  management: "Rollback partial entry and flatten any orphan traded leg."
  close: "Close both registered legs at abs(z)<0.5 or framework Friday close."
estimated_complexity: medium
estimated_test_runtime: "one low-frequency logical-basket D1 Q02 run"
data_requirements: "AUDUSD.DWX, EURAUD.DWX, and EURUSD.DWX D1 histories"
```

## 14. Pipeline History

| Version | Date | Rebuild reason | Phase reached | Verdict |
|---|---|---|---|---|
| v1 | 2026-08-05 | next-ranked non-duplicate fixed-scan FX basket | G0 | APPROVED |
| v2 | 2026-08-05 | initial sign-aware two-leg implementation | Q01 | PASS |
| v3 | 2026-08-05 | logical basket priority-track enqueue | Q02 | PENDING |

## 15. Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-05 | APPROVED | this card |
| Q01 Build Validation | 2026-08-05 | PASS | `D:\QM\reports\framework\21\build_check_20260804_224845.json` |
| Q02 Baseline Screening | 2026-08-05 | PENDING | work item `214ac1b6-a810-456f-801a-97e3673bc953` |

## 16. Lessons Captured

- 2026-08-05: Rank 33 has negative DEV performance, a sub-0.8 OOS score, and
  a slow estimated half-life; it is admitted only as the explicitly requested
  next-best one-shot sleeve, with retirement rather than rescue after economic
  failure.
