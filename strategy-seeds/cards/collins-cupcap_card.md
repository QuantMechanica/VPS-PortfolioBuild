# Strategy Card - Collins Cups and Caps

## Card Header

```yaml
strategy_id: SRC08_S02
ea_id: TBD
slug: collins-cupcap
status: DRAFT
created: 2026-06-26
created_by: Research
last_updated: 2026-06-26

strategy_type_flags:
  - n-period-min-reversion
  - time-stop
  - symmetric-long-short
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Collins, Art. (2006). Beating the Financial Futures Market. John Wiley & Sons."
    location: "Chapter 15, pp. 49-55; Appendix Table 15.1-15.3, pp. 208-209 PDF text pages"
    quality_tier: A
    role: primary
```

## 2. Concept

Cups and caps are three-bar reversal formations. Collins tests both a next-day day-trade version and an overnight variant, then adds a target/stop form to improve tradeability on index markets. The QM port uses the target/stop version because the pure close-to-next-open edge is too thin after realistic CFD costs.

## 3. Markets & Timeframes

```yaml
markets:
  - indices
  - forex
  - commodities
timeframes:
  - D1
primary_target_symbols:
  - SP500.DWX
  - NDX.DWX
  - WS30.DWX
  - GDAXI.DWX
  - XAUUSD.DWX
  - XAGUSD.DWX
  - XTIUSD.DWX
  - GBPUSD.DWX
```

## 4. Entry Rules

Evaluate on completed D1 bars. Bar indexing below uses `bar0` as the latest closed bar, `bar1` as the middle bar, `bar2` as the oldest bar of the three-bar formation.

```text
Cup long setup:
- bar1.low < bar2.low
- bar1.low < bar0.low
- bar1.close < bar2.close
- bar1.close < bar0.close
- bar1.low < lowest(low, 3 bars before bar2)
- enter long at next bar open

Cap short setup:
- bar1.high > bar2.high
- bar1.high > bar0.high
- bar1.close > bar2.close
- bar1.close > bar0.close
- bar1.high > highest(high, 3 bars before bar2)
- enter short at next bar open
```

## 5. Exit Rules

Baseline uses Collins' target/stop variant rather than pure next-open exit.

```text
Long:
- target = highest(high, 3) + 0.25 * average(range, 3)
- stop = lowest(low, 3) - one_tick
- if neither target nor stop hits, exit at the next D1 open after one full bar.

Short:
- target = lowest(low, 3) - 0.25 * average(range, 3)
- stop = highest(high, 3) + one_tick
- if neither target nor stop hits, exit at the next D1 open after one full bar.
```

Framework Friday close and news blackout remain enabled.

## 6. Filters (No-Trade module)

```text
- skip if average(range, 3) is unavailable or zero
- skip if target distance is below spread-adjusted minimum
- skip if stop distance is below broker minimum stop distance
- optional P3 filter: trade only if 20-day ATR percentile is above 20 to avoid too-thin overnight moves
```

## 7. Trade Management Rules

```text
- no pyramiding
- no grid
- one active position per symbol/magic
- no trailing stop in baseline; target/stop/time exit are the complete management model
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: preceding_extreme_lookback
  default: 3
  sweep_range: [2, 3, 5]
- name: target_range_mult
  default: 0.25
  sweep_range: [0.10, 0.25, 0.50]
- name: time_exit_bars
  default: 1
  sweep_range: [1, 2, 3]
- name: atr_percentile_floor
  default: 0
  sweep_range: [0, 20, 40]
```

## 9. Author Claims (verbatim, with quote marks)

```text
"The cup side is the buy projection, the cap is the sell." (Chapter 15, p. 49).
"Talk about robustness!" (Chapter 15, p. 51).
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.2
expected_dd_pct: 10
expected_trade_frequency: 25/year/symbol
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical.
- [x] No Machine Learning required.
- [x] No gridding.
- [x] Not a scalper; D1 only.
- [x] Friday Close compatibility: yes.
- [x] Source citation is precise enough to reproduce.
- [x] Dedup check performed against approved cards and strategy seeds on 2026-06-26.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "History availability, range floor, spread and broker stop-distance checks."
  trade_entry:
    used: true
    notes: "Three-bar cup/cap local extreme with prior-three-bar extension filter."
  trade_management:
    used: false
    notes: "No active management beyond orders."
  trade_close:
    used: true
    notes: "Three-bar target, three-bar stop, and short time exit."

hard_rules_at_risk:
  - friday_close
at_risk_explanation: |
  The source emphasizes overnight bias; Friday entries must be blocked or flattened by default
  to avoid weekend-gap behavior not represented in the book's futures tests.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD
  management: TBD
  close: TBD
estimated_complexity: small
estimated_test_runtime: "standard D1 BL sweep"
data_requirements: standard
```

## 14. Pipeline History (per `_v<n>` rebuild)

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-06-26 | initial research draft | TBD | TBD |

## 15. Pipeline Phase Status (current `_v<n>`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-26 | DRAFT | this card |
| P1 Build Validation | TBD | TBD | TBD |
| P2 Baseline Screening | TBD | TBD | TBD |
| P3 Parameter Sweep | TBD | TBD | TBD |
| P3.5 CSR | TBD | TBD | TBD |
| P4 Walk-Forward | TBD | TBD | TBD |
| P5 Stress | TBD | TBD | TBD |
| P5b Calibrated Noise | TBD | TBD | TBD |
| P5c Crisis Slices | TBD | TBD | TBD |
| P6 Multi-Seed | TBD | TBD | TBD |
| P7 Statistical Validation | TBD | TBD | TBD |
| P8 News Impact | TBD | TBD | TBD |
| P9 Portfolio Construction | TBD | TBD | TBD |
| P9b Operational Readiness | TBD | TBD | TBD |
| P10 Shadow Deploy | TBD | TBD | TBD |
| Live Promotion | TBD | TBD | TBD |

## 16. Lessons Captured

```text
- 2026-06-26: Pure overnight version is likely too cost-thin; target/stop variant is the buildable V5 baseline.
```
