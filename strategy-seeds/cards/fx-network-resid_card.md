# Strategy Card — FX Network Residual Mean Reversion

> Drafted by Codex Research on 2026-06-04 from internal empirical DWX M1 research (`SRC07`).
> Status: DRAFT pending CEO + Quality-Business G0/G1 review. Not approved for EA build.

## Card Header

```yaml
strategy_id: SRC07_S01
ea_id: TBD
slug: fx-network-resid
status: DRAFT
created: 2026-06-04
created_by: Research
last_updated: 2026-06-04

strategy_type_flags:
  - symmetric-long-short
  - time-stop
```

## 1. Source

```yaml
source_citations:
  - type: other
    citation: "Internal empirical research batch SRC07: DWX M1 close-bar FX network residual scan, generated locally under .codex_tmp on 2026-06-03."
    location: ".codex_tmp/fx_network_residual_strategy_brief.md; .codex_tmp/fx_network_research/quick_4h_selected.csv"
    quality_tier: C
    role: primary
```

## 2. Concept

Major FX pairs form a cross-sectional currency-strength network. When one pair's short-horizon return deviates materially from the USD-normalized network-implied return, the residual may mean-revert as cross-rate pressure, liquidity-provider inventory, and correlated FX flows normalize.

This is statistical mean reversion on a network residual, not riskless triangular arbitrage.

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - M1
primary_target_symbols:
  - EURJPY.DWX
  - AUDJPY.DWX
  - USDJPY.DWX
```

## 4. Entry Rules

```text
- Build a liquid FX network from the approved DWX pair set.
- On M1 data, compute pair log returns over lookback L.
- Fit USD-normalized currency-strength vector from the network.
- For each traded pair, compute residual = observed_pair_return - fitted_network_return.
- Normalize residual by rolling residual volatility to form residual_z.
- At the decision cadence, if residual_z >= threshold, SELL the traded pair.
- If residual_z <= -threshold, BUY the traded pair.
- One open position per symbol.
```

Frozen prototype parameters from research:

```yaml
prototype_parameters:
  - symbol: EURJPY.DWX
    lookback_min: 15
    hold_min: 15
    threshold: 3.0
  - symbol: AUDJPY.DWX
    lookback_min: 15
    hold_min: 15
    threshold: 1.5
  - symbol: USDJPY.DWX
    lookback_min: 60
    hold_min: 15
    threshold: 3.0
```

## 5. Exit Rules

```text
- Exit by fixed time stop after hold_min.
- Emergency ATR stop TBD for MT5 validation.
- Friday Close enforced by default V5 framework.
```

## 6. Filters (No-Trade module)

```text
- Skip if any required network symbol has missing recent M1 bars.
- Skip if current spread exceeds rolling 60th percentile for the symbol/session.
- Skip boundary-hour trades until bid/ask validation proves they are not session artifacts.
- Apply default V5 kill-switch and news controls.
```

## 7. Trade Management Rules

```text
- No pyramiding.
- No gridding.
- One open position per symbol/magic.
- No partial exits in v1.
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: lookback_min
  default: 15
  sweep_range: [15, 30, 60]
- name: hold_min
  default: 15
  sweep_range: [15, 30, 60]
- name: threshold
  default: 3.0
  sweep_range: [1.5, 2.0, 2.5, 3.0]
- name: decision_cadence_min
  default: 120
  sweep_range: [60, 120, 240]
```

## 9. Author Claims (verbatim, with quote marks)

```text
"EURJPY.DWX lookback=15 hold=15 threshold=3.0: Train 2023-2024 121 trades, +13.57 bp/trade, t=2.64; OOS 2025 82 trades, +25.41 bp/trade, t=4.70." (.codex_tmp/fx_network_residual_strategy_brief.md)
"AUDJPY.DWX lookback=15 hold=15 threshold=1.5: Train 363 trades, +4.86 bp/trade, t=1.60; OOS 211 trades, +11.43 bp/trade, t=3.39." (.codex_tmp/fx_network_residual_strategy_brief.md)
"USDJPY.DWX lookback=60 hold=15 threshold=3.0: Train 425 trades, +6.14 bp/trade, t=2.30; OOS 220 trades, +8.98 bp/trade, t=2.43." (.codex_tmp/fx_network_residual_strategy_brief.md)
```

## 10. Initial Risk Profile

```yaml
expected_pf: TBD
expected_dd_pct: TBD
expected_trade_frequency: 80-220/year/symbol from M1-close research
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical
- [x] No Machine Learning required
- [x] Gridding not used
- [ ] Friday Close impact requires MT5 validation
- [x] Source citation points to local reproducible research artifacts
- [ ] Near-duplicate check against existing approved cards still required by CEO/QB

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "network data completeness, spread percentile, boundary-hour quarantine"
  trade_entry:
    used: true
    notes: "network residual z-score mean reversion"
  trade_management:
    used: false
    notes: "v1 uses one position and time stop"
  trade_close:
    used: true
    notes: "fixed hold-minute exit"

hard_rules_at_risk:
  - dwx_suffix_discipline
  - model4_every_real_tick
  - friday_close
  - kill_switch_coverage
at_risk_explanation: |
  Multi-symbol network inputs require strict .DWX suffix discipline and missing-bar handling. Research was M1 close based; MT5 Model 4 bid/ask validation is mandatory. Positions are short-horizon but Friday Close compatibility still needs validation.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD
  management: TBD
  close: TBD
estimated_complexity: large
estimated_test_runtime: TBD
data_requirements: multi_symbol_m1_network
```

## 14. Pipeline History (per `_v<n>` rebuild)

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-06-04 | initial draft card from internal M1 research | G0 Research Intake | DRAFT |

## 15. Pipeline Phase Status (current `_v<n>`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-04 | DRAFT | this card |
| P1 Build Validation | TBD | TBD | TBD |
| P2 Baseline Screening | TBD | TBD | TBD |
| P3 Parameter Sweep | TBD | TBD | TBD |
| P3.5 CSR | TBD | TBD | TBD |
| P4 Walk-Forward | TBD | TBD | TBD |
| P5 Stress | TBD | TBD | TBD |

## Hypothesis

FX pair returns temporarily dislocate from a cross-sectional currency-strength network. Extreme residuals should mean-revert over short horizons after liquidity and cross-rate pressure normalize.

## Rules

- Compute network-implied return from the liquid FX pair set.
- Enter against residual z-score extremes on approved symbols.
- Exit by fixed time stop.
- Skip missing network data, high spreads, and quarantined boundary-hour conditions.

## Risk

- Multi-symbol dependency can create missing-data and synchronization failures.
- M1-close research must be repeated with MT5 bid/ask and Model 4 validation.
- JPY concentration can create hidden portfolio correlation.
