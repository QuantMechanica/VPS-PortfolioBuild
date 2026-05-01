# Strategy Card — Lien Perfect Order (5-MA sequential-stack trend-confirmation entry, daily TF, multi-month hold)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC04/raw/ch13-16_technical.txt` (verbatim Lien Ch 16 § chapter intro + 5-rule strategy rule list + 3 worked examples on EURUSD / USDSGD / USDJPY daily charts).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3 / DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC04_S09
ea_id: 1015
slug: lien-perfect-order
status: APPROVED
created: 2026-04-28
created_by: Research
last_updated: 2026-05-01
g0_issue: QUA-641
g0_reviewed_at: 2026-05-01
g0_reviewer: CEO (DL-037)
g0_verdict: APPROVED

strategy_type_flags:
  - ma-stack-entry                            # vocabulary-gap PROPOSED — entry trigger: K consecutive moving averages of increasing periods are in MONOTONIC SEQUENTIAL ORDER (long: SMA(P1) > SMA(P2) > ... > SMA(PK) for P1 < P2 < ... < PK; short mirror). Lien's perfect-order canonical case: K=5 with periods (10, 20, 50, 100, 200). Entry fires N candles AFTER initial formation if stack still holds. Distinct from `trend-filter-ma` (single MA filter, e.g., Close > SMA(200), used as overlay rather than entry trigger); distinct from `cross-sectional-decile-sort` (universe-ranked relative-strength, not single-instrument MA stack); distinct from `vol-regime-gate` (vol-bucket classifier, not MA-based). V4 had no MA-stack-entry EA per `strategy_type_flags.md` Mining-provenance table — 5-MA sequential-stack as ENTRY trigger is net-new with SRC04 Lien Ch 16. Flagged at § 16; batch-ratified at SRC04 closeout.
  - signal-reversal-exit                      # Lien rule 5: "Exit the position when the perfect order no longer holds" — exit fires when ANY adjacent pair in the MA stack reverses (e.g., SMA(10) crosses below SMA(20) for longs). Worked examples confirm: EURUSD short exit on Oct 17 when 10 SMA moved above 20 SMA; USDSGD long exit on Mar 27 when 10 SMA crossed below 20 SMA; USDJPY long exit on Dec 19 when 10 SMA crossed below 20 SMA. The 10-vs-20 adjacent pair is the FIRST pair to break a perfect order (highest-frequency adjacent crossover); deeper stack breaks (50-vs-100, 100-vs-200) are slower-developing.
  - atr-hard-stop                             # Lien rule 4: "Initial stop is the low on the day of the initial crossover for longs and the high for shorts" — fixed price stop anchored to formation-bar extreme; V5 maps to ATR(14)·M variant via `stop_anchor` parameter sweep
  - symmetric-long-short                      # Lien Ch 16 PDF p. 144 explicit: "For an uptrend ... in a downtrend, the opposite is true"; rule 4: "for longs and the high for shorts"
  - friday-close-flatten                      # LOAD-BEARING — Lien examples hold for MULTIPLE MONTHS (EURUSD: Aug 2014 entry → Oct 17 exit ~2.5 months; USDSGD: Nov entry → Mar exit ~5 months; USDJPY: Oct entry → Dec exit ~2.5 months). Friday-close waiver candidacy at P3 — precedent: SRC03_S03 williams-cdc-pattern + SRC02_S01 chan-pairs-stat-arb + SRC04_S05/S07 inside-day/20-day-breakout
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Lien, Kathy (3rd ed., 2015). Day Trading and Swing Trading the Currency Market: Technical and Fundamental Strategies to Profit from Market Moves. Wiley Trading. Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 16 'Technical Trading Strategy: Perfect Order' (PDF pp. 143-148) including § chapter intro / perfect-order definition (PDF pp. 143-144) + 5-rule strategy rule list (PDF p. 144) + § 'Examples' three worked examples (EURUSD daily Fig 16.1 PDF pp. 144-145; USDSGD daily Fig 16.2 PDF pp. 145-146; USDJPY daily Fig 16.3 PDF pp. 146-147) + § closing risk-reward summary (PDF p. 148)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC04/raw/ch13-16_technical.txt` lines 347-384 (chapter intro: perfect-order definition + 5-rule strategy + ADX>20 confirmation + entry timing + stop placement + signal-reversal exit), lines 385-449 (three worked examples with explicit pip arithmetic + closing low-probability-high-profit risk-reward summary). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Day Trading and Swing Trading t - Kathy Lien.pdf`.

## 2. Concept

A "perfect order" in moving averages is a state where multiple MAs of increasing period are in strict monotonic sequential order. For an uptrend, Lien's canonical 5-MA stack (PDF p. 143) requires: SMA(10) > SMA(20) > SMA(50) > SMA(100) > SMA(200). For a downtrend the reverse holds. The premise (PDF pp. 143-144): "Having the moving averages stacked up in sequential order are generally a strong indicator of a trending environment. Not only does it indicate that the momentum is on the side of trend, but the moving averages also serve as multiple levels of support."

The strategy is a trend-CAPTURE pattern, not a trend-CONTINUATION pattern: enter shortly AFTER a fresh perfect-order formation (5 candles after, if it still holds — Lien rule 3). This timing rule is intended to filter false-formation cases where a stack briefly forms then breaks. Stop is at the formation-bar's opposite extreme. Exit when any adjacent MA pair breaks the perfect order — typically the 10-vs-20 pair (highest-frequency adjacent crossover).

ADX > 20 trend-strength confirmation is layered on (Lien rule 2: "Look for ADX pointing upwards, ideally greater than 20") — this is structurally similar to `atr-regime-mr-gate` but in the opposite direction (trend-confirmation, not range-confirmation). Documented as card-level filter; future-vocab-watch for `adx-trend-confirm-gate` if pattern recurs in SRC05+.

Verbatim Lien framing on perfect-order definition + thesis (PDF pp. 143-144):

> "A perfect order in moving averages is defined as a set of moving averages that is in sequential order. For an uptrend, a perfect order would be a situation in which the 10-day simple moving average (SMA) is at a higher price level than the 20-day SMA, which is higher than the 50-day SMA. Meanwhile, the 100-day SMA would be below the 50-day SMA, while the 200-day SMA would be below the 100-day SMA. In a downtrend, the opposite is true, where the 200-day SMA is at the highest level and the 10-day SMA is at the lowest level. Having the moving averages stacked up in sequential order are generally a strong indicator of a trending environment. Not only does it indicate that the momentum is on the side of trend, but the moving averages also serve as multiple levels of support. To optimize the perfect order strategy, traders should also look for ADX to be greater than 20 and trending upward. This represents a strong trend. ... Perfect orders do not happen often, and the premise of this strategy is to capture the perfect order when it first happens."

## 3. Markets & Timeframes

```yaml
markets:
  - forex                                     # Lien Ch 16 universe is forex; 3 worked examples on EURUSD / USDSGD / USDJPY majors+exotic
timeframes:
  - D1                                        # Lien primary: all 3 worked examples on daily charts; SMA periods are explicitly stated as "X-day"
  - W1                                        # plausible variant; out-of-source extrapolation (5-week perfect order would be far rarer)
session_window: not specified                 # D1 strategy; no intraday session restriction
primary_target_symbols:
  - "EURUSD.DWX (Lien example: D1, perfect order down formation Aug 2014, ADX > 20, short entry @ 1.3390 (5 candles after formation), stop @ 1.3432 (Aug 8 high = formation bar high), exit Oct 17 when 10 SMA crossed above 20 SMA at 1.2758, total profit +632 pips, risk 42 pips → 15.0R win; PDF pp. 144-145)"
  - "USDSGD.DWX (Lien example: D1, perfect order up formation Nov 6, ADX > 20, long entry @ 1.2916, formation bar's low 1.2911 was BELOW entry price so stop placed at 20-day SMA of 1.2822 — STOP-PLACEMENT EXCEPTION when formation-extreme would be on wrong side of entry; exit Mar 27 when 10 SMA crossed below 20 SMA at 1.3685, total move +770 pips, risk 89 pips → 8.65R win; PDF pp. 145-146)"
  - "USDJPY.DWX (Lien example: D1, perfect order up formation October, long entry @ 116.20 (5 candles after), stop @ 108.75 — implied wide stop, possibly 200-day SMA or formation-bar low; exit Dec 19 when 10 SMA crossed below 20 SMA at 119.45, profit +425 pips, risk 645 pips → 0.66R win — Lien acknowledges this 'was far from ideal'; PDF pp. 146-147)"
  - "GBPUSD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX (multi-major generalization implicit in Lien's chapter framing)"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Lien's PDF p. 144 5-rule list with stop-placement-exception note from USDSGD example.

```text
PARAMETERS:
- BAR                  = D1         // Lien primary
- MA_PERIODS           = [10, 20, 50, 100, 200]    // Lien Ch 16 PDF p. 143 canonical 5-MA stack
- MA_TYPE              = "SMA"       // Lien explicit: "simple moving average"
- ADX_PERIOD           = 14          // Lien rule 2 (default — though not specified, V5 standard)
- ADX_THRESHOLD        = 20          // Lien rule 2: "ideally greater than 20"
- ENTRY_DELAY_CANDLES  = 5           // Lien rule 3: "Buy five candles after the initial formation"
- STOP_ANCHOR          = "formation_bar_extreme_with_safe_fallback"
                                     // Lien rule 4: "Initial stop is the low on the day of the initial crossover for longs"
                                     //   USDSGD example: when formation-extreme is on the WRONG side of entry, fall back to SMA(20) extreme

DEFINITION (perfect-order long state on bar t):
- IsPerfectOrderLong(t) =
      SMA(close, 10)[t]  > SMA(close, 20)[t]
  AND SMA(close, 20)[t]  > SMA(close, 50)[t]
  AND SMA(close, 50)[t]  > SMA(close, 100)[t]
  AND SMA(close, 100)[t] > SMA(close, 200)[t]

DEFINITION (perfect-order short state on bar t): mirror — all "<" comparisons.

DEFINITION (initial formation bar):
- formation_long_bar = first bar t where IsPerfectOrderLong(t) is true
                                          AND IsPerfectOrderLong(t-1) is false
- formation_short_bar: mirror

STATE MACHINE (long side):
1. ARMED_AWAITING_FORMATION: monitor each D1 close for IsPerfectOrderLong(t).
   On detection: record formation_long_bar = t; record formation_low = low[t]; advance to ARMED_DELAY.
2. ARMED_DELAY: wait ENTRY_DELAY_CANDLES (= 5) bars. Each new bar t' in delay:
   - if IsPerfectOrderLong(t') is FALSE (stack broke during delay): cancel state; return to ARMED_AWAITING_FORMATION.
   - else continue counting.
3. ARMED_PENDING_ENTRY at bar t' = formation_long_bar + ENTRY_DELAY_CANDLES:
   - re-confirm: IsPerfectOrderLong(t') is true
   - re-confirm (Lien rule 2): ADX(ADX_PERIOD)[t'] > ADX_THRESHOLD AND ADX trending upward
                              // OPTIONAL: card sweep `require_adx_trending_up ∈ {true, false}`
   - if both confirmations hold:
       OPEN_LONG at next-bar open (= bar t'+1 open)
       entry_price        = open[t'+1]
       initial_stop_price = compute_long_stop()                 // see below
       advance to IN_POSITION
   - if ADX condition fails: return to ARMED_AWAITING_FORMATION (re-arm on fresh formation)

DEFINITION (compute_long_stop()):
- candidate_stop = formation_low                                 // Lien rule 4 default
- if candidate_stop >= entry_price:                              // formation low is ABOVE entry — wrong-side
    fallback_stop = SMA(close, 20)[t']                           // Lien USDSGD example: "stop should be at the November 6 low ... but that is below our entry price so we put our stop at the 20-day SMA"
                                                                  //   note: USDSGD example actually says formation low was BELOW entry — Lien's text reads "stop should be at the November 6 low of 1.2911 but that is below our entry price"
                                                                  //   re-interpreting: the issue is when formation_low is TOO CLOSE to entry, not just on wrong side. Lien's exception triggers when stop-anchor is too tight or too far in the wrong direction.
                                                                  //   Card adopts: if (entry - formation_low) < MIN_STOP_PIPS OR formation_low > entry: use SMA(20) fallback
    return fallback_stop
- else: return candidate_stop

EACH-BAR (in long position, entered):
- HARD STOP at initial_stop_price (Lien rule 4 + USDSGD-example fallback)
```

**Stop-placement-exception note**: Lien USDSGD example (PDF p. 146) reads: "Our stop should be at the November 6 low of 1.2911 but that is below our entry price so we put our stop at the 20-day SMA of 1.2822." Reading literally, "below entry price" is the standard expected location for a long stop, so the verbatim text is internally inconsistent. Reverse-engineered intent: the issue is the formation-bar's low is BARELY below entry (= too-tight stop, would be vulnerable to noise), so Lien substitutes the more-distant 20-day SMA as a wider stop. Card adopts that interpretation: if formation-bar's extreme yields stop-distance < MIN_STOP_PIPS (default = ATR(14)·1), substitute SMA(20) extreme as fallback. Per BASIS rule, verbatim text preserved in § 9 with explanatory note.

## 5. Exit Rules

Lien rule 5 (PDF p. 144) verbatim:

> "5. Exit the position when the perfect order no longer holds."

Plus partial-take suggestion at chapter close (PDF p. 148):

> "Also, when the currency pair moves more than 250 to 300 pips in profit, you may want to consider taking profit on part of the positions."

Worked examples confirm exit fires on the 10-vs-20 SMA crossover specifically (not deeper-stack pairs):
- EURUSD short: "the 10-day SMA moves above the 20-day SMA" (PDF p. 145)
- USDSGD long: "the 10-day SMA moves below the 20-day SMA" (PDF p. 146)
- USDJPY long: "the 10-day SMA crossed below the 20-day SMA" (PDF p. 147)

Pseudocode:

```text
PARAMETERS:
- EXIT_TRIGGER       = "first_adjacent_pair_breaks"
                                  // Lien rule 5 + worked-example precedent: 10-vs-20 SMA crossover (first/fastest pair)
                                  //   sweep variants: any_adjacent_pair_breaks, deeper_pairs_break_only
- PARTIAL_TAKE_PIPS  = 250        // Lien chapter-close commentary (PDF p. 148): "more than 250 to 300 pips in profit"
                                  //   default: ENABLED at 250 pips; sweep [disabled, 250, 300, 400, 500]
- PARTIAL_TAKE_FRAC  = 0.5        // not specified by Lien; default 50% per V5 standard

EACH-BAR (in long position):
- HARD STOP — fires at initial_stop_price (computed at entry per § 4)
- PARTIAL TAKE (optional, V5-default-ENABLED at 250p):
    if (high[t] - entry_price) >= PARTIAL_TAKE_PIPS:
      CLOSE_PARTIAL_TAKE_FRAC fraction of position    // first time only
      // remaining position retains original stop (NO BE move per Lien's verbatim — Lien rule 5 says hold until perfect-order break)
- SIGNAL-REVERSAL EXIT (Lien rule 5):
    if NOT IsPerfectOrderLong(t):                     // perfect order broken
      CLOSE_REMAINDER

EACH-BAR (in short position): mirror.

FRIDAY CLOSE: D1 strategy with multi-month holds (Lien examples 2.5-5 months). Friday-close
LOAD-BEARING. Default: friday_close ENABLED with waiver candidacy at P3. Precedent:
SRC03_S03 williams-cdc-pattern, SRC02_S01 chan-pairs-stat-arb, SRC04_S05/S07 multi-day swing
cards all received P3 waiver consideration on similar multi-day-hold thesis.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close (with waiver candidacy)
- pyramiding: NOT allowed (single position; state machine is single-shot per perfect-order formation)
- gridding: NOT allowed
- ADX>20 trend-strength gate is the PRIMARY trend-confirmation filter (Lien rule 2). OPTIONAL: ADX-trending-upward sub-condition (Lien: "ADX pointing upwards, ideally greater than 20") — exposed as P3 sweep variant.
- 5-candle delay (Lien rule 3) acts as a built-in false-formation filter — perfect orders that fail within 5 bars don't trigger entry.
- Optional P3 sweep: ADX_THRESHOLD ∈ {15, 18, 20, 22, 25, 30}, ENTRY_DELAY_CANDLES ∈ {3, 5, 7, 10}
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding, no stacking)
- formation-armed state machine: ARMED_AWAITING_FORMATION → ARMED_DELAY (5 bars) → ARMED_PENDING_ENTRY → IN_POSITION
- position size: V5 RISK_PERCENT / RISK_FIXED standard; perfect-order stops vary widely (42 / 89 / 645 pips per Lien examples) → V5 RISK_PERCENT auto-scales position size
- partial-take at +250 pips (V5-default-ENABLED per Lien chapter-close commentary); remainder held until signal-reversal exit
- Trail on remainder: NONE per Lien rules — full remainder held to perfect-order-break exit
- ALTERNATIVE P3 sweep: trail-on-remainder (2-bar-low/high or ATR-trail) — Lien-default vs trail comparison
- Friday Close: ENABLED by default; waiver sweep variant for multi-month-hold edge if PASS_G0
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: ma_periods
  default: [10, 20, 50, 100, 200]             # Lien canonical 5-MA stack
  sweep_range:
    - [10, 20, 50, 100, 200]                  # Lien default
    - [5, 10, 20, 50, 100]                    # tighter / faster stack
    - [10, 20, 50, 100, 200, 300]             # 6-MA deeper stack
    - [20, 50, 100, 200]                      # 4-MA simpler stack
    - [10, 50, 200]                           # 3-MA minimal stack
- name: ma_type
  default: SMA                                # Lien explicit
  sweep_range: [SMA, EMA, HMA]                # EMA / HMA = out-of-source variants
- name: adx_threshold
  default: 20                                 # Lien: "ideally greater than 20"
  sweep_range: [15, 18, 20, 22, 25, 30]
- name: adx_trending_up_required
  default: false                              # Lien: optional ("ADX pointing upwards")
  sweep_range: [false, true]
- name: entry_delay_candles
  default: 5                                  # Lien rule 3
  sweep_range: [3, 5, 7, 10]
- name: stop_anchor
  default: formation_bar_extreme_with_safe_fallback
  sweep_range:
    - formation_bar_extreme_with_safe_fallback
    - sma_20_extreme
    - sma_50_extreme
    - atr14_x2
    - atr14_x3
- name: min_stop_pips
  default: 30                                 # not in source; floor for safe-fallback trigger
  sweep_range: [10, 20, 30, 50]
- name: partial_take_pips
  default: 250                                # Lien commentary: "250 to 300 pips"
  sweep_range: [disabled, 200, 250, 300, 400, 500]
- name: partial_take_frac
  default: 0.5                                # V5 standard
  sweep_range: [0.33, 0.5, 0.67]
- name: exit_trigger
  default: first_adjacent_pair_breaks         # Lien worked-example precedent (10-vs-20 break)
  sweep_range: [first_adjacent_pair_breaks, any_adjacent_pair_breaks, deeper_pairs_break_only]
- name: trail_method
  default: none                               # Lien-verbatim: hold remainder to signal-reversal
  sweep_range: [none, two_bar_extreme, atr14x3_trail, donchian10_trail]
- name: friday_close
  default: enabled                            # V5 default; multi-month edge
  sweep_range: [enabled, disabled_with_waiver]
- name: tf
  default: D1                                 # Lien primary
  sweep_range: [D1, W1]
```

P3.5 (CSR) axis: full Darwinex FX cohort + crosses. Perfect-order formation density is symbol-dependent — strongly trending pairs (USDJPY 2012-2015, USDCAD 2014-2015 per Lien Ch 8 examples) produce more formations than range-bound pairs.

## 9. Author Claims (verbatim, with quote marks)

Strategy framing — perfect-order definition + trend-strength thesis, PDF pp. 143-144:

> "A perfect order in moving averages is defined as a set of moving averages that is in sequential order. For an uptrend, a perfect order would be a situation in which the 10-day simple moving average (SMA) is at a higher price level than the 20-day SMA, which is higher than the 50-day SMA. Meanwhile, the 100-day SMA would be below the 50-day SMA, while the 200-day SMA would be below the 100-day SMA. In a downtrend, the opposite is true, where the 200-day SMA is at the highest level and the 10-day SMA is at the lowest level. Having the moving averages stacked up in sequential order are generally a strong indicator of a trending environment. Not only does it indicate that the momentum is on the side of trend, but the moving averages also serve as multiple levels of support. To optimize the perfect order strategy, traders should also look for ADX to be greater than 20 and trending upward. This represents a strong trend. Entry and exit levels are difficult to determine with this strategy, but generally speaking, we want to stay in the trade for as long as the perfect order remains in place and exit once the perfect order no longer holds. Perfect orders do not happen often, and the premise of this strategy is to capture the perfect order when it first happens."

5-rule strategy rule list, PDF p. 144:

> "The perfect order seeks to take advantage of a trending environment near the beginning of the trend:
> 1. Look for a currency pair with moving averages in perfect order.
> 2. Look for ADX pointing upwards, ideally greater than 20.
> 3. Buy five candles after the initial formation of the perfect order (if it still holds).
> 4. Initial stop is the low on the day of the initial crossover for longs and the high for shorts.
> 5. Exit the position when the perfect order no longer holds."

Worked-example pip P&L, EURUSD daily Fig 16.1 PDF pp. 144-145 (15.0R short):

> "In August 2014, the moving averages in the EURUSD formed a sequential perfect order. We check and see that ADX is greater than 20, and we look to enter into a short trade five candles after the initial formation at 1.3390. Our initial stop is placed at the August 8 high of 1.3432. The pair continues to move lower in the days and weeks that follow, and we remain in the trade until the moving averages are no longer in perfect and the 10-day SMA moves above the 20-day SMA, which occurs on October 17 when EURUSD settles the day at 1.2758. The total profit on this trade is 632 pips. We risked 42 pips on the trade."

Worked-example pip P&L, USDSGD daily Fig 16.2 PDF pp. 145-146 (8.65R long, with stop-anchor fallback):

> "the perfect order forms on November 6. We check and see that ADX is greater than 20, and we look to enter into a long trade five candles after the initial formation at 1.2916. Our stop should be at the November 6 low of 1.2911 but that is below our entry price so we put our stop at the 20-day SMA of 1.2822. The pair continues to move higher in the months that follow, and we remain in the trade until the moving averages are no longer in perfect and the 10-day SMA moves below the 20-day SMA, which occurs on March 27, when USD/SGD closes the day at 1.3685. The total move on this trade is 770 pips for a risk of 89 pips."

Worked-example pip P&L, USDJPY daily Fig 16.3 PDF pp. 146-147 (0.66R long — Lien acknowledges sub-optimal):

> "The perfect order formed in October and when that occurred, we entered the trade five days afterward at 116.20. Our stop was placed at 108.75, and we remained in the trade until the 10-day SMA crossed below the 20-day SMA on December 19 at 119.45. In this example, the profit was 425 pips for a risk of 645 pips, which was far from ideal."

Closing risk-reward summary + partial-take suggestion, PDF p. 148:

> "The perfect order is a strategy that can be high profit but low probability and low frequency. This means there could be numerous stop outs before a long trend emerges. Also, when the currency pair moves more than 250 to 300 pips in profit, you may want to consider taking profit on part of the positions."

**Lien provides one descriptive non-numeric performance claim** ("can be high profit but low probability and low frequency", PDF p. 148) plus per-trade pip-P&L on three worked examples (EURUSD: +632 pips/42-pip risk = 15.0R; USDSGD: +770 pips/89-pip risk = 8.65R; USDJPY: +425 pips/645-pip risk = 0.66R, "far from ideal" per Lien). Per BASIS rule, no extrapolated aggregate performance number is asserted; the descriptive claim is preserved verbatim with no numeric substitution.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.5                              # rough estimate; Lien's "high profit but low probability" framing implies high R-multiple wins (8-15R per worked examples) offsetting frequent stop-outs; PF likely 1.3-1.8 range when stop-discipline holds
expected_dd_pct: 25                           # rough estimate; "numerous stop outs before a long trend emerges" (Lien PDF p. 148) implies extended drawdowns during non-trending periods; D1 multi-month hold with wide stops (40-650 pips per examples)
expected_trade_frequency: 1-3/year/symbol     # rough estimate; Lien explicit: "Perfect orders do not happen often" — strongly trending markets only
risk_class: medium                            # D1 long-term swing; wide stops (variable, can exceed 600 pips per USDJPY example) but low signal density
gridding: false
scalping: false                               # D1 bars; multi-month holds — opposite end of timeframe spectrum from scalping
ml_required: false                            # SMA + ADX + threshold + state machine; no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (5-MA monotonic-order test + ADX threshold + 5-bar entry delay + formation-bar-extreme stop with safe fallback + signal-reversal exit; deterministic given D1 OHLC + SMA library + ADX library)
- [x] No Machine Learning required
- [x] If gridding: not applicable (single position; state machine is single-shot)
- [x] If scalping: not applicable (D1 bars; multi-month holds)
- [x] Friday Close compatibility: load-bearing — multi-month-hold strategy. Default ENABLED; waiver candidacy at P3.
- [x] Source citation is precise enough to reproduce (PDF pp. 143-148 5-rule list + 3 worked examples + chapter-close commentary; verbatim quotes preserved with stop-anchor-exception note)
- [x] No near-duplicate of existing approved card — `trend-filter-ma` is single-MA filter; `cross-sectional-decile-sort` is universe-ranked relative-strength; `donchian-breakout` is N-bar extreme. Lien Ch 16 is structurally distinct: 5-MA monotonic stack as ENTRY trigger.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default + ADX>20 trend-strength gate (Lien rule 2); optional ADX-trending-upward sub-gate; 5-candle entry delay acts as built-in false-formation filter"
  trade_entry:
    used: true
    notes: "5-state state machine: ARMED_AWAITING_FORMATION → ARMED_DELAY (5 bars, IsPerfectOrderLong re-check each bar) → ARMED_PENDING_ENTRY (re-confirm + ADX gate) → IN_POSITION; formation-bar-extreme stop with safe-SMA-20-fallback when too tight"
  trade_management:
    used: true
    notes: "partial-take at +250 pips (default ENABLED per Lien commentary); remainder held to signal-reversal (perfect-order break, typically 10-vs-20 SMA cross — first adjacent pair); NO trail by default, trail variants as P3 sweep"
  trade_close:
    used: true
    notes: "exit on initial formation-bar-extreme stop OR signal-reversal (perfect-order break) on remainder OR partial-take + signal-reversal on remainder"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # LOAD-BEARING — multi-month-hold strategy (Lien examples 2.5-5 months). Default V5 friday_close ENABLED; waiver candidacy at P3.
  - enhancement_doctrine                      # LOAD-BEARING on MA-period choices (10/20/50/100/200) and ADX-threshold (20) — Lien-verbatim defaults; cross-pair generalization may favor different periods. P3 sweep tests this.
  - news_pause_default                        # NOT LOAD-BEARING — D1 multi-month strategy is well-protected by V5 P8 default news-pause window; news events are noise vs the multi-month perfect-order signal. Listed for CTO completeness.

at_risk_explanation: |
  friday_close — D1 multi-month-hold strategy. Lien's three worked examples all hold across
  multiple weekend gaps (EURUSD 2.5 months, USDSGD 5 months, USDJPY 2.5 months). Default V5
  friday_close ENABLED; waiver sweep variant if PASS_G0. Precedent: SRC03_S03 williams-
  cdc-pattern + SRC02_S01 chan-pairs-stat-arb + SRC04_S05/S07 multi-day-swing precedents.

  enhancement_doctrine — Lien's verbatim 10/20/50/100/200 SMA periods are textbook-canonical
  but not necessarily optimal for FX D1. Faster (5/10/20/50/100) and slower (20/50/100/200/300)
  variants tested as P3 sweep axis. Once a live period set is fixed, any subsequent retune
  is enhancement_doctrine.

  news_pause_default — D1 multi-month strategy is robust to intraday news events; V5 P8
  default news-pause covers any high-impact news cleanly without needing strategy-specific
  override. No waiver requested.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default + ADX-threshold gate + optional ADX-trending-up sub-gate
  entry: TBD                                  # 5-state state machine on D1 close + 5-MA SMA library + ADX library + formation-bar-extreme + safe-fallback stop logic; ~150-220 LOC in MQL5
  management: TBD                             # partial-take at +250p (V5 default) + signal-reversal exit on perfect-order break (10-vs-20 SMA cross primary check)
  close: TBD                                  # standard SL + signal-reversal exit + partial-take logic
estimated_complexity: medium                  # state-machine logic + 5-MA computation + ADX integration + safe-fallback stop logic adds nontrivial LOC vs simple breakout strategies; D1-only timeframe simplifies tick handling
estimated_test_runtime: 3-6h                  # P3 sweep ~50,000 cells with cell-axis pruning; D1 bars; 5+ years; FX cohort
data_requirements: standard                   # D1 OHLC on Darwinex .DWX FX symbols; SMA + ADX standard libraries
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
- 2026-04-28: SRC04_S09 surfaces a NEW `strategy_type_flags` controlled-vocabulary GAP
  (entry side): `ma-stack-entry` — multi-MA sequential-monotonic-order pattern as ENTRY
  trigger (long: SMA(P1) > SMA(P2) > ... > SMA(PK) for P1 < P2 < ... < PK; short mirror).
  Lien's perfect-order canonical case: K=5 with periods (10, 20, 50, 100, 200). Entry fires
  N candles AFTER initial formation if stack still holds.

  Distinct from existing flags:
    - `trend-filter-ma` (single MA OVERLAY filter, e.g., Close > SMA(200); used as entry-
      suppression overlay rather than entry trigger; V4 examples Modernised Turtle SMA(200)
      filter and Two-Regime Trend-Following bull-state slow-MA signal)
    - `cross-sectional-decile-sort` (universe-ranked relative-strength entry; ma-stack-entry
      is single-instrument MA stack, not universe sort)
    - `donchian-breakout` (N-bar extreme; ma-stack-entry uses MA crossover state, not extreme)
    - `vol-regime-gate` (vol-bucket classifier; ma-stack-entry uses SMA-based price state)
    - `regime-filter-multi` (multi-feature engineered tree; ma-stack-entry is single-feature
      monotonic-stack-state, not engineered tree)

  V4 had no MA-stack-entry EA per `strategy_type_flags.md` Mining-provenance table — 5-MA
  sequential-monotonic-stack as ENTRY trigger is net-new with SRC04 Lien Ch 16. Research
  will batch-propose this gap at SRC04 closeout per process 13 § Exits + DL-033 Rule 1.

- 2026-04-28: ADX>20 trend-strength gate is functionally similar to existing
  `atr-regime-mr-gate` (low-ATR MR gate) but in OPPOSITE direction (high-ADX trend gate).
  This is the SECOND SRC04 card to surface ADX-regime-gate pattern (after SRC04_S06 lien-
  fader's ADX<20 range gate). Future-vocab-watch reinforced: if SRC05+ surfaces a third
  ADX-regime card, propose `adx-trend-confirm-gate` and `adx-range-mr-gate` as a paired
  vocab addition (symmetric to existing atr-regime-mr-gate).

- 2026-04-28: Lien provides one descriptive non-numeric performance claim ('high profit but
  low probability and low frequency', PDF p. 148) plus three worked examples spanning the
  full performance range: EURUSD 15.0R (excellent), USDSGD 8.65R (very good), USDJPY 0.66R
  ('far from ideal' per Lien). The variance illustrates Lien's "low probability" framing
  (some trades pay handsomely; others stop out before trend develops). Per BASIS rule, no
  extrapolated aggregate performance number is asserted; § 9 cites only what the source
  verbatim quotes.

- 2026-04-28: Stop-anchor exception (Lien USDSGD example PDF p. 146) introduces a non-trivial
  edge case: when formation-bar's extreme yields too-tight a stop, fall back to SMA(20)
  extreme. Card adopts safe-fallback logic via `min_stop_pips` parameter; CTO will need to
  verify edge-case handling at IMPL.

- 2026-04-28: Friday-close is load-bearing for the FOURTH time in SRC04 (after S05 inside-
  day, S07 20-day-breakout, and indirectly other multi-day swings). Multi-month perfect-
  order holds (2.5-5 months in Lien examples) make this card the LONGEST-HOLD strategy in
  SRC04 to date. P3 waiver consideration mirroring SRC03_S03 + SRC02_S01 precedent.

- 2026-04-28: V5-architecture-fit profile is FAVOURABLE — single-symbol forex, D1 bars,
  no multi-leg / multi-stock / cointegration architecture concerns. SMA + ADX libraries
  are standard. State machine is straightforward bookkeeping. Expected G0 yield CLEAN
  with `friday_close` waiver evaluation at P3 + `ma-stack-entry` vocab gap ratification
  at SRC04 closeout.

- 2026-04-28: This is the FOURTH multi-state-machine entry pattern in SRC04 (after S04
  Waiting-Deal, S06 Fader, S07 20-day-breakout). State-machine entry patterns are now an
  established SRC04 architectural signature. CTO state-machine validation guidance noted
  at S07 IMPL is reinforced here.
```
