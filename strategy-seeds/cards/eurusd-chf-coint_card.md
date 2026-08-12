---
strategy_id: AI-CLAUDE-FX-COINT66-20260609-EURUSD-USDCHF
ea_id: QM5_20191
slug: eurusd-chf-coint
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
    location: "pp. 55-59, 126-133, and 140-142; approved local extraction strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md"
    quality_tier: A
    role: primary
research_evidence: "docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md; framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py --include-negative-hedges"
strategy_type_flags: [cointegration-pair-trade, zscore-band-reversion, mean-reversion]
concepts: [cointegration-pair-trade, zscore-band-reversion, market-neutral-fx-basket]
indicators: [rolling-zscore, atr-stop]
markets: [forex]
timeframes: [D1]
primary_target_symbols: [EURUSD.DWX, USDCHF.DWX]
target_symbols: [EURUSD.DWX, USDCHF.DWX]
logical_symbol: QM5_20191_EURUSD_USDCHF_COINTEGRATION_D1
period: D1
expected_trade_frequency: "Approximately 7-9 two-leg state changes per year at basket level; Q02 must retire the sleeve if realized frequency is below the binding floor."
expected_trades_per_year_per_symbol: 4
expected_pf: 1.05
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
pipeline_phase: Q02_QUEUED
g0_approval_reasoning: "R1 PASS single durable in-house scan lineage with OWNER-approved Chan SRC02 method; R2 PASS fixed-beta closed-D1 two-leg mechanics and explicit exits/stops; R3 PASS EURUSD.DWX and USDCHF.DWX factory data; R4 PASS deterministic ML-free one-position-per-magic-slot basket."
---

# QM5_20191 EURUSD/USDCHF D1 Cointegration Basket

## Source

The canonical lineage is the OWNER-requested QuantMechanica 66-pair FX scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced by
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
--include-negative-hedges` on the fixed Darwinex `.DWX` D1 export. The
mechanical pair-trading method comes from the OWNER-approved Tier-A SRC02
extraction of Ernest Chan's *Quantitative Trading*:
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`.

The sign-aware rerun ranks EURUSD/USDCHF tenth of 66 pairs by OOS net Sharpe
and first among pairs without a dedicated cointegration card or EA:

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | Fixed DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURUSD / USDCHF | -0.310802 | 0.751252 | 3.970936% | 17 | -0.585986704 | 347.361 D1 bars |

The negative DEV Sharpe and sub-0.8 OOS Sharpe are adverse evidence, not
something to optimize away. They make this a regime-unstable frontier
experiment with a strict no-rescue kill criterion.

## Concept

EURUSD and USDCHF are liquid USD majors with opposite USD quote orientation.
For a negative fitted beta, a long spread buys both pairs: the short-USD
exposure in EURUSD is partly offset by the long-USD exposure in USDCHF. The
strategy trades deviations in that fixed common-USD residual rather than a
standalone directional forecast.

## Hypothesis

Temporary deviations in
`ln(EURUSD) - (-0.585986704) * ln(USDCHF)` can mean-revert because both legs
load on broad USD pressure while retaining EUR and CHF residual risk. The OOS
ranking supports one low-frequency frontier test under the OWNER continuation
mission, while the negative DEV result and sub-bar OOS Sharpe say the
relationship may be regime-specific. Q02 onward is the judge; no adaptive
refit or added filter is authorized to conceal instability.

## Rules

- Evaluate the fixed two-leg basket only after a newly closed D1 bar.
- Use the fixed DEV beta and a rolling z-score with a strictly prior
  calibration window.
- Open and close both legs as one logical package.
- Never average, pyramid, grid, martingale, trail, or refit the pair in-test.
- Keep framework news, kill-switch, symbol, risk, and Friday-close guards
  active.

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - D1
primary_target_symbols:
  - EURUSD.DWX
  - USDCHF.DWX
host_symbol: EURUSD.DWX
logical_symbol: QM5_20191_EURUSD_USDCHF_COINTEGRATION_D1
```

The host chart is `EURUSD.DWX` D1. `USDCHF.DWX` is the second traded leg and
also supplies the CHF/USD conversion relationship required by the USD tester.

## 4. Entry Rules

- On a newly closed D1 bar, load the newest closed price for both symbols plus
  the preceding 60 time-aligned closed observations.
- Compute `spread = ln(EURUSD) - strategy_beta * ln(USDCHF)`, with
  `strategy_beta = -0.585986704`.
- Score the newest closed spread against the mean and sample standard
  deviation of the strictly preceding 60 spreads. The scored observation must
  not enter its own calibration window.
- If no basket package is open and `z > +2.0`, enter a short-spread package:
  short EURUSD and short USDCHF.
- If no basket package is open and `z < -2.0`, enter a long-spread package:
  long EURUSD and long USDCHF.
- Split the fixed risk budget by absolute hedge weights `1.0` and
  `abs(strategy_beta)`.
- Attach a hard `ATR(20, D1) * 2.0` stop loss to each leg at entry.

## 5. Exit Rules

- Close both legs when the closed-bar spread reaches `abs(z) < 0.5`.
- If either protective stop leaves only one leg open, flatten the orphan leg
  immediately with a strategy exit reason.
- Framework Friday Close remains enabled and flattens both legs at the
  configured broker hour.
- No profit target, partial close, break-even move, trailing stop, or
  adaptive time stop is authorized.

## 6. Filters (No-Trade module)

- Permit execution only when the chart symbol is `EURUSD.DWX` or
  `USDCHF.DWX`, the chart period is D1 or the supported H1 host wrapper, and
  the chart symbol resolves to the configured magic slot.
- Require both symbols to be selected and to expose at least the full D1
  warm-up window.
- Require exact timestamp alignment for every paired D1 close used in the
  spread.
- Inherit framework news, kill-switch, Friday-close, weekend, broker
  disconnect, and symbol guards without a strategy waiver.

## 7. Trade Management Rules

- Treat the two positions as one logical package with separate registered
  magic slots.
- If package entry is only partly successful, close the opened leg
  immediately.
- If an open package contains other than exactly two valid legs, flatten all
  surviving package legs.
- Pyramiding, averaging, grid placement, martingale sizing, partial closes,
  and discretionary intervention are prohibited.

## 8. Parameters To Test

Only these predeclared Q03 dimensions are authorized. Q02 uses every default
unchanged.

```yaml
- name: strategy_z_lookback_d1
  default: 60
  sweep_range: [40, 60, 90]
- name: strategy_beta
  default: -0.585986704
  sweep_range: [-0.70, -0.585986704, -0.48]
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

Chan does not make a performance claim for EURUSD/USDCHF. His source supplies
the deterministic fixed-beta spread, z-score entry/exit, cointegration-vs-
correlation discipline, and half-life framework. The pair-specific figures
above are QuantMechanica in-house research evidence and include the scan's
approximate `0.8 bp/leg` cost assumption; swap remains unmodeled.

## Risk

Backtests must use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg receives its own ATR hard stop, and the basket
code must clean up partial entry and orphan-leg states. No live setfile or live
risk setting is authorized by this card.

Kill criteria:

- RETIRE at Q02 if realized cadence is below the binding frequency floor.
- RETIRE on a terminal economic Q02/Q04 failure; the negative DEV Sharpe
  forbids rescue by adding a regime, carry, or trend filter.
- RETIRE if either leg lacks complete aligned D1 history after normal cold-cache
  retry behavior; do not substitute another symbol or strip `.DWX`.
- RETIRE or return to Research if fixed-beta sign handling cannot be verified
  as long-long for long spread and short-short for short spread.
- Any future parameter result must come from the predeclared Q03 dimensions;
  no post-failure parameter sweep is allowed.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.05
expected_dd_pct: 30.0
expected_trade_frequency: "7-9 two-leg state changes/year at basket level"
risk_class: high
gridding: false
scalping: false
ml_required: false
```

The estimate is intentionally conservative because DEV performance was
negative and the half-life is long. Multi-day swap and Friday flattening are
material risks that only the deterministic pipeline can measure.

## 11. Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS | One durable source lineage (`claude_cross_asset_discovery_2026-06-09`) with OWNER-approved Chan SRC02 method evidence. |
| R2 | PASS | Fixed symbols, beta, z-score entry/exit, ATR stops, risk split, and orphan cleanup are deterministic. |
| R3 | PASS | `EURUSD.DWX` and `USDCHF.DWX` are in the exported 66-pair D1 universe and are native factory symbols. |
| R4 | PASS | No ML, adaptive PnL fit, grid, martingale, randomness, or multi-position-per-magic behavior. |

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "Fixed host, timeframe, symbol selection, aligned-history, and framework guard checks."
  trade_entry:
    used: true
    notes: "Closed-D1 fixed-beta spread z-score and atomic sign-aware two-leg package entry."
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
at_risk_explanation: |
  The logical basket must preserve RISK_FIXED backtest mode, exact .DWX
  symbols, ea_id*10000+slot magic resolution, and package-level Friday
  flattening. No exception or live artifact is requested.
```

## 13. Implementation Notes

```yaml
target_modules:
  no_trade: "Select and warm EURUSD.DWX/USDCHF.DWX; reject wrong host, timeframe, slot, or unaligned history."
  entry: "Use the strictly prior 60-bar spread window and sign-aware two-leg QM_BasketOrder requests."
  management: "Rollback partial entry and flatten any orphan package leg."
  close: "Close both registered legs at abs(z)<0.5 or framework Friday close."
estimated_complexity: medium
estimated_test_runtime: "one low-frequency logical-basket D1 Q02 run"
data_requirements: standard
```

## 14. Pipeline History

| Version | Date | Rebuild reason | Phase reached | Verdict |
|---|---|---|---|---|
| v1 | 2026-08-01 | initial next-ranked non-duplicate FX cointegration basket | G0 | APPROVED |
| v1 | 2026-08-01 | V5 basket build, manifest, RISK_FIXED sets, strict compile | BUILD | PASS |
| v1 | 2026-08-01 | single logical-basket enqueue below the seven-terminal ceiling | Q02 | PENDING |
