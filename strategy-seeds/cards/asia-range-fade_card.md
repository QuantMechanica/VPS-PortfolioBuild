# Strategy Card — Asian Session Range Fade

> Drafted by Codex Research on 2026-06-04 from internal empirical DWX M1 research (`SRC07`).
> Status: DRAFT pending CEO + Quality-Business G0/G1 review. Not approved for EA build.

## Card Header

```yaml
strategy_id: SRC07_S02
ea_id: TBD
slug: asia-range-fade
status: DRAFT
created: 2026-06-04
created_by: Research
last_updated: 2026-06-04

strategy_type_flags:
  - intraday-session-pattern
  - time-stop
  - symmetric-long-short
```

## 1. Source

```yaml
source_citations:
  - type: other
    citation: "Internal empirical research batch SRC07: DWX M1 Asian-session range fade scan, generated locally under .codex_tmp on 2026-06-03."
    location: ".codex_tmp/next_ideas_research/next_ideas_shortlist.md; .codex_tmp/next_ideas_research/asia_range_selected.csv"
    quality_tier: C
    role: primary
```

## 2. Concept

The 00:00-07:00 UTC range is used as an intraday reference box. When price is outside that range by early US hours, the move may be stretched and mean-revert over the next few hours as US liquidity absorbs the prior session extension.

## 3. Markets & Timeframes

```yaml
markets:
  - commodities
  - indices
  - forex
timeframes:
  - M1
primary_target_symbols:
  - XTIUSD.DWX
  - XAUUSD.DWX
  - NDX.DWX
  - SP500.DWX
  - GBPUSD.DWX
```

## 4. Entry Rules

```text
- For each symbol, compute the 00:00-07:00 UTC session high and low using M1 data.
- At decision hour H, compare current price with the Asian range.
- If current price is above the Asian high by threshold_range_frac * Asian range, open SHORT.
- If current price is below the Asian low by threshold_range_frac * Asian range, open LONG.
- Use closed M1 bars only.
```

Representative research parameters:

```yaml
prototype_parameters:
  - symbol: XTIUSD.DWX
    hour_utc: 14
    threshold_range_frac: 0.0
    hold_min: 240
    mode: fade
  - symbol: XAUUSD.DWX
    hour_utc: 14
    threshold_range_frac: 0.0
    hold_min: 240
    mode: fade
  - symbol: GBPUSD.DWX
    hour_utc: 14
    threshold_range_frac: 0.0
    hold_min: 240
    mode: fade
```

## 5. Exit Rules

```text
- Exit by fixed time stop after hold_min.
- Emergency ATR stop TBD for MT5 validation.
- Friday Close enforced by default V5 framework.
```

## 6. Filters (No-Trade module)

```text
- Skip if Asian range is zero, incomplete, or has missing M1 data.
- Skip if spread exceeds rolling session percentile threshold.
- Skip high-impact news window unless P8 explicitly validates news-mode variant.
- Apply default V5 kill-switch.
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
- name: asian_start_hour_utc
  default: 0
  sweep_range: [0]
- name: asian_end_hour_utc
  default: 7
  sweep_range: [6, 7, 8]
- name: decision_hour_utc
  default: 14
  sweep_range: [13, 14]
- name: threshold_range_frac
  default: 0.0
  sweep_range: [0.0, 0.25, 0.5]
- name: hold_min
  default: 240
  sweep_range: [120, 240]
```

## 9. Author Claims (verbatim, with quote marks)

```text
"XTIUSD.DWX, 14:00 UTC, threshold 0.00, hold 240, fade: Train 175 trades, +72.74 bp/trade, t=11.09; OOS 93 trades, +52.35 bp/trade, t=7.27." (.codex_tmp/next_ideas_research/next_ideas_shortlist.md)
"XAUUSD.DWX, 14:00 UTC, threshold 0.00, hold 240, fade: Train 148 trades, +29.95 bp/trade, t=9.94; OOS 69 trades, +39.83 bp/trade, t=7.69." (.codex_tmp/next_ideas_research/next_ideas_shortlist.md)
"GBPUSD.DWX, 14:00 UTC, threshold 0.00, hold 240, fade: Train 192 trades, +17.58 bp/trade, t=9.35; OOS 76 trades, +17.97 bp/trade, t=7.50." (.codex_tmp/next_ideas_research/next_ideas_shortlist.md)
```

## 10. Initial Risk Profile

```yaml
expected_pf: TBD
expected_dd_pct: TBD
expected_trade_frequency: 60-95/year/symbol from M1-close research
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
    notes: "range completeness, spread, news, session availability"
  trade_entry:
    used: true
    notes: "fade extension beyond Asian session range"
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
at_risk_explanation: |
  M1 close research must be repeated with Model 4 bid/ask. Commodity and index sessions must be checked for tradability at the decision and exit times. High-impact news overlap must be governed by P8 defaults unless explicitly validated.
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
data_requirements: m1_session_range
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

Price extensions beyond the 00:00-07:00 UTC range are often overstretched by early US hours and mean-revert as US liquidity absorbs the prior session move.

## Rules

- Build the Asian session range from M1 data.
- At the approved decision hour, fade breaks above the range high or below the range low.
- Exit by fixed time stop.
- Skip incomplete ranges, high spreads, news windows, and unavailable sessions.

## Risk

- Current research used M1 close range as a proxy; true high/low and bid/ask validation are required.
- Commodity and index CFD sessions may affect entry/exit availability.
- News around the US session can dominate the signal.
