# Strategy Card — Williams Consecutive Down Closes Pattern (2-3 down closes + range-shrinking + trend filter; multi-symbol Bonds + S&P)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC03/raw/probe_pp30-60.txt` (verbatim Bonds-context § "1. CONSECUTIVE DOWN CLOSES" PDF pp. 35-36, S&P-context § "3.) CONSECUTIVE DOWN CLOSES" PDF p. 40).
> Submitted for CEO + Quality-Business review per DL-032 + DL-030.

## Card Header

```yaml
strategy_id: SRC03_S14
ea_id: TBD
slug: williams-cdc-pattern
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - vol-expansion-breakout                    # canonical match — entry: stop-buy at "open + (today's H − today's C)" range-projection after the consecutive-down-close precondition; same range-projection family as S01 williams-vol-bo with a different setup precondition (multi-bar consecutive-down-closes). CEO ratified 2026-04-28 in QUA-298 closeout (comment cc655c56); back-port QUA-334.
  - n-period-min-reversion                    # complementary entry-class flag — short-bias N-bar minimum / consecutive-down-close setup precondition (the CDC pattern is the precondition; vol-expansion-breakout is the next-bar trigger mechanic)
  - trend-filter-ma                           # Williams: requires close > close 30 days ago (or bond-trend filter on S&P-context)
  - atr-hard-stop
  - long-only                                 # Williams: only describes long-side CDC entries; bear-side mirror is V5 ablation
  - friday-close-flatten
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF pp. 35-36 (Bonds-context § '1. CONSECUTIVE DOWN CLOSES', sub-rules A-B with 30-day-trend filter and Gold filter); PDF p. 40 (S&P-context § '3.) CONSECUTIVE DOWN CLOSES', sub-rules A-C with bond-trend filter)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/probe_pp30-60.txt` lines 322-332 (Bonds CDC sub-rules A-B), lines 567-578 (S&P CDC sub-rules A-C).

## 2. Concept

A **mean-reversion entry after consecutive down closes** in an established uptrend, with range-shrinking confirmation. Williams' multi-condition setup:

1. **2 or 3 consecutive down closes** (close[t-1] < close[t-2] etc.)
2. **Range-shrinking confirmation**: today's high-minus-close (H-C) is LESS than yesterday's H-C — suggests selling pressure exhausting
3. **Trend filter**: today's close > close 30 days ago (Bonds-context) OR Bonds_Close > 2-or-20 days ago (S&P-context)
4. **Optional Gold filter** (Bonds-context): "even better if gold closes lower than the previous day"
5. **Entry**: stop-buy at next-day open + today's (H − C) — projected range-completion

Williams' verbatim Bonds-context framing, PDF pp. 35-36:

> "1. CONSECUTIVE DOWN CLOSES
>
> A. When there are two consecutive down closes AND the distance from today's true high to today's close is less than that same value from yesterday THEN buy tomorrow at the open p[lus] that value, today's high - today'sl[ow] IF today's close is greater than the close 30 days ago. (this is even better if gold closes lower than the previous day)
>
> B. When there are three consecutive days with lower closes than the prior day AND the distance from today's high to today's close is less than that same value from the prior day, THEN buy tomorrow at the open plus today's high- today's close."

S&P-context framing, PDF p. 40:

> "3.) CONSECUTIVE DOWN CLOSES
>
> A. This calls for 2 consecutive down closes with today's h-c less than that value from yesterday, today is Wednesday or Thursday[,] bonds greater than 2 or 20 days ago, THEN buy tomorrow at the open Plus today's h-c value.
>
> B. Exactly as above but there have been three consecutive down closes.
>
> C. If today is Thursday and today's close is less than the prior day and that day is also down close (close to close) while today's high is greater or = the prior close (no gaps[)] and today's high and low are lower than yesterdays high and low THEN buy tomorr[ow at] today's high on a stop."

## 3. Markets & Timeframes

```yaml
markets:
  - bond_futures                              # Williams' Bonds-context PDF pp. 35-36
  - index_futures                             # Williams' S&P-context PDF p. 40 → US500.DWX
timeframes:
  - D1
session_window: cash_session
primary_target_symbols:
  - "T-Bonds (Williams) → bond CFD if available; flag dwx_suffix_discipline"
  - "S&P 500 (Williams) → US500.DWX V5 proxy"
```

## 4. Entry Rules

```text
PARAMETERS:
- N_DOWN_CLOSES     = 2                        // Williams: sub-rule A=2, sub-rule B=3
- USE_TRUE_HIGH     = true                     // Williams: "true high to today's close" (Bonds-context)
- TREND_FILTER      = close_above_30d          // Bonds-context default; S&P uses bonds_above_2d_or_20d
- GOLD_FILTER       = off                      // Bonds-context optional ("even better")
- WEEKDAY_FILTER    = off                      // S&P-context restricts to Wed/Thu (sub-rule A); ablation axis
- ENTRY_METHOD      = open_plus_h_minus_c      // Williams: "buy tomorrow at the open plus today's high - today's close"

EACH-BAR (next-day open trigger, evaluated at prior-day close):
- consecutive_down_closes(N) at bar t-1:
    Close[b] < Close[b-1] for b in [t-N, t-1]   // N-1 chain of strict down closes
- range_shrinking at bar t-1:
    h_c = (USE_TRUE_HIGH ? TrueHigh(t-1) : High[t-1]) - Close[t-1]
    h_c_prior = (USE_TRUE_HIGH ? TrueHigh(t-2) : High[t-2]) - Close[t-2]
    h_c < h_c_prior
- trend_ok at bar t-1:
    Close[t-1] > Close[t-1 - 30]              // Bonds-context default
    OR (S&P-context) Bonds_Close[t-1] > Bonds_Close[t-1 - 2 OR t-1 - 20]
- (optional) gold_ok at bar t-1:
    Gold_Close[t-1] < Gold_Close[t-2]
- (optional) weekday_ok:
    DayOfWeek(t) in {WED, THU}                  // S&P-context sub-rule A

ENTRY (only when not in position):
- if all gating conditions hold:
    stop_trigger = Open[t] + (High[t-1] - Close[t-1])
    stage stop-buy at stop_trigger
    if intra-day High[t] >= stop_trigger: FILL_LONG at stop_trigger
- single-attempt-per-day
```

Sub-rule C variant (S&P-context, PDF p. 40) — entry at THIS bar's high on a stop, instead of open+H-C:

```text
sub-rule C (S&P-context Thursday-specific):
  WEEKDAY[t-1] == THU
  Close[t-1] < Close[t-2] AND Close[t-2] < Close[t-3]   // 2-day down-close chain
  High[t-1] >= Close[t-2] AND no_gaps                    // no gap-down condition
  High[t-1] < High[t-2] AND Low[t-1] < Low[t-2]          // inside-down-shape
  → BUY at High[t-1] on a stop
```

Sub-rule C is mechanically distinct enough that it could fold into S15 Gap-Down-Close family, but Williams positions it under CDC; sweep-axis includes sub-rule C as alternative entry method.

## 5. Exit Rules

Williams' standard short-term exit:

```text
DEFAULT EXIT:
- HARD_STOP_USD     = 1500
- BAIL_OUT_ON_PROFIT_OPEN = true
- TIME_STOP         = 5 bars (backstop)

EACH-BAR (in position):
- HARD STOP — fires at HARD_STOP_USD-equivalent ATR distance from entry
- BAIL_OUT_ON_PROFIT_OPEN: if Open[t+1] > entry_price: CLOSE_LONG at Open[t+1]
- TIME_STOP backstop

FRIDAY CLOSE: V5 default; 1-3 day typical hold.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults
- N_DOWN_CLOSES gate per § 4
- range_shrinking gate (h_c < h_c_prior)
- TREND_FILTER (close vs 30d ago for Bonds; bonds_close vs 2-or-20d ago for S&P)
- WEEKDAY_FILTER (S&P-context sub-rule A: Wed/Thu only) — ablation axis
- GOLD_FILTER (Bonds-context optional)
- pyramiding/gridding: NOT allowed
```

## 7. Trade Management Rules

```text
- one open position per direction at any time
- single-attempt-per-day
- position size: V5 risk-mode framework
- Friday Close: V5 default
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: n_down_closes
  default: 2                                  # sub-rule A
  sweep_range: [2, 3, 4]                      # 3 = sub-rule B; 4 = stricter ablation
- name: use_true_high
  default: true                               # Williams Bonds-context
  sweep_range: [true, false]
- name: trend_filter
  default: close_above_30d                    # Bonds-context default
  sweep_range: [off, close_above_15d, close_above_30d, close_above_60d, bonds_above_2d_or_20d]
- name: gold_filter
  default: off
  sweep_range: [off, gold_below_1d, gold_below_5d]
- name: weekday_filter
  default: off
  sweep_range: [off, wed_thu_only, mon_thu_fri_only]
- name: entry_method
  default: open_plus_h_minus_c
  sweep_range: [open_plus_h_minus_c, this_bar_high_stop]   # this_bar_high_stop = sub-rule C variant
- name: hard_stop_atr_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5, 3.0]
```

P3.5 (CSR) axis: re-run on Darwinex symbol cohort. The 30-day-trend + range-shrinking pattern is structurally generic; expected positive transfer to most major instruments.

## 9. Author Claims (verbatim, with quote marks)

Bonds CDC sub-rule A, PDF p. 35:

> "A. When there are two consecutive down closes AND the distance from today's true high to today's close is less than that same value from yesterday THEN buy tomorrow at the open p[lus] that value, today's high - today'sl[ow] IF today's close is greater than the close 30 days ago. (this is even better if gold closes lower than the previous day)"

Bonds CDC sub-rule B, PDF p. 35:

> "B. When there are three consecutive days with lower closes than the prior day AND the distance from today's high to today's close is less than that same value from the prior day, THEN buy tomorrow at the open plus today's high- today's close."

S&P CDC sub-rule A, PDF p. 40:

> "A. This calls for 2 consecutive down closes with today's h-c less than that value from yesterday, today is Wednesday or Thursday[,] bonds greater than 2 or 20 days ago, THEN buy tomorrow at the open Plus today's h-c value."

**Williams provides NO numeric performance claim for CDC specifically.** The Bonds-context Specific-Patterns wrap-up at PDF p. 37 reports an aggregate Bonds backtest ($72,550 / 87% accuracy / 1990-1999) covering ALL Bonds rules combined (CDC + Gap-Down + Friday-Set-Up + Hidden OOPS!) — NOT per-strategy attributable. Per BASIS rule, no extrapolated CDC-specific number asserted.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3
expected_dd_pct: 12
expected_trade_frequency: 15-30/year/symbol   # 2-down-close events with range-shrinking + trend filter
risk_class: low
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Mechanical
- [x] No ML
- [x] Not gridding / not scalping
- [x] Friday Close compatibility
- [x] Source citation precise (PDF pp. 35-36 + p. 40)
- [x] No near-duplicate

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "N-down-closes + range-shrinking + trend filter + optional Gold/weekday filters + standard V5"
  trade_entry:
    used: true
    notes: "stop-buy at open + (H − C); single-attempt-per-day"
  trade_management:
    used: false
  trade_close:
    used: true
    notes: "bail-out + ATR hard stop + 5-bar backstop"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # Bonds + S&P contexts; CSR P3.5 validates breadth
  - friday_close                              # NOT load-bearing
  - news_pause_default                        # standard V5 P8
  - one_position_per_magic_symbol             # NOT load-bearing
  - enhancement_doctrine                      # load-bearing on N_DOWN_CLOSES (2 vs 3) and TREND_FILTER selection

at_risk_explanation: |
  enhancement_doctrine — Williams' sub-rule A (N=2) and sub-rule B (N=3) are alternative
  parameter values for the same mechanical entry. Default = sub-rule A (N=2); P3 sweeps both.
  Once deployment-live N fixed, retune = enhancement_doctrine.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD                                  # multi-condition setup + stop-buy at open + range; ~100-140 LOC
  management: TBD
  close: TBD
estimated_complexity: medium                  # multi-condition setup with sub-rule dispatcher
estimated_test_runtime: 1-3h
data_requirements: standard                   # Gold-filter variant requires GOLD.DWX
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-28 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-28 | DRAFT | this card |

## 16. Lessons Captured

```text
- 2026-04-28: SRC03_S14 fits the EXISTING `n-period-min-reversion` flag — short-bias entry on
  consecutive-down-close pattern. The range-shrinking + trend-filter overlay distinguishes it
  from generic N-bar-min entries. Reuses S01's `vol-expansion-breakout` family flag for the
  entry-method (open + H-C range projection). No new gap surfaced.

- 2026-04-28: Williams provides NO numeric performance claim for CDC alone. The Bonds aggregate
  backtest (PDF p. 37: $72,550 / 87% accuracy / 1990-1999) covers ALL Bonds-rule cards combined
  (CDC + Gap-Down + Friday-Set-Up + Hidden OOPS!). Per BASIS rule, NOT asserted as per-strategy
  number.

- 2026-04-28: Sub-rule C (S&P-context Thursday-specific) is mechanically a hybrid of CDC +
  inside-bar shape; folded into S14 as an entry-method ablation rather than separate card —
  Williams positions it under CDC heading. P3 sweep `entry_method` axis tests sub-rule C as
  alternative.

- 2026-04-28: Cards-vs-fold decision (S14 vs S15 Gap-Down): DISTINCT despite shared entry-
  method (open + H-C). Different setup conditions: S14 = 2-3 consecutive down closes; S15 =
  full gap-down (today's high < yesterday's low). Per DL-033 Rule 1.
```
