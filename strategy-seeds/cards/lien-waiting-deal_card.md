# Strategy Card — Lien Waiting for the Deal (London-open opening-range false-breakout fade)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC04/raw/ch08-12_technical.txt` (verbatim Lien Ch 11 § "Strategy Rules" Long + Short rule lists + 3 worked examples on GBPUSD M5 / M10 / M15 charts).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3 / DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC04_S04
ea_id: TBD
slug: lien-waiting-deal
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - intraday-session-pattern                  # Lien Ch 11 PDF p. 117: "exploits the common perception that UK traders are notorious stop hunters" — entry exploits a known intraday micro-pattern within the London-open session window. V4 precedent: SM_221 SilverBullet (NY 10:00-11:00 liquidity grab) + SM_419 ProGo (pivot break-and-go). Lien's variant is a London-open false-breakout-fade (range defined 06:00-07:00 GMT during Frankfurt-London power hour; entry on post-07:00 spike-through-and-reverse pattern).
  - symmetric-long-short                      # Lien Ch 11 PDF pp. 118-119: explicit Long + Short rule lists (mirror)
  - atr-hard-stop                             # Lien rule 4: "no more than 25 pips away from your range high, or 35 pips" — fixed pip stop; V5 maps to ATR(14)·M variant via `stop_offset_pips` parameter sweep
  - friday-close-flatten                      # M5-M15 intraday strategy with same-session close (Lien example PDF p. 120 second-half exits "after the London open on the following trading day" so occasional overnight hold; default V5 friday_close applies cleanly)
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Lien, Kathy (3rd ed., 2015). Day Trading and Swing Trading the Currency Market: Technical and Fundamental Strategies to Profit from Market Moves. Wiley Trading. Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 11 'Technical Trading Strategy: Waiting for the Deal' (PDF pp. 117-121) including § chapter intro / GBPUSD-stop-hunt thesis (PDF pp. 117-118) + § 'Strategy Rules' Long (PDF p. 118) + Short (PDF pp. 118-119) + § 'Examples' three worked examples (GBPUSD M5 Fig 11.1 PDF pp. 119-120; GBPUSD M10 Fig 11.2 PDF pp. 120-121; GBPUSD M15 Fig 11.3 PDF p. 121)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC04/raw/ch08-12_technical.txt` lines 568-626 (chapter intro: Asian-session quietness → London-open volume → UK-dealer stop-hunt thesis), lines 628-658 (Long + Short rule lists verbatim), lines 660-704 (three worked examples with explicit pip arithmetic). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Day Trading and Swing Trading t - Kathy Lien.pdf`.

## 2. Concept

GBPUSD's intraday volume distribution is heavily concentrated in the European/London session (UK = 41% of total FX volume per Lien's BIS 2014 reference, PDF p. 117). UK and European interbank dealers are the primary market makers for GBPUSD, and Lien (PDF pp. 117-118) frames them as "notorious stop hunters" who, "at the onset of trading and use their client data to trigger close stops on both sides of the markets to gain the pip differential." The strategy takes advantage of this dynamic: in the early Asian/Frankfurt session, GBPUSD trades a tight range (Lien defines "the range" = 06:00-07:00 GMT high/low). At the London open (~07:00 GMT), dealers spike price through ONE side of the range to flush stops. Lien's strategy fades the spike: once price has spiked through one side AND reversed back through the OPPOSITE side, enter in the OPPOSITE direction of the spike at the OPPOSITE-side range extreme + 10 pips offset.

Mechanical translation: between 06:00-07:00 GMT, record range_high + range_low. After 07:00 GMT, monitor for either (a) price > range_high + 25 pips (false-up spike) → place stop-sell at range_low - 10 pips, OR (b) price < range_low - 25 pips (false-down spike) → place stop-buy at range_high + 10 pips. Stop is at OPPOSITE-side range extreme + 25 pips (= 35-pip risk from entry). TP1 at +50 pips (~1.4R) → close half + BE; TP2 at +105 pips (3R from entry).

Verbatim Lien framing on GBPUSD-specific stop-hunt thesis (PDF pp. 117-118):

> "The British pound trades most actively against the U.S. dollar during the European and London trading hours. ... This provides a great opportunity for day traders to capture the initial directional intraday real move that occurs within the first few hours of London trading. This strategy exploits the common perception that UK traders are notorious stop hunters. This means that the initial movement at the London open may not always be the real one. Since UK and European dealers are the primary market makers for the GBPUSD, they have tremendous insight into the extent of actual supply and demand for the pair. The 'waiting for the real deal' trading strategy first sets up when interbank dealing desks survey their books at the onset of trading and use their client data to trigger close stops on both sides of the markets to gain the pip differential. Once these stops are taken out and the books are cleared, the real directional move in the GBPUSD will begin to occur, at which point we look for the rules of this strategy to be met before entering into a long or short position."

## 3. Markets & Timeframes

```yaml
markets:
  - forex                                     # Lien Ch 11 explicitly GBPUSD-specific in framing; thesis admits other UK-dealer-active pairs but examples are GBPUSD-only
timeframes:
  - M5                                        # Lien example Fig 11.1 GBPUSD M5 chart
  - M10                                       # Lien example Fig 11.2 GBPUSD M10 chart
  - M15                                       # Lien example Fig 11.3 GBPUSD M15 chart
session_window:
  range_definition: "06:00-07:00 GMT (Frankfurt-London power hour)"  # Lien: "the price action between the Frankfurt and London power hour of 6 GMT to 7 GMT NY Time"
  entry_window: "07:00 GMT - end of London/NY session"               # Lien: "Once these stops are taken out and the books are cleared, the real directional move in the GBPUSD will begin to occur"; 2 of 3 examples close before NY close, 1 holds to next-day London open
primary_target_symbols:
  - "GBPUSD.DWX (Lien's primary universe per chapter framing — UK-dealer stop-hunt thesis is GBPUSD-specific. All 3 worked examples are GBPUSD: PDF p. 119 Fig 11.1 fade-up spike short entry @ 1.5324 with stop @ 1.5359 = 35-pip risk, exit half @ 1.5274 + remainder @ 1.5219 for 3R hit; PDF p. 120 Fig 11.2 fade-up spike short @ 1.5389 with stop @ 1.5424, exits @ 1.5339 + 1.5284; PDF p. 121 Fig 11.3 fade-down spike long @ 1.5197 with stop @ 1.5172, exits @ 1.5247 + BE)"
  - "EURUSD.DWX (out-of-source — Lien's chapter framing also cites EURUSD as Asian-session-quiet pair: 'currencies such as the EURUSD and GBPUSD tend to trade within a very tight range during these hours' PDF p. 117; thesis-admissible but no worked examples)"
  - "EURGBP.DWX, GBPCHF.DWX, GBPJPY.DWX (out-of-source — UK-dealer-primary-market-maker pairs; thesis-admissible candidates for P3.5 CSR)"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Lien's PDF pp. 118-119 rule lists (with ambiguity-resolution notes against the worked examples).

```text
PARAMETERS:
- BAR                  = M5         // Lien example Fig 11.1; sweep [M5, M10, M15] per other examples
- RANGE_START_GMT      = "06:00"    // Lien: "Frankfurt and London power hour of 6 GMT to 7 GMT NY Time"
- RANGE_END_GMT        = "07:00"
- SPIKE_THRESHOLD_PIPS = 25         // Lien rule 1 (short): "trades more than 25 pips above the high established"
- ENTRY_OFFSET_PIPS    = 10         // Lien rule 3: "10 pips below the low of the range" / "10 pips above the high of the range"
- STOP_OFFSET_PIPS     = 25         // Lien rule 4: "no more than 25 pips away from your range high, or 35 pips"
                                    //   total risk = ENTRY_OFFSET_PIPS + STOP_OFFSET_PIPS = 35 pips
- ENTRY_WINDOW_END_GMT = "21:00"    // not specified by Lien; default = London/NY session close per V5 friday-close discipline. Default 21:00 broker time = US close.

DEFINITION (range over 06:00-07:00 GMT window):
- range_high = max(high[t]) for all M5 bars t in [06:00 GMT, 07:00 GMT]
- range_low  = min(low[t])  for all M5 bars t in [06:00 GMT, 07:00 GMT]

EACH-BAR (after 07:00 GMT, in arming state ARMED_AWAITING_SPIKE):
- if high[t] > range_high + SPIKE_THRESHOLD_PIPS:           // FALSE-UP-SPIKE detected
    advance to ARMED_AWAITING_REVERSE_SHORT
- elif low[t] < range_low - SPIKE_THRESHOLD_PIPS:           // FALSE-DOWN-SPIKE detected
    advance to ARMED_AWAITING_REVERSE_LONG

EACH-BAR (in ARMED_AWAITING_REVERSE_SHORT, post-spike-up):
- Lien rule 2 (short): "Wait for the pair to reverse and penetrate the low [of the range]."
- if low[t] < range_low:                                    // reversal back through opposite extreme
    PLACE stop-sell at range_low - ENTRY_OFFSET_PIPS
    initial_stop_price = range_low + STOP_OFFSET_PIPS       // 25p above range_low; 35p total risk
    advance to ARMED_PENDING_FILL
- if t > ENTRY_WINDOW_END_GMT: cancel state; return to ARMED_AWAITING_SPIKE next session

EACH-BAR (in ARMED_AWAITING_REVERSE_LONG, post-spike-down):
- Lien rule 2 (long, reverse-engineered from Fig 11.3 example PDF p. 121):
   "the low [of the range] is broken first, and when that happens we place an order to buy 10 pips above the previous days high at 1.0806"
   — wait, that quote is from Ch 13 Fader; let me re-cite. Lien Ch 11 LONG rule 2 reads:
   "Look for the pair to reverse and penetrate the high [of the range]"
   (text near PDF p. 118 says "make new range low" but that wording is inconsistent with the
    short rule 1 mirror and the Fig 11.3 worked example where LONG entry is placed AFTER price
    breaks BELOW range low THEN reverses; § 9 verbatim quotes preserved with explanatory note)
- if high[t] > range_high:                                  // reversal back through opposite extreme
    PLACE stop-buy at range_high + ENTRY_OFFSET_PIPS
    initial_stop_price = range_high - STOP_OFFSET_PIPS       // 25p below range_high; 35p total risk
    advance to ARMED_PENDING_FILL
- if t > ENTRY_WINDOW_END_GMT: cancel state; return to ARMED_AWAITING_SPIKE next session

ON FILL:
- entry_price        = stop-buy / stop-sell trigger price
- initial_risk_pips  = abs(entry_price - initial_stop_price)  ≈ 35 pips at default offsets
- advance to IN_POSITION
```

**Long-rule-1 ambiguity note**: Lien's verbatim Long rule 1 (PDF p. 118) reads "Early European trading in GBPUSD begins around 1am NY Time, and we look for the pair to make new range low of at least 25 pips above the opening price". This phrasing is internally inconsistent with the Short rule 1 mirror and with Fig 11.3 worked example. Reverse-engineered intent from Fig 11.3 (PDF p. 121: "GBPUSD drips lower, breaking below the range low and trading down to 1.5105" → buy entry placed 10p above range_high) is: Long rule 1 should read "GBPUSD opens in Europe and trades more than 25 pips BELOW the LOW established during the Frankfurt to London power hour" (mirror of Short rule 1). Card adopts the reverse-engineered mirror; § 9 preserves the verbatim quote with explanatory note.

## 5. Exit Rules

Lien rule 5 (long, PDF p. 118) verbatim:

> "If the position moves lower by 50 pips, close half of the position, move stop on rest to breakeven, and target three times risk, or 105 pips on the remainder."

Note: Lien's verbatim rule 5 says "moves LOWER by 50 pips" for the LONG side, which is internally inconsistent (long profit is upward, not lower). Reverse-engineered from Fig 11.1 worked example (PDF p. 119: "A take profit on half of the position is placed at 1.5274, or 50 pips below the entry price" — this is for SHORT entry, where 50 pips BELOW entry = profit). For LONG, the corresponding rule reads "if the position moves HIGHER by 50 pips". Card adopts the consistent direction-aware reading; § 9 preserves verbatim text with note.

Pseudocode:

```text
PARAMETERS:
- TP1_PIPS           = 50         // Lien rule 5: "50 pips" partial-take threshold
- TP2_RR             = 3.0        // Lien rule 5: "target three times risk, or 105 pips on the remainder"
- TRAIL_AFTER_TP1    = "BE"       // Lien rule 5: "move stop on rest to breakeven"
- TRAIL_METHOD       = "fixed_TP2_3R"
                                  // Lien specifies fixed 3R exit, NOT a trailing stop on the remainder
                                  // Some traders may prefer trailing — exposed as P3 sweep variant

EACH-BAR (in long position, default fixed-TP2 exit):
- HARD STOP — fires at initial_stop_price (range_high - 25p anchor)
- TP1 (close half + BE move) at +TP1_PIPS = +50 pips:
    if (high[t] - entry_price) >= TP1_PIPS:
      CLOSE_HALF
      move_remaining_stop to BE (entry_price)
- TP2 (close remainder) at +TP2_RR × initial_risk_pips ≈ +105 pips:
    if (high[t] - entry_price) >= TP2_RR * initial_risk_pips:
      CLOSE_REMAINDER

EACH-BAR (in short position): mirror — TP1 at -50 pips, BE move, TP2 at -105 pips.

FRIDAY CLOSE: M5-M15 intraday strategy with same-session-or-next-session close. Lien
example Fig 11.2 (PDF p. 120) holds remainder until "after the London open on the following
trading day" — occasional ~24h hold but never multi-day. Default V5 friday_close applies
cleanly; weekend-hold rare. No waiver requested.

P3 sweep variant: trailing-stop-on-remainder (instead of fixed TP2_RR=3R) — adds upside
capture on strong post-London directional moves; loses pip P&L on chop-then-reverse cases.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed (single position; state machine is single-shot per session)
- gridding: NOT allowed
- Lien thesis is GBPUSD-specific (UK-dealer stop-hunt mechanic). For non-GBPUSD majors, edge is unproven — exposed as P3.5 CSR axis but with `darwinex_native_data_only` no-issue (all G10 majors trade on Darwinex). Default symbol filter: GBPUSD-only at first deployment.
- Pre-news exclusion: Lien (PDF pp. 117-118) frames the strategy as exploiting the post-stop-hunt RETURN-TO-MEAN move, which can coincide with ECB / NFP / BoE rate decisions. V5 default P8 News Impact pause-window applies; standard framework gating handles it.
- Session-time-gate: ARMED state machine is GATED ON the Frankfurt-London power hour 06:00-07:00 GMT for range definition + post-07:00 entry window. NO ENTRIES outside this session.
- Range-validity filter (OPTIONAL P3 sweep axis): minimum range width (e.g., range >= 15 pips OR range >= 0.5×ATR(20) on D1) — prevents trading on Asian-quiet days where range is too tight to define a meaningful spike threshold.
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding, no stacking)
- bracket-style state machine: only ONE direction is armed at any time after spike detection (whichever side spikes first wins; the alternate side stays disarmed for that session)
- position size: V5 RISK_PERCENT / RISK_FIXED standard
- TP1 (50% close + BE move): hard rule at +50 pips
- TP2 (close remainder): hard rule at +3R from original entry (~+105 pips at default offsets)
- ALTERNATIVE P3 sweep: trail-after-TP1 (2-bar-low/high or ATR(14)·M) instead of fixed TP2
- Friday Close: ENABLED by default; intraday timeframe → no waiver candidacy
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: range_start_gmt
  default: "06:00"                            # Lien: "6 GMT"
  sweep_range: ["05:00", "06:00", "06:30"]
- name: range_end_gmt
  default: "07:00"                            # Lien: "7 GMT"
  sweep_range: ["07:00", "07:30", "08:00"]
- name: spike_threshold_pips
  default: 25                                 # Lien: "more than 25 pips above"
  sweep_range: [10, 15, 20, 25, 30, 40]
- name: entry_offset_pips
  default: 10                                 # Lien: "10 pips above/below the high/low of the range"
  sweep_range: [5, 10, 15, 20]
- name: stop_offset_pips
  default: 25                                 # Lien: "no more than 25 pips away from your range high"
  sweep_range: [15, 20, 25, 30, 40]
- name: tp1_pips
  default: 50                                 # Lien: "50 pips"
  sweep_range: [30, 40, 50, 60, 75]
- name: tp2_rr
  default: 3.0                                # Lien: "three times risk, or 105 pips"
  sweep_range: [2.0, 2.5, 3.0, 4.0, trail_after_tp1]
- name: trail_method_after_tp1
  default: "none_fixed_tp2"                   # Lien-verbatim: fixed TP2 = 3R, no trail
  sweep_range: [none_fixed_tp2, two_bar_extreme, atr14x2_trail, atr14x3_trail]
- name: tf
  default: M5                                 # Lien Fig 11.1 example
  sweep_range: [M5, M10, M15]                 # all three Lien-cited
- name: range_validity_min_pips
  default: 0                                  # OFF; Lien does not specify
  sweep_range: [0, 10, 15, 20, 30]
```

P3.5 (CSR) axis: GBPUSD-primary deployment per Lien's thesis. P3.5 candidates: `GBPUSD.DWX` (primary), `EURUSD.DWX` (Lien-cited Asian-quiet pair), `EURGBP.DWX`, `GBPCHF.DWX`, `GBPJPY.DWX` (UK-dealer-primary pairs). Cross-pair PASS rate is a thesis-validation check — if non-GBP pairs fail at P3.5, that confirms Lien's UK-dealer-specificity claim.

## 9. Author Claims (verbatim, with quote marks)

Strategy framing — Asian-quiet-then-London-volume + UK-dealer stop-hunt thesis, PDF pp. 117-118:

> "Traditionally, trading tends to be the quietest during the Asian market hours as we indicated in Chapter 4. This means that currencies such as the EURUSD and GBPUSD tend to trade within a very tight range during these hours. According to the Bank of International Settlement's Triennial FX Survey published in September of 2014, the United Kingdom is the most active trading center, capturing 41% of total volume. ... The British pound trades most actively against the U.S. dollar during the European and London trading hours. ... This provides a great opportunity for day traders to capture the initial directional intraday real move that occurs within the first few hours of London trading. This strategy exploits the common perception that UK traders are notorious stop hunters. This means that the initial movement at the London open may not always be the real one. Since UK and European dealers are the primary market makers for the GBPUSD, they have tremendous insight into the extent of actual supply and demand for the pair. The 'waiting for the real deal' trading strategy first sets up when interbank dealing desks survey their books at the onset of trading and use their client data to trigger close stops on both sides of the markets to gain the pip differential. Once these stops are taken out and the books are cleared, the real directional move in the GBPUSD will begin to occur, at which point we look for the rules of this strategy to be met before entering into a long or short position. This strategy works best following the U.S. open or after a major economic release. With this strategy, you are looking for the noise in the markets to settle before trading the real trend of the day."

Long rule list, PDF p. 118 (verbatim, including the rule-1 wording inconsistency flagged in § 4):

> "Strategy Rules
> Longs:
> 1. Early European trading in GBPUSD begins around 1am NY Time, and we look for the pair to make new range low of at least 25 pips above the opening price (the range is defined as the price action between the Frankfurt and London power hour of 6 GMT to 7 GMT NY Time).
> 2. Look for the pair to reverse and penetrate the high.
> 3. Place an entry order to buy 10 pips above the high of the range.
> 4. Place a protective stop no more than 25 pips away from your range high, or 35 pips.
> 5. If the position moves lower by 50 pips, close half of the position, move stop on rest to breakeven, and target three times risk, or 105 pips on the remainder."

Short rule list, PDF pp. 118-119:

> "Shorts:
> 1. GBPUSD opens in Europe and trades more than 25 pips above the high established during the Frankfurt to London power hour.
> 2. Wait for the pair to reverse and penetrate the low.
> 3. When that occurs, place an entry order to sell 10 pips below the low of the range.
> 4. Place a protective stop no more than 25 pips away from your range low, or 35 pips.
> 5. If the position moves lower by 50 pips, close half of the position, move stop on rest to breakeven, and target three times risk, or 105 pips on the remainder."

Worked-example pip P&L, GBPUSD M5 Fig 11.1 PDF pp. 119-120 (false-up-spike short):

> "Between 6 and 7 GMT, the range high and low for GBPUSD are 1.5359 and 1.5234, respectively. At the start of the London trading session, we see GBPUSD squeeze upwards, taking out the range high of 1.5359. At the time, we place an order to sell GBPUSD 10 pips below the range low at 1.5324. The entry is triggered about an hour and a half later. The protective stop is placed 25 pips above the range low (35 pips total) at 1.5359. A take profit on half of the position is placed at 1.5274, or 50 pips below the entry price. The stop on the remainder of the position is moved to breakeven or 1.5324. The second half of the position is exited at three times risk at 1.5219 shortly after the NY open."

Worked-example pip P&L, GBPUSD M10 Fig 11.2 PDF pp. 120-121 (false-up-spike short):

> "the range high and low established between 6 and 7 GMT are 1.5433 and 1.5399, respectively. At the start of the London trading session, we see GBPUSD squeeze upward, taking out the range high of 1.5433 and racing all the way to 1.5492. At the time, we place an order to sell GBPUSD 10 pips below the range low at 1.5389. The entry is triggered around the NY open. ... A take profit on half of the position is placed at 1.5339, or 50 pips below the entry price. ... The second half of the position is exited at three times risk at 1.5284 after the London open on the following trading day."

Worked-example pip P&L, GBPUSD M15 Fig 11.3 PDF p. 121 (false-down-spike long):

> "the range during the Frankfurt London power hour is 1.5187 and 1.5139. At the start of the London trading session, GBPUSD drips lower, breaking below the range low and trading down to 1.5105. When the range low is broken, we place an order to buy GBPUSD 10 pips below the range high at 1.5197. The entry is triggered around the NY open. The protective stop is placed 25 pips below the range high (35 pips total) at 1.5172. A take profit on half of the position is placed at 1.5247, or 50 pips below the entry price. The stop on the remainder of the position is moved to breakeven or 1.5197. The second exit is not shown in the chart in Figure 11.3, but the breakeven stop is triggered."

Worked-example arithmetic note: Fig 11.3 quote contains a typo — "buy GBPUSD 10 pips below the range high at 1.5197" with range_high = 1.5187 implies entry at 1.5187 + 10 = 1.5197, i.e., "10 pips ABOVE the range high", consistent with the rules.

**Lien provides NO numeric aggregate performance claim** — only the descriptive thesis ("notorious stop hunters") and per-trade pip-P&L on three GBPUSD examples (Fig 11.1: 35-pip risk → +50 pips half + +105 pips remainder = ~+155 pips total; Fig 11.2: same R/R structure with overnight hold; Fig 11.3: +50 pips half + BE on remainder = ~+50 pips total). Per BASIS rule, no extrapolated performance number is asserted in this card; pipeline P2-P9 produce the actual edge measurement.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3                              # rough estimate; intraday session-pattern fade with TP1=1.4R + TP2=3R structure typically 1.2-1.5 PF when filter-discipline holds
expected_dd_pct: 12                           # rough estimate; M5-M15 intraday with 35-pip stops + same-session close typically 8-15% DD range
expected_trade_frequency: 50-150/year         # rough estimate; daily session-window strategy with spike+reverse precondition — not every London open produces a valid setup
risk_class: medium                            # M5-M15 intraday with 35-pip stops; latency-sensitive at the spike-detection edge but not strict scalping
gridding: false
scalping: false                               # M5 bars; not scalping per V5 framework definition
ml_required: false                            # range arithmetic + state machine + threshold checks; no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (range-window arithmetic + spike-threshold check + reverse-back-through-opposite-extreme + stop-buy/sell at offset; deterministic given M5+ bar data)
- [x] No Machine Learning required
- [x] If gridding: not applicable (single position; state machine is single-shot per session)
- [x] If scalping: not applicable (M5+ bars; though spike-detection latency at the edge is P5b-relevant)
- [x] Friday Close compatibility: same-session or single-overnight-hold typical; default V5 friday_close applies cleanly
- [x] Source citation is precise enough to reproduce (PDF pp. 117-121 rule lists + 3 worked examples with explicit pip arithmetic; verbatim quotes preserved in § 9 with reverse-engineering notes for the rule-1 long-side wording inconsistency)
- [x] No near-duplicate of existing approved card (no SRC card uses London-open opening-range false-breakout-fade pattern; SRC03_S04 williams-tdw-bias is a calendar-day-of-week bias, not session-window opening-range; SRC04_S03 fade-double-zeros uses round-number anchor, not session-range anchor)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default + session-time-gate (06:00-07:00 GMT range definition + 07:00-21:00 GMT entry window); GBPUSD-default symbol filter (override at P3.5 CSR for cross-pair tests); optional range_validity_min_pips axis for Asian-quiet-day filter"
  trade_entry:
    used: true
    notes: "3-state state machine: ARMED_AWAITING_SPIKE → ARMED_AWAITING_REVERSE_{LONG|SHORT} → ARMED_PENDING_FILL; range = 06:00-07:00 GMT high/low; spike threshold +25p; reverse condition = price re-penetrates opposite range extreme; stop-buy/sell at opposite range extreme + 10p offset"
  trade_management:
    used: true
    notes: "TP1 = +50 pips partial close + move-rest-to-BE; TP2 = +3R fixed exit on remainder (Lien-verbatim) or trail-after-TP1 (P3 variant)"
  trade_close:
    used: true
    notes: "exit on initial 35-pip stop OR TP1+TP2 sequence OR trail-fired-on-remainder (P3 variant)"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # NOT load-bearing — typical same-session close. Listed for CTO completeness.
  - enhancement_doctrine                      # LOAD-BEARING on session-window times (06:00-07:00 GMT) and pip thresholds (25/10/25 base). Lien's GMT times are calibrated for Frankfurt-London power hour; cross-pair generalization (e.g., applying to EURUSD with NY-open or AUDUSD with Tokyo-open) requires re-anchoring session-window times. P3 sweep `range_start_gmt` / `range_end_gmt` axes test this. Once fixed, retune is enhancement_doctrine.
  - news_pause_default                        # NOT load-bearing — Lien (PDF p. 117) frames the strategy as exploiting RETURN-TO-MEAN AFTER stop hunt, which can coincide with London-open ECB/BoE/news. V5 default P8 news-pause applies; standard framework gating handles it.
  - scalping_p5b_latency                      # POTENTIALLY load-bearing — M5 bars + spike-detection at the edge of bar boundaries means VPS latency on stop-buy/sell fills materially affects measured edge. P5b stress with calibrated VPS latency simulation recommended at IMPL.

at_risk_explanation: |
  friday_close — Intraday M5-M15 strategy with typical same-session close (Fig 11.1 example
  closes "shortly after the NY open"; Fig 11.2 holds to "following trading day" but never
  crosses a weekend in any worked example). Default V5 friday_close applies cleanly. Listed
  for completeness.

  enhancement_doctrine — Lien's verbatim 06:00-07:00 GMT range window is calibrated for
  Frankfurt-London power hour. Cross-pair generalization (especially to non-GBP pairs with
  different active-dealer geographies — e.g., EURUSD with ECB/Frankfurt anchor, USDJPY with
  Tokyo open) may require re-anchoring the range window. P3 sweep axes test this. Pip
  thresholds (25/10/25) are similarly major-FX-volatility-calibrated; cross-pair generalization
  may require ATR-scaled offsets. Once fixed, retune is enhancement_doctrine.

  news_pause_default — Lien explicitly states the strategy works best "after a major economic
  release" (PDF p. 118) — i.e., post-news re-emergence-of-trend, not during the news event
  itself. V5 default P8 news-pause covers the news-window blackout cleanly.

  scalping_p5b_latency — M5 bars + spike-detection at intra-bar high/low means latency on the
  spike-trigger and on the subsequent stop-buy/sell fills can materially affect measured edge,
  especially at the 25-pip spike threshold which can be crossed in milliseconds during high-
  vol London open. P5b stress with calibrated VPS latency simulation recommended at IMPL.
  CTO sanity-check at G0.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default + session-time-gate (06:00-07:00 GMT range, 07:00-21:00 GMT entry) + GBPUSD-only symbol filter at first deployment
  entry: TBD                                  # 3-state state machine with M5+ bar evaluation; range-window aggregation across 12 M5 bars (06:00-07:00 GMT); spike-threshold check on each post-07:00 bar; reverse-back-through opposite-extreme check; stop-buy/sell at offset; ~150-200 LOC in MQL5
  management: TBD                             # TP1=+50p partial close + BE; TP2=+3R fixed exit (default) or trail-after-TP1 (variant)
  close: TBD                                  # standard SL/TP plus P3 variant trail
estimated_complexity: medium                  # session-window state machine + spike+reverse detection + intra-day timezone handling adds nontrivial LOC vs simple bar-close strategies
estimated_test_runtime: 4-8h                  # P3 sweep ~30,000 cells; M5 bars over 5+ years across GBPUSD primary + 4 cross-pair CSR symbols
data_requirements: standard                   # M5 OHLC on Darwinex GBPUSD.DWX + cross-pair candidates
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
- 2026-04-28: SRC04_S04 reuses existing `intraday-session-pattern` flag (V4 SM_221 SilverBullet,
  SM_419 ProGo precedent) — Lien's London-open opening-range false-breakout-fade is a session-
  window-driven micro-pattern that fits the existing flag's definition. Card-level documentation
  distinguishes Lien's variant from SilverBullet's NY-10:00 liquidity-grab-break-and-go: Lien's
  entry is at OPPOSITE range extreme (fade direction) while SilverBullet/ProGo go-with the
  break direction. No vocab gap proposed.

- 2026-04-28: Lien Ch 11 LONG rule 1 contains an internal-consistency bug ("make new range low
  of at least 25 pips above the opening price"). Reverse-engineered intent from Fig 11.3
  worked example + Short rule 1 mirror: the long rule should read "GBPUSD opens in Europe and
  trades more than 25 pips BELOW the LOW established during the Frankfurt to London power hour".
  Card adopts the reverse-engineered mirror; § 9 preserves verbatim text with explanatory note
  per BASIS rule.

- 2026-04-28: Lien Ch 11 LONG rule 5 contains a similar consistency bug ("If the position moves
  LOWER by 50 pips" for the LONG side). Reverse-engineered intent from Fig 11.3 example pip
  arithmetic: should read "If the position moves HIGHER by 50 pips" for long, mirror of short.
  Card adopts the consistent reading; § 9 preserves verbatim text.

- 2026-04-28: Lien provides NO numeric aggregate performance claim — only descriptive thesis
  ("notorious stop hunters", PDF p. 117) and per-trade pip-P&L on three GBPUSD examples
  (~+155 pips on Fig 11.1, similar on Fig 11.2 with overnight hold, +50 pips on Fig 11.3 with
  BE-trail on remainder). Per BASIS rule, no extrapolated number is asserted.

- 2026-04-28: GBPUSD-specificity is load-bearing per Lien's UK-dealer thesis. Card defaults to
  GBPUSD-only first deployment; cross-pair generalization (EURUSD, EURGBP, GBP-crosses) is a
  P3.5 CSR test that DOUBLES as thesis-validation: if non-GBPUSD pairs fail at P3.5, that
  confirms the UK-dealer-specificity claim; if they PASS, the thesis generalizes more broadly
  than Lien claimed.

- 2026-04-28: Latency sensitivity flagged at `scalping_p5b_latency` despite M5 bar size. The
  spike-detection at intra-bar high/low can be crossed in milliseconds during high-vol London
  open; subsequent stop-buy/sell fills are similarly latency-sensitive. P5b stress with
  calibrated VPS latency simulation recommended at IMPL.

- 2026-04-28: V5-architecture-fit profile is FAVOURABLE — single-symbol forex, M5+ bars, no
  multi-leg / multi-stock / cointegration architecture concerns. Session-window state machine
  adds modest LOC but is straightforward bookkeeping. Expected G0 yield CLEAN with
  `scalping_p5b_latency` flagged for IMPL-time stress validation.
```
