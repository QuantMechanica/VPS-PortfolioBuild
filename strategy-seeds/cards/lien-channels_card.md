# Strategy Card — Lien Channels (narrow-channel breakout, intraday/daily, bracket entry at channel ±10p)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC04/raw/ch13-16_technical.txt` (verbatim Lien Ch 15 § "Strategy Rules" Long-only rule list with explicit "short rules are the reverse" instruction + 3 worked examples on USDCAD / EURGBP / EURUSD M15 charts).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3 / DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC04_S08
ea_id: TBD
slug: lien-channels
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - narrow-range-breakout                     # Lien Ch 15 PDF p. 139 rule 1: "First, identify a channel on either an intraday or daily chart. The price should be contained within a narrow range." Lien's verbatim framing references "trendline" + "parallel line" implying SLOPED channels, but all 3 worked examples (USDCAD / EURGBP / EURUSD on M15) use HORIZONTAL n-bar high/low ranges. Card-level parameter `range_definition = "n-bar-horizontal-range"` (default; matches all 3 worked examples) vs `linear-regression-channel` (P3 variant; matches the trendline framing). This is the SECOND `narrow-range-breakout` card in SRC04 alongside SRC04_S05 inside-day-breakout, distinguished by `range_contraction_pattern` parameter (`n-bar-horizontal-range` here vs `consecutive-inside-days` for S05).
  - symmetric-long-short                      # Lien Ch 15 PDF p. 139 rule 4: "The short rules are the reverse" — explicit symmetric long/short
  - atr-hard-stop                             # Lien rule 3: "Place a stop at the lower channel line" — fixed price stop anchored to opposite channel boundary; V5 maps to ATR(14)·M variant
  - friday-close-flatten                      # M15 intraday strategy; Lien examples close within hours-to-day; default V5 friday_close applies cleanly (not load-bearing)
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Lien, Kathy (3rd ed., 2015). Day Trading and Swing Trading the Currency Market: Technical and Fundamental Strategies to Profit from Market Moves. Wiley Trading. Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 15 'Technical Trading Strategy: Channels' (PDF pp. 139-141) including § chapter intro / channel-during-Asian-then-breakout-during-London thesis (PDF p. 139) + § channel definition + 4-rule strategy rule list (PDF pp. 139-140) + § 'Examples' three worked examples (USDCAD M15 Fig 15.1 PDF p. 140; EURGBP M15 Fig 15.2 PDF pp. 140-141; EURUSD M15 Fig 15.3 PDF p. 141 — including conservative-vs-aggressive trader management commentary)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC04/raw/ch13-16_technical.txt` lines 237-285 (chapter intro + thesis + channel-construction definition + 4-rule strategy rules), lines 287-342 (three worked examples with explicit pip arithmetic + conservative-vs-aggressive trade-management discussion). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Day Trading and Swing Trading t - Kathy Lien.pdf`.

## 2. Concept

Lien (PDF p. 139) frames the strategy as exploiting volatility-compression breakouts: "currencies rarely spend much time in tight trading ranges and have the tendency to develop strong trends." A narrow channel signals coiled-spring vol compression; the breakout direction tends to carry follow-through. Common scenario: channel forms during quiet Asian session → breakout fires during London or U.S. session, often catalyzed by major economic releases.

Mechanical translation: identify a narrow-range channel on M15+ (or D1) — Lien's verbatim text says "draw a trendline, and then draw a line that is parallel" implying sloped channels, but all 3 worked examples reduce to HORIZONTAL high/low pairs over a multi-bar window (USDCAD: 30-pip range over Asian-session bars; EURGBP: 12-pip range; EURUSD: 18-pip range). Card adopts horizontal n-bar-range as default; sloped linear-regression channel as P3 variant.

Bracket order: stop-buy at channel_high + 10p AND stop-sell at channel_low - 10p; whichever fires first opens the position. Stop is at OPPOSITE channel boundary (so risk = channel width + 10-pip entry offset). TP target is "double the amount risked" (= 2R fixed) — Lien notes (PDF p. 141) that for risks > 20 pips this can be hard to achieve on intraday, so "more conservative" management exits half at 1R and trails the rest.

Verbatim Lien framing on volatility-compression-then-trend rationale (PDF p. 139):

> "Channel trading is a less exotic but popular trading technique for currencies. The reason why it can work is because currencies rarely spend much time in tight trading ranges and have the tendency to develop strong trends. By reviewing a few charts, traders can see that channels can easily be identified and occur frequently. A common scenario would be channel trading during the Asian session and a breakout in either the London or U.S. session. There are many instances where economic releases are one of the most common triggers for a break of the channel."

## 3. Markets & Timeframes

```yaml
markets:
  - forex                                     # Lien Ch 15 universe is forex; 3 worked examples on USDCAD / EURGBP / EURUSD majors+crosses
timeframes:
  - M15                                       # Lien primary: all 3 worked examples on M15 charts
  - M30                                       # plausible variant; out-of-source extrapolation
  - H1                                        # plausible intermediate; Lien rule 1: "intraday or daily chart"
  - H4                                        # plausible variant; Lien admits "daily chart"
  - D1                                        # Lien rule 1 explicitly admits "daily chart"
session_window:                                # Lien preferred: Asian-session channel formation + London/NY breakout
  channel_window: "Asian session (variable, e.g., 22:00-06:00 GMT)"
  breakout_window: "London/NY session (06:00-21:00 GMT)"
                                              # Lien implies but does not strictly require — exposed as P3 sweep variant
                                              # also: pre-economic-release channel formation → post-release breakout
primary_target_symbols:
  - "USDCAD.DWX (Lien example: M15, channel 1.2028-1.2056 = 30-pip range, long entry @ 1.2066, stop @ 1.2028 = 38p risk, target @ 1.2142 = 2R hit; PDF p. 140)"
  - "EURGBP.DWX (Lien example: M15, channel 0.7148-0.7160 = 12-pip range, long entry @ 0.7170, stop @ 0.7160 = 10p risk, target @ 2R = +20p; PDF pp. 140-141)"
  - "EURUSD.DWX (Lien example: M15, channel 1.1188-1.1206 = 18-pip range, short entry @ 1.1178, stop @ 1.1206 = 28p risk, did NOT reach 2R target before stopping out — Lien uses this to argue conservative-management is preferable when risk > 20p; PDF p. 141)"
  - "GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX (multi-major generalization implicit in Lien's chapter framing)"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Lien's PDF pp. 139-140 rule list with horizontal-n-bar-range mechanical translation per worked examples.

```text
PARAMETERS:
- BAR                  = M15        // Lien primary; sweep [M15, M30, H1, H4, D1]
- CHANNEL_LOOKBACK     = 16         // not in source; default = 4 hours of M15 = 16 bars (matches Asian-session ~4-hour quiet window)
                                    //   sweep [8, 12, 16, 20, 30, 50, 100]
- CHANNEL_MAX_PIPS     = 30         // Lien examples: 12 / 18 / 30 pips ranges; default 30 = upper observed
                                    //   sweep [10, 15, 20, 30, 50, 75, 100, no_cap]
- CHANNEL_MIN_PIPS     = 10         // not in source; default 10 to filter Asian-quiet noise
                                    //   sweep [5, 10, 15, 20]
- ENTRY_OFFSET_PIPS    = 10         // Lien rule 2 (long): "Enter long as the price breaks above the upper channel line by 10 pips"
                                    //   sweep [5, 10, 15, 20]

DEFINITION (n-bar horizontal channel as of close of bar t):
- channel_high = max(high[t-N+1], ..., high[t])
- channel_low  = min(low[t-N+1], ..., low[t])
- channel_width_pips = (channel_high - channel_low) in pips

EACH-BAR (evaluated on close of bar t — bracket orders go live for bar t+1):
- if CHANNEL_MIN_PIPS <= channel_width_pips <= CHANNEL_MAX_PIPS:
    PLACE bracket orders, valid for next session:

    LONG side stop-buy at:    channel_high + ENTRY_OFFSET_PIPS
                                                  // Lien rule 2 (long): "Enter long as the price breaks above the upper channel line by 10 pips"
    initial stop (long):      channel_low         // Lien rule 3: "Place a stop at the lower channel line"
                                                  //   risk_long = (channel_high - channel_low) + ENTRY_OFFSET_PIPS pips

    SHORT side stop-sell at:  channel_low - ENTRY_OFFSET_PIPS
                                                  // Lien rule 4: "The short rules are the reverse" → mirror of rule 2
    initial stop (short):     channel_high        // mirror of rule 3
                                                  //   risk_short = (channel_high - channel_low) + ENTRY_OFFSET_PIPS pips

    On fill (whichever fires first): cancel opposite side; advance to IN_POSITION.
    On NO fill within next M bars: re-evaluate channel from new bar t' (rolling window).

OPTIONAL session-time gate (P3 sweep axis):
- arm_only_during ∈ {always, asian_session_channel_only, pre_economic_release_only}
                                                  // Lien thesis preference: Asian-formed channel + London-NY breakout
                                                  //   default = always (rolling-window evaluation regardless of session)
```

**Channel-definition translation note**: Lien's verbatim text (PDF p. 139) says "Channels are created when we draw a trendline, and then draw a line that is parallel to that trendline" — implying SLOPED channels (trendline + parallel line). However, all 3 worked examples (USDCAD / EURGBP / EURUSD) compute ranges as `(high, low)` pairs over a multi-bar window with NO slope — purely HORIZONTAL high/low ranges. The internal inconsistency between Lien's verbose framing and her worked examples is resolved by adopting the worked-example definition (horizontal n-bar range) as default; sloped linear-regression channel exposed as P3 sweep variant. Per BASIS rule, the discrepancy is documented; § 9 preserves the verbatim "trendline + parallel line" text.

## 5. Exit Rules

Lien rule 4 (verbatim, PDF p. 140):

> "4. Exit the position when it moves by double the amount risked.
>
> The short rules are the reverse."

Plus conservative-management commentary at example commentary level (PDF p. 141):

> "More conservative traders could exit half of the position when it moves by the amount risked, or 38 pips, and trail the stop on the remainder of the position."

> "Whenever the risk is greater than 20 pips, it may be more prudent to exit half and trail the stop."

Pseudocode:

```text
PARAMETERS:
- TP_RR_LIEN_DEFAULT = 2.0          // Lien rule 4: "double the amount risked" — full-position exit at 2R
- TP_RR_CONSERVATIVE = 1.0          // Lien commentary: "exit half of the position when it moves by the amount risked"
- MANAGEMENT_MODE    = "conservative"
                                    // default: conservative (TP1 + BE + trail) per Lien commentary on risk > 20p
                                    // Lien-verbatim default: "lien_2r_full_exit" exposed as sweep variant
- TRAIL_METHOD       = "two_bar_extreme"
                                    // not specified in Lien rule 4; commentary only says "trail the stop on the remainder"
                                    // default 2-bar-extreme matching Lien Ch 13/14 textbook precedent

EACH-BAR (in long position, conservative-management default):
- HARD STOP — fires at initial_stop_price (channel_low for long)
- TP1 (close half + BE move) at +1R from entry (Lien commentary):
    initial_risk = entry - channel_low
    if (high[t] - entry) >= initial_risk:
      CLOSE_HALF
      move_remaining_stop to BE (entry)
      activate trailing stop on remainder
- TRAIL on remainder (2-bar-low default; sweep variants available)
- exit on trail-stop fire OR initial_stop fire

EACH-BAR (in long position, lien_2r_full_exit variant):
- HARD STOP at initial_stop
- TP at +2R: full-position exit (Lien rule 4 verbatim)

EACH-BAR (in short position): mirror.

FRIDAY CLOSE: M15 intraday with same-session-or-next-session close (Lien examples reach 2R
or fail within hours; EURUSD example "stops us out a few days later" is the longest hold but
still well within standard friday_close window). Default V5 friday_close applies cleanly.
Not load-bearing.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed (single position; bracket-order is single-shot per channel evaluation)
- gridding: NOT allowed
- Lien thesis preference (PDF p. 139): "channel trading during the Asian session and a breakout in either the London or U.S. session" — OPTIONAL P3 sweep axis: `arm_only_during ∈ {always, asian_session_channel_only, pre_economic_release_only}`
- Lien narrow-range filter: `CHANNEL_MIN_PIPS <= channel_width <= CHANNEL_MAX_PIPS` — restricts entries to genuinely narrow channels (filters out trending or wide-range periods)
- Lien (PDF p. 139): "If a channel has formed and a big U.S. number (per say) is expected to be released, and the currency pair is at the top of a channel, the probability of a break is high, so traders should be looking to buy the break out, not fade it." — pre-news-release entry framing is FAVORED by Lien; V5 P8 default news-pause window may suppress these — flagged as `news_pause_default` interaction in § 12. Pre-news entry is exposed as P3 sweep variant (default: V5 standard P8 pause; variant: pre-news-window arming).
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding, no stacking)
- bracket order: stop-buy at channel_high + 10p AND stop-sell at channel_low - 10p, both staged at session boundary; whichever fires first opens the position; alternate side is cancelled at fill
- position size: V5 RISK_PERCENT / RISK_FIXED standard; channel-width-dependent risk varies (10-30+ pips per Lien examples) → V5 RISK_PERCENT auto-scales position size to keep dollar-risk constant
- conservative management (default per Lien commentary): TP1 = +1R partial close + move-rest-to-BE + trail
- Lien-verbatim management (P3 variant): full position exit at +2R (no partial; no trail)
- Trail on remainder: 2-bar-extreme default; ATR-trail / donchian-N variants exposed as sweep
- Friday Close: ENABLED by default; intraday timeframe → no waiver candidacy
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: channel_lookback
  default: 16                                 # not in source; default 4h of M15 = 16 bars (Asian-session approximation)
  sweep_range: [8, 12, 16, 20, 30, 50, 100]
- name: channel_max_pips
  default: 30                                 # Lien examples upper bound
  sweep_range: [10, 15, 20, 30, 50, 75, 100, no_cap]
- name: channel_min_pips
  default: 10                                 # not in source; floor to filter noise
  sweep_range: [5, 10, 15, 20]
- name: entry_offset_pips
  default: 10                                 # Lien rule 2: "by 10 pips"
  sweep_range: [5, 10, 15, 20]
- name: management_mode
  default: conservative                       # Lien commentary preferred for risk > 20p
  sweep_range: [conservative, lien_2r_full_exit]
- name: tp1_rr
  default: 1.0                                # used in conservative mode (Lien commentary: "amount risked")
  sweep_range: [0.75, 1.0, 1.25, 1.5]
- name: tp_full_rr
  default: 2.0                                # used in lien_2r_full_exit mode (Lien rule 4: "double the amount risked")
  sweep_range: [1.5, 2.0, 2.5, 3.0]
- name: trail_method
  default: two_bar_extreme                    # not in source; matches Lien Ch 13/14 precedent
  sweep_range: [two_bar_extreme, three_bar_extreme, atr14x2_trail, atr14x3_trail, donchian5_trail]
- name: channel_definition
  default: n-bar-horizontal-range             # matches all 3 worked examples
  sweep_range: [n-bar-horizontal-range, linear-regression-channel-2sigma, linear-regression-channel-1sigma]
- name: arm_only_during
  default: always                             # broad rolling-window evaluation
  sweep_range: [always, asian_session_channel_only, pre_economic_release_only]
- name: tf
  default: M15                                # Lien examples
  sweep_range: [M15, M30, H1, H4, D1]
```

P3.5 (CSR) axis: full Darwinex FX cohort (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`) plus crosses (`EURGBP.DWX`, `EURJPY.DWX`, `GBPJPY.DWX` if Darwinex offers).

## 9. Author Claims (verbatim, with quote marks)

Strategy framing — channel-then-breakout thesis, PDF p. 139:

> "Channel trading is a less exotic but popular trading technique for currencies. The reason why it can work is because currencies rarely spend much time in tight trading ranges and have the tendency to develop strong trends. By reviewing a few charts, traders can see that channels can easily be identified and occur frequently. A common scenario would be channel trading during the Asian session and a breakout in either the London or U.S. session. There are many instances where economic releases are one of the most common triggers for a break of the channel. Therefore, it is imperative that traders keep on top of economic releases. If a channel has formed and a big U.S. number (per say) is expected to be released, and the currency pair is at the top of a channel, the probability of a break is high, so traders should be looking to buy the break out, not fade it."

Channel definition (verbose framing — implies sloped channels; worked examples use horizontal), PDF p. 139:

> "Channels are created when we draw a trendline, and then draw a line that is parallel to that trendline. Most if not all of the price activity of the currency pair should fall between the two channel lines. We will seek to identify situations where the price is trading within a narrow channel, and then trade in the direction of a breakout from the channel. This strategy can be particularly effective when used prior to a fundamental market event such as the release of major economic news, or prior to the 'open' of a major financial market."

Strategy rule list (long-only with explicit "short rules are the reverse"), PDF pp. 139-140:

> "Here are some rules for using this technique to find long trades:
> 1. First, identify a channel on either an intraday or daily chart. The price should be contained within a narrow range.
> 2. Enter long as the price breaks above the upper channel line by 10 pips.
> 3. Place a stop at the lower channel line.
> 4. Exit the position when it moves by double the amount risked.
>
> The short rules are the reverse."

Worked-example pip P&L, USDCAD M15 Fig 15.1 PDF p. 140:

> "The total range of the channel is approximately 30 pips with the low being 1.2028 and the high 1.2056. In accordance with our strategy, we place entry orders 10 pips above and below the channel at 1.2018 and 1.2066. The order to buy gets triggered first, and almost immediately we place a stop order at the low of the channel or 1.2028, which means we are risking 38 pips on the trade. USDCAD then proceeds to rally and reaches our target of double the range at 1.2142. More conservative traders could exit half of the position when it moves by the amount risked, or 38 pips, and trail the stop on the remainder of the position."

Worked-example pip P&L, EURGBP M15 Fig 15.2 PDF pp. 140-141:

> "The total range between the two lines is 12 pips with the low being 0.7148 and the high 0.7160. In accordance with our strategy, we place entry orders 10 pips above and below the channel at 0.7138 and 0.7170. The order to buy gets triggered first and almost immediately we place a stop at the low of the channel or 0.7160 for 10-pip risk. EURGBP then proceeds to rally and reaches our target of 20 pips or double the amount risked."

Worked-example pip P&L, EURUSD M15 Fig 15.3 PDF p. 141 (failed 2R — argument for conservative management):

> "The total range during this four-hour period is 18 pips with a high of 1.1206 and a low of 1.1188. In accordance with our strategy, we place entry orders 10 pips above and below the channel at 1.1216 and 1.1178. The order to sell gets triggered first and almost immediately, we place a stop order at the channel high of 1.1206 for a risk of 28 pips. The EURUSD then proceeds to sell off significantly but only makes it to a low of 1.1132 before stopping us out a few days later. We chose to show this example because it explains why the more conservative approach of exiting half of the position when it moves by the amount risk is more desirable, even though it has worse risk reward. A move of 58 pips is sizable on an intraday basis and may be difficult to achieve. Whenever the risk is greater than 20 pips, it may be more prudent to exit half and trail the stop."

**Lien provides NO numeric aggregate performance claim** — only the descriptive thesis ("channels can easily be identified and occur frequently", PDF p. 139) and per-trade pip-P&L on three worked examples (USDCAD: +76 pips at 2R; EURGBP: +20 pips at 2R; EURUSD: -28 pips stopped out under 2R management, would have been +28 pips first half + trail under conservative management). Per BASIS rule, no extrapolated performance number is asserted in this card; pipeline P2-P9 produce the actual edge measurement.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.2                              # rough estimate; vol-compression breakout with 2R fixed-target structure typically 1.0-1.4 PF; conservative management variant likely 1.1-1.3 PF
expected_dd_pct: 15                           # rough estimate; M15 intraday with 10-30+ pip stops + multi-pair cohort
expected_trade_frequency: 100-300/year/symbol # rough estimate; rolling-window M15 evaluation with channel-width filter — depends heavily on width thresholds
risk_class: medium                            # M15 intraday; latency-sensitive at narrow-channel-width edge (channels < 15p have low pip-tolerance for fill latency)
gridding: false
scalping: false                               # M15 bars; not scalping per V5 framework
ml_required: false                            # rolling-window arithmetic + threshold checks; no fitted parameters (linear-regression-channel variant uses OLS but is closed-form, not fitted in ML sense)
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (n-bar rolling high/low + width threshold + bracket stop-orders at +/-10p; deterministic given M15+ bar data). Lien's verbose "trendline + parallel line" framing is resolved to horizontal n-bar range per worked-example precedent.
- [x] No Machine Learning required
- [x] If gridding: not applicable (single position; bracket is single-shot)
- [x] If scalping: not applicable (M15+ bars)
- [x] Friday Close compatibility: typical same-session close per Lien examples (longest is "a few days later" stop-out on EURUSD); default applies
- [x] Source citation is precise enough to reproduce (PDF pp. 139-141 rule list + 3 worked examples + conservative-vs-aggressive management commentary; verbatim quotes preserved in § 9 with channel-definition-translation note)
- [x] No near-duplicate of existing approved card — DISTINCT FROM SRC04_S05 inside-day-breakout (which uses CONSECUTIVE-INSIDE-DAY containment as range-contraction precondition; this card uses N-BAR ROLLING HIGH/LOW range with explicit width threshold). Both share `narrow-range-breakout` flag with card-level parameter `range_contraction_pattern` distinguishing.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default + channel-width range filter (CHANNEL_MIN_PIPS <= width <= CHANNEL_MAX_PIPS); optional Asian-session-channel-only or pre-economic-release sub-gates"
  trade_entry:
    used: true
    notes: "n-bar rolling high/low channel computation + width threshold + bracket stop-orders at channel±10p; long/short symmetric"
  trade_management:
    used: true
    notes: "conservative default: TP1 = +1R partial close + move-rest-to-BE + 2-bar-extreme trail (per Lien commentary on risk > 20p); lien_2r_full_exit P3 variant matches Lien rule 4 verbatim"
  trade_close:
    used: true
    notes: "exit on initial channel-opposite-line stop OR TP1+trail (conservative) OR full 2R exit (variant)"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # NOT load-bearing — typical intraday close per Lien examples. Listed for CTO completeness.
  - enhancement_doctrine                      # LOAD-BEARING on entry-offset (10p) and channel-width thresholds (10-30 pips). Lien's pip values are calibrated for major-FX intraday volatility; cross-pair generalization (JPY pairs and crosses) may require ATR-scaled thresholds. P3 sweep tests this. Once fixed, retune is enhancement_doctrine.
  - news_pause_default                        # POTENTIALLY LOAD-BEARING — Lien (PDF p. 139) FAVORS pre-economic-release entry: "If a channel has formed and a big U.S. number is expected to be released ... traders should be looking to buy the break out". V5 default P8 news-pause may suppress these. Default V5 P8 applies; pre-news-window arming exposed as P3 variant for thesis-validation testing.
  - scalping_p5b_latency                      # POTENTIALLY LOAD-BEARING — narrow channels (e.g., 12-pip range like EURGBP example) yield 22-pip risk after 10p offset. Tight pip-tolerance for fill latency. P5b stress with calibrated VPS latency simulation recommended at IMPL.

at_risk_explanation: |
  friday_close — Intraday M15 strategy with typical same-session close. Default V5
  friday_close applies cleanly. Listed for completeness.

  enhancement_doctrine — Lien's verbatim 10-pip entry offset and 10-30-pip channel-width
  thresholds are calibrated for major-FX intraday volatility. Cross-pair generalization
  (especially JPY pairs with different absolute pip values, and high-vol pairs like GBPJPY)
  may require ATR-scaled offsets. P3 sweep tests this.

  news_pause_default — Lien EXPLICITLY favors pre-news entry for this strategy: "If a
  channel has formed and a big U.S. number is expected to be released ... the probability
  of a break is high, so traders should be looking to buy the break out, not fade it"
  (PDF p. 139). V5 default P8 news-pause window blocks this entry pattern. Default V5
  applies; `pre-news-window-arming` exposed as P3 sweep variant for thesis-validation. If
  P3 reveals material edge in pre-news arming, CEO + CTO ratification required for a
  documented news-pause waiver on this card.

  scalping_p5b_latency — Narrow channels (e.g., EURGBP 12-pip range example) compress
  pip-tolerance for fill latency to single-digit pips. P5b stress with calibrated VPS
  latency simulation recommended at IMPL. CTO sanity-check at G0.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default + channel-width range filter + optional Asian-session / pre-news arming gates
  entry: TBD                                  # rolling-window high/low computation (cheap; ~10-20 LOC), width threshold + bracket stop-order placement; ~80-120 LOC in MQL5
  management: TBD                             # conservative default: TP1 + BE + 2-bar trail; lien_2r_full_exit variant: full position exit at 2R
  close: TBD                                  # standard SL/TP plus trail variants
estimated_complexity: small                   # rolling-window range computation is trivial; bracket-order management standard; no state machine beyond bracket
estimated_test_runtime: 4-8h                  # P3 sweep ~50,000 cells; M15 bars over 5+ years across FX cohort
data_requirements: standard                   # M15+ OHLC on Darwinex FX symbols
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
- 2026-04-28: SRC04_S08 reuses existing `narrow-range-breakout` flag (second card in SRC04
  alongside SRC04_S05 inside-day-breakout). Card-level parameter `range_contraction_pattern`
  distinguishes the two: `n-bar-horizontal-range` (this card) vs `consecutive-inside-days`
  (S05). NO vocab gap proposed; the existing flag's definition admits both range-contraction
  variants per the canonical V4 SM_404 ADX5NR6 precedent.

- 2026-04-28: Lien Ch 15's verbose "trendline + parallel line" channel definition (PDF p. 139)
  is internally inconsistent with all 3 worked examples, which compute ranges as horizontal
  high/low pairs over multi-bar windows (no slope). Card adopts horizontal-n-bar-range as
  default (matches worked examples) and exposes `linear-regression-channel-{1,2}sigma` as
  P3 sweep variants (matches the verbose trendline framing). Per BASIS rule, the source
  inconsistency is documented; § 9 preserves the verbatim "trendline + parallel line" text.

- 2026-04-28: Lien Ch 15 introduces a structural conflict with V5 default P8 news-pause
  policy: Lien EXPLICITLY favors pre-economic-release entry on this strategy (PDF p. 139:
  'If a channel has formed and a big U.S. number is expected to be released ... traders
  should be looking to buy the break out, not fade it'). V5 default P8 blocks this. Card
  adopts V5 default (P8 pause applies) and exposes `pre-news-window-arming` as P3 sweep
  variant. CEO + CTO ratification required if P3 reveals material edge in the pre-news
  variant — would need a documented news-pause waiver, similar in scope to other
  `news_pause_default` waiver decisions in the framework.

- 2026-04-28: Lien provides explicit conservative-vs-aggressive management commentary
  (PDF p. 141): for narrow channels (risk <= 20p), full 2R fixed-target exit (Lien rule 4
  verbatim) works; for wider channels (risk > 20p), conservative TP1 + BE + trail is
  preferred. Card EXPOSES BOTH as `management_mode ∈ {conservative, lien_2r_full_exit}`
  with conservative as default per Lien's own commentary preference. This is unusual for
  a Lien strategy card — Ch 9-13 strategies all use TP1 + BE + trail uniformly; Ch 15 is
  the first where Lien herself recommends a regime-conditional exit policy.

- 2026-04-28: Lien provides NO numeric aggregate performance claim — only thesis ('channels
  can easily be identified and occur frequently', PDF p. 139) and per-trade pip-P&L on
  three examples (USDCAD: +76 pips at 2R; EURGBP: +20 pips at 2R; EURUSD: -28 pips
  stopped out under 2R, would-have-been +28 first half + trail under conservative).
  Per BASIS rule, no extrapolated number is asserted.

- 2026-04-28: Latency sensitivity (`scalping_p5b_latency`) flagged for narrow-channel
  variants: EURGBP example (12-pip range) yields 22-pip risk after 10p offset — single-digit
  pip-tolerance for VPS latency. P5b stress with calibrated VPS latency simulation
  recommended at IMPL.

- 2026-04-28: V5-architecture-fit profile is FAVOURABLE — single-symbol forex, M15 bars,
  no multi-leg / multi-stock / cointegration architecture concerns. Rolling-window range
  computation is trivial; bracket-order management is standard. Expected G0 yield CLEAN
  with `news_pause_default` interaction flagged for CEO-decision on the pre-news variant
  axis and `scalping_p5b_latency` flagged for IMPL-time stress validation.
```
