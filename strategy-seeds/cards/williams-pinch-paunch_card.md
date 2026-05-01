# Strategy Card — Williams Pinch & Paunch (DMI/ADX-vs-Stochastic divergence + ADX-cross-40 confirmation)

> Drafted by Research Agent on 2026-05-01 from `strategy-seeds/sources/SRC03/raw/full_text.txt` lines 297-355 (verbatim Williams Inner Circle Workshop "§ 4. THE PINCH AND THE PAUNCH TOP AND BOTTOM INDICATOR" PDF pp. 8-9). Closes a SRC03 first-pass classification revisit: Pinch/Paunch was tabulated in `strategy-seeds/sources/SRC03/source.md` line 182 as `LOW (filter only)` and consciously NOT extracted per completion-report § 137 ("workshop §§ 1-8 are setup-tools, not entry triggers; integrated as filters per-card"). Williams' own text contradicts the filter-only classification: PDF p. 8 verbatim _"When the weekly 7-bar ADX line rises above 40 a buy point of lasting duration is at hand"_ and PDF p. 9 verbatim _"If you will just limit yourself to these trades you will trade less often and catch most all major highs and lows"_ — both are explicit entry-strategy framings, not filter-overlay framings. Per DL-033 Rule 1, every distinct mechanical strategy with a verbatim entry rule gets a card; Pipeline gates do the filtering. Authority for revisiting: QUA-664 (OWNER bounded supersede of DL-044, Card 2 of 2 in 7-day backlog).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per DL-032 + DL-030 Class 2 Review-only execution policy). CEO may reject the re-classification — if the filter-only verdict is preserved, this card converts to a no-card SKIP record with documented Williams-text rationale; the SRC03 completion-report would then be left as-is.

## Card Header

```yaml
strategy_id: SRC03_S17
ea_id: TBD
slug: williams-pinch-paunch
status: DRAFT
created: 2026-05-01
created_by: Research
last_updated: 2026-05-01

strategy_type_flags:
  - atr-hard-stop                              # Williams' canonical $1,500 dollar-stop framing (PDF p. 21) — V5 ATR-equivalent translation
  - symmetric-long-short                       # Williams: Pinch/Paunch rules stated as symmetric pair (sell on top divergence, buy on bottom divergence)
  - friday-close-flatten                       # V5 default; Williams calls Paunch a "buy point of LASTING DURATION" (PDF p. 8) — multi-week-to-multi-month hold typical; STRONG `friday_close` waiver candidate; default applies, CEO decision at G0
  - signal-reversal-exit                       # Williams: "Additionally, it will pay to wait a turn down in the index to signal the trend move is over" (PDF p. 8) — ADX-turn-down is the natural exit
  # PROPOSED NEW VOCAB GAP (entry-mechanism): `momentum-strength-divergence` — see § 16 Lessons + future-vocab-watches
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF pp. 8-9 (Inner Circle Workshop companion volume), § '4. THE PINCH AND THE PAUNCH TOP AND BOTTOM INDICATOR'. Cross-references: PDF pp. 6-7 § '3. THE \"END OF THE TREND\" INDICATOR' (DMI > 60 absolute-threshold predecessor; structurally distinct from § 4 divergence pattern, treated as a separate-card future candidate not folded here). Williams cites worked-example chart pages 65-73 (Pinch) and 74-86 (Paunch) which fall in the OCR-degraded range of the supplied PDF — Research could not extract numerical examples, only the indicator-construction rules + entry-rule families."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/full_text.txt` lines 297-355 (Pinch + Paunch + refined-Paunch entry rules verbatim) and lines 1108 (Williams' own retrospective placement: "[I use] break outs Pro/Go, seasonal indications and all the other tricks of our trades"). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf`.

## 2. Concept

A **divergence + confirmation system** between two indicators that measure structurally different things: the **DMI/ADX line** (which "shows if a market is trending — does it have any strength to what it is doing?" — PDF p. 8) and the **Stochastic oscillator** (which "measures how far the market is getting away from price x days ago, regardless of the integrity of the move" — PDF p. 8). Williams' thesis: when these two indicators DIVERGE in specific patterns, the divergence flags an exhaustion or accumulation regime that produces high-quality intermediate-to-long-term entry signals.

The two named patterns:

- **Pinch (sell)** — Stochastic rising and above 75% (overbought) WHILE DMI is declining. Geometric: the two lines pinch together. Williams' interpretation: "the price move that pushed Stochastic higher had no 'umph' or meaning behind it and any sells coming should be good ones" (PDF p. 8).

- **Paunch (buy)** — Stochastic declining and below 25% (oversold) WHILE DMI is rapidly advancing. Geometric: a widening (paunch) between the two lines. Williams' interpretation: "selling panic ... selling climax is at hand and a market bottom very near" (PDF p. 8).

- **Refined Paunch (buy, lasting-duration variant)** — when the **weekly 7-bar ADX** line crosses up through 40, AND market is "substantially oversold" (Stochastic < 25%) at the cross. Williams: "a buy point of lasting duration is at hand. The +40 reading does not cause the entry, only tells us the time is ripe" (PDF p. 8).

Williams' verbatim core, PDF p. 8:

> "I have noticed one more relationship in the DMI (ADX) and Stochastic innerworkings that can be of real value to the trader looking for intermediate term set up plays."
>
> "THE PINCH...So consider what it means when Stochastic is rising, and above 75%, the usual overbought area, while the DMI has been declining. This suggest to me the price move that pushed stochastic higher had no 'umph' or meaning behind it and any sells coming should be good ones. This appears as a 'pinch' on charts as the DMI is coming down, the Stochastic coming up, as the lines pinch together."
>
> "A buying indication is just the opposite, Stochastic declining and below 25%, while DMI is rapidly advancing. This suggests a selling panic as, usually, price declines on a declining DMI. This appears as a widening between these two lines, a 'paunch' effect."
>
> "THE PAUNCH SIGNAL...When the weekly 7-bar ADX line rises above 40 a buy point of lasting duration is at hand. The +40 reading does not cause the entry, only tells us the time is ripe."
>
> "CRITICAL POINT...This pattern, of going from below 40 to above 40 only creates buy signals if the market is substantially oversold as the crossing takes place. What is going on is that not only is the market oversold, Stochastic below 25%, but downside volatility has picked up."

This card extracts the **two entry families** Williams names and treats the refined-Paunch (weekly 7-bar ADX up-cross 40 AND Stochastic < 25) as the deterministic primary entry. The bare Pinch and bare Paunch (no ADX-cross qualifier) are exposed as P3 alternative-entry axes since Williams' "rapidly advancing" DMI qualifier is enhancement_doctrine load-bearing without a numeric threshold.

## 3. Markets & Timeframes

```yaml
markets:
  - index_futures                              # Williams' deployment context: S&P 500. V5 proxy: US500.DWX
  - bond_futures                               # Williams' deployment context: T-Bonds. V5 proxy: bond CFD if Darwinex offers; else flag dwx_suffix_discipline
  - commodities                                # Williams' workshop deployment universe: Wheat / Cotton / Pork Bellies / Copper / Sugar / Coffee / Beans / Gold (PDF p. 8 closing remark "ON DAILY CHARTS TOO" implies multi-market). V5 proxy: GOLD.DWX, OIL.DWX, NATGAS.DWX where Darwinex offers.
  - forex                                      # Williams: "CONCERNING THE CURRENCIES — Currencies do well with the WVI, but perhaps do" (text truncated at line 153 of raw; framing is positive on multi-currency applicability)
timeframes:
  - W1                                         # Williams PRIMARY: "the weekly 7-bar ADX line" (PDF p. 8 refined-Paunch); weekly preferred for "lasting duration" framing
  - D1                                         # Williams: "ON DAILY CHARTS TOO — Yes, these formations do appear on daily and even interdaily charts and are usually pretty good set up patterns to alert us to important trend changes for the time frame we are trading" (PDF p. 9)
session_window: not specified                  # signal evaluated at bar close
primary_target_symbols:
  - "S&P 500 futures (Williams' deployment) → US500.DWX V5 proxy"
  - "T-Bonds futures (Williams' deployment) → bond CFD if available; else flag dwx_suffix_discipline"
  - "GOLD.DWX, EURUSD.DWX, USDJPY.DWX, GBPUSD.DWX as multi-market generalization (Williams: 'these formations do appear on daily and even interdaily charts')"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Williams PDF p. 8 § 4 + the refined-Paunch ADX-cross qualifier. Default = refined-Paunch (deterministic given thresholds); bare Pinch and bare Paunch exposed as P3 alternative-entry axes.

```text
PARAMETERS:
- ADX_PERIOD          = 7         // Williams: "weekly 7-bar ADX line" (PDF p. 8, verbatim)
- ADX_CROSS_THRESHOLD = 40        // Williams: "rises above 40" (PDF p. 8, verbatim)
- STOCH_PERIOD        = 14        // Williams does not specify; 14 is the standard short-term default
- STOCH_K_SMOOTHING   = 3         // %K smoothing; default 3 (standard)
- STOCH_D_SMOOTHING   = 3         // %D smoothing; default 3 (standard)
- STOCH_OB            = 75        // Williams: "above 75%, the usual overbought area" (PDF p. 8)
- STOCH_OS            = 25        // Williams: "below 25%" (PDF p. 8)
- DMI_DECLINE_BARS    = 5         // P3 sweep axis; Williams qualitative "DMI is coming down"
- DMI_RAPID_BARS      = 5         // P3 sweep axis; Williams qualitative "DMI rapidly advancing"
- BAR                 = W1        // Williams primary; D1 as P3 alt-timeframe per "ON DAILY CHARTS TOO"

INDICATOR (computed at bar close each weekly bar):
- adx[t]      = ADX(ADX_PERIOD)[t]                           // 7-bar ADX (Williams' explicit period)
- adx[t-1]    = ADX(ADX_PERIOD)[t-1]
- stoch_k[t]  = Stochastic_%K(STOCH_PERIOD, STOCH_K_SMOOTHING)[t]
- dmi_plus[t] = +DI(ADX_PERIOD)[t]                           // optional axis for direction-confirm
- dmi_minus[t]= -DI(ADX_PERIOD)[t]                           // optional axis for direction-confirm
- adx_recent_decline = adx[t] < adx[t-DMI_DECLINE_BARS]      // "DMI has been declining" (qualitative; bar-count default)
- adx_recent_advance = adx[t] > adx[t-DMI_RAPID_BARS]        // "DMI rapidly advancing" (qualitative; bar-count default)

ENTRY — RULE C (REFINED PAUNCH BUY, default; deterministic):
- if adx[t-1] < ADX_CROSS_THRESHOLD                          // prior bar: ADX below 40
    AND adx[t] >= ADX_CROSS_THRESHOLD                        // current bar: ADX crosses up through 40
    AND stoch_k[t] < STOCH_OS                                // Williams: "substantially oversold ... Stochastic below 25%"
    AND not in position
  then OPEN_LONG at next-bar open

ENTRY — RULE D (REFINED PAUNCH SELL, symmetric mirror; deterministic):
- if adx[t-1] < ADX_CROSS_THRESHOLD                          // mirror: ADX cross-up still applies (climax detection)
    AND adx[t] >= ADX_CROSS_THRESHOLD
    AND stoch_k[t] > STOCH_OB                                // overbought instead of oversold
    AND not in position
  then OPEN_SHORT at next-bar open
   // Williams states the long-side refined-Paunch verbatim and not the short-side; the mirror is structural
   // (workshop § 4 opens with symmetric Pinch sell + Paunch buy framing, implying symmetric refined-Pinch/Paunch).
   // Card defaults Rule D as ON for V5 long/short symmetry; OFF as a P3 sweep variant for buy-only-validation.

ENTRY — RULE A (BARE PINCH SELL, P3 alt-entry axis):
- if stoch_k[t] > STOCH_OB
    AND adx_recent_decline                                   // Williams: "DMI has been declining"
    AND not in position
  then OPEN_SHORT at next-bar open

ENTRY — RULE B (BARE PAUNCH BUY, P3 alt-entry axis):
- if stoch_k[t] < STOCH_OS
    AND adx_recent_advance                                   // Williams: "DMI is rapidly advancing"
    AND not in position
  then OPEN_LONG at next-bar open

EXCLUSIVITY: one open position per direction per symbol; no pyramiding.
DUAL-FIRE HANDLING: refined-Paunch (Rule C/D) and bare-Pinch/Paunch (Rule A/B) firing in the same direction
  on the same bar = signal confluence → take the position. Opposite directions = no entry; wait for next bar.
```

Williams uses qualitative "rapidly advancing" / "has been declining" wording without specific bar-count. Card adopts **5-bar lookback** as conservative; sweep axis covers [3, 5, 10, 15] bars. The refined-Paunch ADX-cross-40 is the deterministic primary entry per Williams' explicit threshold-ratification.

## 5. Exit Rules

Williams names ONE Pinch/Paunch-specific exit on PDF p. 8: "it will pay to wait a turn down in the index to signal the trend move is over or [at] least in the terminal stages of market atrophy" — a signal-reversal exit using the ADX line. Default exit combines this signal-reversal with the SRC03-family standard ATR-equivalent hard-stop and 3-bar non-inside trailing stop.

> **3-bar trail spec ratified at `framework/V5_TM_MODULES.md` § TM-3BAR-TRAIL** (Williams PDF p. 21; CEO ratified 2026-04-28 in QUA-298 closeout). The pseudocode below is retained inline and matches the canonical TM-module spec.

```text
DEFAULT EXIT (ADX-turn-down signal-reversal + 3-bar trail + hard-stop):
PARAMETERS:
- HARD_STOP_USD     = 1500       // Williams PDF p. 21 generic "$1,500 as final proof I am wrong"
                                 //   V5 translation: ATR-scaled hard stop at entry; ATR(14) × {1.5..3.0} sweep
- TRAIL_BARS        = 3          // Williams' "Amazing 3 Bar Entry/Exit Technique" PDF p. 21
- TRAIL_NO_INSIDE   = true       // Williams: "None of these can be an inside day"
- TRAIL_ACTIVATE    = first_close_in_profit
- ADX_TURNDOWN_EXIT = true       // Williams: "wait a turn down in the index" (PDF p. 8)
- ADX_TURNDOWN_BARS = 2          // bars of consecutive ADX decline to confirm turn-down (P3 axis)

EACH-BAR (in position):
- HARD STOP — fires at HARD_STOP_USD-equivalent ATR distance from entry; never moves
- TRAIL (activates after first profitable close OR position has held 3 non-inside bars):
  if LONG:
    trail_anchor_close = highest_close_since_entry
    trail_window = three most recent non-inside bars ending at the bar of trail_anchor_close
    trail_level = MIN( true_low(b) for b in trail_window )
    if Low[t] <= trail_level: CLOSE_LONG at trail_level (or next-bar open if gap-through)
  if SHORT: mirror — lowest_close_since_entry / true_high / max(true_high)
- ADX_TURNDOWN_EXIT (default ON):
  if LONG  and adx[t] < adx[t-1] for ADX_TURNDOWN_BARS consecutive bars: CLOSE_LONG at next-bar open
  if SHORT and adx[t] < adx[t-1] for ADX_TURNDOWN_BARS consecutive bars: CLOSE_SHORT at next-bar open
   // Williams' "turn down in the index" signals trend-move-end; symmetric for both sides per workshop framing.

FRIDAY CLOSE: V5 default applies (force-flat at Friday 21:00 broker time). Williams CALLS the
refined-Paunch a "buy point of LASTING DURATION" (PDF p. 8) — typical hold may span multiple
weeks-to-months. This is the STRONGEST `friday_close` waiver case in SRC03 (stronger than
SRC04_S09 lien-perfect-order MA-stack which got a conditional waiver candidacy). CEO decision
at G0:
  (a) accept default Friday-close as-is and let pipeline measure the impact (will likely
      produce many premature mid-week / first-Friday closures and degrade PF severely);
  (b) grant unconditional waiver based on Williams' "lasting duration" thesis;
  (c) grant conditional waiver tied to ADX-still-rising state (only HOLD over weekend if ADX
      is still trending in the position direction);
  (d) set a hold-cap (e.g., close at first Friday after K weeks held).
This card defaults to (a) per V5 standard and surfaces the case for review; no waiver asserted
unilaterally by Research.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed (one position per direction per symbol)
- gridding: NOT allowed
- BURN-IN: skip first max(ADX_PERIOD, STOCH_PERIOD) × 3 = 42 bars after deployment for indicator stability
- "Sentiment + Commercial confirmation" optional confluence filter (P3 sweep axis): trade only
  when at least ONE of Williams' workshop §§ 1-2 setup tools agrees with entry direction:
  - Sentiment < 33 (extreme bearish public) for longs / Sentiment > 75 (extreme bullish public) for shorts
  - COT 12-month extremes (Commercials extreme net-long → bullish for longs; extreme net-short → bearish for shorts)
  - Williams' verbatim PDF p. 8: "Another ideal confirmation comes from the Market Sentiment or Commercial data confirming a high or low"
  - Off by default; on as axis variant for high-conviction filter test
- Below-20 ADX + Commercial-heavy-buying alternative-entry note (Williams PDF p. 9): "AN ADDITIONAL USE — In recent years I have noticed that a very low DMI/ADX reading, below 20, at the same time the Commercials are heavy buyers sets up beautiful and immediate buy signals"
  - Documented for CEO awareness; NOT folded into this card's primary entry (rule structure differs — absolute-low-ADX vs. ADX-cross-up-through-40)
  - Future-card candidate: `williams-low-adx-cot` if CEO approves a successor extraction in a future Research budget
- ATR floor (P3 sweep axis): skip entries when ATR(14) < ATR(50) × 0.5
  // Standard V5 framework filter; ADX-based strategies whipsaw in extreme low-vol regimes.
```

## 7. Trade Management Rules

```text
- one open position per direction per symbol at any time (no pyramiding, no stacking)
- position size: maps to V5 risk-mode framework at sizing-time;
  Williams' explicit money-management formula (PDF pp. 28-31) uses fixed-fractional with
  20% of equity divided by largest accepted loss = number of contracts. V5 adapts to its
  own RISK_PERCENT / RISK_FIXED switch.
- Friday Close: forced flat per V5 default (waiver candidacy for CEO at G0; see § 5 + § 12)
- gridding: NOT allowed
- "lasting duration" Williams hold-horizon implication: V5 does not impose a maximum hold;
  trail / signal-reversal (ADX-turn-down) / hard-stop / Friday-close handle exit
- maximum-hold time-stop (P3 sweep axis): [off, 12 weeks, 26 weeks, 52 weeks] — Williams' "lasting duration"
  is unbounded but V5 portfolio sanity may require capping
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: adx_period
  default: 7                                   # Williams: "weekly 7-bar ADX" (PDF p. 8, verbatim)
  sweep_range: [5, 7, 10, 14]                  # bracket [reduced, ADX-standard]
- name: adx_cross_threshold
  default: 40                                  # Williams: "rises above 40" (PDF p. 8, verbatim)
  sweep_range: [30, 35, 40, 45, 50]
- name: stoch_period
  default: 14                                  # Williams does not specify; 14 = standard short-term
  sweep_range: [9, 14, 21]
- name: stoch_ob
  default: 75                                  # Williams: "above 75%" (PDF p. 8, verbatim)
  sweep_range: [70, 75, 80]
- name: stoch_os
  default: 25                                  # Williams: "below 25%" (PDF p. 8, verbatim)
  sweep_range: [20, 25, 30]
- name: entry_rule
  default: refined_paunch_only                 # deterministic primary
  sweep_range: [refined_paunch_only, bare_paunch_only, both_or_either, both_and_confluence]
- name: dmi_decline_bars
  default: 5                                   # Williams qualitative; default 5 weekly bars (~5 weeks)
  sweep_range: [3, 5, 8, 10]                   # only relevant when entry_rule includes bare-Pinch/Paunch
- name: dmi_rapid_bars
  default: 5                                   # Williams qualitative; default 5 weekly bars
  sweep_range: [3, 5, 8, 10]                   # only relevant when entry_rule includes bare-Pinch/Paunch
- name: timeframe
  default: W1                                  # Williams primary
  sweep_range: [W1, D1]                        # Williams: "ON DAILY CHARTS TOO"
- name: long_short_symmetry
  default: symmetric                           # Rule C + Rule D both ON
  sweep_range: [symmetric, long_only, short_only]
- name: adx_turndown_exit
  default: true                                # Williams' named exit
  sweep_range: [true, false]
- name: adx_turndown_bars
  default: 2                                   # bars of consecutive ADX decline
  sweep_range: [1, 2, 3, 5]
- name: trail_bars
  default: 3                                   # Williams TM-3BAR-TRAIL
  sweep_range: [2, 3, 4, 5]
- name: hard_stop_atr_mult
  default: 2.5                                 # ATR-equivalent of Williams' $1,500 (slightly wider for weekly bars)
  sweep_range: [2.0, 2.5, 3.0, 4.0]
- name: confluence_filter
  default: off
  sweep_range: [off, sentiment_extreme, cot_12mo, ANY_2_AGREE]
- name: max_hold_weeks
  default: off
  sweep_range: [off, 12, 26, 52]               # cap for "lasting duration" thesis sanity
```

P3.5 (CSR) axis: re-run on Darwinex symbol cohort. Pinch/Paunch is generic across markets per Williams' "ON DAILY CHARTS TOO" multi-market framing. CSR validates whether the divergence + ADX-cross-40 edge survives across:
- Index CFDs: US500.DWX, US100.DWX, GER40.DWX, UK100.DWX
- Metals: GOLD.DWX, XAGUSD.DWX
- Energies: OIL.DWX, NATGAS.DWX (if Darwinex offers)
- Spot FX: EURUSD.DWX, USDJPY.DWX, GBPUSD.DWX, AUDUSD.DWX

## 9. Author Claims (verbatim, with quote marks)

Indicator-construction rationale + Pinch/Paunch geometric definitions, PDF p. 8:

> "I have noticed one more relationship in the DMI (ADX) and Stochastic innerworkings that can be of real value to the trader looking for intermediate term set up plays."
>
> "Keep in mind the DMI simply shows if a market is trending, in other words does it have any strength to what it is doing? If so it will be steadily increasing, if not it will be declining. Stochastic on the other hand measures how far the market is getting away from price x days ago regardless of the integrity of the move."
>
> "THE PINCH...So consider what it means when Stochastic is rising, and above 75%, the usual overbought area, while the DMI has been declining. This suggest to me the price move that pushed stochastic higher had no 'umph' or meaning behind it and any sells coming should be good ones. This appears as a 'pinch' on charts as the DMI is coming down, the Stochastic coming up, as the lines pinch together."
>
> "A buying indication is just the opposite, Stochastic declining and below 25%, while DMI is rapidly advancing. This suggests a selling panic as, usually, price declines on a declining DMI. This appears as a widening between these two lines, a 'paunch' effect."

Refined-Paunch (deterministic primary entry), PDF p. 8:

> "THE PAUNCH SIGNAL...When the weekly 7-bar ADX line rises above 40 a buy point of lasting duration is at hand. The +40 reading does not cause the entry, only tells us the time is ripe."
>
> "CRITICAL POINT...This pattern, of going from below 40 to above 40 only creates buy signals if the market is substantially oversold as the crossing takes place. What is going on is that not only is the market oversold, Stochastic below 25%, but downside volatility has picked up. This means a selling climax is at hand and a market bottom very near as not only have prices been suppressed, sellers have become irrational, almost dumping at the market, hence the DMI picks up."

Exit rationale, PDF p. 8:

> "Additionally, it will pay to wait a turn down in the index to signal the trend move is over or [at] least in the terminal stages of market atrophy."

Strategy-class self-framing (entry-strategy, NOT filter-only), PDF pp. 8-9:

> "IF YOU WILL JUST LIMIT YOURSELF TO THESE TRADES YOU WILL TRADE LESS OFTEN AND CATCH MOST ALL MAJOR HIGHS AND LOWS."
>
> "ON DAILY CHARTS TOO — Yes, these formations do appear on daily and even interdaily charts and are usually pretty good set up patterns to alert us to important trend changes for the time frame we are trading. My use here is to help us further evaluate and zero on major trend changes using weekly bar chart data."

Sentiment + COT confirmation note, PDF p. 8:

> "Another ideal confirmation comes from the Market Sentiment or Commercial data confirming a high or low."

Future-card-candidate companion rule (NOT extracted in this card), PDF p. 9:

> "AN ADDITIONAL USE — In recent years I have noticed that a very low DMI/ADX reading, below 20, at the same time the Commercials are heavy buyers sets up beautiful and immediate buy signals. This makes sense, what's going on is an apparently lackless market where it appears nothing is going on, but under the surface the commercials have been accumulating telling us to expect higher prices."

**Williams provides NO numeric performance claim** for Pinch/Paunch on its own — chart pages 65-73 (Pinch examples) and 74-86 (Paunch examples) referenced for visual evidence fall in the OCR-degraded range of the supplied PDF. Williams' qualitative framing is strongly positive ("you will trade less often and catch most all major highs and lows", "buy point of lasting duration") but no win-rate, Sharpe, drawdown, or cumulative-P&L number is asserted. Per BASIS rule, no extrapolated performance number is asserted in this card; Pipeline P2-P9 produce the actual edge measurement.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                              # rough estimate; refined-Paunch (ADX-cross-40 + Stoch-extreme) is a strict-conditions strategy with low signal density and high quality per Williams' framing; expected positive expectancy on weekly bars
expected_dd_pct: 18                           # rough estimate; weekly-bar divergence-confirmation systems typically show modest DD between sparse signals; concentrated P&L on the rare high-quality entries
expected_trade_frequency: 1-3/year/symbol     # rough estimate; Williams: "you will trade less often"; ADX-cross-40 events on weekly bars are rare (typically once or twice per major trend); refined-Paunch even rarer
risk_class: medium                            # weekly-bar divergence-confirmation entry; not scalping, not gridding; Williams' "lasting duration" implies multi-month hold which loads `friday_close` discussion
gridding: false
scalping: false                               # W1 / D1 bars
ml_required: false                            # ADX + Stochastic + threshold logic; no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (deterministic ADX-cross threshold + Stochastic threshold + signal-reversal exit; bare-Pinch/Paunch's "rapidly advancing" qualifier is parameterised as a bar-count lookback, not discretionary)
- [x] No Machine Learning required
- [x] If gridding: not applicable (one open position per direction)
- [x] If scalping: not applicable (W1 / D1 bars)
- [x] Friday Close compatibility: STRONG waiver candidacy per § 5 + § 12 — Williams' "lasting duration" thesis implies multi-week-to-multi-month hold; default V5 force-flat may fundamentally degrade the strategy. CEO decision at G0 on waiver path; default Friday-close applies as-is until ratified.
- [x] Source citation is precise enough to reproduce (PDF p. 8 § 4 indicator + entry rules + exit rationale; verbatim quotes preserved; OCR-degraded chart-pages 65-86 limitation explicitly documented; SRC03 completion-report filter-only classification re-classification rationale in card § 16)
- [x] No near-duplicate of existing approved card (`strategy-seeds/cards/`: SRC03 williams-* family covers volatility-breakout, calendar-bias, OOPS gap-fade, Failure-Day-Family rejection-bar, narrow-range, MA-stack, single-MA-trend filter, derived-flow-divergence-crossover Pro-Go (SRC03_S16) — none use ADX-vs-Stochastic divergence + ADX-cross-40 confirmation)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); 42-bar burn-in for indicator stability; optional Sentiment+COT confluence and ATR floor as P3 sweep axes"
  trade_entry:
    used: true
    notes: "refined-Paunch ADX-cross-40 + Stoch<25 (Rule C/D, default deterministic) OR bare-Pinch/Paunch (Rules A/B, P3 alternative-entry axes); next-bar open entry"
  trade_management:
    used: false
    notes: "no break-even, no partial close, no pyramiding; trail engages at first profitable close; ADX-turn-down monitored each bar"
  trade_close:
    used: true
    notes: "ADX-turn-down signal-reversal exit (Williams' named exit) + 3-bar non-inside trail + ATR-equivalent hard-stop"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                      # Williams' deployment is futures (S&P / T-Bonds / commodities). V5 maps to .DWX CFDs / spot FX. Per-symbol map at G0 + CSR (P3.5) to validate generalization — Pinch/Paunch indicators (ADX + Stochastic) are universal-symbol-applicable but the empirical edge may be CME-microstructure-dependent.
  - friday_close                               # LOAD-BEARING (STRONGEST in SRC03 — stronger than SRC04_S09 lien-perfect-order MA-stack). Williams explicitly calls the refined-Paunch a "buy point of LASTING DURATION" — multi-week-to-multi-month hold is the THESIS. Default V5 force-flat will likely degrade PF severely. CEO decision at G0: (a) accept default; (b) unconditional waiver; (c) ADX-still-rising-conditional weekend-hold; (d) hold-cap. Card defaults to (a) per V5 standard and surfaces case for review.
  - enhancement_doctrine                       # LOAD-BEARING on under-specified axes: stoch_period (Williams unspecified; 14 default + sweep [9, 14, 21]); dmi_decline_bars / dmi_rapid_bars (Williams qualitative "DMI has been declining" / "rapidly advancing"; 5-bar default + sweep [3, 5, 8, 10]); long_short_symmetry (Williams states refined-Paunch buy explicitly; symmetric refined-Pinch sell is structural mirror). All three are P3-swept; any post-PASS retune is enhancement_doctrine.
  - news_pause_default                         # standard V5 P8 news-blackout applies. Pinch/Paunch is built on weekly bars typically; news event would reflect in the ADX/Stochastic indicator state via underlying daily bars but no Pinch/Paunch-specific override is asserted.

at_risk_explanation: |
  dwx_suffix_discipline — Williams' rules originate on US futures (CME / CBOT). V5 deploys on
  Darwinex .DWX CFD / spot FX symbols. ADX and Stochastic are universal indicators (computed
  from OHLC); the only symbol-specific concern is whether the divergence + ADX-cross-40
  empirical edge is a US-futures-microstructure artifact. CSR P3.5 cohort (indices, metals,
  FX, energies) validates this. Williams' own framing is multi-market positive ("ON DAILY
  CHARTS TOO ... these formations do appear on daily and even interdaily charts ... important
  trend changes for the time frame we are trading").

  friday_close — STRONGEST `friday_close` waiver case in SRC03. Williams' refined-Paunch
  thesis depends on holding through "lasting duration" trend moves. On weekly-bar timeframe
  with V5 default Friday-close-flatten, every signal closes at first Friday after entry —
  fundamentally reducing the strategy from a "ride the major bottom-to-top trend" to
  "intra-week ADX-cross-40 spike fade." The empirical edge difference may be a 50%+ PF
  reduction. CEO decision required at G0 between four options listed in § 5; this card
  asserts none unilaterally per V5 default. If CEO declines a waiver, the strategy may
  still deliver positive expectancy under V5 default (intra-week ADX-spike effect) but
  Williams' "lasting duration" thesis is no longer the operative thesis — that's a
  legitimate strategy variant, just not Williams' own.

  enhancement_doctrine — Three under-specified axes:
    1. stoch_period — Williams cites Stochastic thresholds (75/25) but does not specify
       the Stochastic period (window of price-vs-x-days-ago). Default = 14 (standard);
       sweep [9, 14, 21]. Any post-PASS retune is enhancement_doctrine.
    2. dmi_decline_bars / dmi_rapid_bars — Williams uses qualitative "DMI has been
       declining" / "DMI rapidly advancing" without bar-count threshold. Default = 5 weekly
       bars; sweep [3, 5, 8, 10]. Refined-Paunch (Rule C/D, primary) does not depend on
       these — only the bare-Pinch/Paunch (Rules A/B, alt-entry axes) do.
    3. long_short_symmetry — Williams states the refined-Paunch BUY rule explicitly. The
       symmetric refined-Pinch SELL rule (ADX cross-up through 40 + Stoch > 75) is a
     structural mirror inferred from workshop § 4's symmetric Pinch sell + Paunch buy
       framing. Default = symmetric (Rules C+D both ON); sweep [symmetric, long_only,
       short_only]. If CEO prefers a strict-Williams-explicit-only interpretation, the
       long_only variant captures it.
  All three are documented; the card defaults are the conservative-mechanical readings; P3
  exposes the sensitivity space.

  news_pause_default — V5 P8 news-blackout applies at high-impact macro events. Standard
  framework gating handles event-windows; no Pinch/Paunch-specific override is asserted.
  CTO at G0 may want to confirm that P8 gating accounts for weekly-bar timeframe
  semantics (a daily news event may affect 1 of 5 underlying daily bars in a weekly bar;
  the weekly close is contaminated; conservative reading: skip the next weekly bar's
  Pinch/Paunch evaluation — this is a CTO implementation detail).
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                                # standard V5 default + 42-bar indicator burn-in
  entry: TBD                                   # ADX(7) cross-up-through-40 detector + Stochastic(14) overbought/oversold gate; symmetric long/short
  management: TBD                              # n/a (no break-even, no partial close)
  close: TBD                                   # ADX-turn-down signal-reversal exit + 3-bar non-inside trail + hard-stop
estimated_complexity: small                    # standard ADX + Stochastic indicator calls + threshold/cross logic + 3-bar trail; ~150 LOC MQL5
estimated_test_runtime: 6-12h                  # P3 sweep (~10,000 cells under default refined-paunch_only; ~30,000 cells with bare-Pinch/Paunch axes; W1 + D1 timeframes; 10+ years; multi-market) — moderate
data_requirements: standard                    # W1 (and optionally D1) OHLC on Darwinex .DWX symbols; no external feeds
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-05-01 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-05-01 | DRAFT (awaiting CEO + Quality-Business review) | this card |
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
- 2026-05-01: SRC03_S17 closes a SRC03 first-pass classification revisit. The original SRC03
  source.md candidate table line 182 tabulated "Workshop §4 The Pinch and the Paunch (DMI vs
  Stochastic)" as `LOW (filter only)`, and completion_report.md § 137 stated workshop §§ 1-8
  "are FILTER conditions, not entry triggers; integrated into per-card § 6 Filters where they
  bind". Williams' own text contradicts this filter-only classification:
    - PDF p. 8 verbatim: "When the weekly 7-bar ADX line rises above 40 a buy point of
      lasting duration is at hand. The +40 reading does not cause the entry, only tells us
      the time is ripe." — explicit ENTRY framing with a deterministic threshold.
    - PDF p. 9 verbatim: "IF YOU WILL JUST LIMIT YOURSELF TO THESE TRADES YOU WILL TRADE LESS
      OFTEN AND CATCH MOST ALL MAJOR HIGHS AND LOWS." — Williams explicitly prescribes Pinch/
      Paunch as a STANDALONE trading strategy, not as a filter overlay.
  Per DL-033 Rule 1 (every distinct mechanical strategy that passes V5 hard rules gets a card;
  pipeline gates do the filtering, not Research's prior beliefs), Pinch/Paunch qualifies as
  a Strategy Card. This card is Research's good-faith re-read; CEO retains full authority to
  reject the re-classification at G0 if the filter-only verdict is preferred. If rejected,
  this card converts to a no-card SKIP record with documented Williams-text rationale.
  Authority for revisiting: QUA-664 (OWNER bounded supersede of DL-044, Card 2 of 2 in 7-day
  backlog, 2026-05-01).

- 2026-05-01: PROPOSED NEW VOCAB GAP (entry-mechanism) — `momentum-strength-divergence`.
  Pinch/Paunch is a divergence between two indicators that measure orthogonal market
  properties: trend strength (ADX/DMI) vs. price-displacement-from-x-days-ago (Stochastic).
  This is structurally distinct from existing entry-mechanism flags:
  - `vol-expansion-breakout` / `narrow-range-breakout` / `donchian-breakout` (price-based
    breakouts; no two-indicator divergence);
  - `flow-divergence-crossover` (proposed in SRC03_S16 williams-pro-go; that flag is on
    derived-flow series — public/professional decomposition; Pinch/Paunch is on standard
    indicators, different mechanism family);
  - `n-period-min-reversion` / `n-period-max-continuation` (price-based extreme reversion;
    no divergence between two indicators).
  V4 had no equivalent EA per `strategy_type_flags.md` Mining-provenance table — divergence
  detection between standard indicators is V5-net-new vocabulary. Vocab proposal deferred
  to a future SRC03 vocab back-port follow-up issue OR batched with SRC02/SRC03/SRC04
  future-vocab-watches at next ratification cycle. Until ratified, Header strategy_type_flags
  lists the strict-existing-vocabulary subset only.

- 2026-05-01: Workshop § 3 ("END OF THE TREND" Indicator) ALSO contains an entry rule that
  is NOT folded into this card. Williams PDF pp. 6-7 verbatim: "All you need look for is a
  DMI reading of over 60. Such readings have an excellent record of saying a top is at hand.
  Readings of > 60 in market declines indicate excellent buying opportunities at hand."
  This is structurally distinct from § 4 Pinch/Paunch (absolute DMI threshold > 60 vs.
  relative DMI-vs-Stochastic divergence). It is a SEPARATE-but-related card candidate
  (`williams-dmi-60` would be the slug). NOT extracted in QUA-664's 2-card scope; future
  Research budget can extract if CEO approves a successor extraction. The "AN ADDITIONAL
  USE" note on PDF p. 9 (low DMI/ADX < 20 + Commercials-heavy-buyers) is a THIRD distinct
  rule (absolute-low-DMI + COT-extremes); also a separate-card future candidate
  (`williams-low-adx-cot`). This card focuses on workshop § 4's Pinch/Paunch divergence
  pattern as the richest single-card extraction; § 3 and the "additional use" rule are
  noted in § 9 author-claims for evidentiary completeness.

- 2026-05-01: Williams provides NO numeric performance claim for Pinch/Paunch on its own —
  chart pages 65-73 (Pinch examples) and 74-86 (Paunch examples) Williams references for
  visual evidence fall in the OCR-degraded range of the supplied PDF (text-clean range is
  pp. 1-46 per SRC03 source.md § 2). Per BASIS rule, no extrapolated number is asserted in
  § 9; the entry rules + indicator definitions + exit rationale are the verbatim mechanical
  content available. Pipeline P2-P9 produce the actual edge measurement.

- 2026-05-01: V5-architecture-fit profile is FAVOURABLE — single-symbol, weekly bars (D1 as
  alt-timeframe sweep axis), standard indicators (ADX, Stochastic, DMI), no multi-leg /
  multi-stock / cointegration architecture concerns. CSR P3.5 generalization should expose
  whether the divergence + ADX-cross-40 edge holds across Darwinex .DWX CFD / spot FX cohort
  on both W1 and D1 timeframes. Primary CSR sensitivity dimension: timeframe (weekly being
  the rare-signal high-quality regime per Williams; daily being signal-denser per his "ON
  DAILY CHARTS TOO" remark).

- 2026-05-01: STRONG `friday_close` waiver candidacy — possibly the strongest in V5 corpus to
  date. Williams' own framing ("buy point of LASTING DURATION") is the multi-month-hold
  thesis that Friday-close-flatten directly nullifies. CEO at G0 has four documented paths
  (accept default, unconditional waiver, conditional ADX-rising waiver, hold-cap variant);
  this card asserts none unilaterally. Pipeline P3-P5 measurement under each variant would
  inform the durability question.
```
