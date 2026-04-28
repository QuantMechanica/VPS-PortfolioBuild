# Strategy Card — Lien Fading the Double Zeros (round-number psychological-level fade)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC04/raw/ch08-12_technical.txt` (verbatim Lien Ch 10 § "Fading the Double Zeros" rule list + Market Conditions + Further Optimization sections + 3 worked examples).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3 / DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC04_S03
ea_id: TBD
slug: lien-fade-double-zeros
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - round-num-fade                            # entry: stop-buy/stop-sell at fixed pip offset (Lien default 10–15p) from absolute round-number price (xx.00 / x.x000 / x.x500) with counter-trend 20MA filter on M15. Ratified in SRC04 batch (CEO 2026-04-28, QUA-333 closeout, QUA-351 back-port). See `strategy-seeds/strategy_type_flags.md` § A entry-mechanism for canonical definition.
  - trend-filter-ma                           # Lien rule 1 (long): "trading below its intraday 20-period simple moving average on a 15-minute chart" — MA-position filter; counter-trend orientation
  - atr-hard-stop                             # Lien: 20-pip protective stop (rule 3); V5 maps to ATR(14) × M-multiple sweep
  - symmetric-long-short                      # Lien explicitly mirrors long and short rules (PDF p. 113)
  - friday-close-flatten                      # V5 default; intraday strategy with 35-pip-class moves typically closes same session
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Lien, Kathy (3rd ed., 2015). Day Trading and Swing Trading the Currency Market: Technical and Fundamental Strategies to Profit from Market Moves. Wiley Trading. Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 10 'Technical Trading Strategy: Fading the Double Zeros' (PDF pp. 111-115) including § 'Strategy Rules' (PDF pp. 112-113), § 'Market Conditions' (PDF p. 113), § 'Further Optimization' (PDF p. 113), and three worked examples (USDJPY Fig 10.1 PDF pp. 113-114; GBPUSD Fig 10.2 PDF pp. 114-115; USDCAD Fig 10.3 PDF p. 115)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC04/raw/ch08-12_technical.txt` lines 451-477 (Long + Short rule lists verbatim), lines 478-484 (Market Conditions), lines 486-492 (Further Optimization), lines 496-555 (three worked examples with explicit pip arithmetic). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Day Trading and Swing Trading t - Kathy Lien.pdf`.

## 2. Concept

Lien's thesis (PDF p. 112): traders cluster take-profit orders at round numbers ("double zeros" — last two digits zero, e.g., 1.3000 in EURUSD or 110.00 in USDJPY) because humans think in round numbers. Stop-loss orders cluster JUST BEYOND the round numbers. Large banks with order-book visibility "actively seek to exploit this clustering of positions to basically gun stops" (PDF p. 112) — i.e., when price approaches a round number from one side, dealer flow tends to drive price THROUGH the round number to trigger clustered stops, then reverse back as the dealer absorbs the resulting flow.

The strategy fades this stop-gun: enter in the OPPOSITE direction of the prevailing intraday trend (price below 20MA → go LONG above the figure; price above 20MA → go SHORT below the figure), placing a stop-buy 10-15 pips ABOVE the round number for longs (anchored to the round number itself, not the prior bar's range or extreme). Stop is 20 pips below the round number (so 30-35-pip risk on long, 30-35-pip risk on short). First profit target is "amount risked" (~35 pips), partial close 50% with BE move on rest, then trail.

Lien's verbatim concept framing, PDF p. 112:

> "Trading off psychologically important levels such as the double zeros or round numbers is one good way of identifying such opportunities. Double zeros represent numbers where the last two digits are zeros. Examples of double zeros would be 118.00 in USDJPY or 1.1100 in the EURUSD. After noticing how many times a currency pair would bounce off double zero support or resistance levels intraday despite the underlying trend, we have observed that these bounces are usually much larger and more relevant that rallies off other price levels."

PDF p. 112:

> "Market participants as a whole tend to put conditional orders near or around the same levels. While stop-loss orders are usually placed just beyond the round numbers, traders will cluster their take profit orders at the round number. ... Large banks with access to conditional order flow, like stops and limits, actively seek to exploit this clustering of positions to basically gun stops. The fading the double zero strategy attempts to put traders on the same side as market makers by positioning traders for a quick contra-trend move at the double zero level."

## 3. Markets & Timeframes

```yaml
markets:
  - forex                                     # Lien Ch 10 entire universe is forex spot pairs; examples: USDJPY, GBPUSD, USDCAD
timeframes:
  - M15                                       # Lien explicit: "intraday 20-period simple moving average on a 15-minute chart" (PDF p. 113, long rule 1)
  - M30                                       # plausible M15-derivative; out-of-source extrapolation (P3 axis variant)
  - H1                                        # plausible variant; out-of-source extrapolation (P3 axis variant)
session_window: not specified                 # Lien implies 24-hour applicability; "Market Conditions" (PDF p. 113) prefers "quieter market conditions without the influence of major reports"
primary_target_symbols:
  - "USDJPY.DWX (Lien example: PDF pp. 113-114, fade @ 120.00 level, sell @ 119.85 with 20MA above)"  # Note: Lien text uses '1110.85' and '1110.50' which appears to be a typesetting artifact for '110.85' / '110.50' (USDJPY range). PDF p. 114 chart Fig 10.1 confirms USDJPY ~110-120 range.
  - "GBPUSD.DWX (Lien example: PDF p. 114-115, fade @ 1.5500, sell @ 1.5485)"
  - "USDCAD.DWX (Lien example: PDF p. 115, fade @ 1.2000 — triple-zero level — long @ 1.2015)"
  - "EURUSD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX (multi-major generalization implicit in Lien's chapter framing)"
  - "Crosses preferred per Lien: 'It is more successful for currency pairs with tighter trading ranges, crosses, and commodity currencies' (PDF p. 113)"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Lien's PDF pp. 112-113 rule lists.

```text
PARAMETERS:
- BAR                = M15        // Lien: "15-minute chart" (PDF p. 113, long rule 1)
- TREND_MA_PERIOD    = 20         // Lien: "intraday 20-period simple moving average" (PDF p. 113, long rule 1)
- ENTRY_OFFSET_PIPS  = 12         // Lien: "10 to 15 pips above the figure" (PDF p. 113, long rule 2) — midpoint 12 default; sweep 10-15
- STOP_OFFSET_PIPS   = 20         // Lien: "20 pips below the figure" (PDF p. 113, long rule 3)
- ROUND_NUMBER_GRID  = "double_zero"  // Lien: "the last two digits are zeros" — e.g. 1.3000, 110.00
                                      //   For JPY pairs, double-zero grid = NN.00 (every full unit)
                                      //   For non-JPY majors, double-zero grid = N.NN00 (every 100 pips)
                                      //   "Triple zero" levels (PDF p. 115 USDCAD example: 1.2000 = both
                                      //   double-zero and the round-thousand 1.2000) hold "even more
                                      //   significance than a double zero level"

DEFINITION (round-number nearest level):
- For non-JPY majors (4-decimal quote): nearest round-number = round(price * 100) / 100
                                        // i.e. the nearest x.xx00 level
- For JPY pairs (2-decimal quote):       nearest round-number = round(price * 1) / 1
                                        // i.e. the nearest xxx.00 level
- "Significance" tiers (Further Optimization PDF p. 113):
  Tier-1 (double-zero):  e.g., 1.3000, 110.00
  Tier-2 (triple-zero):  e.g., 1.2000, 100.00 (round number AND big-figure round number)
                                        // Lien: "Triple zero levels hold even more significance than a
                                        // double zero level because of their less frequent occurrence"
  Tier-3 (technical-confluence): round number AND key technical level (Fibonacci, BB,
                                  prior support/resistance) — "even higher probability of success"
                                  per Lien PDF p. 113

EACH-BAR (evaluated on close of each M15 candle):
- ma_20         = SMA(close, TREND_MA_PERIOD) on M15
- nearest_round = nearest_round_number_to(close[t])
- distance_to_round = nearest_round - close[t]    // signed: positive = round above, negative = below

LONG ENTRY (counter-trend fade BELOW MA, anticipating round-number stop-gun + reversal):
- precondition: close[t] < ma_20[t]               // Lien: "trading below its intraday 20-period simple moving average"
- staging:      nearest round_number ABOVE close[t] is within reasonable proximity (≤ N_PROXIMITY pips)
                // Lien rule does not specify a max distance; default 50 pips; sweep [25, 50, 100]
- stop-buy at:  nearest_round + ENTRY_OFFSET_PIPS // Lien: "Enter a long position 10 to 15 pips above the figure"
- if intra-day high reaches stop-buy: OPEN_LONG at stop-buy
- initial stop: nearest_round - STOP_OFFSET_PIPS  // Lien: "Place an initial protective stop 20 pips below the figure"
                                                   //   Note: stop is anchored to the ROUND NUMBER, not entry — risk = ENTRY_OFFSET_PIPS + STOP_OFFSET_PIPS = 30-35 pips

SHORT ENTRY (mirror — counter-trend fade ABOVE MA):
- precondition: close[t] > ma_20[t]               // Lien: "trading above its intraday 20-period simple moving average"
- staging:      nearest round_number BELOW close[t] within ≤ N_PROXIMITY pips
- stop-sell at: nearest_round - ENTRY_OFFSET_PIPS // Lien: "Short the currency pair 10 to 15 pips below the figure"
- if intra-day low reaches stop-sell: OPEN_SHORT at stop-sell
- initial stop: nearest_round + STOP_OFFSET_PIPS  // Lien: "Place an initial protective stop 20 pips above the round number"
```

Notation clarification: Lien's rule says "below the figure" / "above the figure" where "figure" = round number. The stop-buy is staged ABOVE the figure (10-15 pips above) for LONG, anticipating that price will retrace UP through the figure after the stop-gun, with stop just BELOW the figure. The structurally important detail is that BOTH entry and stop are anchored to the round number itself, NOT to the entry price — so risk = (ENTRY_OFFSET_PIPS + STOP_OFFSET_PIPS) ≈ 30-35 pips per Lien's worked examples.

## 5. Exit Rules

Lien's exit rule list (PDF p. 113, long rule 3a/3b — note: Lien's rule numbering merges entry-rule 3 with exit-sub-rules a/b):

> "3. Place an initial protective stop 20 pips below the figure.
>    a. When the position is profitable by the amount risked, close half of the position and move your stop on the remaining portion of the trade to breakeven.
>    b. Trail your stop as the price moves in your favor."

Pseudocode:

```text
PARAMETERS:
- TP1_RR             = 1.0        // Lien: "When the position is profitable by the amount risked"
                                  //   = ENTRY_OFFSET_PIPS + STOP_OFFSET_PIPS (≈ 30-35 pips at default)
- TRAIL_AFTER_TP1    = "BE"       // Lien: "move your stop on the remaining portion of the trade to breakeven"
- TRAIL_METHOD       = "two_bar_low"
                                  // Lien example USDJPY (PDF p. 114): "We choose to trail the stop by
                                  //   two-bar low for a really short-term trade"
                                  // Alt-method per GBPUSD example (PDF p. 114): "we proceed to trail it
                                  //   by the 20-day SMA + 10 pips" — hybrid PT-by-2BL or by-MA P3 sweep axis

EACH-BAR (in position):
- HARD STOP — fires at initial stop price
- TP1 (close half + BE move):
    if abs(price - entry) >= 1 * (initial_stop_distance):
      CLOSE_HALF
      move_remaining_stop to BE (entry price)
- TRAIL on remaining: 2-bar-low (long) / 2-bar-high (short)
  Alt sweep: 20-bar SMA + 10 pips offset (Lien's GBPUSD example variant, PDF p. 114)

FRIDAY CLOSE: V5 default applies. Intraday M15 strategy with ~35-pip stops typically closes
within hours; weekend hold is not a structural concern. Default-flatten preserves edge.
No waiver requested.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed (Lien rules describe single-position-at-a-time)
- gridding: NOT allowed
- Lien Market Conditions (PDF p. 113): "This strategy works best when the move happens in
  quieter market conditions without the influence of major reports." — V5 P8 News Impact
  pause-window covers this; standard framework gating handles it. As an OPTIONAL P3 sweep
  axis: stricter pre-news exclusion window (e.g., ±60 min around scheduled news vs default ±30 min).
- Lien preferred symbols (PDF p. 113): "It is more successful for currency pairs with tighter
  trading ranges, crosses, and commodity currencies." — symbol-cohort filter at CSR P3.5
  rather than per-card.
- Lien Further Optimization (PDF p. 113): "the strategy has an even higher probability of
  success when other important support or resistance levels converge at the figure. This can
  be caused by moving averages, key Fibonacci levels or Bollinger Bands, or other technical
  indicators." — OPTIONAL P3 sweep axis variant: require confluence with one or more of
  {SMA(50), SMA(200), Fib retrace at 38.2/50/61.8 of last swing, Bollinger band(20,2)}. Off
  by default; on as confluence-filter axis.
- Triple-zero priority (PDF p. 115): an OPTIONAL P3 sweep axis can restrict trading to
  triple-zero levels only (every 1000 pips on non-JPY, every 10 yen on JPY pairs) — Lien
  cites these as higher-probability.
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding, no stacking)
- position size: V5 RISK_PERCENT / RISK_FIXED standard; Lien example pip P&L: 35 pips first half + 35-135 pips second half across 3 worked examples
- TP1 (50% close + BE move): hard rule
- Trail on remainder: 2-bar-low/high default, with 20MA+10 pips alternative (P3 sweep)
- Friday Close: forced flat per V5 default (no waiver)
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: trend_ma_period
  default: 20                                 # Lien: "intraday 20-period simple moving average"
  sweep_range: [10, 14, 20, 26, 34, 50]
- name: entry_offset_pips
  default: 12                                 # Lien: "10 to 15 pips above the figure" — midpoint 12
  sweep_range: [8, 10, 12, 15, 20, 25]
- name: stop_offset_pips
  default: 20                                 # Lien: "20 pips below the figure"
  sweep_range: [10, 15, 20, 25, 30, 40]
- name: round_grid_tier
  default: double_zero                        # Lien primary
  sweep_range: [double_zero, triple_zero_only, double_or_triple, half_round_inc]
                                              # half_round_inc tests intermediate xx50 levels which Lien does NOT cite — sanity check
- name: proximity_pips
  default: 50                                 # not in source; Lien's rule does not bound staging distance
  sweep_range: [25, 50, 100, 200, no_limit]
- name: trail_method
  default: two_bar_low                        # Lien USDJPY example variant
  sweep_range: [two_bar_low, ma20_plus_10, atr2_trail, fixed_pct_05]
- name: confluence_filter
  default: off                                # Lien Further-Optimization OPTIONAL filter
  sweep_range: [off, sma50_confluence, fib_confluence, bb20_confluence, ANY_2_AGREE]
- name: tf
  default: M15                                # Lien explicit
  sweep_range: [M15, M30, H1]                 # M30 / H1 are out-of-source variants
```

P3.5 (CSR) axis: re-run on Darwinex FX cohort (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`) plus crosses (`EURGBP.DWX`, `EURJPY.DWX`, `GBPJPY.DWX`, `AUDNZD.DWX`, `AUDCAD.DWX` if Darwinex offers). Lien states crosses and commodity currencies are preferred (PDF p. 113), so cross-pair PASS rate is a primary CSR validation.

## 9. Author Claims (verbatim, with quote marks)

Strategy framing, PDF p. 112:

> "Trading off psychologically important levels such as the double zeros or round numbers is one good way of identifying such opportunities. Double zeros represent numbers where the last two digits are zeros. Examples of double zeros would be 118.00 in USDJPY or 1.1100 in the EURUSD."

Order-flow rationale, PDF p. 112:

> "Market participants as a whole tend to put conditional orders near or around the same levels. While stop-loss orders are usually placed just beyond the round numbers, traders will cluster their take profit orders at the round number. ... Large banks with access to conditional order flow, like stops and limits, actively seek to exploit this clustering of positions to basically gun stops. The fading the double zero strategy attempts to put traders on the same side as market makers by positioning traders for a quick contra-trend move at the double zero level."

Long rule list, PDF p. 113:

> "Strategy Rules
> Long:
> 1. Identify a currency pair that is trading below its intraday 20-period simple moving average on a 15-minute chart.
> 2. Enter a long position 10 to 15 pips above the figure.
> 3. Place an initial protective stop 20 pips below the figure.
>    a. When the position is profitable by the amount risked, close half of the position and move your stop on the remaining portion of the trade to breakeven.
>    b. Trail your stop as the price moves in your favor."

Short rule list, PDF p. 113:

> "Short:
> 1. Identify a currency pair that is trading above its intraday 20-period simple moving average on a 15-minute chart.
> 2. Short the currency pair 10 to 15 pips below the figure.
> 3. Place an initial protective stop 20 pips above the round number.
> 4. When the position is profitable by the amount that you risked, close half of the position and move your stop on the remaining portion of the trade to breakeven. Trail your stop as the price moves in your favor."

Expected pip P&L, PDF p. 112:

> "This type of reaction is perfect for intraday FX traders because it gives them the opportunity to make 30 to 50 pips while risking only 15-20 pips."

Market Conditions, PDF p. 113:

> "This strategy works best when the move happens in quieter market conditions without the influence of major reports. It is more successful for currency pairs with tighter trading ranges, crosses, and commodity currencies. This strategy also works in the majors but under quieter market conditions since the stop loss is relatively tight."

Further Optimization, PDF p. 113:

> "Round numbers are important because they are significant levels but if the price coincides with a key technical level, a reversal becomes more likely. This means the strategy has an even higher probability of success when other important support or resistance levels converge at the figure. This can be caused by moving averages, key Fibonacci levels or Bollinger Bands, or other technical indicators."

Worked example pip P&L, PDF p. 114 (USDJPY @ 110.00 fade):

> "We close half of the position when it moves by the amount risked or 35 pips at 1110.50. ... earning us 35 pips on the first and second half of the positions."

(Interpretation: round number = 120.00 per source line 500; stop value 120.20 per source line 502 is clean text, not OCR-corrupted; therefore '1110.85' = OCR artifact for 119.85 and '1110.50' = OCR artifact for 119.50.)

Worked example pip P&L, PDF p. 114-115 (GBPUSD @ 1.5500 fade):

> "GBPUSD moves in our favor, and our first profit target is hit at (1.5485 -.0035) at 1.5450. We then move our stop to breakeven, or our initial entry price of 1.5485, and proceed to trail it by the 20-day SMA + 10 pips. If we manage our trade using this type of trailing stop, the second half of the position would have been exited at 1.5350 for 35 pips on the first half of the position and 135 pips on the second."

Worked example pip P&L, PDF p. 115 (USDCAD @ 1.2000 triple-zero fade):

> "We earned 35 pips on the first position and 40 pips on the second position."

Triple-zero significance, PDF p. 115:

> "The great thing about this trade is that it is triple zero level rather than just a double zero level. Triple zero levels hold even more significance than a double zero level because of their less frequent occurrence."

**Lien provides NO numeric performance claim** (no win-rate, profit-factor, max-drawdown, or annualized-return figure) for this strategy on its own — only the per-trade pip-P&L on three worked examples (35/35, 35/135, 35/40 pips) and a target-zone framing of "30 to 50 pips while risking only 15-20 pips" (PDF p. 112). Per BASIS rule, no extrapolated performance number is asserted in this card; pipeline P2-P9 produce the actual edge measurement.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.2                              # rough estimate; tight-stop intraday fade with 1R partial + trail typically 1.1-1.4 PF range when win rate is moderate-to-good; round-number-fade is V5-net-new so no V4 archive baseline
expected_dd_pct: 15                           # rough estimate; M15 single-symbol intraday strategies typically 10-20% DD when stop-discipline holds
expected_trade_frequency: 200-500/year/symbol # rough estimate at M15 / multiple round-numbers per day; Lien's pre-conditions (MA-side + proximity + news-quiet) reduce raw signal count substantially
risk_class: medium                            # M15 intraday with ~35-pip stops; not strictly scalping but latency-sensitive due to tight stops — flag P5b consideration in IMPL
gridding: false
scalping: false                               # M15 bars with 35-pip stops; not scalping per V5 framework (`scalping_p5b_latency` typically triggers at sub-M5 / sub-M1)
ml_required: false                            # threshold + MA-position filter + round-number arithmetic; no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (MA-position filter + round-number staging + stop-buy/stop-sell offset; deterministic intraday fill)
- [x] No Machine Learning required
- [x] If gridding: not applicable (one open position per direction)
- [x] If scalping: not applicable per V5 framework definition (M15 bars; `scalping_p5b_latency` flagged at hard_rules_at_risk for CTO review on latency sensitivity)
- [x] Friday Close compatibility: intraday M15 with ~35-pip stops typically closes same session; V5 default Friday-close applies cleanly. No waiver required.
- [x] Source citation is precise enough to reproduce (PDF pp. 112-115 rule lists + Market Conditions + Further Optimization + 3 worked examples; verbatim quotes preserved)
- [x] No near-duplicate of existing approved card (`strategy-seeds/cards/`: no V4 SM_XXX EA uses round-number anchored stop-entries per `strategy_type_flags.md` Mining-provenance table; SRC03 williams-monday-oops uses CALENDAR-pattern + GAP-through reference, not round-number; SRC02 chan-bollinger-es uses ±2σ band, not round-number)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); Lien Market-Conditions news-quiet emphasis covered by P8 default; optional confluence-filter (SMA50 / Fib / Bollinger) and triple-zero-only filter as P3 sweep axes"
  trade_entry:
    used: true
    notes: "stop-buy/stop-sell at fixed pip offset from nearest round-number price, conditioned on 20MA-position counter-trend filter; M15 evaluation; long/short symmetric"
  trade_management:
    used: true
    notes: "TP1 = 1R (≈ 35 pips) partial close + move-rest-to-BE; trail remainder via 2-bar-low/high (default) or 20MA+10-pips (Lien GBPUSD example variant)"
  trade_close:
    used: true
    notes: "exit on initial 20-pip stop OR TP1 partial + trail-fired-on-remainder"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # NOT load-bearing — typical same-session hold; default V5 Friday-close applies cleanly. Listed for CTO completeness.
  - enhancement_doctrine                      # load-bearing on entry-offset and stop-offset (10-15 / 20 pips); Lien's pip values are calibrated for major-FX vol scale. Cross-pair generalization may require ATR-scaled offsets. P3 sweep + CSR P3.5 test this. Any post-PASS retune of offset values is enhancement_doctrine.
  - news_pause_default                        # load-bearing — Lien EXPLICITLY states "works best ... without the influence of major reports" (PDF p. 113). Default V5 P8 news-blackout covers this; Lien's framing aligns with default policy.
  - scalping_p5b_latency                      # M15 bars + tight 20-30-pip stops makes the strategy LATENCY-SENSITIVE even though not strictly scalping. P5b VPS-realistic latency calibration recommended at IMPL. Flagged for CTO review.

at_risk_explanation: |
  friday_close — Intraday M15 strategy with ~35-pip stops typically closes within hours;
  weekend-hold rare. Default V5 Friday-close applies cleanly. Listed for completeness.

  enhancement_doctrine — Lien's verbatim 10-15-pip entry offset and 20-pip stop offset are
  calibrated for major-FX volatility scale. Cross-pair generalization (especially to JPY pairs
  where pip values differ in absolute terms vs non-JPY majors, and to crosses where
  intraday volatility patterns differ) may require ATR-scaled offsets. P3 sweep `entry_offset_pips`
  / `stop_offset_pips` axes test this. Once a live offset is fixed, any subsequent retune is
  enhancement_doctrine.

  news_pause_default — Lien EXPLICITLY says the strategy works best in quieter market
  conditions without major reports. V5 P8 news-blackout aligns with this; standard
  framework gating handles it. No waiver requested.

  scalping_p5b_latency — Although M15 bars place this above the strict "scalping" boundary,
  the 20-pip stop is tight enough that VPS latency on stop-buy / stop-sell fills materially
  affects measured edge. P5b stress with calibrated VPS latency simulation is recommended
  at IMPL. CTO sanity-check at G0.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default + optional confluence-filter + triple-zero-only axis
  entry: TBD                                  # round-number grid computation per pair (4-decimal vs 2-decimal JPY) + 20MA M15 filter + stop-buy/stop-sell at offset; ~120-200 LOC in MQL5 (round-number grid is the novel logic)
  management: TBD                             # 50% partial close at 1R + move-rest-to-BE; 2-bar-low/high trail (default) or 20MA+10-pips (Lien variant)
  close: TBD                                  # standard SL/TP plus trail variants
estimated_complexity: medium                  # round-number grid logic + per-pair pip-decimal handling + triple-zero detection adds nontrivial LOC vs simple BB/MA strategies
estimated_test_runtime: 4-8h                  # P3 sweep ≈ 6×6×6×4×5×4×5×3 ≈ 86,400 cells; M15 bars; 5+ years; FX cohort — wider than D1 strategies due to higher tick-rate
data_requirements: standard                   # M15 OHLC on Darwinex .DWX FX symbols; no external feeds
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
- 2026-04-28: SRC04_S03 surfaces a NEW `strategy_type_flags` controlled-vocabulary GAP (entry side):
  `round-num-fade` — entry mechanism: stop-buy/stop-sell at fixed pip offset (10-15) from a
  PSYCHOLOGICAL ROUND-NUMBER price (xx.00 / x.x000 / x.x500), conditioned on a counter-trend
  MA-position filter. The reference price is an ABSOLUTE round-number anchor (independent of
  prior bar's range, prior N-bar extreme, or bar-internal candle shape). Distinct from:
    - `vol-expansion-breakout` (uses prior-bar range scaled by N% — relative anchor)
    - `gap-fade-stop-entry` (calendar-pattern + gap-through reference price — calendar-conditional)
    - `n-period-min-reversion` (N-bar minimum extreme — not absolute psychological level)
    - `narrow-range-breakout` (range-contraction precondition + reference at prior-bar extreme)
    - `rejection-bar-stop-entry` (single-bar candle-shape rejection — bar-internal structure)
    - `failed-breakout-fade` (multi-bar trend + box + breakout precondition — multi-bar pattern)
  V4 had no equivalent SM_XXX EA per `strategy_type_flags.md` Mining-provenance table — round-
  number-anchored stop-entries are net-new with SRC04 Lien Ch 10. Research will batch-propose
  this gap at SRC04 closeout per process 13 § Exits + DL-033 Rule 1.

- 2026-04-28: Lien provides NO numeric aggregate performance claim — only target-zone framing
  ("30 to 50 pips while risking only 15-20 pips" PDF p. 112) and per-trade pip-P&L on three
  worked examples. Per BASIS rule, no extrapolated number is asserted; § 9 cites only what the
  source verbatim quotes.

- 2026-04-28: USDJPY example pip values in source PDF text are typeset with stray '1' prefix
  ('1110.85' / '1110.50') which is a transcription / OCR artifact — actual values are 119.85
  / 119.50 per source-stated round number 120.00 (raw line 500) and stop value 120.20 (raw
  line 502, no OCR artifact). Per JPY-pair pip arithmetic: 119.85 - 0.35 = 119.50. Card
  preserves verbatim text in § 9 with explanatory note in § 3 markets section.

- 2026-04-28: Latency sensitivity flagged at `scalping_p5b_latency` despite M15 bar size. The
  20-pip stop is tight enough that VPS latency on stop-buy / stop-sell fills materially affects
  measured edge. P5b stress with calibrated VPS latency simulation recommended at IMPL.

- 2026-04-28: Triple-zero levels (PDF p. 115) are an INTRA-strategy filter axis rather than a
  separate strategy. Card exposes `round_grid_tier` as a P3 sweep axis with `triple_zero_only`
  as a variant; if triple-zero-only outperforms in P3, that becomes a deployment-time choice
  rather than a separate Strategy Card.

- 2026-04-28: V5-architecture-fit profile is FAVOURABLE — single-symbol forex, M15 bars, no
  multi-leg / multi-stock / cointegration architecture concerns. Round-number grid logic adds
  modest LOC but is straightforward arithmetic. Expected G0 yield CLEAN with `scalping_p5b_latency`
  flagged for IMPL-time stress validation.
```
