---
strategy_id: AI-CLAUDE-FX-COINT66-20260609-EURUSD-USDCAD
ea_id: QM5_20193
slug: eurusd-cad-coint
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
primary_target_symbols: [EURUSD.DWX, USDCAD.DWX]
target_symbols: [EURUSD.DWX, USDCAD.DWX]
logical_symbol: QM5_20193_EURUSD_USDCAD_COINTEGRATION_D1
period: D1
expected_trade_frequency: "Approximately 6-7 two-leg state changes per year at basket level; Q02 must retire the sleeve if realized frequency is below the binding floor."
expected_trades_per_year_per_symbol: 3
expected_pf: 1.03
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
g0_approval_reasoning: "R1 PASS: OWNER-requested fixed scan plus CEO-ratified Tier-A Chan SRC02; R2 PASS: fixed two-leg D1 beta/z/ATR mechanics and explicit package exits; R3 PASS: EURUSD.DWX and USDCAD.DWX native history; R4 PASS: deterministic, structural, ML-free."
---

# QM5_20193 EURUSD/USDCAD D1 Cointegration Basket

## Source

The pair-trading method is taken from the OWNER-ratified Tier-A SRC02
extraction of Ernest Chan's *Quantitative Trading*:
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Chan provides
the fixed-beta spread, z-score entry and mean-reach exit, cointegration versus
correlation discipline, and Ornstein-Uhlenbeck half-life framework. He does
not claim results for EURUSD/USDCAD.

Pair selection comes from QuantMechanica's OWNER-requested fixed 66-pair FX
scan in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced by
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
--include-negative-hedges` on the frozen Darwinex `.DWX` D1 export.

EURUSD/USDCAD ranks eleventh of 66 by OOS net Sharpe and is the next ranked
relationship after QM5_20191 without a dedicated fixed-pair D1 cointegration
card, EA, or logical basket manifest:

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | Fixed DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURUSD / USDCAD | 0.006938 | 0.734143 | 4.351185% | 14 | -0.839757300 | 160.705 D1 bars |

The near-zero DEV result and sub-0.8 OOS Sharpe are adverse evidence. This is
one low-frequency frontier test, not a certified edge, and no filter, refit,
or parameter rescue is authorized after a terminal economic failure.

## Non-Duplicate Boundary

The deterministic duplicate checker found no exact slug or strategy-ID
collision. Its one fuzzy match was sibling `eurusd-chf-coint_card.md`, caused
by the deliberately shared family template. This card changes the companion
instrument from USDCHF to USDCAD, the fitted residual beta from
`-0.585986704` to `-0.839757300`, the residual history, and the logical basket
identity. Existing broad FX baskets and `QM5_13062` may declare both symbols
for universe or currency-conversion history, but none trades the dedicated
EURUSD/USDCAD fixed-beta D1 package.

## Concept

EURUSD and USDCAD are liquid USD majors with opposite USD quote orientation.
With a negative fitted beta, a long spread buys both pairs: EURUSD's short-USD
exposure is partly offset by USDCAD's long-USD exposure. The strategy therefore
trades deviations in a common-USD residual rather than a standalone direction.

## Hypothesis

The hypothesis is that temporary deviations in
`ln(EURUSD) - (-0.839757300) * ln(USDCAD)` can mean-revert while the underlying
USD factor is partially hedged. The fixed scan supports only a one-shot
pipeline test: its DEV evidence is effectively flat and its OOS result is
below the original survivor bar.

## Rules

- Evaluate the two-leg basket only after a newly closed D1 bar.
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
  - USDCAD.DWX
host_symbol: EURUSD.DWX
logical_symbol: QM5_20193_EURUSD_USDCAD_COINTEGRATION_D1
```

The tester host is `EURUSD.DWX` D1. `USDCAD.DWX` is the companion traded leg.
Both settle naturally into the USD tester account, so no third conversion-only
symbol is part of the manifest.

## 4. Entry Rules

- On a newly closed D1 bar, load the newest closed price for both symbols plus
  the preceding 60 time-aligned closed observations.
- Compute `spread = ln(EURUSD) - strategy_beta * ln(USDCAD)`, with
  `strategy_beta = -0.839757300`.
- Score the newest closed spread against the mean and sample standard
  deviation of the strictly preceding 60 spreads. The scored observation must
  not enter its own calibration window.
- If no package is open and `z > +2.0`, enter a short-spread package: short
  EURUSD and short USDCAD.
- If no package is open and `z < -2.0`, enter a long-spread package: long
  EURUSD and long USDCAD.
- Split the one fixed-risk budget by absolute hedge weights `1.0` and
  `abs(strategy_beta)`.
- Attach a hard `ATR(20, D1) * 2.0` stop loss to each leg at entry.

## 5. Exit Rules

- Close both legs when the closed-bar spread reaches `abs(z) < 0.5`.
- If either protective stop leaves only one leg open, flatten the orphan leg
  immediately with a strategy exit reason.
- Framework Friday Close remains enabled and flattens both legs at the
  configured broker hour.
- No profit target, partial close, break-even move, trailing stop, or adaptive
  time stop is authorized.

## 6. Filters (No-Trade module)

- Permit execution only when the host resolves to `EURUSD.DWX`, the configured
  period is D1 or the supported H1 tester wrapper, and the host magic slot is 0.
- Require both symbols to be selected and to expose the full D1 warm-up window.
- Require exact timestamp alignment for every paired D1 close used in the
  spread.
- Inherit framework news, kill-switch, Friday-close, weekend, broker
  disconnect, and symbol guards without a strategy waiver.

## 7. Trade Management Rules

- Treat the two positions as one logical package with separate registered
  magic slots.
- If package entry is only partly successful, close the opened leg immediately.
- If an open package contains other than exactly two valid legs, flatten every
  surviving package leg.
- Pyramiding, averaging, grid placement, martingale sizing, partial closes,
  and discretionary intervention are prohibited.

## 8. Parameters To Test

Q02 uses every default unchanged. The fitted beta is structural and frozen;
it is not an arbitrary neighborhood parameter. Only these predeclared Q03
dimensions may be swept:

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

Chan makes no performance claim for EURUSD/USDCAD. The pair-specific figures
are QuantMechanica in-house research evidence and include the scan's
approximate `0.8 bp/leg` cost assumption. Swap remains unmodeled, and the
pipeline is the economic judge.

## Risk

Backtests must use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg receives its own ATR hard stop, and the basket
must clean up partial-entry and orphan-leg states. No live setfile or live risk
setting is authorized.

Kill criteria:

- RETIRE at Q02 if realized cadence is below the binding frequency floor.
- RETIRE on a terminal economic Q02/Q04 failure; no regime, carry, or trend
  filter may be added as a rescue.
- RETIRE if either leg lacks complete aligned D1 history after normal
  cold-cache retry behavior; do not substitute a symbol or strip `.DWX`.
- RETIRE or return to Research if negative-beta handling cannot be verified as
  long-long for long spread and short-short for short spread.
- Any future parameter result must use only the predeclared Q03 dimensions.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.03
expected_dd_pct: 30.0
expected_trade_frequency: "6-7 two-leg state changes/year at basket level"
risk_class: high
gridding: false
scalping: false
ml_required: false
```

The estimate is deliberately conservative because DEV performance was almost
flat and the half-life is long. Multi-day swap and Friday flattening are
material risks that only deterministic testing can measure.

## 11. Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS | Durable OWNER-requested scan lineage plus OWNER-ratified Tier-A Chan SRC02 method evidence. |
| R2 | PASS | Fixed symbols, beta, closed-D1 z-score entry/exit, ATR stops, risk split, and orphan cleanup are deterministic. |
| R3 | PASS | `EURUSD.DWX` and `USDCAD.DWX` are native factory symbols in the fixed D1 scan export. |
| R4 | PASS | No adaptive fit, banned indicator, grid, martingale, randomness, or learned model is used. |

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
  no_trade: "Select and warm EURUSD.DWX/USDCAD.DWX; reject wrong host, timeframe, slot, or unaligned history."
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
| v1 | 2026-08-01 | next-ranked non-duplicate fixed-scan FX basket | G0 | APPROVED |
| v1 | 2026-08-01 | V5 basket implementation and strict compile/build validation | Q01 | PASS |
| v1 | 2026-08-01 | deterministic two-run host-symbol smoke | Q01 | PASS |
| v1 | 2026-08-01 | one logical-basket work item auto-enqueued by governed build recorder | Q02 | PENDING |
