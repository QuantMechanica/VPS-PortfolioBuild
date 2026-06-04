# Strategy Card — Gold US-Session Pullback Continuation

> Drafted by Codex Research on 2026-06-04 from internal empirical DWX M1 research (`SRC07`).
> Status: DRAFT pending CEO + Quality-Business G0/G1 review. Not approved for EA build.
> Warning: raw edge is unusually strong and must be treated as suspicious until bid/ask validation.

## Card Header

```yaml
strategy_id: SRC07_S03
ea_id: TBD
slug: xau-pull-cont
status: DRAFT
created: 2026-06-04
created_by: Research
last_updated: 2026-06-04

strategy_type_flags:
  - intraday-session-pattern
  - trend-filter-ma
  - time-stop
  - symmetric-long-short
```

## 1. Source

```yaml
source_citations:
  - type: other
    citation: "Internal empirical research batch SRC07: DWX M1 gold trend-pullback scan, generated locally under .codex_tmp on 2026-06-03."
    location: ".codex_tmp/more_ideas_research/more_successful_ideas_shortlist.md; .codex_tmp/more_ideas_research/trend_pullback_selected.csv"
    quality_tier: C
    role: primary
```

## 2. Concept

Gold sometimes has a strong 12-hour trend into the US session, then a short pullback against that trend around 13:00 UTC. The empirical result suggests that this pullback frequently continues through the rest of the US session rather than immediately mean-reverting.

This card is deliberately marked suspicious because the M1-close research showed an unusually high win rate.

## 3. Markets & Timeframes

```yaml
markets:
  - commodities
timeframes:
  - M1
primary_target_symbols:
  - XAUUSD.DWX
```

## 4. Entry Rules

```text
- At 13:00 UTC on M1 data, compute trend_return over trend_lookback_min.
- Normalize trend_return by rolling median absolute trend_return.
- Compute pullback_return over pullback_lookback_min.
- If abs(trend_z) >= threshold and sign(pullback_return) is opposite sign(trend_return), trade in the pullback direction.
- If trend is up and pullback is down, SELL XAUUSD.
- If trend is down and pullback is up, BUY XAUUSD.
- One open position per symbol.
```

Representative research parameters:

```yaml
prototype_parameters:
  symbol: XAUUSD.DWX
  hour_utc: 13
  trend_lookback_min: 720
  pullback_lookback_min: 120
  hold_min: 480
  threshold: 1.0
  mode: pullback_continues
```

## 5. Exit Rules

```text
- Exit by fixed time stop after 480 minutes.
- Emergency ATR stop TBD for MT5 validation.
- Friday Close enforced by default V5 framework.
```

## 6. Filters (No-Trade module)

```text
- Skip if XAUUSD session is not tradable at entry or planned exit.
- Skip if spread exceeds rolling session percentile threshold.
- Skip high-impact USD news window unless P8 explicitly validates a news-mode variant.
- Skip if recent M1 data gap exists in trend or pullback lookback.
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
- name: hour_utc
  default: 13
  sweep_range: [13]
- name: trend_lookback_min
  default: 720
  sweep_range: [720]
- name: pullback_lookback_min
  default: 120
  sweep_range: [30, 60, 120]
- name: threshold
  default: 1.0
  sweep_range: [1.0, 1.5, 2.0]
- name: hold_min
  default: 480
  sweep_range: [240, 480]
```

## 9. Author Claims (verbatim, with quote marks)

```text
"XAUUSD.DWX, 13:00 UTC, trend lookback 720, pullback lookback 120, hold 480, pullback_continues: Train 149 trades, +70.73 bp/trade, t=18.27; OOS 59 trades, +99.77 bp/trade, t=10.97." (.codex_tmp/more_ideas_research/more_successful_ideas_shortlist.md)
"The win rate is extreme, roughly 98-99%, so this must be treated as high-priority but suspicious until MT5 bid/ask tester validation." (.codex_tmp/more_ideas_research/more_successful_ideas_shortlist.md)
```

## 10. Initial Risk Profile

```yaml
expected_pf: TBD
expected_dd_pct: TBD
expected_trade_frequency: approximately 60/year from M1-close research
risk_class: high
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
- [ ] Suspicious win-rate forensic review required before approval

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "spread, session availability, data completeness, news handling"
  trade_entry:
    used: true
    notes: "13:00 UTC gold trend/pullback continuation setup"
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
  - news_pause_default
  - enhancement_doctrine
at_risk_explanation: |
  The raw edge is unusually clean and must not be optimized further before bid/ask validation. Model 4 tester validation, spread checks, and session availability are mandatory before approval. News windows around 13:00 UTC may be material.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD
  management: TBD
  close: TBD
estimated_complexity: medium
estimated_test_runtime: TBD
data_requirements: xauusd_m1_bidask_validation
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

Gold pullbacks against a strong 12-hour trend around 13:00 UTC can continue through the US session instead of immediately reverting, possibly reflecting US-session order-flow repricing.

## Rules

- At 13:00 UTC, compute the 12-hour trend z-score and recent pullback direction.
- If the pullback opposes a sufficiently strong trend, trade in the pullback direction.
- Exit by fixed time stop.
- Skip missing data, high spreads, unavailable XAUUSD session windows, and unvalidated news overlap.

## Risk

- The research win rate is unusually high and must be treated as suspicious until bid/ask validation.
- Gold spreads and US news events can materially change realized fills.
- Further optimization before forensic validation is prohibited.
