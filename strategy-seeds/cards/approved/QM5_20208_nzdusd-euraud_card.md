---
strategy_id: AI-CODEX-FX-COINT66-20260609-NZDUSD-EURAUD
ea_id: QM5_20208
slug: nzdusd-euraud
type: strategy
status: APPROVED
g0_status: APPROVED
created: 2026-08-03
created_by: Research+Development
last_updated: 2026-08-03
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
primary_target_symbols: [NZDUSD.DWX, EURAUD.DWX]
target_symbols: [NZDUSD.DWX, EURAUD.DWX]
logical_symbol: QM5_20208_NZDUSD_EURAUD_COINTEGRATION_D1
period: D1
expected_trade_frequency: "Approximately 5 completed two-leg packages per year per traded symbol, inferred from 19 OOS basket state changes across 2023-2024; Q02 must retire the sleeve if realized frequency is below the binding floor."
expected_trades_per_year_per_symbol: 5
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
g0_approval_reasoning: "Mission-directed G0 approval: R1 OWNER-requested fixed scan plus OWNER-ratified Tier-A Chan SRC02; R2 fixed sign-aware D1 beta/z/ATR package; R3 native NZDUSD/EURAUD and conversion histories; R4 structural deterministic ML-free."
---

# QM5_20208 NZDUSD/EURAUD D1 Cointegration Basket

## Source

The structural pair-trading method comes from the OWNER-ratified Tier-A SRC02
extraction of Ernest Chan's *Quantitative Trading* at
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`. Chan supplies
the fixed-beta spread, z-score entry, mean-reach exit, distinction between
cointegration and correlation, and half-life framework. He makes no performance
claim for NZDUSD/EURAUD.

Pair selection comes from QuantMechanica's OWNER-requested fixed 66-pair FX
scan in `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`, reproduced by
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
--include-negative-hedges` on the frozen Darwinex `.DWX` D1 export.

NZDUSD/EURAUD ranks twenty-seventh of 66 by OOS net Sharpe. Rank 26,
NZDUSD/AUDJPY, is already the dedicated D1 basket QM5_12749. An unordered
manifest reconciliation and exact card/registry search found no dedicated
fixed-beta NZDUSD/EURAUD D1 card, allocation, EA, or logical basket before this
card.

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | Fixed DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| NZDUSD / EURAUD | -0.091704 | 0.474703 | 4.877699% | 19 | -0.286008035 | 138.333 D1 bars |

Negative DEV Sharpe, sub-0.8 OOS Sharpe, and very slow half-life are adverse
evidence. This authorizes one low-frequency frontier test, not a certified
edge. A terminal economic failure ends the hypothesis; beta refitting, rescue
filters, pair substitution, and parameter rescue are forbidden.

## Non-Duplicate Boundary

Broad adaptive or multi-pair engines may contain either symbol, but they are
not this frozen-beta, closed-D1, one-pair logical package. Conversion-history
declarations do not duplicate a traded relationship. The immutable identity is
the unordered traded pair, beta, two registered magic slots, and logical
symbol.

## Concept

The fitted residual is
`ln(NZDUSD) - (-0.286008035) * ln(EURAUD)`. The negative beta makes a long
spread buy both legs and a short spread sell both legs. This offsets part of
the AUD/USD factor through the EURAUD cross but does not eliminate NZD, EUR,
AUD, USD, carry, or risk-sentiment exposure. “Market-neutral” therefore means
neutral only to the frozen fitted residual.

## Hypothesis

Temporary deviations in the fixed NZDUSD/EURAUD residual may mean-revert
slowly enough for D1 execution to retain a cost-adjusted edge. The scan does
not establish robustness: DEV was negative and the estimated half-life was
about 138 D1 bars. Q02 is the first platform-economic falsification gate.

## Rules

- Evaluate only after a newly closed D1 bar.
- Score the newest aligned spread against a strictly prior 60-bar window.
- Use the fixed DEV beta; never refit it in-test.
- Open and close both traded legs as one logical package.
- Never average, pyramid, grid, martingale, trail, or add a regime filter.
- Keep framework risk, news, kill-switch, symbol, and Friday-close guards.

## 3. Markets & Timeframes

```yaml
markets: [forex]
timeframes: [D1]
primary_target_symbols: [NZDUSD.DWX, EURAUD.DWX]
host_symbol: NZDUSD.DWX
logical_symbol: QM5_20208_NZDUSD_EURAUD_COINTEGRATION_D1
conversion_history_only: [AUDUSD.DWX, EURUSD.DWX]
```

The tester host is `NZDUSD.DWX` D1. `EURAUD.DWX` is the off-chart traded leg.
`AUDUSD.DWX` and `EURUSD.DWX` provide USD tester conversion history only and
must never receive orders or magic rows.

## 4. Entry Rules

- On a newly closed D1 bar, load the newest closed price for both traded
  symbols plus the preceding 60 time-aligned closed observations.
- Compute `spread = ln(NZDUSD) - strategy_beta * ln(EURAUD)`, with
  `strategy_beta = -0.286008035`.
- Score the newest closed spread against the mean and sample standard
  deviation of the strictly preceding 60 spreads; the scored observation must
  not enter its calibration window.
- With no package open, `z > +2.0` enters a short spread: sell NZDUSD and sell
  EURAUD. `z < -2.0` enters a long spread: buy NZDUSD and buy EURAUD.
- Split the single fixed-risk package by absolute hedge weights `1.0` and
  `abs(strategy_beta)`.
- Preflight both normalized volumes. If either is below broker minimum, reject
  the whole package instead of inflating or opening one leg.
- Attach a hard `ATR(20, D1) * 2.0` stop loss to each traded leg.

## 5. Exit Rules

- Close both legs when the closed-bar residual reaches `abs(z) < 0.5`.
- If a stop leaves one leg open, flatten the orphan immediately with a
  strategy exit reason.
- Framework Friday Close remains enabled and flattens the full package at the
  configured broker hour.
- No profit target, partial close, break-even move, trailing stop, or adaptive
  time stop is authorized.

## 6. Filters (No-Trade module)

- Permit execution only on `NZDUSD.DWX`, magic slot 0, and D1 (or the
  supported H1 tester wrapper used to advance D1 decisions).
- Require all four manifest symbols to be selected with complete D1 warm-up.
- Require identical timestamps for every paired D1 close used by the signal.
- Require both normalized traded-leg volumes to pass broker rules before entry.
- Inherit framework news, kill-switch, weekend, disconnect, symbol, and
  Friday-close guards without waiver.

## 7. Trade Management Rules

- Treat the two registered positions as one logical package.
- Send the host through the framework order path and the companion only after
  host success; roll back the host immediately if the companion fails.
- If package state contains other than exactly two valid legs, flatten every
  surviving package leg.
- Pyramiding, averaging, grids, martingale sizing, partial closes, and
  discretionary intervention are prohibited.

## 8. Parameters To Test

Q02 uses every default unchanged. The fitted beta is structural and frozen.
Only these predeclared Q03 dimensions may be swept:

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

Chan makes no NZDUSD/EURAUD performance claim. Pair figures are in-house scan
evidence with an approximate `0.8 bp/leg` cost model. Swap is unmodeled. The
deterministic pipeline, not the research estimate, judges economics.

## Risk

Every backtest setfile must use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The fixed package budget is divided by absolute hedge
weights. Each leg has an ATR stop; partial entries and orphans fail closed. No
live setfile or live risk setting is authorized.

Kill criteria:

- RETIRE at Q02 if realized cadence is below the binding frequency floor.
- RETIRE on terminal economic Q02/Q04 failure; do not add rescue mechanics.
- RETIRE if complete aligned D1 history remains unavailable after normal
  cold-cache retry behavior; never substitute or strip `.DWX`.
- RETIRE if either normalized leg is below broker minimum volume within the
  fixed budget; never inflate a leg independently.
- RETIRE or return to Research if negative-beta direction cannot be verified
  as long-long for a long spread and short-short for a short spread.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.01
expected_dd_pct: 30.0
expected_trade_frequency: "approximately 5 completed packages/year per traded symbol"
risk_class: high
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS | OWNER-requested fixed scan plus OWNER-ratified Tier-A Chan SRC02. |
| R2 | PASS | Fixed symbols, beta, closed-D1 z-score, ATR stops, risk split, and orphan cleanup are deterministic. |
| R3 | PASS | All four `.DWX` D1 histories exist in the frozen scan universe. |
| R4 | PASS | Structural deterministic rules only; no learned model, prohibited indicator, grid, or martingale. |

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "Host, timeframe, symbol selection, aligned-history, volume, and framework guards."
  trade_entry:
    used: true
    notes: "Closed-D1 fixed-beta z-score and atomic sign-aware two-leg entry."
  trade_management:
    used: true
    notes: "Partial-entry rollback and orphan cleanup only."
  trade_close:
    used: true
    notes: "Mean-reach package exit, hard stops, and framework Friday close."
hard_rules_at_risk:
  - risk_mode_dual
  - dwx_suffix_discipline
  - magic_schema
  - friday_close
at_risk_explanation: |
  The logical basket must preserve RISK_FIXED backtests, exact .DWX symbols,
  ea_id*10000+slot magic resolution, conversion-only histories, and full-package
  Friday flattening. No live artifact or exception is authorized.
```

## 13. Implementation Notes

```yaml
target_modules:
  no_trade: "Warm NZDUSD/EURAUD plus AUDUSD/EURUSD conversion histories; reject wrong host, timeframe, slot, or alignment."
  entry: "Use the prior 60-bar fixed-beta residual; host via QM_TM and companion via QM_BasketOrder."
  management: "Roll back partial entry and flatten orphaned package state."
  close: "Close both registered legs at abs(z)<0.5 or framework Friday close."
estimated_complexity: medium
estimated_test_runtime: "one low-frequency logical-basket D1 Q02 run"
data_requirements: standard
```

## 14. Pipeline History

| Version | Date | Rebuild reason | Phase reached | Verdict |
|---|---|---|---|---|
| v1 | 2026-08-03 | next-ranked non-duplicate fixed-scan FX basket | G0 | APPROVED |
| v2 | 2026-08-03 | initial sign-aware two-leg V5 implementation | Q01 | PASS |
| v3 | 2026-08-03 | guarded logical-basket priority-track enqueue | Q02 | PENDING |
