---
strategy_id: AI-CODEX-FX-COINT66-20260609-USDJPY-EURGBP
ea_id: 20246
slug: usdjpy-eurgbp
type: strategy
status: APPROVED
g0_status: APPROVED
force_build: true
created: 2026-08-06
created_by: Research
last_updated: 2026-08-06
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
primary_target_symbols: [USDJPY.DWX, EURGBP.DWX]
target_symbols: [USDJPY.DWX, EURGBP.DWX]
logical_symbol: QM5_20246_USDJPY_EURGBP_COINTEGRATION_D1
period: D1
expected_trade_frequency: "Approximately 3 completed two-leg packages per year per traded symbol, inferred from 13 OOS basket state changes across 2023-2024; Q02 must retire the sleeve if realized frequency is below the binding floor."
expected_trades_per_year_per_symbol: 3
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
g0_approval_reasoning: "R1 PASS: OWNER-requested fixed FX scan plus OWNER-ratified Tier-A Chan SRC02; R2 PASS: fixed low-frequency two-leg D1 beta/z/ATR package; R3 PASS: traded and conversion histories are Darwinex-native; R4 PASS: structural, deterministic, and learned-model-free."
---

# USDJPY/EURGBP D1 Cointegration Basket

## 1. Source

The pair-trading method comes from the OWNER-ratified Tier-A SRC02 extraction
of Ernest Chan's *Quantitative Trading* at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. The source
specifies a fitted two-instrument spread, standardized-deviation entry,
mean-reach exit, cointegration-versus-correlation discipline, and a
low-frequency daily implementation. Chan makes no claim for USDJPY/EURGBP.

Pair selection comes from QuantMechanica's OWNER-requested frozen 66-pair FX
scan in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced from
the frozen Darwinex `.DWX` D1 export by
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
--include-negative-hedges`.

GBPUSD/USDJPY ranks fifty-eighth but is already mechanized as pair slot 5 in
`QM5_1156_caldeira-cointegration-pairs-fx`. USDCHF/GBPJPY ranks fifty-ninth
and is built as `QM5_20240`. USDJPY/EURGBP ranks sixtieth of 66 by OOS net
Sharpe and is the next relationship-level build gap. The deterministic dedup
check found no exact collision across 4,303 registry rows and 420 direct
cards. No tracked two-leg basket manifest trades this exact pair.

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | Fixed DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| USDJPY / EURGBP | 0.252701098850 | -0.456864966287 | -6.371810072221% | 13 | -1.281773609960 | 132.813394758594 D1 bars |

The negative OOS result, long half-life, and low inferred cadence are adverse
evidence. This card authorizes a one-shot low-frequency falsification test,
not a certified edge. Terminal economic, cadence, or history failure retires
the exact sleeve without a filter, beta refit, or parameter rescue.

## Non-Duplicate Boundary

`QM5_1156` explicitly mechanizes rank 58 but its universe does not contain
EURGBP. Broad momentum, carry, trend, and strength baskets that contain
USDJPY and EURGBP as unrelated members do not trade this frozen-beta D1
residual or logical two-leg package. Sibling fixed-scan sleeves use different
pairs, coefficients, magics, and logical identities.

## 2. Concept

Trade temporary deviations in the fixed log-price residual
`ln(USDJPY) - (-1.281773609960) * ln(EURGBP)`. The negative fitted coefficient
means a long spread buys both pairs and a short spread sells both pairs.

"Market-neutral" means neutral only to the fitted regression residual. The
package retains USD, JPY, EUR, GBP, carry, and policy-divergence exposure.

## Hypothesis

The frozen scan found positive DEV but negative OOS performance. This card
tests whether large fixed-residual deviations survive native tick costs and
swap in the canonical D1 implementation. Economic, cadence, or history
failure retires this exact sleeve.

## Rules

- Evaluate only after a newly closed D1 bar.
- Use the frozen DEV beta and a strictly prior rolling calibration window.
- Open and close both traded legs as one logical package.
- Never average, pyramid, grid, martingale, trail, or refit the relationship.
- Keep framework risk, news, kill-switch, symbol, and Friday-close guards on.

## 3. Markets & Timeframes

```yaml
markets: [forex]
timeframes: [D1]
primary_target_symbols: [USDJPY.DWX, EURGBP.DWX]
host_symbol: USDJPY.DWX
logical_symbol: QM5_20246_USDJPY_EURGBP_COINTEGRATION_D1
tester_currency: USD
conversion_only_symbols: [GBPUSD.DWX, EURUSD.DWX]
```

`USDJPY.DWX` is the tester host and first traded leg. `EURGBP.DWX` is the
companion traded leg. `GBPUSD.DWX` and `EURUSD.DWX` are warmed only for
USD-account conversion; neither receives an order or magic slot.

## 4. Entry Rules

- Load the newest closed D1 price for both traded symbols plus the preceding
  60 time-aligned closed observations.
- Compute `spread = ln(USDJPY) - strategy_beta * ln(EURGBP)`, with frozen
  `strategy_beta = -1.281773609960`.
- Score the newest spread against the mean and sample standard deviation of
  the strictly preceding 60 spreads; exclude the scored bar from calibration.
- With no package open, `z > +2.0` enters a short-spread package: short both
  USDJPY and EURGBP.
- With no package open, `z < -2.0` enters a long-spread package: long both
  USDJPY and EURGBP.
- Split fixed package risk by normalized absolute hedge weights `1.0` and
  `1.281773609960`.
- Attach a hard `ATR(20, D1) * 2.0` stop to each leg.
- Reject the complete package if either normalized leg is below broker minimum
  volume; never open only one leg or inflate a leg independently.

## 5. Exit Rules

- Close both legs when the closed-bar residual reaches `abs(z) < 0.5`.
- If a stop leaves one leg open, flatten the orphan immediately.
- Framework Friday Close remains enabled and flattens both legs.
- No profit target, partial close, break-even move, trailing stop, or adaptive
  time stop is authorized.

## 6. Filters (No-Trade module)

- Permit entry only on host `USDJPY.DWX`, D1 or the supported H1 tester
  wrapper, and magic slot 0.
- Require both traded symbols and both conversion histories selected and warm.
- Require exact D1 timestamp alignment across both residual legs.
- Require both normalized volumes to meet broker rules before either order.
- Inherit framework news, kill-switch, Friday-close, weekend, disconnect, and
  symbol guards without a waiver.
- Do not add carry, trend, correlation, volatility-regime, triangular, or
  stationarity rescue filters.

## 7. Trade Management Rules

- Treat the two traded positions as one package with separate magic slots.
- Roll back a partial entry and flatten any orphaned package leg.
- Conversion-only symbols receive neither orders nor magic allocations.
- Pyramiding, averaging, grid placement, martingale sizing, partial closes,
  and discretionary intervention are prohibited.

## 8. Parameters To Test

Q02 uses every default unchanged. The fitted beta is structural and frozen;
it is not a Q03 neighborhood parameter.

```yaml
- {name: strategy_z_lookback_d1, default: 60, sweep_range: [40, 60, 90]}
- {name: strategy_entry_z, default: 2.0, sweep_range: [1.75, 2.0, 2.25]}
- {name: strategy_exit_z, default: 0.5, sweep_range: [0.25, 0.5, 0.75]}
- {name: strategy_atr_period_d1, default: 20, sweep_range: [14, 20, 30]}
- {name: strategy_atr_sl_mult, default: 2.0, sweep_range: [1.5, 2.0, 2.5]}
```

## 9. Author Claims

Chan supplies the pair-trading method but reports no USDJPY/EURGBP result. The
pair table is in-house evidence net only of the scan's approximate 0.8 bp/leg
cost assumption. Swap was unmodeled; the deterministic pipeline is the judge.

## Risk

Backtests must use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each traded leg receives its own ATR hard stop, while
partial-entry and orphan states are flattened. No live setfile or live risk
setting is authorized.

Kill criteria:

- RETIRE at Q02 if realized cadence is below the binding frequency floor.
- RETIRE on terminal economic Q02/Q04 failure; do not add a rescue filter.
- RETIRE if declared history remains unavailable after normal cold-cache retry
  behavior; never substitute or strip `.DWX`.
- RETIRE or return to Research if negative-beta direction is not long-long for
  a long spread and short-short for a short spread.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.00
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
| R1 | PASS | Durable OWNER mission lineage plus OWNER-ratified Tier-A Chan SRC02 method evidence. |
| R2 | PASS | Fixed symbols, beta, D1 z-score entry/exit, ATR stops, sizing, and cleanup are deterministic. |
| R3 | PASS | Traded and conversion-only `.DWX` histories are native factory symbols. |
| R4 | PASS | No learned component, online refit, banned indicator, grid, martingale, or randomness is used. |

## 12. Framework Alignment

```yaml
modules_used:
  no_trade: {used: true, notes: "Host, timeframe, history, volume, and framework guards."}
  trade_entry: {used: true, notes: "Closed-D1 fixed-beta residual and atomic sign-aware package entry."}
  trade_management: {used: true, notes: "Partial-entry rollback and orphan cleanup only."}
  trade_close: {used: true, notes: "Mean-reach package exit, hard stops, and Friday close."}
hard_rules_at_risk: [risk_mode_dual, dwx_suffix_discipline, magic_schema, friday_close, one_position_per_magic_symbol]
at_risk_explanation: "The basket preserves RISK_FIXED backtests, exact .DWX symbols, registered magics, one position per leg, and package Friday flattening."
```

## 13. Implementation Notes

```yaml
target_modules:
  no_trade: "Warm traded and conversion history; reject wrong host, timeframe, slot, alignment, or volume."
  entry: "Use the strictly prior 60-bar residual and sign-aware two-leg basket orders."
  management: "Rollback partial entry and flatten orphan legs."
  close: "Close both registered legs at abs(z)<0.5 or Friday close."
estimated_complexity: medium
estimated_test_runtime: "one low-frequency logical-basket D1 Q02 run"
data_requirements: "USDJPY.DWX, EURGBP.DWX, GBPUSD.DWX, and EURUSD.DWX D1 histories"
```

## 14. Pipeline History

| Version | Date | Rebuild reason | Phase reached | Verdict |
|---|---|---|---|---|
| v1 | 2026-08-06 | next-ranked non-duplicate fixed-scan FX basket | G0 | APPROVED |

## 15. Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_usdjpy_eurgbp_cointegration_g0.md` |
| Q01 Build Validation | - | PENDING | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED | - |

## 16. Lessons Captured

- 2026-08-06: Rank 58 is an explicit QM5_1156 pair slot and rank 59 is
  QM5_20240; rank 60 is the first relationship-level build gap.
- 2026-08-06: Rank 60 is OOS-negative and slower than the expected Q02 cadence
  floor; it is admitted only as the explicitly requested next-best one-shot
  sleeve, with retirement rather than rescue after economic failure.
