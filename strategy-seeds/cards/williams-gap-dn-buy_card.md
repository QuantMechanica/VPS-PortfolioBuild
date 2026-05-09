# Strategy Card — Williams Gap-Down-Close Buy Pattern (today's high < yesterday's low + Gold filter; Bonds)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC03/raw/probe_pp30-60.txt` (verbatim Williams Bonds-context § "2. GAP DOWN CLOSES", PDF p. 36).
> Submitted for CEO + Quality-Business review per DL-032 + DL-030.

## Card Header

```yaml
strategy_id: SRC03_S15
ea_id: TBD
slug: williams-gap-dn-buy
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - vol-expansion-breakout                    # canonical match — entry: stop-buy at "open + (H − C)" range-projection after the gap-down-close setup precondition (today H < yesterday L); same range-projection family as S01 williams-vol-bo with a different setup precondition (single-bar gap-down vs none). CEO ratified 2026-04-28 in QUA-298 closeout (comment cc655c56); back-port QUA-334.
  - n-period-min-reversion                    # complementary entry-class flag — gap-down + open-rebound setup precondition; mean-reversion class
  - trend-filter-ma                            # Bonds-context sub-rule B requires Gold-trend filter
  - atr-hard-stop
  - long-only                                 # Williams: only describes long-side gap-down-buy; short-side mirror is V5 ablation
  - friday-close-flatten
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF p. 36 (Inner Circle Workshop companion volume), § 'TREASURY BOND TRADING RULES — 2. GAP DOWN CLOSES' (sub-rules A-B). Distinct from S14 Consecutive Down Closes (different setup condition: gap-down vs N-down-close-chain)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/probe_pp30-60.txt` lines 335-344 (Gap-Down sub-rules A-B verbatim).

## 2. Concept

A **gap-down + intraday-recovery long entry** — a structural cousin of S02 Monday OOPS! (gap-fade) but with different setup conditions and different reference price calculation. Williams' setup:

1. **Today's high < yesterday's low** — full gap-down (entire today's bar trades below yesterday's range)
2. **Tomorrow's open** is above today's low BUT below yesterday's low — i.e., next-day open is INSIDE today's range but still gap-down vs prior day
3. **Entry**: stop-buy at next-day open + min(today's H − today's C, today's open − today's low)

Williams' verbatim framing, PDF p. 36:

> "2. GAP DOWN CLOSES
>
> A. If today's high is less, [or] below, yesterdays low (a gap down) and the open tomorrow is above today's low but less than yesterdays low THEN buy tomorrow at the open plus whichever amount is less; today's high minus today's close or today's open minus today's low.
>
> B. If today's high is less than yesterdays low and Gold has closed lower than the close of Gold 15 or 24 days ago THEN buy tomorrow at the open plus today's high minus today's close."

Sub-rule A is the canonical Williams gap-down-recovery; sub-rule B is the Gold-filtered simpler variant (no constraint on tomorrow's open position). Per DL-033 Rule 1, distinct from S02 (S02 uses prior-bar's TRUE LOW as reference; S15 uses next-day open + range-projection).

## 3. Markets & Timeframes

```yaml
markets:
  - bond_futures                              # Williams' explicit Bonds-context PDF p. 36
  # No S&P-context analog; potentially generalizable to indices via CSR P3.5 — Williams does NOT publish S&P version
timeframes:
  - D1
session_window: cash_session
primary_target_symbols:
  - "T-Bonds (Williams' explicit deployment) → bond CFD if available; flag dwx_suffix_discipline"
  - "Generalization: any liquid-D1 instrument; CSR P3.5 multi-symbol"
```

## 4. Entry Rules

```text
PARAMETERS:
- USE_TRUE_EXTREMES = false                   // Williams: "today's high"/"yesterdays low" — plain
- ENTRY_METHOD      = open_plus_min_range     // sub-rule A: open + min(H-C, open-L)
- GOLD_FILTER       = off                     // sub-rule B uses Gold filter; sweep-axis variant

EACH-BAR (next-day open trigger, evaluated at prior-day close):
- gap_down_setup at bar t-1:
    High[t-1] < Low[t-2]                      // today's high BELOW yesterday's low — full gap-down
- next_open_in_range (sub-rule A): at start of bar t:
    Open[t] > Low[t-1]                        // next-day open above today's low
    AND Open[t] < Low[t-2]                    // but still below yesterday's low — gap-down persists
- gold_ok at bar t-1:
    Gold_Close[t-1] < Gold_Close[t-1 - 15]    // sub-rule B: Gold lower than 15d ago
    OR Gold_Close[t-1] < Gold_Close[t-1 - 24] // OR 24d ago

ENTRY (only when not in position):
- sub-rule A:
    if gap_down_setup AND next_open_in_range:
      h_c = High[t-1] - Close[t-1]
      o_l = Open[t-1] - Low[t-1]
      stop_trigger = Open[t] + min(h_c, o_l)
      stage stop-buy at stop_trigger
      if intra-day High[t] >= stop_trigger: FILL_LONG at stop_trigger
- sub-rule B (Gold-filtered simpler variant):
    if gap_down_setup AND gold_ok:
      stop_trigger = Open[t] + (High[t-1] - Close[t-1])
      stage stop-buy at stop_trigger
      if intra-day High[t] >= stop_trigger: FILL_LONG at stop_trigger
- single-attempt-per-day
```

## 5. Exit Rules

```text
DEFAULT EXIT:
- HARD_STOP_USD     = 1500
- BAIL_OUT_ON_PROFIT_OPEN = true
- TIME_STOP         = 5 bars (backstop)

FRIDAY CLOSE: V5 default; 1-3 day typical hold.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults
- gap_down_setup gate per § 4
- next_open_in_range constraint (sub-rule A)
- GOLD_FILTER (sub-rule B optional)
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
- name: sub_rule
  default: A_canonical                        # sub-rule A
  sweep_range: [A_canonical, B_gold_filtered, A_or_B]
- name: gold_filter
  default: off
  sweep_range: [off, gold_below_15d, gold_below_24d, gold_below_15d_or_24d]
- name: entry_method
  default: open_plus_min_h_c_o_l              # sub-rule A
  sweep_range: [open_plus_min_h_c_o_l, open_plus_h_minus_c_only]
- name: hard_stop_atr_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5, 3.0]
- name: time_stop_bars
  default: 5
  sweep_range: [3, 5, 7, 10]
```

P3.5 (CSR) axis: Williams only documents Bonds-context for Gap-Down. CSR P3.5 critical to validate whether the gap-down-recovery thesis transfers to indices / FX (FX has near-zero weekend gap so transfer expected weak; indices share Bonds-like overnight-gap dynamics so transfer expected positive).

## 9. Author Claims (verbatim, with quote marks)

Bonds Gap-Down sub-rules A-B, PDF p. 36:

> "2. GAP DOWN CLOSES
>
> A. If today's high is less, [or] below, yesterdays low (a gap down) and the open tomorrow is above today's low but less than yesterdays low THEN buy tomorrow at the open plus whichever amount is less; today's high minus today's close or today's open minus today's low.
>
> B. If today's high is less than yesterdays low and Gold has closed lower than the close of Gold 15 or 24 days ago THEN buy tomorrow at the open plus today's high minus today's close."

**Williams provides NO Gap-Down-specific performance claim.** The Bonds aggregate backtest (PDF p. 37: $72,550 / 87% accuracy / 1990-1999) covers all Bonds rules combined; not per-strategy. Per BASIS rule, NOT asserted as Gap-Down-specific number.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.2
expected_dd_pct: 14
expected_trade_frequency: 5-12/year/symbol    # full-gap-down setups are relatively rare
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
- [x] Source citation precise (PDF p. 36 verbatim)
- [x] No near-duplicate (S02 / S03 / S14 mechanically distinct per § 2)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "gap-down setup + sub-rule conditions + standard V5"
  trade_entry:
    used: true
    notes: "stop-buy at next-day open + range-projection; single-attempt-per-day"
  trade_management:
    used: false
  trade_close:
    used: true
    notes: "bail-out + ATR hard stop + 5-bar backstop"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # Bonds-context only; CSR P3.5 validates cross-symbol transfer
  - friday_close                              # NOT load-bearing
  - news_pause_default                        # gap-downs frequently event-driven (overnight news); P8 ablation question
  - one_position_per_magic_symbol             # NOT load-bearing
  - kill_switch_coverage                      # gap-down recovery can fail (event-driven sustained downtrend); P5c crisis-slice load-bearing

at_risk_explanation: |
  news_pause_default — Gap-down setups frequently coincide with event-driven overnight news.
  P8 ablation: does the pattern survive when news-event days are excluded? If pattern collapses
  post-news-removal, the edge is news-driven not flow-driven.

  kill_switch_coverage — gap-down-recovery thesis fails on sustained event-driven down-trends
  (Lehman 2008-09, COVID 2020-03). P5c crisis-slice load-bearing. Hard-stop covers single-trade
  case; account-level kill-switch covers sequential adverse fades.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD                                  # gap-down detection + sub-rule dispatcher; ~80-120 LOC
  management: TBD
  close: TBD
estimated_complexity: small
estimated_test_runtime: 1-2h
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
- 2026-04-28: SRC03_S15 fits EXISTING `n-period-min-reversion` flag (gap-down + open-rebound).
  Reuses S01-family `vol-expansion-breakout` for the entry-method (open + range-projection).
  No new vocab gap.

- 2026-04-28: Williams provides NO Gap-Down-specific performance claim. Per BASIS rule, no
  number asserted. Bonds aggregate backtest covers all rules; not per-strategy attributable.

- 2026-04-28: Cards-vs-fold decision (S15 vs S14 CDC): DISTINCT despite shared entry-method.
  S14 = 2-3 consecutive down closes (multi-bar setup); S15 = single full-gap-down (single-bar
  setup with cross-bar gap condition). Different setup conditions = different mechanical
  triggers. Per DL-033 Rule 1.

- 2026-04-28: Cards-vs-fold decision (S15 vs S02 Monday-OOPS! / S03 Hidden OOPS!): DISTINCT.
  S02/S03 are CALENDAR-DAY-conditional (Monday gap from Friday); S15 is CALENDAR-AGNOSTIC
  (any-day gap-down). Different setup conditions; different reference prices for stop entry
  (S02 = prior-day TRUE LOW; S03 = projected H/L formula; S15 = open + range-projection).

- 2026-04-28: Williams documents Gap-Down ONLY for Bonds; no S&P-context analog. CSR P3.5
  multi-symbol generalization is the load-bearing G0/P3 question.

- 2026-04-28: P5c crisis-slice load-bearing (Lehman 2008-09, COVID 2020-03) — gap-down-recovery
  thesis fails catastrophically on sustained event-driven trends. Account-level kill-switch
  must absorb sequential adverse fades.
```
