# Strategy Card - Collins 9-Day 66 Percent Momentum

## Card Header

```yaml
strategy_id: SRC08_S01
ea_id: TBD
slug: collins-66mom
status: DRAFT
created: 2026-06-26
created_by: Research
last_updated: 2026-06-26

strategy_type_flags:
  - n-period-max-continuation
  - signal-reversal-exit
  - time-stop
  - symmetric-long-short
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Collins, Art. (2006). Beating the Financial Futures Market. John Wiley & Sons."
    location: "Chapter 41, pp. 177-179; Appendix Table 41.3, p. 232 PDF text page"
    quality_tier: A
    role: primary
```

## 2. Concept

Collins frames this as a daily momentum entry that tries to enter earlier in a move: buy only when the prior close sits nearer the 9-day low than the 9-day high, and require a next-day upward stop trigger. The stop distance is derived from the same 9-day high/low geometry, so the entry and risk model come from one price-location thesis rather than a bolted-on indicator.

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
  - XTIUSD.DWX
  - EURUSD.DWX
  - USDJPY.DWX
```

## 4. Entry Rules

Evaluate on completed D1 bars. One position per symbol and magic.

```text
hc = highest(high, 9) - close
lc = close - lowest(low, 9)
xx = max(hc, lc)

Long setup:
- if hc > lc
- place next-bar buy stop at next_open + 0.66 * lc

Short setup:
- if lc > hc
- place next-bar sell stop at next_open - 0.66 * hc
```

If both conditions are equal, no trade. Pending stop is day-only and expires if not filled on the next D1 bar.

## 5. Exit Rules

```text
Long:
- initial SL = entry_price - 1.32 * xx
- exit/reverse when a valid short setup stop fills

Short:
- initial SL = entry_price + 1.32 * xx
- exit/reverse when a valid long setup stop fills

Framework exits:
- Friday close enforced
- kill-switch enforced
- optional safety time-stop after 20 D1 bars for V5 bounded-hold testing
```

## 6. Filters (No-Trade module)

```text
- skip if 9-day range is zero or unavailable
- skip if computed stop distance is below broker minimum stop distance
- skip if spread exceeds V5 symbol-class threshold
- skip high-impact news per QM_NewsFilter default
```

## 7. Trade Management Rules

```text
- no pyramiding
- no averaging down
- no grid
- one active position per symbol/magic
- pending order expires at end of the next D1 bar
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: lookback
  default: 9
  sweep_range: [7, 9, 12]
- name: entry_fraction
  default: 0.66
  sweep_range: [0.50, 0.66, 0.75]
- name: stop_fraction
  default: 1.32
  sweep_range: [1.00, 1.32, 1.50]
- name: max_hold_bars
  default: 20
  sweep_range: [10, 20, 30]
```

## 9. Author Claims (verbatim, with quote marks)

```text
"The next system is a barnburner in the indexes" (Chapter 41, p. 177).
"You can't find much fault in the Table 41.3 results." (Chapter 41, p. 178).
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3
expected_dd_pct: 15
expected_trade_frequency: 35/year/symbol
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
- [x] Friday Close compatibility: yes, with forced flat.
- [x] Source citation is precise enough to reproduce.
- [x] Dedup check performed against approved cards and strategy seeds on 2026-06-26.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "History availability, spread, broker stop-distance, news blackout."
  trade_entry:
    used: true
    notes: "D1 9-bar close-location geometry plus next-open stop entry."
  trade_management:
    used: true
    notes: "Day-only pending order expiry; no pyramiding or grid."
  trade_close:
    used: true
    notes: "Formula-derived stop and optional signal reversal/time stop."

hard_rules_at_risk:
  - friday_close
  - one_position_per_magic_symbol
at_risk_explanation: |
  D1 momentum trades can remain open across weekends; V5 Friday close should stay enabled.
  The original continuous/reversal formulation can imply always-in-market behavior, but the V5 port
  must enforce one position per symbol/magic and no same-bar double fills.
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
- 2026-06-26: Collins card is D1/OHLC-only and portfolio-relevant if it survives; watch for index-cluster correlation.
```
