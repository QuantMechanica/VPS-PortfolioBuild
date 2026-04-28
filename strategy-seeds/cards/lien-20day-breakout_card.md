# Strategy Card — Lien 20-Day Breakout Trade (failed-pullback continuation breakout, daily TF)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC04/raw/ch13-16_technical.txt` (verbatim Lien Ch 14 § "Strategy Rules" Long + Short rule lists + § "Examples" three worked examples on GBPUSD / EURUSD / AUDUSD daily charts).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3 / DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC04_S07
ea_id: TBD
slug: lien-20day-breakout
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - donchian-breakout                         # Lien Ch 14 PDF p. 135 rule 1 (long): "Look for a currency pair that is making a 20-day high" — 20-day rolling extreme is canonical Donchian. Card-level parameter `pre-breakout-pullback-required = true` distinguishes Lien's variant from canonical turtle-style 20-day breakout (which fires on ANY new 20-day high). Lien's filter requires (a) prior 20-day high → (b) reversal to 2-day low within next bar → (c) re-break of original 20-day high within 3 days of the 2-day low. This is a "failed-pullback continuation" refinement of canonical Donchian.
  - symmetric-long-short                      # Lien Ch 14 PDF pp. 135-136: explicit Long + Short rule lists (mirror)
  - atr-hard-stop                             # Lien rule 4 (long): "Place the initial stop a few pips below the two-day low" — fixed price stop anchored to recent extreme; V5 maps to ATR(14)·M variant via `stop_anchor_offset_pips` param sweep
  - atr-trailing-stop                         # Lien rule 6 (both sides): "Trail stop on the remainder of the position" — trail method not specified in rule list; Lien EURUSD example (PDF p. 137) uses "2-bar high" → adopt 2-bar-extreme as default, ATR-trail as P3 variant
  - friday-close-flatten                      # D1 swing strategy with multi-day holds (Lien GBPUSD example PDF p. 136 entry Feb 12, EURUSD example PDF p. 137 trailed for multiple bars to 1.1846); Friday-close waiver candidacy at P3 — precedent: SRC03_S03 williams-cdc-pattern + SRC02_S01 chan-pairs-stat-arb
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Lien, Kathy (3rd ed., 2015). Day Trading and Swing Trading the Currency Market: Technical and Fundamental Strategies to Profit from Market Moves. Wiley Trading. Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 14 'Technical Trading Strategy: 20-Day Breakout Trade' (PDF pp. 135-138) including § chapter intro (PDF p. 135) + § 'Strategy Rules' Long (PDF p. 135) + Short (PDF pp. 135-136) + § 'Examples' three worked examples (GBPUSD Fig 14.1 PDF pp. 136-137; EURUSD Fig 14.2 PDF p. 137; AUDUSD Fig 14.3 PDF pp. 137-138)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC04/raw/ch13-16_technical.txt` lines 134-156 (chapter intro + thesis on shaking-out-weak-hands), lines 157-181 (Long + Short rule lists verbatim, including pullback-precondition + 3-day re-break window + half-off-at-1R + BE move + trail), lines 183-236 (three worked examples with explicit pip arithmetic). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Day Trading and Swing Trading t - Kathy Lien.pdf`.

## 2. Concept

Donchian-style 20-day breakouts in forex have a high false-breakout rate because, per Lien (PDF p. 135), the FX market "is more technically driven than others and as a result, there are many market participants who intentionally look to break pairs out in order to 'suck' in other nonsuspecting traders". To filter false breakouts, Lien layers a "shake-out then re-break" precondition on top of the canonical 20-day rule: the strategy enters only AFTER a 20-day high has formed → the pair has retraced to make a 2-day low (the shake-out flushing weak longs) → the original 20-day high is re-broken within 3 days. The thesis (PDF p. 135): "this type of setup tends to have a very high success rate as it allows traders to enter strong trending markets after weaker players have been flushed out, only to have real money players reenter the market and push the pair up to new highs."

Mechanical translation: arm the strategy on a fresh 20-day high. Check for a 2-day low forming on the same day or next. Wait up to 3 days from that 2-day low for the 20-day high to be re-broken; enter on re-break a few pips above prior 20-day high. Place initial stop a few pips below the 2-day low (creating a wide stop reflecting the full pullback range). On +1R, close half + move stop to BE; trail the remainder. Symmetric for shorts.

Verbatim Lien framing on the false-breakout problem and shake-out thesis (PDF p. 135):

> "Trading breakouts can be both a rewarding and frustrating endeavor as breakouts have a tendency to fail. A major reason why this can occur frequently in the foreign exchange market is because it is more technically driven than others and as a result, there are many market participants who intentionally look to break pairs out in order to 'suck' in other nonsuspecting traders. In an effort to filter out potential false breakouts, a price action screener should be used to identify breakouts that have a higher probability of success. The rules behind this strategy are specifically developed to take advantage of strong trending markets that make new highs that then proceed to 'fail' by taking out a recent low and then reverse again to make another new high. This type of setup tends to have a very high success rate as it allows traders to enter strong trending markets after weaker players have been flushed out, only to have real money players reenter the market and push the pair up to new highs."

## 3. Markets & Timeframes

```yaml
markets:
  - forex                                     # Lien Ch 14 entire universe is forex spot pairs; 3 worked examples on GBPUSD / EURUSD / AUDUSD
timeframes:
  - D1                                        # Lien primary: chapter intro + "20-day high" + worked examples all on daily charts (PDF pp. 135-138)
  - H4                                        # plausible variant; out-of-source extrapolation (P3 axis variant — would require recalibrating 20-day to H4 equivalent ~120 H4 bars)
  - W1                                        # plausible variant; out-of-source extrapolation (e.g., 4-week breakout = ~20 trading days); not Lien-cited
session_window: not specified                 # D1 strategy; no intraday session restriction.
primary_target_symbols:
  - "GBPUSD.DWX (Lien example: PDF pp. 136-137, 20-day high Feb 5, two-day low forms in next 3 days, re-break Feb 12 at prior 20-day high 1.5352, entry @ 1.5360, stop @ 1.5190 below original 2-day low 1.5197, risk 155 pips, half off at 1.5507 = +155 pips, BE on rest)"
  - "EURUSD.DWX (Lien example: PDF p. 137, 20-day low Dec 23 @ 1.2165, two-day high forms next day, re-break, short entry @ 1.2155, stop @ 1.2260 above two-day high 1.2254, risk 105 pips, exit half @ 1.2050, BE trail with 2-bar high → exit remainder @ 1.1846)"
  - "AUDUSD.DWX (Lien example: PDF pp. 137-138, 20-day low Jan 26, two-day high forms intraday, re-break, short entry @ 0.7850, stop @ 0.8032 above two-day high 0.8025, risk 182 pips, exit half @ 0.7668, BE-stop hit same day)"
  - "EURGBP.DWX, USDJPY.DWX, USDCHF.DWX, USDCAD.DWX, NZDUSD.DWX (multi-major generalization implicit in Lien's chapter framing — strategy rules state 'currency pair' generically)"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Lien's PDF p. 135-136 rule lists.

```text
PARAMETERS:
- BAR                       = D1     // Lien: "20-day high" + chapter examples all D1
- BREAKOUT_LOOKBACK         = 20     // Lien rule 1: "making a 20-day high" / "making a 20-day low"
- PULLBACK_LOOKBACK         = 2      // Lien rule 2 (long): "to make a two-day low"
- PULLBACK_TIMING           = 1      // Lien rule 2 (long): "the same day or next"
                                     //   = within 1 bar after the 20-day high
- REBREAK_WINDOW            = 3      // Lien rule 3 (long): "within three days of making the two-day low"
- BREAKOUT_OFFSET_PIPS      = 5      // Lien rule 3 (long): "if it takes out the 20-day high"
                                     //   GBPUSD example PDF p. 136: "we buy GBPUSD a few pips above the previous 20-day high of 1.5352. We enter at 1.5360." → 8-pip offset
                                     //   AUDUSD example PDF p. 137: "we enter a short AUDUSD trade a few pips below the 20-day low at 0.7850" — implied small offset
                                     //   default 5p as midpoint of "a few pips"; sweep [2, 5, 10, 15]
- STOP_ANCHOR_OFFSET_PIPS   = 7      // Lien rule 4 (long): "a few pips below the two-day low"
                                     //   GBPUSD: "stop a few pips below the original two-day low of 1.5197 (or 1.5190)" → 7-pip offset
                                     //   default 7p; sweep [3, 5, 7, 10, 15]

DEFINITION (rolling extremes):
- IsNew20DHigh(bar t):
    return high[t] == max(high[t-19], high[t-18], ..., high[t])
    AND high[t] > max(high[t-20], ..., high[t-39])      // strict new-high (not equal to prior 20-day max)
- IsNew2DLow(bar t):
    return low[t] < min(low[t-1], low[t-2])             // 2-day low = lower than prior 2 bars

STATE MACHINE (long side; short is mirror):
1. ARMED_SCAN: monitor each bar t for IsNew20DHigh(t).
   On hit: record new_20d_high_value = high[t]; advance to ARMED_PULLBACK; reset clock.
2. ARMED_PULLBACK: within next PULLBACK_TIMING bars (default 1 — i.e., bar t+1):
   - if IsNew2DLow(t+1) OR IsNew2DLow(t):                // Lien: "the same day or next"
       record two_day_low_value = low[at-pullback-bar]; advance to ARMED_REBREAK; reset clock to 0.
   - else (no pullback): return to ARMED_SCAN; cancel state.
3. ARMED_REBREAK: within next REBREAK_WINDOW bars (default 3):
   - PLACE stop-buy at: new_20d_high_value + BREAKOUT_OFFSET_PIPS
       // Lien rule 3 (long): "Buy the pair if it takes out the 20-day high within three days"
   - if intra-bar high reaches stop-buy: OPEN_LONG; record entry; advance to IN_POSITION.
   - if 3-bar window expires without fill: cancel order; return to ARMED_SCAN.

ON ENTRY (long side):
- entry_price        = new_20d_high_value + BREAKOUT_OFFSET_PIPS
- initial_stop_price = two_day_low_value - STOP_ANCHOR_OFFSET_PIPS
                                        // Lien rule 4 (long): "Place the initial stop a few pips below the two-day low"
- initial_risk_pips  = (entry_price - initial_stop_price)
                                        // typically 100-200 pips per Lien examples (155 / 105 / 182 pips)

SHORT ENTRY (mirror):
1. ARMED_SCAN: monitor IsNew20DLow.
2. ARMED_PULLBACK: monitor IsNew2DHigh within 1 bar of low.
3. ARMED_REBREAK: stop-sell at new_20d_low_value - BREAKOUT_OFFSET_PIPS within 3 bars; fire on touch.
- entry_price        = new_20d_low_value - BREAKOUT_OFFSET_PIPS
- initial_stop_price = two_day_high_value + STOP_ANCHOR_OFFSET_PIPS
                                        // Lien rule 4 (short): "Risk up to a few ticks above the two-day high"
```

## 5. Exit Rules

Lien rules 5-6 (long, PDF p. 135) verbatim:

> "5. Take profit on half of the position when it moves by the amount risked; move stop on rest to breakeven.
> 6. Trail stop on the remainder of the position."

Pseudocode:

```text
PARAMETERS:
- TP1_RR             = 1.0        // Lien rule 5: "when it moves by the amount risked"
- TRAIL_AFTER_TP1    = "BE_then_trail"
                                  // Lien rule 5: "move stop on rest to breakeven"
                                  // Lien rule 6: "Trail stop on the remainder of the position"
- TRAIL_METHOD       = "two_bar_extreme"
                                  // Lien rule 6 does not specify trail method explicitly
                                  // EURUSD worked example (PDF p. 137): "we trail the stop using a 2-bar high"
                                  // → adopt 2-bar-extreme (low for long / high for short) as default
                                  // Alt: ATR(14)·M trail, donchian-N trail (P3 sweep variants)

EACH-BAR (in long position):
- HARD STOP — fires at initial_stop_price (Lien rule 4 anchor)
- TP1 (close half + BE move) at +1R from entry (Lien rule 5):
    if (high[t] - entry_price) >= initial_risk_pips:
      CLOSE_HALF
      move_remaining_stop to BE (entry_price)
      activate trailing stop on remainder
- TRAIL on remainder (Lien rule 6, method per Lien EURUSD example):
    trail_long = max(trail_prev, min(low[t-1], low[t-2]))
                                  // 2-bar-low default; sweep ATR(14)·M / donchian-N alternatives
- exit on trail-stop fire OR on initial_stop fire (whichever first)

EACH-BAR (in short position): mirror — TP1 at -1R, BE move, 2-bar-high trail.

FRIDAY CLOSE: D1 swing strategy with multi-day-to-multi-week holds (Lien EURUSD example
PDF p. 137 trail extends across multiple bars). Friday-close-flatten WILL be load-bearing.
Waiver candidacy at P3 (precedent: SRC03_S03 williams-cdc-pattern Friday-close waiver at
P3 + SRC02_S01 chan-pairs-stat-arb). Default: friday_close ENABLED, with waiver sweep
variant for the multi-day-hold case if PASS_G0.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close (with waiver candidacy)
- pyramiding: NOT allowed (single position; the state machine is single-shot — once ARMED_REBREAK fires or expires, returns to ARMED_SCAN)
- gridding: NOT allowed
- Lien does NOT specify a symbol-cohort preference for this strategy (unlike Ch 12 inside-day where she cited tight-range pairs); chapter framing uses generic "currency pair" → no per-card symbol filter, full Darwinex FX cohort at CSR P3.5
- Pre-news exclusion: D1 daily-bar timing means re-breaks can coincide with major economic releases; V5 default P8 News Impact pause-window discipline applies (no strategy-specific override).
- Trend-precondition refinement (OPTIONAL P3 sweep axis): require the original 20-day extreme to be the highest/lowest of past N>20 days (e.g., N=40 or N=60) — strengthens "strong trending market" precondition Lien describes (PDF p. 135). Off by default; on as `multi-window-extreme-confluence` axis.
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding, no stacking)
- state machine is single-shot — once a 20-day-high → 2-day-low pullback signal arms ARMED_REBREAK, it either fills within 3 bars or expires, then strategy returns to ARMED_SCAN for a fresh setup
- position size: V5 RISK_PERCENT / RISK_FIXED standard
- TP1 (50% close + BE move): hard rule at 1× initial risk
- Trail on remainder: 2-bar-extreme default (Lien EURUSD example precedent); ATR-trail / donchian-N variants exposed as sweep
- Friday Close: ENABLED by default; waiver sweep variant if multi-day-hold edge appears (P3 phase)
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: breakout_lookback
  default: 20                                 # Lien: "20-day"
  sweep_range: [10, 15, 20, 25, 30, 40, 55]    # 55 = classic Turtle long-window; 10-15 = shorter-trend variants
- name: pullback_lookback
  default: 2                                  # Lien: "two-day low"
  sweep_range: [2, 3, 5]                       # higher = wider definition of "shake-out"
- name: pullback_timing
  default: 1                                  # Lien: "the same day or next"
  sweep_range: [0, 1, 2, 3]                    # 0 = same-day-only; 3 = looser timing
- name: rebreak_window
  default: 3                                  # Lien: "within three days"
  sweep_range: [1, 2, 3, 5, 7]
- name: breakout_offset_pips
  default: 5                                  # Lien: "a few pips above the previous 20-day high"
  sweep_range: [2, 5, 10, 15, 20]
- name: stop_anchor_offset_pips
  default: 7                                  # Lien: "a few pips below the two-day low" (GBPUSD example: 7p)
  sweep_range: [3, 5, 7, 10, 15, 20]
- name: tp1_rr
  default: 1.0                                # Lien rule 5: "amount risked"
  sweep_range: [0.75, 1.0, 1.25, 1.5, 2.0]
- name: trail_method
  default: two_bar_extreme                    # Lien EURUSD example precedent
  sweep_range: [two_bar_extreme, three_bar_extreme, atr14x2_trail, atr14x3_trail, donchian5_trail, donchian10_trail]
- name: multi_window_extreme_confluence
  default: off                                # OPTIONAL trend-strength refinement
  sweep_range: [off, also_40d_extreme, also_60d_extreme]
- name: tf
  default: D1                                 # Lien primary
  sweep_range: [D1, H4, W1]                   # H4 / W1 are out-of-source variants
- name: friday_close
  default: enabled                            # V5 default; multi-day swing edge
  sweep_range: [enabled, disabled_with_waiver]
```

P3.5 (CSR) axis: re-run on Darwinex FX cohort (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`) plus crosses (`EURGBP.DWX`, `EURJPY.DWX`, `GBPJPY.DWX`, `AUDNZD.DWX` if Darwinex offers). Lien does not pre-specify a preferred cohort for this strategy; CSR is broad-cohort.

## 9. Author Claims (verbatim, with quote marks)

Strategy framing + thesis, PDF p. 135:

> "Trading breakouts can be both a rewarding and frustrating endeavor as breakouts have a tendency to fail. A major reason why this can occur frequently in the foreign exchange market is because it is more technically driven than others and as a result, there are many market participants who intentionally look to break pairs out in order to 'suck' in other nonsuspecting traders. In an effort to filter out potential false breakouts, a price action screener should be used to identify breakouts that have a higher probability of success. The rules behind this strategy are specifically developed to take advantage of strong trending markets that make new highs that then proceed to 'fail' by taking out a recent low and then reverse again to make another new high. This type of setup tends to have a very high success rate as it allows traders to enter strong trending markets after weaker players have been flushed out, only to have real money players reenter the market and push the pair up to new highs."

Long rule list, PDF p. 135:

> "Strategy Rules
> Longs:
> 1. Look for a currency pair that is making a 20-day high.
> 2. Look for the pair to reverse the same day or next to make a two-day low.
> 3. Buy the pair if it takes out the 20-day high within three days of making the two-day low.
> 4. Place the initial stop a few pips below the two-day low.
> 5. Take profit on half of the position when it moves by the amount risked; move stop on rest to breakeven.
> 6. Trail stop on the remainder of the position."

Short rule list, PDF pp. 135-136:

> "Shorts:
> 1. Look for a currency pair that is making a 20-day low.
> 2. That day or the next the pair rallies to make a two-day high.
> 3. Sell the pair if it trades below the 20-day low within three days of making the two-day high.
> 4. Risk up to a few ticks above the two-day high.
> 5. Take profit on half of the position when it moves by the amount risked; move stop on rest to breakeven.
> 6. Trail stop on the remainder of the position."

Worked-example pip P&L, GBPUSD Fig 14.1 PDF pp. 136-137:

> "The daily chart of GBPUSD shows the currency pair making a new 20-day high on February 5. ... we wait for the currency pair to make a new 20-day high, which occurs on February 12. At the time, we buy GBPUSD a few pips above the previous 20-day high of 1.5352. We enter at 1.5360. The stop is placed a few pips below the original two-day low of 1.5197 (or 1.5190). As the currency pair moves in our favor, we look to exit half of the position when it moves by the amount that we risked, which is 155 pips or 1.5507. The stop on the remainder of the position is moved to breakeven or the initial entry price of 1.5352. This rest of the trade is exited 24 hours later."

Worked-example pip P&L, EURUSD Fig 14.2 PDF p. 137:

> "On December 23, the currency pair makes a new 20-day low of 1.2165. ... we enter a short EURUSD trade at 1.2155 with a stop at 1.2260, or a few pips above the two-day high of 1.2254. Our risk on the trade is 105 pips. When the currency pair drops to 1.2050, we exit the first half of the position and move the stop on the rest to breakeven. Then we trail the stop using a 2-bar high and end up exiting the remainder of the position at 1.1846."

Worked-example pip P&L, AUDUSD Fig 14.3 PDF pp. 137-138:

> "The currency starts by making a new 20-day low on January 26. ... we enter a short AUDUSD trade a few pips below the 20-day low at 0.7850 with a stop at 0.8032, or a few pips above the two-day high of 0.8025. Our risk on the trade is 182 pips. When the currency pair drops to 0.7668, we exit the first half of the position and move the stop on the rest to breakeven. The breakeven stop is triggered the very same day that the first target is reached."

**Lien provides one descriptive non-numeric performance claim** for this strategy — the thesis assertion (PDF p. 135):

> "This type of setup tends to have a very high success rate as it allows traders to enter strong trending markets after weaker players have been flushed out, only to have real money players reenter the market and push the pair up to new highs."

No numeric win rate, profit factor, max drawdown, or annualized return is provided — only descriptive ("very high success rate") plus per-trade pip-P&L on three worked examples (GBPUSD: +155 pips half off + remainder exited at BE = ~+155 pips total; EURUSD: half off at +105 pips + trail to 1.1846 = +105 + (1.2155 - 1.1846) × 10000 = +105 + 309 = ~+414 pips total; AUDUSD: half off at +182 pips + BE-stop on rest = ~+182 pips total). Per BASIS rule, no extrapolated performance number is asserted in this card; pipeline P2-P9 produce the actual edge measurement.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                              # rough estimate; failed-pullback continuation breakout with 1R partial + BE-trail typically 1.2-1.6 PF range when filter discipline holds; D1 swing on multi-pair cohort
expected_dd_pct: 15                           # rough estimate; D1 single-symbol with 100-200-pip stops and BE-after-1R management typically 12-22% DD range
expected_trade_frequency: 3-8/year/symbol     # rough estimate; the 20-day-high → 2-day-low pullback → 3-day re-break compound filter is signal-restrictive — Lien acknowledges low signal density implicitly via "very high success rate" framing (high quality, low quantity)
risk_class: medium                            # D1 swing with multi-day-to-multi-week holds; wide stops (100-200 pips per worked examples) give room but can amplify single-trade DD
gridding: false
scalping: false                               # D1 bars; far from scalping
ml_required: false                            # rolling extremes + bar-counting state machine + threshold arithmetic; no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (rolling-N extreme test + state-machine pullback-timing + re-break stop order; no discretionary judgment)
- [x] No Machine Learning required
- [x] If gridding: not applicable (single position; state machine is single-shot)
- [x] If scalping: not applicable (D1 bars)
- [x] Friday Close compatibility: load-bearing — multi-day-to-multi-week swing strategy. Default ENABLED; waiver candidacy at P3 if multi-day edge surfaces. Precedent: SRC03_S03 williams-cdc-pattern + SRC02_S01 chan-pairs-stat-arb received Friday-close waiver consideration.
- [x] Source citation is precise enough to reproduce (PDF pp. 135-138 rule lists + 3 worked examples with explicit pip arithmetic; verbatim quotes preserved)
- [x] No near-duplicate of existing approved card (`strategy-seeds/cards/`: closest is SRC03_S15 williams-gap-dn-buy which uses range-projection forward-stop on Bonds-context Gap-Down-Close pattern — different mechanism; no existing card uses 20-day-high → 2-day-low pullback → 3-day re-break state machine)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); optional `multi_window_extreme_confluence` axis (require 40-day or 60-day extreme alignment) for trend-strength refinement"
  trade_entry:
    used: true
    notes: "3-state-machine entry: ARMED_SCAN (monitor 20-day extreme) → ARMED_PULLBACK (within 1 bar, look for 2-day opposite extreme) → ARMED_REBREAK (within 3 bars, stop-buy/sell at original 20-day extreme + offset); D1 evaluation; long/short symmetric"
  trade_management:
    used: true
    notes: "TP1 = 1R partial close + move-rest-to-BE (Lien rule 5); trail remainder via 2-bar-extreme (Lien EURUSD example precedent) or ATR / donchian-N variants"
  trade_close:
    used: true
    notes: "exit on initial stop (anchored to 2-day extreme + offset) OR TP1 partial + BE-trail-fired-on-remainder OR trail-stop-on-remainder fire"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # LOAD-BEARING — D1 swing; Lien EURUSD example trails for multiple bars to 1.1846 (PDF p. 137). Default V5 friday_close ENABLED; waiver candidacy at P3 if multi-day edge appears.
  - enhancement_doctrine                      # LOAD-BEARING on entry/stop pip offsets ("a few pips") — Lien's offsets are vague ("a few" without numeric specificity). Card defaults to 5/7 pips per GBPUSD example pip arithmetic; cross-pair generalization requires ATR-scaled offsets. P3 sweep `breakout_offset_pips` / `stop_anchor_offset_pips` axes test this. Once a live offset is fixed, any subsequent retune is enhancement_doctrine.
  - news_pause_default                        # NOT LOAD-BEARING — Lien does not address news interaction explicitly. V5 default P8 news-pause applies. Listed for CTO completeness.

at_risk_explanation: |
  friday_close — D1 swing strategy with multi-day-to-multi-week holds. Lien's worked examples
  trail across multiple bars (EURUSD example: trail extends from 1.2050 partial-take to 1.1846
  trail-exit, multi-week duration). Default V5 friday_close ENABLED; waiver sweep variant if
  PASS_G0 reveals multi-day-hold edge. Precedent: SRC03_S03 williams-cdc-pattern and SRC02_S01
  chan-pairs-stat-arb both received P3 waiver consideration.

  enhancement_doctrine — Lien's verbatim "a few pips" entry/stop offsets are imprecise. Card
  defaults to 5/7 pips per worked-example reverse-engineering (GBPUSD: entry at 1.5360 above
  20-day high 1.5352 = 8 pips; stop at 1.5190 below 2-day low 1.5197 = 7 pips). Cross-pair
  generalization (especially to JPY pairs with different absolute pip values) may require
  ATR-scaled offsets. P3 sweep tests this. Once fixed, retune is enhancement_doctrine.

  news_pause_default — Lien does not discuss news interaction for this strategy. V5 default
  P8 news-pause applies; no strategy-specific override needed. Listed for CTO completeness.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default + optional multi-window-extreme-confluence axis
  entry: TBD                                  # 3-state state machine on bar close (ARMED_SCAN → ARMED_PULLBACK → ARMED_REBREAK) with rolling-N extreme tests + pullback-timing window + re-break window; ~120-180 LOC in MQL5
  management: TBD                             # TP1 = 1R partial close + BE move; 2-bar-extreme trail (default) or ATR / donchian-N (variants)
  close: TBD                                  # standard SL/TP/trail; trail method controlled by `trail_method` parameter
estimated_complexity: medium                  # state machine bookkeeping + rolling-extreme detection + pullback-timing window adds nontrivial LOC vs simple breakout strategies; D1-only timeframe simplifies tick handling
estimated_test_runtime: 3-6h                  # P3 sweep ≈ 7×3×4×5×5×6×5×6×3×3×2 ≈ 6,800,000 cells nominal — needs cell-axis pruning to ~30,000 cells for budget; D1 bars; 5+ years; FX cohort
data_requirements: standard                   # D1 OHLC on Darwinex .DWX FX symbols; no external feeds
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-28 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-28 | DRAFT (awaiting CEO + Quality-Business review) | this card |
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
- 2026-04-28: SRC04_S07 reuses existing `donchian-breakout` flag with card-level parameter
  `pre-breakout-pullback-required = true`. Lien's variant is NOT canonical Donchian (which
  fires on ANY new 20-day extreme); it requires (a) 20-day extreme → (b) opposite-direction
  2-day extreme within 1 bar → (c) re-break of original 20-day extreme within 3 bars. This
  is a "failed-pullback continuation" refinement of canonical Donchian, distinct from the
  V4 Modernised Turtle pattern which uses unconditional 20/55-day breakouts. Card-level
  parameterization preferred over a new sub-flag — if P3 reveals that the pullback filter
  materially changes edge characteristics, a sub-flag (`donchian-failed-pullback-rebreak`?)
  could be proposed at SRC04 closeout for CEO ratification.

- 2026-04-28: Strategy is the FIRST canonical Donchian-breakout card across all SRCs (SRC01-04).
  V4 Modernised Turtle was an inspiration spec, not a deployed EA. SRC04_S07 brings the
  Donchian family into the SRC card library. Future SRC cards using Donchian variants can
  cross-reference this card for the pullback-filter refinement convention.

- 2026-04-28: Lien provides ONE descriptive non-numeric performance claim ("very high success
  rate", PDF p. 135) plus per-trade pip-P&L on three worked examples (GBPUSD ~+155 pips,
  EURUSD ~+414 pips, AUDUSD ~+182 pips). Per BASIS rule, no extrapolated number is asserted;
  the descriptive claim is preserved verbatim in § 9 with no numeric substitution.

- 2026-04-28: The 3-state state machine (ARMED_SCAN → ARMED_PULLBACK → ARMED_REBREAK) is the
  FIRST multi-state entry pattern in the SRC card library. All prior SRC cards use
  single-bar entry triggers (signal evaluated each bar, fires immediately on condition).
  CTO will need to validate state-machine bookkeeping discipline at IMPL — particularly
  state-reset on PULLBACK_TIMING expiry vs REBREAK_WINDOW expiry, and overlap handling if a
  new 20-day extreme prints while an existing setup is in ARMED_PULLBACK or ARMED_REBREAK.

- 2026-04-28: Friday-close is load-bearing — Lien's worked examples trail across multiple bars
  (EURUSD example PDF p. 137 trails from 1.2050 partial-take to 1.1846 trail-exit). Default
  ENABLED; waiver sweep variant exposed for P3 evaluation. Precedent: SRC03_S03
  williams-cdc-pattern + SRC02_S01 chan-pairs-stat-arb both received P3 waiver consideration.

- 2026-04-28: V5-architecture-fit profile is FAVOURABLE — single-symbol forex, D1 bars, no
  multi-leg / multi-stock / cointegration architecture concerns. State-machine logic adds
  modest LOC but is straightforward bookkeeping. Expected G0 yield CLEAN with friday_close
  flagged for P3 waiver evaluation.

- 2026-04-28: P3 cell count nominal estimate ~6.8M cells exceeds standard P3 budget; CTO will
  need to apply cell-axis pruning at IMPL (e.g., orthogonal-design selection of param tuples
  rather than full cross-product). This is a cosmetic IMPL constraint, not a strategy-design
  concern.
```
