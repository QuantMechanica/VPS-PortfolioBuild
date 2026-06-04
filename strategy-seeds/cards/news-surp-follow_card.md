# Strategy Card — Numeric News-Surprise Follow

> Drafted by Codex Research on 2026-06-04 from internal empirical DWX M1 research (`SRC07`).
> Status: DRAFT pending CEO + Quality-Business G0/G1 review. Not approved for EA build.

## Card Header

```yaml
strategy_id: SRC07_S04
ea_id: TBD
slug: news-surp-follow
status: DRAFT
created: 2026-06-04
created_by: Research
last_updated: 2026-06-04

strategy_type_flags:
  - news-blackout
  - time-stop
  - symmetric-long-short
```

## 1. Source

```yaml
source_citations:
  - type: other
    citation: "Internal empirical research batch SRC07: DWX M1 numeric news-surprise follow scan using local news_calendar_2015_2025.csv, generated under .codex_tmp on 2026-06-03."
    location: ".codex_tmp/next_ideas_research/next_ideas_shortlist.md; .codex_tmp/next_ideas_research/news_surprise_selected.csv"
    quality_tier: C
    role: primary
```

## 2. Concept

For high-impact calendar events with numeric actual and forecast values, the sign of actual minus forecast may create a short-lived directional impulse in the related currency. The strategy follows the surprise direction for a fixed post-event holding period.

This is an event-gated sleeve and should be sized conservatively because 2025 OOS sample counts are small.

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - M1
primary_target_symbols:
  - AUDJPY.DWX
  - AUDNZD.DWX
  - GBPUSD.DWX
  - CHFJPY.DWX
```

## 4. Entry Rules

```text
- Read high-impact events from the local cleaned news calendar.
- Keep events where actual and forecast parse to numeric values.
- surprise = actual - forecast.
- If event currency is base currency, trade pair in sign(surprise) direction.
- If event currency is quote currency, invert the side.
- Enter at event timestamp after data availability confirmation.
```

Representative research parameters:

```yaml
prototype_parameters:
  - symbol: AUDJPY.DWX
    bucket: all_numeric
    hold_min: 120
    mode: surprise_follow
  - symbol: AUDJPY.DWX
    bucket: inflation
    hold_min: 120
    mode: surprise_follow
  - symbol: AUDNZD.DWX
    bucket: all_numeric
    hold_min: 240
    mode: surprise_follow
```

## 5. Exit Rules

```text
- Exit by fixed time stop after hold_min.
- No target/stop in v1 research form; emergency ATR stop TBD for MT5 validation.
- Friday Close enforced by default V5 framework.
```

## 6. Filters (No-Trade module)

```text
- Trade only high-impact events with numeric actual and forecast.
- Skip duplicate event timestamps per symbol unless explicitly aggregated.
- Skip if event timestamp cannot be aligned to M1 market data.
- Skip if spread exceeds rolling event-window percentile threshold.
- No entry if another position is already open for symbol/magic.
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
- name: event_bucket
  default: all_numeric
  sweep_range: [all_numeric, inflation, jobs, growth]
- name: hold_min
  default: 120
  sweep_range: [60, 120, 240]
- name: min_abs_surprise_z
  default: 0.0
  sweep_range: [0.0, 0.5, 1.0]
```

## 9. Author Claims (verbatim, with quote marks)

```text
"AUDJPY.DWX, all numeric high-impact events, hold 120, surprise_follow: Train 241 trades, +2.17 bp/trade, t=1.92; OOS 30 trades, +7.88 bp/trade, t=1.56." (.codex_tmp/next_ideas_research/next_ideas_shortlist.md)
"AUDJPY.DWX, inflation, hold 120, surprise_follow: Train 94 trades, +3.78 bp/trade, t=2.88; OOS 13 trades, +6.41 bp/trade, t=1.95." (.codex_tmp/next_ideas_research/next_ideas_shortlist.md)
"AUDNZD.DWX, all numeric, hold 240, surprise_follow: Train 186 trades, +7.31 bp/trade, t=4.89; OOS 21 trades, +3.05 bp/trade, t=2.02." (.codex_tmp/next_ideas_research/news_surprise_selected.csv)
```

## 10. Initial Risk Profile

```yaml
expected_pf: TBD
expected_dd_pct: TBD
expected_trade_frequency: low/event-dependent
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
- [ ] Calendar timestamp quality requires CEO/QB review
- [ ] Near-duplicate check against existing approved cards still required by CEO/QB

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "event availability, duplicate event control, spread, timestamp alignment"
  trade_entry:
    used: true
    notes: "actual-minus-forecast surprise direction"
  trade_management:
    used: false
    notes: "v1 uses one position and time stop"
  trade_close:
    used: true
    notes: "fixed hold-minute exit"

hard_rules_at_risk:
  - news_pause_default
  - darwinex_native_data_only
  - model4_every_real_tick
  - dwx_suffix_discipline
at_risk_explanation: |
  This strategy intentionally trades around news, so P8 handling must be explicit and cannot rely on default blackout assumptions. The calendar is local data, not broker-native; CEO/CTO must approve this data dependency before build.
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
data_requirements: custom_news_calendar
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
| P8 News Impact | TBD | TBD | TBD |

## Hypothesis

High-impact events with numeric actual-versus-forecast surprises can create directional currency impulse that persists for a short fixed window after release.

## Rules

- Parse high-impact numeric calendar events.
- Compute surprise as actual minus forecast.
- Map event currency surprise to pair direction, inverted when the event currency is quote.
- Enter after timestamp/data alignment and exit by fixed time stop.

## Risk

- This strategy intentionally trades around news and needs explicit P8 governance.
- Calendar timestamps and actual/forecast parsing require validation.
- OOS event counts are small, so sizing must be conservative.
