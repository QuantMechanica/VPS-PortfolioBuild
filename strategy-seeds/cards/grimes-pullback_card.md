# Strategy Card — Grimes Pullback (canonical pattern) — **T2_PENDING**

> Drafted by Research Agent on 2026-04-27 from `strategy-seeds/sources/_t2_pending/grimes-blog/raw/2014-11-05_trade-pullbacks.md` (was `strategy-seeds/sources/SRC01/raw/...` before the 17:28 OWNER T1/T2/T3 mandate moved Grimes blog to T2).
>
> **Status (2026-04-27 ~18:10):** T2_PENDING — work product preserved but **NOT** in the active pipeline. Grimes blog is T2 per OWNER directive 2026-04-27 ~17:28 local; T2 dispatch begins only after T1 (57 PDFs) is drained or partially-exhausted with CEO+OWNER ratification. When that happens, this card is re-numbered with the real SRC ID and submitted to CEO + Quality-Business for G0 intake review.

## Card Header

```yaml
strategy_id: TBD                              # was SRC01_S01 under the 17:15 directive; re-allocated when Grimes blog gets its real SRC ID at T2 dispatch
ea_id: TBD
slug: grimes-pullback
status: T2_PENDING                            # was DRAFT; demoted from active queue per 17:28 T1/T2/T3 mandate
created: 2026-04-27
created_by: Research
last_updated: 2026-04-27

strategy_type_flags:
  - trend-following
  - pullback
  - breakout                                  # entry trigger uses prior-bar-high breakout
```

## 1. Source

```yaml
source_citations:
  - type: article
    citation: "Grimes, Adam H. (2014-11-05). \"How to trade pullbacks.\" The Blog of Adam H Grimes. https://www.adamhgrimes.com/trade-pullbacks/ (accessed 2026-04-27)."
    location: "post body, sections \"How to trade pullbacks\", \"Further refinements for entries\", \"Stop location\", \"Trade management\""
    quality_tier: B
    role: primary
```

Raw evidence file: `strategy-seeds/sources/SRC01/raw/2014-11-05_trade-pullbacks.md`.

## 2. Concept

Trends move in pulses, not straight lines: a strong with-trend thrust is followed by a pullback toward "average" price before the next leg resumes. Grimes argues the inefficiency is structural — opportunity exists when buying and selling pressure becomes imbalanced, and a pullback after a strong thrust is an asymmetric spot to enter the next leg of an existing trend with a small initial risk and a measured first target. Entering on a lower-timeframe breakout of the prior bar's high (long) confirms the pullback is rolling back into the trend before risk is committed.

## 3. Markets & Timeframes

```yaml
markets:                                     # which the source recommends
  - indices                                  # Grimes cites ES (S&P 500 futures) and EWG (Germany ETF)
  - forex                                    # Grimes cites EUR, GBP
  - stocks                                   # Grimes cites general single-name examples ("S")
  - commodities                              # not explicit in this post; Grimes covers Gold in adjacent posts
timeframes:
  - intraday                                 # Grimes uses 2-minute bars in one example
  - H4
  - D1
  - W1                                       # Grimes states "useful to traders working on timeframes from intraday to months/quarters"
primary_target_symbols:                      # Darwinex re-mapping at CTO sanity-check
  - ES (or US500.DWX equivalent)
  - EURUSD.DWX
  - GBPUSD.DWX
  - GER40.DWX                                # rough re-map of Grimes's EWG (Germany ETF)
```

## 4. Entry Rules

Pseudocode form. Grimes's "strong move" / "trend in place" / "non-exhaustion" filters are mapped to mechanical bands per his own guidance ("bands should contain roughly 80%-90% of the price action").

```text
LONG ENTRY (mirror for short):
- setup condition (prior-bar): close[1] >= upper_band[1]
  where upper_band = Keltner channel calibrated so 80-90% of historical price action is contained
  (Grimes: "bands should contain roughly 80% - 90% of the price action")
- pullback condition (current bar): low <= midline (the channel's moving-average centerline)
  (Grimes: "look to enter somewhere 'around a middle'")
- exhaustion guard: NOT(setup bar's range > exhaustion_atr_mult * ATR(N))
  (Grimes: "Avoid buying and selling after potentially climactic moves, which can be identified
   on the chart as large range with trend bars that often extend far beyond the edge")
- entry trigger: BUY at break of high[1] + 1 tick (lower-timeframe breakout)
  (Grimes: "I've found a useful refinement is to use a lower timeframe breakout as an entry,
   and this can be as simple as buying a breakout of the previous bar's high")
```

## 5. Exit Rules

```text
- initial SL = entry - sl_atr_mult * ATR(N), where sl_atr_mult ∈ [2, 4]
  (Grimes: "they should go somewhere beyond the previous extreme. As a starting point,
   2-4 ATRs beyond the entry is a good, very rough guideline")
- TP1 = entry + initial_risk (i.e., 1R first scale-out)
  (Grimes: "take first profits when my profit is equal to my initial risk on the trade,
   and then to scale out of the remainder")
- partial_close_pct at TP1: 50% of position (Research default; Grimes does not specify the exact %)
- after TP1: trail remainder via QM_TM_TrailATR(period=N, mult=trail_atr_mult)
  (Grimes: "scale out of the remainder" — V5 default is ATR-trail to capture the swing)
- Friday Close enforced (default per V5 framework)
```

## 6. Filters (No-Trade module)

Trading-allowed conditions; strategy-specific in addition to framework defaults.

```text
- skip if exhaustion guard from § 4 fires
- skip if no clear with-trend bias on the higher timeframe
  (Grimes: "you are looking for a market that you believe will continue to trend";
  encoded mechanically as: HTF_close > HTF_SMA(htf_sma_len) for longs)
- skip during news blackout window (per QM_NewsFilter, framework default)
- skip if range-volatility floor not met: ATR(N) >= atr_floor
  (Grimes does not specify; Research default to avoid no-volatility regimes)
```

## 7. Trade Management Rules

```text
- on TP1 hit (+1R): close partial_close_pct of position, move SL to break-even via
  QM_TM_MoveToBreakEven(trigger_pips=1R-distance, buffer_pips=0)
- on remaining position: trail SL via QM_TM_TrailATR(period=N, mult=trail_atr_mult) until
  trailing stop hits OR Friday Close
- pyramiding: NOT allowed in V5 default build (Grimes describes pyramiding as an option,
  but V5 Hard Rule one_position_per_magic_symbol disallows stacking; pyramiding variant
  could be a separate card / future enhancement)
- gridding: NOT allowed (not in source; out of scope)
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: keltner_period
  default: 20
  sweep_range: [14, 20, 30, 50]
- name: keltner_atr_mult
  default: 2.5                                # calibrated so bands contain ~80-90% of price action; instrument-dependent
  sweep_range: [2.0, 2.5, 3.0, 3.5]
- name: atr_period_for_stops
  default: 14
  sweep_range: [10, 14, 20]
- name: sl_atr_mult
  default: 3.0                                # midpoint of Grimes's 2-4 ATR range
  sweep_range: [2.0, 2.5, 3.0, 3.5, 4.0]
- name: trail_atr_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5, 3.0]
- name: htf_sma_len
  default: 200
  sweep_range: [50, 100, 200]
- name: exhaustion_atr_mult
  default: 2.5                                # setup bar range relative to ATR(N) — skip if larger
  sweep_range: [2.0, 2.5, 3.0, 4.0]
- name: partial_close_pct
  default: 50
  sweep_range: [33, 50, 67]
```

## 9. Author Claims (verbatim, with quote marks)

Quote the source exactly. Performance numbers are sparse in this post; Grimes deliberately avoids quantified backtests. The claims that ARE made are recorded verbatim below.

```text
"Most of these recent pullbacks have been winners, and some gave way to outstanding trend moves,
but I also included a losing trade here as well." (post body, § "Some examples", 2014-11-05)

"This is, truly, one of the simplest and most powerful trading patterns, and is useful to traders
working on timeframes from intraday to months/quarters." (post body, § "Some examples")

"Though many of these patterns have a slight edge on their own, I think far better results come
with experience and when the trader learns to read the action in the market; we shift from a
'take every pullback' to a 'find the best pullback' mindset." (post body, intro)

"As a starting point, 2-4 ATRs beyond the entry is a good, very rough guideline." (post body,
§ "Stop location")

"I've found it helpful to take first profits when my profit is equal to my initial risk on the
trade, and then to scale out of the remainder." (post body, § "Trade management")
```

**No quantified performance claim is made in this post.** Grimes explicitly avoids quoting win rate, profit factor, or annualized returns. Reviewers should NOT treat the qualitative "most have been winners" as an author-claimed performance metric.

## 10. Initial Risk Profile

```yaml
expected_pf: TBD                              # Grimes does not state; baseline screening (P2) will produce empirical estimate
expected_dd_pct: TBD                          # not stated by source
expected_trade_frequency: TBD                 # not stated by source; depends on timeframe selected
risk_class: medium                            # operator's read — pullback entries have asymmetric R:R but require trend persistence
gridding: false
scalping: false                               # Grimes is a swing trader; intraday-2min mode could approach scalping if H1+ not selected
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

Before submitting card to CEO:

- [x] Strategy concept is mechanical (Grimes's qualitative cues — "strong trend", "exhaustion" — mapped to band-touch + range-vs-ATR mechanical conditions in § 4)
- [x] No Machine Learning required (V5 ban — `EA_ML_FORBIDDEN`)
- [x] If gridding: N/A — strategy uses single-position discipline
- [x] If scalping: P5b stress with realistic VPS latency calibration must be planned IF intraday timeframes are selected; D1+ swing mode does not require P5b scalping calibration
- [x] Friday Close compatibility: confirmed; Grimes is a swing trader and the trail-after-TP1 design naturally exits at the next adverse swing or at Friday close, whichever first
- [x] Source citation is precise enough to reproduce (post URL + publication date + section anchor + access date)
- [x] No near-duplicate of existing approved card (no prior cards exist; this is the first under V5)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "Exhaustion guard (setup-bar range vs ATR), HTF trend filter (close vs HTF_SMA), volatility floor (ATR vs atr_floor), framework defaults (kill-switch, news, friday close)."
  trade_entry:
    used: true
    notes: "Setup: prior bar closes at/beyond upper Keltner band (long) or lower (short). Pullback: current bar low/high crosses midline. Trigger: market order at break of prior bar's high (long) / low (short) + 1 tick."
  trade_management:
    used: true
    notes: "TP1 at +1R closes partial_close_pct; SL moves to break-even on TP1. Remaining position trailed via QM_TM_TrailATR. No pyramiding (V5 hard rule)."
  trade_close:
    used: false
    notes: "Strategy has no separate exit-signal logic; close is governed by trail/SL/TP1/friday-close only."
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                    # Grimes uses ES, EUR, GBP, EWG (no .DWX); CTO must re-map at sanity-check.
  - friday_close                             # swing positions can be open across Fri 21:00; design trails with Friday-Close as terminal exit, but this should be validated.
  - one_position_per_magic_symbol            # Grimes describes pyramiding as an option; V5 default build excludes it. Card explicitly opts out, but reviewers should confirm.
  - enhancement_doctrine                     # band period/mult and HTF SMA length are entry-side parameters that may shift post-PASS; flagged for awareness.
at_risk_explanation: |
  - dwx_suffix_discipline: Grimes's example symbols are conventional (ES, EUR, GBP, EWG, single-name stocks).
    For V5 deployment, CTO re-maps to nearest Darwinex .DWX instrument. Specifically: ES → US500.DWX,
    EUR → EURUSD.DWX, GBP → GBPUSD.DWX, EWG → GER40.DWX (rough proxy; CTO confirms). Single-name stocks
    (e.g., ROKU from adjacent Grimes post) are out of Darwinex scope and are excluded from this card's
    primary_target_symbols.
  - friday_close: The Grimes pullback is a multi-day-to-multi-week swing on D1+ timeframes. V5 forces
    flat at Friday 21:00 broker time. The strategy survives this constraint (a fresh setup re-fires
    the following Monday), but reviewers should confirm Monday gap handling does not invalidate the
    edge before P4 walk-forward.
  - one_position_per_magic_symbol: Grimes's "pyramid into trend" suggestion is explicitly excluded from
    the V5 build per the framework hard rule. A separate "grimes-pullback-pyramid" card may be drafted
    later if V5 ever adds a sanctioned pyramiding mode; for now, single-position only.
  - enhancement_doctrine: keltner_period, keltner_atr_mult, htf_sma_len are entry-side params with wide
    plausible ranges. Per V5 enhancement doctrine, post-PASS tuning of these params triggers a _v2
    rebuild. Flagged here so CTO + Pipeline-Operator know the param-stability profile up front.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD
  management: TBD
  close: TBD
estimated_complexity: TBD
estimated_test_runtime: TBD
data_requirements: TBD
```

## 14. Pipeline History (per `_v<n>` rebuild)

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | TBD | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v<n>`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-27 | DRAFT | this card |
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
- 2026-04-27: Card drafted from a public blog post. Author makes no quantified performance claims —
  Research must NOT fabricate any. Baseline expectation (PF, DD, freq) deferred to P2 empirical.
- 2026-04-27: First Grimes-blog card. Yield-rate observation (1 mechanical card from 4 posts surveyed)
  feeds into SRC01/source.md § 5 (expected_strategy_count revision after first 5 cards).
```
