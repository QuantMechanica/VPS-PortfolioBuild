# Strategy Card — Lien Inside Days Breakout Play (multi-inside-day volatility-compression breakout, daily TF)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC04/raw/ch08-12_technical.txt` (verbatim Lien Ch 12 § "Strategy Rules" Long + Short rule lists + § "Further Optimization" + 3 worked examples on EURGBP / NZDUSD / EURCAD daily charts).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3 / DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC04_S05
ea_id: 1011
slug: lien-inside-day-breakout
status: APPROVED
created: 2026-04-28
created_by: Research
last_updated: 2026-05-01
g0_issue: QUA-641
g0_reviewed_at: 2026-05-01
g0_reviewer: CEO (DL-037)
g0_verdict: APPROVED

strategy_type_flags:
  - narrow-range-breakout                     # Lien Ch 12 PDF p. 123: "An inside day is defined as a day where the daily range has been contained within the prior day's trading range" — multi-inside-day pattern is the strictest form of range-contraction precondition. Disambiguates from `donchian-breakout` (no contraction precondition, fires on any N-bar extreme) and from `vol-expansion-breakout` (uses single prior-bar range scaled by N%, no containment requirement). Card-level parameter `range_contraction_pattern = "consecutive-inside-days"` distinguishes from canonical NR4/NR7 (Crabel) variants — inside-day requires strict containment (today H ≤ prior H AND today L ≥ prior L), NR-N requires today's range to be the narrowest of past N bars without strict containment.
  - symmetric-long-short                      # Lien Ch 12 PDF pp. 123-124: explicit Long + Short rule lists (mirror)
  - atr-hard-stop                             # Lien rule 3 (long): "stop and reverse order ... at least 10 pips below the low of the nearest inside day" — fixed pip stop anchored to most-recent inside-day extreme; V5 maps to ATR(14)·M variant via `stop_offset_pips` param sweep
  - friday-close-flatten                      # D1 swing strategy with multi-day holds (Lien EURGBP example PDF p. 125 holds from breakout day until target hit "three weeks later"); Friday-close waiver candidacy at P3 — precedent: SRC03_S03 williams-cdc-pattern + SRC02_S01 chan-pairs-stat-arb
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Lien, Kathy (3rd ed., 2015). Day Trading and Swing Trading the Currency Market: Technical and Fundamental Strategies to Profit from Market Moves. Wiley Trading. Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 12 'Technical Trading Strategy: Inside Days Breakout Play' (PDF pp. 123-127) including § 'Strategy Rules' Long (PDF p. 123) + Short (PDF p. 124) + § 'Further Optimization' (PDF p. 124) + § 'Examples' three worked examples (EURGBP Fig 12.1 PDF pp. 124-125; NZDUSD Fig 12.2 PDF pp. 125-126; EURCAD Fig 12.3 PDF pp. 126-127)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC04/raw/ch08-12_technical.txt` lines 717-740 (chapter intro + inside-day definition), lines 742-779 (Long + Short rule lists verbatim, including stop-and-reverse and false-breakout-protection sub-rules), lines 781-794 (Further Optimization on triangle / Fibonacci / MACD confluence), lines 796-907 (three worked examples with explicit pip arithmetic). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Day Trading and Swing Trading t - Kathy Lien.pdf`.

## 2. Concept

Inside-day patterns reflect intra-day volatility compression: each inside day's high and low are contained within the prior day's range, so the daily true range strictly contracts. Lien (PDF p. 123): "There needs to be at least two inside days before the volatility play can be implemented. The more inside days, the higher the likelihood of an upside surge in volatility, or a breakout." The thesis is the classic coiled-spring: when range compresses below recent norm for ≥2 sessions, the breakout direction tends to carry follow-through.

Mechanical translation: identify ≥2 consecutive inside days, then place stop-buy orders 10 pips above the previous inside day's high AND stop-sell orders 10 pips below the previous inside day's low (bracket-order). Whichever side fires first opens the position. Lien's distinctive twist is the **stop-and-reverse for two lots** at the opposite inside-day extreme (10 pips beyond) — if the first breakout fails and price travels to the opposite extreme, flip direction with double size to recover the failed-breakout loss and ride the alternate direction. Take profit at 2× risk or trail.

Verbatim Lien framing on volatility-compression rationale (PDF p. 123):

> "Throughout this book, volatility trading has been discussed as one of the most popular strategies employed by professional traders. There are many ways to interpret changes in volatilities, but one of the simplest strategies is actually a visual one that requires nothing more than a keen eye. Although this is a strategy that is very popular in the world of professional trading, new traders are frequently amazed by its ease, accuracy, and reliability. Breakout traders can identify inside days with nothing more than a basic candlestick chart."

## 3. Markets & Timeframes

```yaml
markets:
  - forex                                     # Lien Ch 12 entire universe is forex spot pairs; 3 worked examples on EURGBP / NZDUSD / EURCAD
timeframes:
  - D1                                        # Lien primary: "This strategy is best employed on daily charts, but the longer the time frame, the more significant the breakout opportunity" (PDF p. 123)
  - H1                                        # Lien secondary: "Some traders use the inside day strategy on hourly charts, which works to some success" (PDF p. 123-124); H1 inside-bar variant — out-of-source but Lien-acknowledged
  - H4                                        # plausible intermediate; out-of-source extrapolation (P3 axis variant)
  - W1                                        # Lien implies: "the longer the time frame, the more significant the breakout opportunity" (PDF p. 123) — weekly inside-week variant; out-of-source extrapolation
session_window: not specified                 # D1 strategy; no intraday session restriction. For H1 variant, Lien notes "chances of a solid breakout increases if the contraction precedes the London or U.S. market opens" (PDF p. 123) — session-time-gate variant for H1 only.
primary_target_symbols:
  - "EURGBP.DWX (Lien example: PDF pp. 124-125, two inside days, long entry @ 0.6634, stop @ 0.6579, risk 45 pips, target @ 0.6724 hit for +90 pips)"
  - "NZDUSD.DWX (Lien example: PDF pp. 125-126, two inside days, long entry @ 0.6638, stop-and-reverse triggered at 0.6560 with -78-pip loss, then short @ 0.6560 to 0.6404 for +156 pips, net +78 pips on combined trade)"
  - "EURCAD.DWX (Lien example: PDF pp. 126-127, two inside days, long entry @ 1.6008 with MACD-confluence directional bias, stop @ 1.5905, target @ 1.6208 hit for +200 pips)"
  - "USDCAD.DWX, EURCHF.DWX, AUDCAD.DWX (Lien preferred-cohort PDF p. 124: 'less frequent instances of false breakouts in the tighter range pairs such as the EURGBP, USDCAD, EURCHF, EURCAD, and AUDCAD')"
  - "EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX (multi-major generalization implicit in 'This strategy works with all currencies pairs', PDF p. 124)"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Lien's PDF pp. 123-124 rule lists.

```text
PARAMETERS:
- BAR                  = D1       // Lien: "best employed on daily charts" (PDF p. 123)
- INSIDE_DAYS_MIN      = 2        // Lien rule 1 (long): "the daily range has been contained within the prior day's range for at least two days" — minimum count
- BREAKOUT_OFFSET_PIPS = 10       // Lien rule 2 (long): "Buy 10 pips above the high of the previous inside day"
- REVERSE_OFFSET_PIPS  = 10       // Lien rule 3 (long): "Place stop and reverse order ... at least 10 pips below the low of the nearest inside day"

DEFINITION (inside-day):
- IsInsideDay(bar t):
    return high[t] <= high[t-1] AND low[t] >= low[t-1]

DEFINITION (multi-inside-day cluster as of EOD bar t):
- N = consecutive count of bars (going backward from t inclusive) for which IsInsideDay(...) holds
  // bar t is the "current inside day" iff IsInsideDay(t)
- "previous inside day" (Lien terminology) = the OLDEST inside day in the consecutive cluster
  // i.e., for a 2-inside-day cluster ending at bar t, previous = bar t-1
  // (because t-1 is also inside day t-2's range)
- "nearest inside day" (Lien terminology) = the NEWEST inside day in the cluster = bar t

EACH-BAR (evaluated on close of D1 bar t — bracket orders go live for bar t+1):
- if N >= INSIDE_DAYS_MIN (default 2):
    prev_inside_high = high of OLDEST inside day in cluster   // Lien: "high of the previous inside day"
    prev_inside_low  = low  of OLDEST inside day in cluster
    near_inside_high = high of NEWEST inside day in cluster (= bar t)
    near_inside_low  = low  of NEWEST inside day in cluster (= bar t)

    LONG side bracket order, valid for next session:
    - stop-buy at:   prev_inside_high + BREAKOUT_OFFSET_PIPS
                                                  // Lien rule 2 (long): "Buy 10 pips above the high of the previous inside day"
    - if filled: OPEN_LONG; initial stop-and-reverse trigger at near_inside_low - REVERSE_OFFSET_PIPS
                                                  // Lien rule 3 (long): "Place stop and reverse order for two lots at least 10 pips below the low of the nearest inside day"

    SHORT side bracket order, valid for next session:
    - stop-sell at:  prev_inside_low - BREAKOUT_OFFSET_PIPS
                                                  // Lien rule 2 (short): "Sell 10 pips below the low of the previous inside day"
    - if filled: OPEN_SHORT; initial stop-and-reverse trigger at near_inside_high + REVERSE_OFFSET_PIPS
                                                  // Lien rule 3 (short): "Place stop and reverse order for two lots at least 10 pips above the high of the nearest inside day"

INSIDE-DAY STREAK MATURITY:
- Lien PDF p. 123: "The more inside days, the higher the likelihood of an upside surge in volatility, or a breakout."
- Card exposes `inside_days_min` parameter (default 2; sweep [2, 3, 4, 5]) — testing whether higher-N requirement (rarer signal) raises win rate.

DIRECTIONAL BIAS (Further Optimization, PDF p. 124, OPTIONAL):
- "if the inside days are building and contracting toward the top of a recent range such as a bullish ascending triangle formation, the breakout has a higher likelihood of occurring to the upside"
- Mechanical proxy: position of inside-day cluster relative to recent N-bar range:
    range_position = (avg(inside_day_close) - low(N_bars)) / (high(N_bars) - low(N_bars))
    if range_position > 0.66: directional bias UP → take long-side bracket only
    if range_position < 0.33: directional bias DOWN → take short-side bracket only
    else: take both sides (neutral bracket)
- OPTIONAL P3 sweep axis: directional_bias_filter ∈ {off, range_position, macd_histogram_sign}
```

## 5. Exit Rules

Lien rule 4 (long, PDF p. 123) verbatim:

> "4. Take profit when prices reach double the amount risked or begin to trail stop at that level."

Plus the false-breakout-protection sub-rule (PDF p. 124):

> "Protect against false breakouts: If the stop and reverse order is triggered, place a stop at least 10 pips above the high of the nearest inside day and protect any profits larger than what you risked with a trailing stop."

Pseudocode:

```text
PARAMETERS:
- TP1_RR             = 2.0        // Lien rule 4: "Take profit when prices reach double the amount risked"
- TRAIL_AFTER_TP1    = "BE_or_TRAIL"
                                  // Lien: "or begin to trail stop at that level" — trader's choice between full-close and trail at 2R level
- TRAIL_METHOD       = "two_bar_low"
                                  // not specified in Ch 12 rule list; Lien Ch 14 (20-Day Breakout) PDF p. 137 EURUSD example uses "2-bar high" trail — adopting consistent default within Lien's textbook
- REVERSE_LOTS       = 2          // Lien rule 3 (long): "stop and reverse order for two lots"
                                  //   V5 hard-rule consideration: 2-lot reversal stresses risk_mode_dual; default 1-lot reversal preferred for V5 compliance, 2-lot exposed as P3 sweep variant only

EACH-BAR (in long position):
- HARD STOP-AND-REVERSE — fires at near_inside_low - REVERSE_OFFSET_PIPS:
    if low[t] <= reverse_trigger_long:
      CLOSE_LONG (loss = entry - reverse_trigger_long)
      OPEN_SHORT with REVERSE_LOTS units at reverse_trigger_long
        // initial stop on new SHORT: near_inside_high + REVERSE_OFFSET_PIPS (Lien: "place a stop at least 10 pips above the high of the nearest inside day")
        // Lien sub-rule (PDF p. 124): "protect any profits larger than what you risked with a trailing stop"
- TP1 (close half + BE move) at +2R from original entry (Lien rule 4):
    initial_risk = entry_long - reverse_trigger_long
    if (high[t] - entry_long) >= 2 * initial_risk:
      CLOSE_HALF
      move_remaining_stop to BE (entry_long)
      activate trailing stop on remainder (2-bar-low default; sweep ATR-trail / N-bar-low alternatives)
- TRAIL on remainder: max(trail_prev, max_high_since_entry - ATR(14)·M) for ATR variant
                       OR min(low[t-1], low[t-2]) for 2-bar-low variant

EACH-BAR (in reversal short position):
- HARD STOP at near_inside_high + REVERSE_OFFSET_PIPS (Lien sub-rule)
- TRAIL: "protect any profits larger than what you risked with a trailing stop" (Lien)
  → trail-from-entry on the reversal leg, no fixed TP1 specified
  → adopt 2-bar-high trail OR ATR(14)·M trail (sweep)

FRIDAY CLOSE: D1 swing strategy with multi-day holds (Lien EURGBP example: entry on
breakout, target reached "three weeks later"). Friday-close-flatten WILL be load-bearing.
Waiver candidacy at P3 (precedent: SRC03_S03 williams-cdc-pattern Friday-close waiver at
P3 + SRC02_S01 chan-pairs-stat-arb similar). Default: friday_close ENABLED, with waiver
sweep variant for the multi-day-hold case if PASS_G0.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close (with waiver candidacy)
- pyramiding: NOT allowed (single position at a time per direction; reversal flips direction, does not stack)
- gridding: NOT allowed
- Lien preferred symbols (PDF p. 124): "less frequent instances of false breakouts in the tighter range pairs such as the EURGBP, USDCAD, EURCHF, EURCAD, and AUDCAD" — symbol-cohort filter at CSR P3.5 rather than per-card.
- Lien Further Optimization (PDF p. 124): "For higher-probability trades, technical formations can be used in conjunction with the visual identification to place a higher weight on a specific direction of the breakout." — OPTIONAL P3 sweep axis variant: require directional-bias confluence (range_position OR MACD-histogram-sign OR ascending/descending triangle proxy). Off by default; on as confluence-filter axis.
- For H1 variant: Lien (PDF p. 123-124) "chances of a solid breakout increases if the contraction precedes the London or U.S. market opens" — session-time-gate `London_open ± 60min OR NY_open ± 60min` for H1 strategy variant. D1 strategy ignores this.
- Pre-news exclusion: D1 daily-bar timing means Lien-traded breakouts can coincide with major economic releases. Lien (PDF p. 123): "Traders using the daily charts could look for breakouts ahead of major economic releases for the specific currency pair" — but V5 default P8 News Impact pause-window discipline applies; Lien's pro-news framing is not adopted (V5 hard rule + research methodology favor news-pause).
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding, no stacking)
- bracket order: long-side and short-side stop-orders staged simultaneously at session start (next D1 bar after multi-inside-day cluster confirmed); whichever fires first opens the position; the OTHER side is cancelled at fill or held as the "stop-and-reverse" trigger per Lien rule 3
- position size: V5 RISK_PERCENT / RISK_FIXED standard; reversal-leg sizing default 1 unit (V5-compliant); 2-unit Lien-verbatim variant exposed as P3 sweep variant only with `risk_mode_dual` flag at hard_rules_at_risk
- TP1 (50% close + BE move): hard rule at 2× initial risk from primary entry
- Trail on remainder: 2-bar-low/high default per Lien Ch 14 worked-example precedent; ATR(14)·M variant exposed as sweep
- Reversal leg: protect-profit-only trail (no fixed TP), per Lien PDF p. 124 sub-rule
- Friday Close: ENABLED by default; waiver sweep variant if multi-day-hold edge appears (P3 phase)
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: inside_days_min
  default: 2                                  # Lien: "at least two days"
  sweep_range: [2, 3, 4, 5]                   # higher count = rarer + higher-confidence signal per Lien "the more inside days, the higher the likelihood"
- name: breakout_offset_pips
  default: 10                                 # Lien: "10 pips above"
  sweep_range: [5, 10, 15, 20, 30]
- name: reverse_offset_pips
  default: 10                                 # Lien: "at least 10 pips below"
  sweep_range: [5, 10, 15, 20, 30]
- name: tp1_rr
  default: 2.0                                # Lien rule 4: "double the amount risked"
  sweep_range: [1.0, 1.5, 2.0, 2.5, 3.0]
- name: reverse_lots
  default: 1                                  # V5 default for risk_mode compliance
  sweep_range: [1, 2]                          # 2-unit is Lien-verbatim variant; risk_mode_dual flag exposes
- name: trail_method
  default: two_bar_low                        # Lien Ch 14 example precedent within textbook
  sweep_range: [two_bar_low, atr14x2_trail, atr14x3_trail, donchian5_trail, donchian10_trail]
- name: directional_bias_filter
  default: off                                # Lien Further Optimization OPTIONAL
  sweep_range: [off, range_position, macd_hist_sign, both_agree]
- name: tf
  default: D1                                 # Lien primary
  sweep_range: [D1, H1, H4, W1]               # H1 is Lien-acknowledged; H4 / W1 are out-of-source variants
- name: friday_close
  default: enabled                            # V5 default; multi-day swing edge
  sweep_range: [enabled, disabled_with_waiver]  # waiver candidacy similar to SRC03_S03 williams-cdc-pattern + SRC02_S01 chan-pairs-stat-arb
```

P3.5 (CSR) axis: re-run on Darwinex FX cohort (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`) plus Lien-preferred crosses (`EURGBP.DWX`, `EURCHF.DWX`, `EURCAD.DWX`, `AUDCAD.DWX` if Darwinex offers). Lien states tight-range pairs/crosses are preferred (PDF p. 124), so cross-pair PASS rate is a primary CSR validation.

## 9. Author Claims (verbatim, with quote marks)

Strategy framing, PDF p. 123:

> "Throughout this book, volatility trading has been discussed as one of the most popular strategies employed by professional traders. There are many ways to interpret changes in volatilities, but one of the simplest strategies is actually a visual one that requires nothing more than a keen eye. Although this is a strategy that is very popular in the world of professional trading, new traders are frequently amazed by its ease, accuracy, and reliability."

Inside-day definition + multi-inside-day rationale, PDF p. 123:

> "An inside day is defined as a day where the daily range has been contained within the prior day's trading range, or in other words, the day's high and low do not exceed the previous day's high and low. There needs to be at least two inside days before the volatility play can be implemented. The more inside days, the higher the likelihood of an upside surge in volatility, or a breakout."

Timeframe and pair-cohort guidance, PDF pp. 123-124:

> "This type of strategy is best employed on daily charts, but the longer the time frame, the more significant the breakout opportunity. Some traders use the inside day strategy on hourly charts, which works to some success, but identifying inside days on daily charts tends to lead to an even greater probability of success. For day traders looking for inside days on hourly charts, chances of a solid breakout increases if the contraction precedes the London or U.S. market opens."

Pair-cohort guidance, PDF p. 124:

> "This strategy works with all currencies pairs, but has less frequent instances of false breakouts in the tighter range pairs such as the EURGBP, USDCAD, EURCHF, EURCAD, and AUDCAD."

Long rule list, PDF pp. 123-124:

> "Strategy Rules
> Long:
> 1. Identify a currency pair where the daily range has been contained within the prior day's range for at least two days (we are looking for multiple inside days).
> 2. Buy 10 pips above the high of the previous inside day.
> 3. Place stop and reverse order for two lots at least 10 pips below the low of the nearest inside day.
> 4. Take profit when prices reach double the amount risked or begin to trail stop at that level.
>
> Protect against false breakouts: If the stop and reverse order is triggered, place a stop at least 10 pips above the high of the nearest inside day and protect any profits larger than what you risked with a trailing stop."

Short rule list, PDF p. 124:

> "Short:
> 1. Identify a currency pair where the daily range has been contained within the prior day's range for at least two days (we are looking for multiple inside days).
> 2. Sell 10 pips below the low of the previous inside day.
> 3. Place stop and reverse order for two lots at least 10 pips above the high of the nearest inside day.
> 4. Take profit when prices reach double the amount risked or begin to trail stop at that level.
>
> Protect against false breakouts: If the stop and reverse order is triggered, place a stop at least 10 pips below the low of the nearest inside day and protect any profits larger than what you risked with a trailing stop."

Further Optimization (directional-bias confluence), PDF p. 124:

> "For higher-probability trades, technical formations can be used in conjunction with the visual identification to place a higher weight on a specific direction of the breakout. For example, if the inside days are building and contracting toward the top of a recent range such as a bullish ascending triangle formation, the breakout has a higher likelihood of occurring to the upside. The opposite scenario is also true; if inside days are building and contracting toward the bottom of a recent range and we begin to see that a bearish descending triangle is forming, the breakout has a higher likelihood of occurring to the downside. Aside from triangles, other technical factors that can be considered include significant support and resistance levels."

Worked-example pip P&L, EURGBP Fig 12.1 PDF pp. 124-125:

> "we are risking 45 pips. When prices reached our target level of double the amount risked (90 pips), or 0.6724, we have two choices: to either close out the entire trade or begin trailing the stop. ... We choose to close out the trade for a 90-pip profit, but those who stayed in and weathered a bit of volatility could have taken advantage of another 100 pips of profits three weeks later."

Worked-example pip P&L, NZDUSD Fig 12.2 PDF pp. 125-126 (failed-breakout reversal):

> "we close our first position at 0.6560 with a 78 pips loss. We then enter into a new short position with the reverse order at 0.6560. ... we choose to close the position once the price reaches our limit of 0.6404 for a profit of 156 pips and a total profit on the entire trade of 78 pips."

Worked-example pip P&L, EURCAD Fig 12.3 PDF pp. 126-127 (with MACD-confluence directional bias):

> "Adding in the MACD histogram to the bottom of the chart, we see that the histogram is also in positive territory right when the inside days are forming. As such, we choose to opt for an upside breakout trade. In accordance with the rules, we go long 10 pips above the high of the previous inside day at 1.6008. Our long trade is triggered, and we place our stop and reverse order 10 pips below the low of the most recent inside day at 1.5905. When prices move by double the amount that we risked to 1.6208, we exit the entire position for a 200-pip profit."

Closing risk-reward summary, PDF p. 127:

> "With the inside day breakout strategy, the risk is generally pretty high if done on daily charts, but the profit potentials following the breakout are usually fairly large as well. ... Generally these breakout trades are a precursor to big trends, and using trailing stops would allow traders to participate in the trend move while also banking some profits."

**Lien provides NO numeric aggregate performance claim** (no win-rate, profit-factor, max-drawdown, or annualized-return figure) for this strategy on its own — only the per-trade pip-P&L on three worked examples (+90 / -78 then +156 = net +78 / +200 pips) and the descriptive risk-reward framing ("the risk is generally pretty high ... but the profit potentials ... are usually fairly large as well", PDF p. 127). Per BASIS rule, no extrapolated performance number is asserted in this card; pipeline P2-P9 produce the actual edge measurement.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3                              # rough estimate; Lien's 2× risk TP with stop-and-reverse tail catches both the original breakout and false-breakout reversals; D1 swing on multi-pair cohort typically 1.2-1.5 PF when stop-discipline holds
expected_dd_pct: 18                           # rough estimate; D1 single-symbol with multi-day hold and 2R TP target typically 12-25% DD range; reversal-leg adds variance
expected_trade_frequency: 8-15/year/symbol    # rough estimate; multi-inside-day clusters are not common — Lien's "more inside days, the higher the likelihood" implies signal density depends heavily on inside_days_min sweep
risk_class: medium                            # D1 swing with bracket-and-reverse logic; multi-day exposure but tight stops; not strictly trend-following due to reversal mechanic
gridding: false
scalping: false                               # D1 bars; far from scalping
ml_required: false                            # bar-counting + threshold + price-arithmetic; no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (inside-day boolean test + bracket-order placement + stop-and-reverse arithmetic; no discretionary judgment on entry/exit; "directional bias" confluence is OPTIONAL P3 axis with mechanical proxies)
- [x] No Machine Learning required
- [x] If gridding: not applicable (single position; reversal flips, does not stack)
- [x] If scalping: not applicable (D1 bars; H1 variant still well above scalping boundary)
- [x] Friday Close compatibility: load-bearing — multi-day swing strategy. Default ENABLED; waiver candidacy at P3 if multi-day edge surfaces. Precedent: SRC03_S03 williams-cdc-pattern + SRC02_S01 chan-pairs-stat-arb received Friday-close waiver consideration.
- [x] Source citation is precise enough to reproduce (PDF pp. 123-127 rule lists + Further Optimization + 3 worked examples with explicit pip arithmetic; verbatim quotes preserved)
- [x] No near-duplicate of existing approved card (`strategy-seeds/cards/`: SRC03 williams-vol-bo uses single prior-bar range scaled by N% with NO containment requirement; SRC03 williams-spec-trap uses 6-20-bar BOX consolidation NOT inside-day strict containment; no existing card uses inside-day pattern as range-contraction precondition)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); session-time-gate for H1 variant only (London/NY open windows); optional directional-bias-filter (range_position / MACD-histogram-sign) and tight-range-pair-cohort filter as P3 sweep axes"
  trade_entry:
    used: true
    notes: "consecutive-inside-day count >= INSIDE_DAYS_MIN → bracket stop-buy at prev_inside_high + 10p AND stop-sell at prev_inside_low - 10p; D1 evaluation; long/short symmetric; whichever side fires first opens position; OTHER side becomes stop-and-reverse trigger"
  trade_management:
    used: true
    notes: "stop-and-reverse on opposite-extreme breach (Lien rule 3) with 1-unit (V5 default) or 2-unit (P3 variant, risk_mode_dual flagged) reversal lot; TP1 = 2R partial close + move-rest-to-BE; trail remainder via 2-bar-low/high (default Lien Ch 14 textbook precedent) or ATR(14)·M (variant)"
  trade_close:
    used: true
    notes: "exit on initial stop-and-reverse trigger (which simultaneously opens reversal leg) OR TP1 partial + trail-fired-on-remainder; reversal leg: protect-profit trail per Lien sub-rule, no fixed TP"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # LOAD-BEARING — D1 swing; Lien EURGBP example holds across "three weeks" (PDF p. 125). Default V5 friday_close ENABLED; waiver candidacy at P3 if multi-day edge appears.
  - risk_mode_dual                            # LOAD-BEARING for the Lien-verbatim 2-lot reversal variant. Lien rule 3: "Place stop and reverse order for two lots". V5 default RISK_PERCENT/RISK_FIXED sizing applies single-unit; 2-unit reversal is non-standard. Card defaults to 1-unit reversal (V5-compliant); 2-unit exposed only as P3 sweep variant with explicit risk_mode_dual flag.
  - enhancement_doctrine                      # LOAD-BEARING on entry/reversal pip offsets (10 / 10) — Lien's pip values are calibrated for major-FX volatility scale. Cross-pair generalization (especially to JPY pairs and crosses) may require ATR-scaled offsets. P3 sweep `breakout_offset_pips` / `reverse_offset_pips` axes test this. Any post-PASS retune is enhancement_doctrine.
  - news_pause_default                        # NOT LOAD-BEARING — Lien (PDF p. 123) suggests pro-news entry on D1 ("breakouts ahead of major economic releases") but V5 hard rule overrides; default P8 news-pause applies. Listed for CTO completeness; standard framework gating handles it.

at_risk_explanation: |
  friday_close — D1 swing strategy with multi-day holds. Lien's worked examples hold from
  breakout day until 2R target hit, often days to weeks. Default V5 friday_close ENABLED;
  waiver sweep variant if PASS_G0 reveals multi-day-hold edge. Precedent: SRC03_S03
  williams-cdc-pattern and SRC02_S01 chan-pairs-stat-arb both received P3 waiver consideration.

  risk_mode_dual — Lien's verbatim "stop and reverse order for two lots" doubles position size
  on the reversal leg, intended to recover the failed-breakout loss AND catch the alternate-direction
  move. V5's RISK_PERCENT/RISK_FIXED sizing model is single-unit-per-trigger; 2-unit reversal
  violates this. Card defaults to 1-unit reversal (V5-compliant; equivalent to Lien rule 3 with
  REVERSE_LOTS=1) and exposes 2-unit only as P3 sweep variant. CTO ratification required if
  2-unit variant outperforms in P3 (would require either a documented hard-rule waiver or a
  decision to retain only the V5-compliant 1-unit version).

  enhancement_doctrine — Lien's verbatim 10-pip offsets (entry + reversal) are calibrated for
  major-FX intraday volatility. Cross-pair generalization (JPY pairs with different pip values
  in absolute terms; commodity-currency volatility profiles) may require ATR-scaled offsets. P3
  sweep `breakout_offset_pips` / `reverse_offset_pips` axes test this. Once a live offset is
  fixed, any subsequent retune is enhancement_doctrine.

  news_pause_default — Lien (PDF p. 123) framing for daily-chart traders suggests pro-news
  entry: "Traders using the daily charts could look for breakouts ahead of major economic
  releases". V5 hard rule overrides this; default P8 news-pause applies. No conflict at
  implementation; flagged for CTO completeness.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default + optional H1 session-time-gate + directional-bias-filter axes
  entry: TBD                                  # consecutive-inside-day boolean test (compare bar[t].high <= bar[t-1].high AND bar[t].low >= bar[t-1].low) + bracket-order placement at prev-inside-day extremes + 10p offset; ~80-150 LOC in MQL5
  management: TBD                             # stop-and-reverse logic with 1-unit (default) or 2-unit (P3 variant) reversal lot; TP1 = 2R partial close + BE move; 2-bar-low/high trail (default) or ATR-trail (variant); reversal-leg protect-profit trail
  close: TBD                                  # standard SL/TP/trail; reversal leg has no fixed TP, only protect-profit trail
estimated_complexity: medium                  # bracket-and-reverse logic + stop-and-reverse trigger management + dual-direction trail bookkeeping adds nontrivial LOC vs simple long-only or symmetric-without-reverse strategies
estimated_test_runtime: 2-4h                  # P3 sweep ≈ 4×5×5×5×2×5×4×4×2 ≈ 32,000 cells; D1 bars; 5+ years; FX cohort — modest compute due to D1 timeframe
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
- 2026-04-28: SRC04_S05 reuses existing `narrow-range-breakout` flag with card-level parameter
  `range_contraction_pattern = "consecutive-inside-days"` rather than proposing a new flag.
  Rationale: the existing flag definition explicitly admits "range-contraction / NR-bar pattern"
  as a class. Inside-day is the strictest sub-variant (full containment vs. NR-N narrowest-range);
  per the controlled-vocabulary discipline (mine flags from V4 SM_XXX evidence; do not
  proliferate without deployment evidence), card-level parameterization is preferred over a
  new sub-flag like `inside-day-breakout`. If P3 / P3.5 reveals materially different edge
  characteristics between inside-day variant and NR4/NR7 variant, a sub-flag proposal can be
  raised at SRC04 closeout for CEO ratification.

- 2026-04-28: Lien's "stop and reverse order for two lots" (Ch 12 rule 3) introduces a
  position-doubling reversal mechanism that stresses V5's risk_mode_dual hard rule. The card
  defaults to 1-unit reversal (V5-compliant) and exposes 2-unit only as a P3 sweep variant
  with explicit risk_mode_dual flag at hard_rules_at_risk. CTO ratification required if 2-unit
  variant outperforms — either via documented hard-rule waiver or by retaining only the
  V5-compliant 1-unit version per pipeline G0 verdict.

- 2026-04-28: Lien provides NO numeric aggregate performance claim — only per-trade pip-P&L
  on three worked examples (+90, +78 net after reversal, +200 pips) and the descriptive
  risk-reward framing ("risk is generally pretty high ... but the profit potentials ... are
  usually fairly large", PDF p. 127). Per BASIS rule, no extrapolated number is asserted.

- 2026-04-28: Friday-close is load-bearing — Lien's worked examples hold from breakout day
  until 2R target hit (EURGBP example PDF p. 125 holds "three weeks"). Default ENABLED;
  waiver sweep variant exposed for P3 evaluation if multi-day-hold edge appears. Precedent:
  SRC03_S03 williams-cdc-pattern + SRC02_S01 chan-pairs-stat-arb both received P3 waiver
  consideration on similar multi-day swing thesis.

- 2026-04-28: V5-architecture-fit profile is FAVOURABLE — single-symbol forex, D1 bars, no
  multi-leg / multi-stock / cointegration architecture concerns. The bracket-and-reverse
  logic adds modest LOC but is straightforward state-machine bookkeeping. Expected G0 yield
  CLEAN with friday_close + risk_mode_dual flagged for CEO ratification on the
  Lien-verbatim 2-unit variant.

- 2026-04-28: Lien's pro-news entry framing (PDF p. 123: "breakouts ahead of major economic
  releases") is overridden by V5 P8 news-pause default. Card adopts V5 standard discipline;
  no waiver requested.
```
