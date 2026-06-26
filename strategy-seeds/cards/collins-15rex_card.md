# Strategy Card - Collins 1.5 Daily Range Expansion

## Card Header

```yaml
strategy_id: SRC08_S03
ea_id: TBD
slug: collins-15rex
status: DRAFT
created: 2026-06-26
created_by: Research
last_updated: 2026-06-26

strategy_type_flags:
  - n-period-max-continuation
  - trend-filter-ma
  - signal-reversal-exit
  - symmetric-long-short
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Collins, Art. (2006). Beating the Financial Futures Market. John Wiley & Sons."
    location: "Chapter 25, p. 103; Appendix Table 25.4, p. 220 PDF text page"
    quality_tier: A
    role: primary
```

## 2. Concept

This is a volatility-expansion continuation system: when price is above a medium-term average, buy only if the next session moves far enough above the open; when price is below that average, sell short only if the next session expands below the open. The same opposite-side range-expansion stop is used as the exit/reversal mechanism.

## 3. Markets & Timeframes

```yaml
markets:
  - indices
  - commodities
  - forex
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
  - EURUSD.DWX
  - USDJPY.DWX
```

## 4. Entry Rules

Evaluate on completed D1 bars and place day-only next-bar stop orders.

```text
Inputs:
- q = 1.5
- n = 25
- prior_range = high[1] - low[1]
- ma = SMA(close, n)

Long:
- if close[1] > ma[1]
- place buy stop at next_open + q * prior_range

Short:
- if close[1] < ma[1]
- place sell stop at next_open - q * prior_range
```

If close equals the moving average, no new entry.

## 5. Exit Rules

Collins' formula uses symmetric opposite stop logic.

```text
Long:
- protective/reversal stop = next_open - q * prior_range
- exit if short-side range-expansion stop is hit

Short:
- protective/reversal stop = next_open + q * prior_range
- exit if long-side range-expansion stop is hit

V5 additions:
- pending entries expire at the end of the D1 bar
- optional max_hold_bars = 10 to avoid indefinite stale holds
- Friday close enforced
```

## 6. Filters (No-Trade module)

```text
- skip if prior_range <= 0
- skip if prior_range is above 5 * ATR(14), to avoid news shock follow-through from a single abnormal bar
- skip if order distance is below spread-adjusted minimum
- skip high-impact news per QM_NewsFilter default
```

## 7. Trade Management Rules

```text
- no pyramiding
- no grid
- one active position per symbol/magic
- no take-profit in baseline
- same-side repeated signal does not add exposure
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: range_mult_q
  default: 1.5
  sweep_range: [1.0, 1.25, 1.5, 2.0]
- name: ma_period
  default: 25
  sweep_range: [20, 25, 40, 50]
- name: max_hold_bars
  default: 10
  sweep_range: [5, 10, 20]
- name: abnormal_range_atr_cap
  default: 5.0
  sweep_range: [3.0, 5.0, 8.0]
```

## 9. Author Claims (verbatim, with quote marks)

```text
"Table 25.4 1.5 Daily Range Expansion" (Appendix, p. 220).
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.2
expected_dd_pct: 14
expected_trade_frequency: 15/year/symbol
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
    notes: "Range sanity, spread/broker distance, news blackout."
  trade_entry:
    used: true
    notes: "SMA(25) regime gate plus next-open +/- 1.5 prior range stop."
  trade_management:
    used: true
    notes: "Day-only pending order expiration and one-position enforcement."
  trade_close:
    used: true
    notes: "Opposite-side range-expansion stop or V5 time stop."

hard_rules_at_risk:
  - friday_close
  - one_position_per_magic_symbol
at_risk_explanation: |
  Original futures formula can operate as a continuous reversal system; V5 must avoid stacked exposure
  and flatten weekends by default.
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
- 2026-06-26: Distinct from generic ATR/channel breakouts because the trigger is next-open plus prior-day range multiple under a close-vs-SMA regime gate.
```
