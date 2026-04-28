# Strategy Card — Williams 8-Week Box Congestion Breakout (go-with-breakout in direction of pre-box trend; multi-market)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` (verbatim Williams § "CONGESTION BREAKOUT TRADING — MY 8 WEEK BOX APPROACH", PDF pp. 23-25).
> Submitted for CEO + Quality-Business review per DL-032 + DL-030.

## Card Header

```yaml
strategy_id: SRC03_S11
ea_id: TBD
slug: williams-8wk-box
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - narrow-range-breakout                     # canonical match — entry on breakout of a range-contraction precondition (8-week sideways consolidation). Williams' rule GOES WITH the breakout (not fade like S10 Specialist Trap)
  - trend-filter-ma                           # Williams: requires identifying "what the major trend move was coming into that 8-week box"
  - atr-trailing-stop                         # Williams' "Keep Swinging" framing implies trailing/re-entry approach; ATR-trail is V5 best fit
  - symmetric-long-short                      # Williams: "you must trade these congestions with 1) no predetermined belief 2) the conviction and bankroll to take all breakouts until the big one"
  - friday-close-flatten                      # V5 default for Williams' typical hold
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF pp. 23-25 (Inner Circle Workshop companion volume), § 'CONGESTION BREAKOUT TRADING — MY 8 WEEK BOX APPROACH'. Distinct from S10 Specialist Trap (which fades short-box-then-breakout); 8-Week Box GOES WITH the breakout in direction of pre-box trend."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` lines 356-405 (8-Week Box verbatim including "Keep Swinging" multi-attempt framing).

## 2. Concept

A **long-consolidation breakout entry** in the direction of the pre-box trend. Williams' multi-step thesis:

1. Scan for any market in a SIDEWAYS move for **at least 8 weeks** (no new rally-high or rally-low for 8+ weeks)
2. Identify the major trend coming INTO the 8-week box (up or down)
3. Mark the box's trend lines (or upper/lower bounds)
4. **Wager**: price will smash out of these trend lines in the SAME direction as the pre-box trend
5. **Multi-attempt rule** ("Keep Swinging"): if first breakout fails, take the OPPOSITE breakout signal too — ~1/3 of initial signals will be wrong, but persistence catches the eventual real breakout

Williams' verbatim framing, PDF p. 24:

> "About one third of the time a market will trend, the other two thirds it's in congestion zones, backing and filling almost with a mind of its' own to find stops, punish or frazzle traders endurance. Then, low and behold, one day it rips out of the congestion zone leaving most traders on the sidelines nursing their wounds, cursing their 'luck'.
>
> SPRINGING THE CONGESTION TRAP IN YOUR FAVOR ... Instead of getting caught in these traps let's turn them to our advantage! The way to do it is to scan through your charts looking for any market that has been in a sideways move for at least 8 weeks. A further 'definition' that may help is that it has been at least 8 weeks since a new rally high or low has been seen.
>
> Isolate the 8 weeks and identify what the major trend move was coming into that 8-week box and expect a break out in the same direction. ... Our wager is price will smash out of these trend lines."

The "Keep Swinging" multi-attempt rule, PDF p. 24:

> "AND HERE'S THE SECRET ... KEEP SWINGING ...
>
> Which means you need to keep a new 8-week box and take opposite breakout signals until one of them is the big one.
>
> Clearly this means you may be whipped around a little, my guess is 1/3 of these initial signals will be wrong and you will be stuck in the mud with other traders. BUT, you got in later [and] you know one of these days it will break out and more importantly — YOU DON'T CARE WHICH WAY IT ULTIMATELY BREAKS OUT — in fact you must trade these congestions with 1) no predetermined belief 2) the conviction and bankroll to take all breakouts until the big one bites your bait, knowing you may loose a few lures first. That is your cost of doing business."

This card extracts the **base 8-week-box entry** with multi-attempt logic as a sweep axis. The "go-with-breakout-in-direction-of-pre-box-trend" is the default entry; "Keep Swinging" enables symmetric breakout-in-either-direction with persistence after failed attempts.

## 3. Markets & Timeframes

```yaml
markets:
  - all_major                                 # Williams: "scan through your charts looking for any market"; multi-market generic
timeframes:
  - D1                                        # Williams: "8 weeks" of daily bars; 8 × 5 = 40 trading days minimum sideways
  - W1                                        # weekly-bar variant (8 weeks = 8 weekly bars; W1 framing is more direct)
session_window: not specified
primary_target_symbols:
  - "all major Darwinex .DWX index/metal/FX/energy symbols (Williams: pattern is generic across markets)"
```

## 4. Entry Rules

```text
PARAMETERS:
- BOX_MIN_DAYS       = 40         // 8 weeks × 5 trading days; Williams: "at least 8 weeks"
- TREND_LOOKBACK     = 100        // pre-box trend identification; Williams qualitative — operationalize with SMA(N) slope
- BOX_RANGE_PCT_ATR  = 2.0        // Williams qualitative "sideways move"; default = box range ≤ 2.0 × ATR(14) at start of box (more permissive than S10's 1.5 since 8 weeks is a longer window)
- USE_TRUE_EXTREMES  = false      // Williams says "trend lines" / "rally high or low" — plain extremes
- ENTRY_OFFSET_TICKS = 0          // entry at box's high/low extreme; 0-tick offset
- KEEP_SWINGING      = true       // Williams' multi-attempt rule

EACH-BAR (next-day open trigger, evaluated at prior-day close):
- Step 1 (8-week box detection at bar t-1):
    box_window_start = bar t-1 - BOX_MIN_DAYS
    box_high = max(High over [box_window_start, t-1])
    box_low  = min(Low over [box_window_start, t-1])
    box_range = box_high - box_low
    box_atr_at_start = ATR(14) at box_window_start
    if box_range > BOX_RANGE_PCT_ATR * box_atr_at_start:
      // box too wide → not a sideways congestion; NO_TRIGGER
      continue
    // Optional: confirm "no new rally high or low has been seen" — equivalent to box_high being the
    //           HIGHEST since 8 weeks ago and box_low the LOWEST since 8 weeks ago
    BOX_FOUND = true

- Step 2 (pre-box trend identification):
    pre_box_close = Close[box_window_start - 1]
    pre_box_sma = SMA(TREND_LOOKBACK) at box_window_start
    if pre_box_close > pre_box_sma + threshold:
      pre_box_trend = UP
    elif pre_box_close < pre_box_sma - threshold:
      pre_box_trend = DOWN
    else:
      pre_box_trend = NONE   // no clear pre-box trend; KEEP_SWINGING-only mode

- Step 3 (breakout entry):
    if BOX_FOUND and pre_box_trend == UP:
      stage stop-buy at box_high + ENTRY_OFFSET_TICKS
      if intra-day High[t] >= box_high: FILL_LONG at box_high
    if BOX_FOUND and pre_box_trend == DOWN:
      stage stop-sell at box_low - ENTRY_OFFSET_TICKS
      if intra-day Low[t] <= box_low: FILL_SHORT at box_low

- Step 4 (KEEP_SWINGING after failed breakout):
    if previous breakout was stopped out:
      stage opposite-direction breakout entry at the OPPOSITE box extreme
      track new 8-week box if pre-existing box has been violated
```

## 5. Exit Rules

```text
DEFAULT EXIT (Williams-style trailing for go-with-breakout):
- HARD_STOP_USD     = 1500       // V5 → ATR-equivalent
- TRAIL_BARS        = 3          // Williams' "Amazing 3 Bar" trailing stop
- TRAIL_NO_INSIDE   = true
- ALT_TRAIL         = atr_trailing_stop ATR(14) × 3.0   // P3 axis

EACH-BAR (in position):
- HARD STOP — fires at HARD_STOP_USD-equivalent ATR distance from entry
- TRAIL — 3-bar non-inside-day trail (default) or ATR-trail (alt)
- KEEP_SWINGING re-entry on stop-out: if stop-out was on opposite-side breakdown, stage opposite breakout

FRIDAY CLOSE: V5 default applies; long-trend hold may span weekends — waiver candidate per
breakout-multi-week thesis. P3 sweep includes friday_close=disabled variant.
```

## 6. Filters (No-Trade module)

```text
- BOX_FOUND gating per § 4 Step 1
- PRE_BOX_TREND classification per Step 2
- "no new rally high or low" sub-condition (per Williams "definition") — sweep axis
- pyramiding: NOT allowed
- gridding: NOT allowed (KEEP_SWINGING is RE-ENTRY after stop-out, not stacking)
```

## 7. Trade Management Rules

```text
- one open position per direction at any time
- KEEP_SWINGING multi-attempt: re-enter opposite direction after stop-out, ONE attempt per failed breakout, with NEW 8-week box detection
- position size: V5 risk-mode framework
- Friday Close: forced flat per V5 default; multi-week-trend hold may need waiver
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: box_min_days
  default: 40                                 # 8 weeks × 5 trading days
  sweep_range: [20, 30, 40, 60, 80]           # 4w / 6w / 8w / 12w / 16w
- name: box_range_pct_atr
  default: 2.0
  sweep_range: [1.0, 1.5, 2.0, 3.0, 4.0]
- name: trend_lookback
  default: 100
  sweep_range: [50, 100, 200]
- name: pre_box_trend_required
  default: true                               # default = require clear pre-box trend
  sweep_range: [true, false]                  # false = take any breakout regardless of pre-box trend
- name: keep_swinging
  default: true
  sweep_range: [true, false]
- name: keep_swinging_max_attempts
  default: 3                                  # max re-entries per failed-breakout cycle
  sweep_range: [1, 2, 3, 5]
- name: hard_stop_atr_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5, 3.0]
- name: alt_exit
  default: trail_3bar
  sweep_range: [trail_3bar, atr_trail_3, atr_trail_5, donchian_trail_20]
- name: friday_close_disable
  default: false                              # default V5 friday-close
  sweep_range: [false, true]
```

P3.5 (CSR) axis: 8-Week Box is multi-market generic; CSR validates breadth across all major Darwinex .DWX symbols. Pattern density at D1 is moderate (≈ 3-8 box-formations/year/symbol with 8-week minimum) — relatively rare setups.

## 9. Author Claims (verbatim, with quote marks)

8-Week Box base rule, PDF p. 24:

> "The way to do it is to scan through your charts looking for any market that has been in a sideways move for at least 8 weeks. A further 'definition' that may help is that it has been at least 8 weeks since a new rally high or low has been seen.
>
> Isolate the 8 weeks and identify what the major trend move was coming into that 8-week box and expect a break out in the same direction."

Keep Swinging multi-attempt, PDF p. 24:

> "AND HERE'S THE SECRET ... KEEP SWINGING ... Which means you need to keep a new 8-week box and take opposite breakout signals until one of them is the big one."

Multi-attempt failure rate, PDF p. 24:

> "Clearly this means you may be whipped around a little, my guess is 1/3 of these initial signals will be wrong and you will be stuck in the mud with other traders."

**Williams provides NO numeric performance claim for 8-Week Box specifically.** Per BASIS rule, no extrapolated number asserted. The 1/3-failure-rate guess is presented as informal estimate, not a tested backtest result.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                              # rough estimate; multi-attempt thesis with trend filter
expected_dd_pct: 20                           # KEEP_SWINGING multi-attempt → potential drawdown across failed breakouts
expected_trade_frequency: 5-15/year/symbol    # rare 8-week setups; multi-attempt expands frequency on failures
risk_class: medium                            # multi-attempt breakout has wider DD profile than single-attempt
gridding: false                               # KEEP_SWINGING is re-entry not stacking
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Mechanical (box-detection scan + breakout-extreme stop-buy/sell + KEEP_SWINGING multi-attempt)
- [x] No ML
- [x] Not gridding (KEEP_SWINGING is re-entry after stop-out, NOT stacking into adverse moves)
- [x] Not scalping
- [x] Friday Close compatibility: long-trend hold may need waiver; sweep-axis variant
- [x] Source citation precise (PDF pp. 23-25 verbatim)
- [x] No near-duplicate

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "BOX_FOUND + pre-box-trend gate + standard V5 default"
  trade_entry:
    used: true
    notes: "stop-buy/sell at box extreme; KEEP_SWINGING re-entry on opposite-direction stop-out"
  trade_management:
    used: false
    notes: "no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "3-bar trail (default) or ATR-trail or Donchian-trail per P3; ATR hard stop"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # generic multi-market; CSR P3.5 validates
  - friday_close                              # potentially load-bearing — multi-week-trend hold; sweep-axis disable variant
  - news_pause_default                        # standard V5 P8
  - one_position_per_magic_symbol             # NOT load-bearing — KEEP_SWINGING is sequential re-entry, one position at a time
  - kill_switch_coverage                      # KEEP_SWINGING multi-attempt amplifies adverse-streak DD; account-level kill-switch must absorb sequential losing breakouts
  - enhancement_doctrine                      # load-bearing on box parameters (BOX_MIN_DAYS, BOX_RANGE_PCT_ATR) — Williams qualitative framing

at_risk_explanation: |
  friday_close — multi-week trends post-breakout may force position holds across multiple
  weekends. Sweep-axis variant tests friday_close=disabled with explicit waiver-cost analysis.

  kill_switch_coverage — KEEP_SWINGING multi-attempt thesis ACCEPTS losing trades during the
  congestion-trap period (Williams: "you may loose a few lures first. That is your cost of
  doing business"). Account-level kill-switch must absorb a maximum-streak of failed breakouts
  before the real breakout fires. P5 stress + P5c crisis-slice load-bearing.

  enhancement_doctrine — BOX_MIN_DAYS, BOX_RANGE_PCT_ATR, TREND_LOOKBACK are Research-
  operationalized defaults of Williams' qualitative framing. Once live values fixed, retune =
  enhancement_doctrine.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # box-detection scan; ~80-120 LOC
  entry: TBD                                  # stop-buy/sell at box extreme + KEEP_SWINGING state machine; ~100-150 LOC
  management: TBD
  close: TBD                                  # trail variants
estimated_complexity: medium                  # multi-attempt state machine + box-detection
estimated_test_runtime: 4-8h                  # P3 sweep cell count moderate-large; KEEP_SWINGING ablation requires multi-attempt simulation
data_requirements: standard
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-28 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-28 | DRAFT | this card |

(remaining phases TBD per V5 pipeline standard)

## 16. Lessons Captured

```text
- 2026-04-28: SRC03_S11 fits the EXISTING `narrow-range-breakout` flag — entry on breakout of
  range-contraction precondition. Williams' rule is GO-WITH-BREAKOUT (in direction of pre-box
  trend), distinct from S10 Specialist Trap which is FADE-the-breakout. No new vocab gap surfaced.

- 2026-04-28: KEEP_SWINGING multi-attempt rule is a NOVEL framework feature for V5 — Williams
  explicitly accepts losing-streak signals as "cost of doing business" until the real breakout
  fires. This is structurally adjacent to gridding (multiple entries during adverse moves) but
  is mechanically RE-ENTRY-after-stop-out, NOT stacking-during-loss. CTO ratification needed
  on whether KEEP_SWINGING qualifies under V5 grid_1pct_cap (likely NO — different mechanism)
  or whether it's a new TM-module pattern.

- 2026-04-28: Williams' 1/3-failure-rate estimate is INFORMAL ("my guess is"); not a tested
  backtest number. Per BASIS rule, NOT asserted as performance claim. Pipeline P2-P9 produces
  actual edge measurement.

- 2026-04-28: 8-Week Box is the longest-precondition pattern in SRC03 (40 trading days
  minimum). Pattern density is rare (~3-8 setups/year/symbol); CSR P3.5 multi-symbol expansion
  required for portfolio-level pattern density.

- 2026-04-28: Cards-vs-fold decision (S11 vs S10 Specialist Trap): DISTINCT. S10 is FADE on a
  6-20 day box with strong-trend precondition; S11 is GO-WITH on an 8-week box with any
  pre-box trend. Different durations, different directions, different risk profiles. Per
  DL-033 Rule 1.
```
