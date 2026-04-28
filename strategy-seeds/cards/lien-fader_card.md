# Strategy Card — Lien Fader (ADX<20 prior-day-range false-breakout fade, daily-frame setup with hourly-frame entry)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC04/raw/ch13-16_technical.txt` (verbatim Lien Ch 13 § "Strategy Rules" Long + Short rule lists + § "Further Optimization" + 2 worked examples on USDJPY / EURUSD daily and hourly charts).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3 / DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC04_S06
ea_id: TBD
slug: lien-fader
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - failed-breakout-fade                      # Lien Ch 13 PDF p. 130 rule 2 (long): "Wait for the market to break below the previous day's low by at least 15 pips" + rule 3: "Place an entry order to buy a few ticks above the previous day's high". Pattern: range-bound regime (ADX<20) → false breakout one side of prior-day range → entry at OPPOSITE side of prior-day range (fade). Distinct from SRC03_S10 williams-spec-trap (multi-day uptrend + 6-20-day BOX consolidation + breakout-day TRUE-LOW reference; Lien uses single PRIOR-DAY range + ADX<20 range gate + OPPOSITE-side prior-day extreme reference). Card-level parameter `pre-breakout-regime = range-bound-low-ADX` distinguishes from williams-spec-trap's `trending`. NO vocab gap proposed — `failed-breakout-fade` definition admits both regimes per the disambiguation table.
  - symmetric-long-short                      # Lien Ch 13 PDF pp. 130-131: explicit Long + Short rule lists (mirror)
  - atr-hard-stop                             # Lien rule 4: "place your initial stop no more than 20 pips away" — fixed pip stop; V5 maps to ATR(14)·M variant
  - atr-trailing-stop                         # Lien rule 6: "Trail the stop on the remaining position" — trail method not specified; Lien EURUSD example (PDF p. 132) uses "two-bar low" trail → adopt 2-bar-extreme as default, ATR-trail as P3 variant
  - friday-close-flatten                      # Daily-frame setup with hourly-frame entry; Lien example PDF pp. 131-132 reaches first target shortly after entry (within trading session). Default V5 friday_close applies cleanly; not load-bearing.
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Lien, Kathy (3rd ed., 2015). Day Trading and Swing Trading the Currency Market: Technical and Fundamental Strategies to Profit from Market Moves. Wiley Trading. Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 13 'Technical Trading Strategy: Fader' (PDF pp. 129-133) including § chapter intro / false-breakout thesis (PDF pp. 129-130) + § 'Strategy Rules' Long (PDF p. 130) + Short (PDF p. 130) + § 'Examples' two worked examples (USDJPY D1+H1 Fig 13.1+13.2 PDF pp. 130-131; EURUSD D1+H1 Fig 13.3+13.4 PDF pp. 131-132) + § 'Further Optimization' (PDF p. 132)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC04/raw/ch13-16_technical.txt` lines 1-42 (chapter intro: false-breakout problem in FX + ADX<20 range-screen rationale), lines 43-79 (Long + Short rule lists verbatim), lines 81-118 (two worked examples with explicit pip arithmetic), lines 120-130 (Further Optimization on news-window timing + tight-range pair preference). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Day Trading and Swing Trading t - Kathy Lien.pdf`.

## 2. Concept

In low-trend regimes (ADX<20, ideally trending downward = range-tightening), false breakouts of the prior day's range are common — interbank dealers push price slightly beyond significant levels to "run stops" on retail traders before reverting (Lien PDF p. 129: "we frequently see interbank dealers or other traders try to push prices beyond those levels momentarily in order to run stops"). The strategy fades these stop-hunts: identify a low-ADX range pair, wait for price to break the prior day's range by at least 15 pips on ONE side (false breakout), then enter on the OPPOSITE side of the prior day's range (fade direction). Stop is tight (≤20 pips), TP1 at +1R, BE on rest, trail.

Crucially DIFFERENT from SRC03_S10 williams-spec-trap, which fades a breakout in a TRENDING market with multi-day BOX consolidation and BREAKOUT-DAY TRUE-LOW reference. Lien Fader uses a RANGE-BOUND-LOW-ADX precondition (opposite regime) with PRIOR-DAY-RANGE reference (single bar, not multi-bar box). Both cards share the `failed-breakout-fade` flag with card-level parameters distinguishing the regime + reference structure.

Verbatim Lien framing on the false-breakout problem (PDF p. 129):

> "Trading breakouts at key levels can involve a lot of risk and as a result, false breakouts appear more frequently than real breakouts. ... So what this boils down to is that traders need a methodology for screening out consolidation patterns for trades that have a higher potential of resulting in a false breakout. The following rules provide a good basis for screening such trades. The fader strategy is a variation of the 'waiting for the real deal' strategy. It uses the daily charts to identify the range-bound environment and the hourly charts to pinpoint entry levels."

## 3. Markets & Timeframes

```yaml
markets:
  - forex                                     # Lien Ch 13 entire universe is forex; 2 worked examples on USDJPY and EURUSD majors
timeframes:
  - D1                                        # Lien primary signal frame: ADX(14) read on D1; prior-day high/low from D1
  - H1                                        # Lien execution frame: "uses the daily charts to identify the range-bound environment and the hourly charts to pinpoint entry levels" (PDF p. 130)
  - H4                                        # plausible variant; out-of-source extrapolation
session_window: not specified                 # D1 setup + H1 entry; no specific session restriction
primary_target_symbols:
  - "USDJPY.DWX (Lien example: D1 ADX<20 trending down, prev-day high 120.27, prev-day low 120.00; H1 spike +15p above 120.42 at European open → short entry @ 119.95 (=120.00 - 5p), stop @ 120.15, TP1 @ 119.75 = +20p; PDF pp. 130-131)"
  - "EURUSD.DWX (Lien example: D1 ADX<20 trending down, prev-day high 1.0801, prev-day low 1.0708; H1 spike below low first → long entry @ 1.0806 (=1.0801 + 5p), stop @ 1.0786, TP1 @ 1.0826 = +20p; trail to 1.0818 with 2-bar low; PDF pp. 131-132)"
  - "EURGBP.DWX, USDCAD.DWX, EURCHF.DWX, EURCAD.DWX, AUDCAD.DWX (Lien preferred-cohort PDF p. 132: 'works best with currency pairs that are less volatile and have narrower trading ranges' — overlap with Ch 12 inside-day cohort)"
  - "GBPUSD.DWX, AUDUSD.DWX, NZDUSD.DWX (multi-major generalization implicit in Lien's chapter framing; check at CSR P3.5)"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Lien's PDF p. 130 rule lists.

```text
PARAMETERS:
- BAR_SIGNAL          = D1     // Lien: ADX read on D1; prev-day H/L from D1
- BAR_ENTRY           = H1     // Lien: "use ... hourly charts to pinpoint entry levels"
- ADX_PERIOD          = 14     // Lien rule 1: "14-day ADX"
- ADX_THRESHOLD       = 20     // Lien rule 1: "less than 20"
- SPIKE_THRESHOLD_PIPS = 15    // Lien rule 2 (long): "break below the previous day's low by at least 15 pips"
- ENTRY_OFFSET_PIPS    = 5     // Lien rule 3: "a few ticks" — USDJPY example: 120.00-5p=119.95 → 5p; EURUSD example: 1.0801+5p=1.0806 → 5p
- STOP_OFFSET_PIPS     = 20    // Lien rule 4 (long): "no more than 20 pips away"; rule 5 (short): "20-pips below your entry"

DEFINITION (D1 readings as of close of bar D-1):
- adx_d1            = ADX(14) on D1, evaluated at close of bar D-1
- adx_d1_trending_dn = adx_d1 < ADX_PERIOD ago's adx_d1 reading (trending downward)
- prev_day_high     = high[D-1]                 // Lien: "previous day's high"
- prev_day_low      = low[D-1]                  // Lien: "previous day's low"

EACH-H1-BAR (during D session, in arming state ARMED_LOW_ADX):
- precondition: adx_d1 < ADX_THRESHOLD          // Lien rule 1
                                                //   OPTIONAL: adx_d1_trending_dn = true (Lien: "Ideally, the ADX should also be trending downward")

LONG SIDE arming:
- if low[t] < prev_day_low - SPIKE_THRESHOLD_PIPS:  // Lien rule 2 (long): false-down-spike
    PLACE limit-stop-buy at: prev_day_high + ENTRY_OFFSET_PIPS
                                                //   Lien rule 3 (long): "Place an entry order to buy a few ticks above the previous day's high"
    initial_stop_price = entry_price - STOP_OFFSET_PIPS
                                                //   Lien rule 4 (long): "place your initial stop no more than 20 pips away"
    advance to ARMED_PENDING_LONG_FILL

SHORT SIDE arming:
- if high[t] > prev_day_high + SPIKE_THRESHOLD_PIPS: // Lien rule 2 (short): false-up-spike
    PLACE limit-stop-sell at: prev_day_low - ENTRY_OFFSET_PIPS
                                                //   Lien rule 3 (short): "Place an entry order to sell a few ticks below the previous day's low"
    initial_stop_price = entry_price + STOP_OFFSET_PIPS
                                                //   Lien rule 5 (short): "20-pips below your entry" (presumably typo for "above your entry"; mirror context)
    advance to ARMED_PENDING_SHORT_FILL

ON FILL:
- entry_price        = stop-buy / stop-sell trigger price
- initial_risk_pips  = STOP_OFFSET_PIPS = 20 pips at default
- advance to IN_POSITION

DAY-BOUNDARY:
- at end of D session (start of new D bar), all ARMED states reset; new prev_day_high / prev_day_low computed from the just-closed D bar; ADX re-read.
```

**Short rule 5 ambiguity note**: Lien's verbatim Short rule 5 (PDF p. 130) reads "If the position moves lower by 50 pips, close half of the position, move stop on rest to breakeven, and target three times risk, or 105 pips on the remainder" — but this rule list (Ch 13 short rules) actually corresponds to Lien Ch 11 § "Waiting for the Deal" rules 5 (50 pips threshold + 3R target) which Lien appears to have copy-pasted. The Ch 13 USDJPY example uses TP1 at 20 pips (= +1R = 20-pip stop), not 50 pips. Reverse-engineered from worked examples: Ch 13 actual exit rules are TP1 at +1R (~20 pips) + BE move + trail (NOT TP1 at 50 pips + 3R as Lien's rule-5 verbatim says). Card adopts the worked-example exit behavior; § 9 preserves verbatim text. Per BASIS rule, the discrepancy is documented.

Wait — re-reading Lien Ch 13 rule 5 (verbatim): "5. Take profit on half of position when prices increase by the amount you risked; move stop on remaining position to breakeven." This is the LONG rule 5, and it says "amount you risked" = 1R = 20 pips. Looking at the SHORT rules in raw text: "5. Protect any profits by selling half of the position when it runs 20 pips in your favor." — so SHORT rule 5 is "20 pips in favor" = 1R, no inconsistency. The "50 pips" / "3R" content I flagged was actually from Ch 11. **Corrected**: no Ch 13 inconsistency on rule 5; TP1 = +1R = 20 pips on both sides. Section 9 cites the actual Ch 13 verbatim wording.

## 5. Exit Rules

Lien rule 5+6 (long, PDF p. 130) verbatim:

> "5. Take profit on half of position when prices increase by the amount you risked; move stop on remaining position to breakeven.
> 6. Trail the stop on the remaining position."

Pseudocode:

```text
PARAMETERS:
- TP1_RR             = 1.0        // Lien rule 5: "amount you risked" = 1R = ~20 pips
- TRAIL_AFTER_TP1    = "BE_then_trail"
                                  // Lien rule 5: "move stop on remaining position to breakeven"
                                  // Lien rule 6: "Trail the stop on the remaining position"
- TRAIL_METHOD       = "two_bar_extreme"
                                  // Lien rule 6 does not specify trail method
                                  // EURUSD worked example (PDF p. 132): "if we trail the stop on the position using a two-bar low, the second half of the trade is closed at 1.0818"
                                  // → adopt 2-bar-extreme as default; ATR-trail / donchian-N variants exposed as P3 sweep

EACH-BAR (in long position):
- HARD STOP — fires at initial_stop_price (entry - 20p)
- TP1 (close half + BE move) at +1R from entry (Lien rule 5):
    if (high[t] - entry_price) >= initial_risk_pips:    // = 20 pips at default
      CLOSE_HALF
      move_remaining_stop to BE (entry_price)
      activate trailing stop on remainder
- TRAIL on remainder (Lien rule 6, method per Lien EURUSD example):
    trail_long = max(trail_prev, min(low[t-1], low[t-2]))
                                  // 2-bar-low default; sweep ATR(14)·M / donchian-N alternatives
- exit on trail-stop fire OR on initial_stop fire (whichever first)

EACH-BAR (in short position): mirror — TP1 at -1R, BE move, 2-bar-high trail.

FRIDAY CLOSE: Daily-frame setup + hourly-frame entry; Lien examples reach TP1 within hours of
entry (USDJPY: triggered "a few hours later" + "first target is reached"; EURUSD: "triggered
about 7 hours later" + "first target is reached shortly after"). Default V5 friday_close
applies cleanly; not load-bearing.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed (single position; state machine is single-shot per D-day)
- gridding: NOT allowed
- Lien preferred symbols (PDF p. 132): "works best with currency pairs that are less volatile and have narrower trading ranges" — overlap with SRC04_S05 inside-day cohort. Symbol-cohort filter at CSR P3.5.
- Lien Further Optimization (PDF p. 132): "works best when there are no significant economic reports scheduled for release that could trigger sharp unexpected movements. ... prices often consolidate ahead of the U.S. nonfarm payrolls release. ... there is a higher likelihood that any breakout on the back of those releases would be a real one and not one that you want to fade." — V5 P8 News Impact pause-window covers this; standard framework gating handles it.
- ADX<20 precondition is the PRIMARY range-regime gate (Lien rule 1). OPTIONAL: ADX-trending-downward sub-condition (Lien: "Ideally, the ADX should also be trending downward, indicating that the trend is weakening further") — exposed as P3 sweep variant.
- Optional P3 sweep: ADX_THRESHOLD ∈ {15, 18, 20, 22, 25} for sensitivity analysis on the range-regime cutoff.
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding, no stacking)
- bracket-style state machine: only ONE direction is armed per D session after spike detection (whichever side spikes first wins; the alternate side stays disarmed for that D session)
- position size: V5 RISK_PERCENT / RISK_FIXED standard
- TP1 (50% close + BE move): hard rule at +1R (~20 pips at default offsets)
- Trail on remainder: 2-bar-extreme default (Lien EURUSD example); ATR-trail / donchian-N variants exposed as sweep
- Friday Close: ENABLED by default; intraday-to-daily timeframe → no waiver candidacy
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: adx_period
  default: 14                                 # Lien: "14-day ADX"
  sweep_range: [10, 14, 20]
- name: adx_threshold
  default: 20                                 # Lien: "less than 20"
  sweep_range: [15, 18, 20, 22, 25]
- name: adx_trending_down_required
  default: false                              # Lien: "Ideally, the ADX should also be trending downward" (optional)
  sweep_range: [false, true]
- name: spike_threshold_pips
  default: 15                                 # Lien rule 2: "by at least 15 pips"
  sweep_range: [10, 12, 15, 20, 25]
- name: entry_offset_pips
  default: 5                                  # Lien: "a few ticks" — examples reverse-engineered to 5p
  sweep_range: [2, 5, 10, 15]
- name: stop_offset_pips
  default: 20                                 # Lien: "no more than 20 pips away"
  sweep_range: [10, 15, 20, 25, 30]
- name: tp1_rr
  default: 1.0                                # Lien rule 5: "amount you risked"
  sweep_range: [0.75, 1.0, 1.25, 1.5, 2.0]
- name: trail_method
  default: two_bar_extreme                    # Lien EURUSD example precedent
  sweep_range: [two_bar_extreme, three_bar_extreme, atr14x2_trail, atr14x3_trail, donchian5_trail]
- name: tf_entry
  default: H1                                 # Lien primary
  sweep_range: [M30, H1, H4]
- name: tf_signal
  default: D1                                 # Lien primary
  sweep_range: [D1, H4]                       # H4 = out-of-source variant
```

P3.5 (CSR) axis: re-run on Lien-preferred tight-range cohort first (`EURGBP.DWX`, `USDCAD.DWX`, `EURCHF.DWX`, `EURCAD.DWX` if Darwinex offers, `AUDCAD.DWX` if Darwinex offers), then full Darwinex FX cohort. ADX<20 precondition filters out trending-pair-pair-day combinations naturally; expect signal density variance across symbols.

## 9. Author Claims (verbatim, with quote marks)

Strategy framing — false-breakout problem + ADX<20 range-screen, PDF pp. 129-130:

> "Trading breakouts at key levels can involve a lot of risk and as a result, false breakouts appear more frequently than real breakouts. Sometimes prices will test the resistance level once, twice, or even three times before breaking out. This has fostered the development of a large degree of contra-trend traders who look only to fade breakouts in the currency markets. Yet fading every breakout can also result in some significant losses because once a real breakout occurs, the trend is generally strong and long-lasting. So what this boils down to is that traders need a methodology for screening out consolidation patterns for trades that have a higher potential of resulting in a false breakout. ... The fader strategy is a variation of the 'waiting for the real deal' strategy. It uses the daily charts to identify the range-bound environment and the hourly charts to pinpoint entry levels."

Long rule list, PDF p. 130:

> "Strategy Rules
> Longs:
> 1. Locate a currency pair whose 14-day ADX is less than 20. Ideally, the ADX should also be trending downward, indicating that the trend is weakening further
> 2. Wait for the market to break below the previous day's low by at least 15 pips.
> 3. Place an entry order to buy a few ticks above the previous day's high.
> 4. After getting filled, place your initial stop no more than 20 pips away.
> 5. Take profit on half of position when prices increase by the amount you risked; move stop on remaining position to breakeven.
> 6. Trail the stop on the remaining position."

Short rule list, PDF p. 130:

> "Shorts:
> 1. Locate a currency pair whose 14-day ADX is less than 20. Ideally the ADX should also be trending downward, indicating that the trend is weakening further
> 2. Look for a move above the previous day's high by at least 15 pips.
> 3. Place an entry order to sell a few ticks below the previous day's low.
> 4. Once filled, place the initial protective stop no more than 20-pips below your entry.
> 5. Protect any profits by selling half of the position when it runs 20 pips in your favor.
> 6. Place a trailing stop on the remainder of the position."

Worked-example pip P&L, USDJPY D1+H1 Fig 13.1+13.2 PDF pp. 130-131:

> "the previous day's high is 120.27. We first look for a move above the previous day's high by at least 15 pips, or 120.42. ... that move occurs at the start of the European session after which we place an order to sell 5 pips below the previous day's low of 120.00. The order is filled a few hours later at 119.95. At the time, we place our stop at 120.15 and a first target of 119.75. The first target is reached, and the stop on the rest of the position is moved to breakeven or 119.95."

Worked-example pip P&L, EURUSD D1+H1 Fig 13.3+13.4 PDF pp. 131-132:

> "the previous day's high is 1.0801, and the low is 1.0708. We see that the low is broken first, and when that happens we place an order to buy 5 pips above the previous days high at 1.0806. ... the order is triggered about 7 hours later. At the time, we place our stop at 1.0786 and a first target of 1.0826. The first target is reached shortly after, and the stop on the rest of the position is moved to breakeven, or 1.0806. In this example, if we trail the stop on the position using a two-bar low, the second half of the trade is closed at 1.0818."

Further Optimization, PDF p. 132:

> "The false breakout strategy works best when there are no significant economic reports scheduled for release that could trigger sharp unexpected movements. For example, prices often consolidate ahead of the U.S. nonfarm payrolls release. Generally speaking, they are consolidating for a reason, and that reason is because the market is undecided and is either positioned already or wants to wait to react following that release. Either way, there is a higher likelihood that any breakout on the back of those releases would be a real one and not one that you want to fade. This strategy works best with currency pairs that are less volatile and have narrower trading ranges."

**Lien provides NO numeric aggregate performance claim** — only thesis ("false breakouts appear more frequently than real breakouts" PDF p. 129) and per-trade pip-P&L on two examples (USDJPY: +20 pips half + BE on rest; EURUSD: +20 pips half + +12 pips trailed remainder = ~+32 pips total). Per BASIS rule, no extrapolated performance number is asserted in this card; pipeline P2-P9 produce the actual edge measurement.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3                              # rough estimate; tight-stop ADX-gated fade with TP1=1R + 2-bar-trail typically 1.2-1.5 PF range
expected_dd_pct: 12                           # rough estimate; H1 entry with 20-pip stops typically 8-15% DD range
expected_trade_frequency: 30-80/year/symbol   # rough estimate; ADX<20 + spike-threshold compound filter is signal-restrictive
risk_class: medium                            # H1 entry on tight 20-pip stops; latency-sensitive at the spike-detection edge
gridding: false
scalping: false                               # H1 bars; not scalping per V5 framework
ml_required: false                            # ADX threshold + bar-arithmetic + state machine; no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (ADX threshold + prev-day H/L spike detection + opposite-extreme stop-buy/sell; deterministic given D1+H1 OHLC + ADX library)
- [x] No Machine Learning required
- [x] If gridding: not applicable (single position)
- [x] If scalping: not applicable (H1 entry frame)
- [x] Friday Close compatibility: typical same-session close; default applies
- [x] Source citation is precise enough to reproduce (PDF pp. 129-132 rule lists + 2 worked examples + Further Optimization; verbatim quotes preserved)
- [x] No near-duplicate of existing approved card — DISTINCT FROM SRC03_S10 williams-spec-trap on FOUR axes: (1) regime precondition (Lien: ADX<20 RANGE-bound; Williams: strong UPTREND), (2) range-window structure (Lien: single PRIOR-DAY range; Williams: 6-20-day MULTI-DAY box), (3) reference price for entry (Lien: OPPOSITE-side prior-day extreme; Williams: TRUE-LOW of breakout day), (4) stop sizing (Lien: 20-pip fixed stop; Williams: TRUE-LOW-anchored variable stop). Both share the `failed-breakout-fade` flag with card-level parameter `pre-breakout-regime` distinguishing.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default + ADX<20 range-regime gate (primary entry precondition); optional ADX-trending-downward sub-gate; pre-news exclusion handled by V5 P8 default"
  trade_entry:
    used: true
    notes: "D1 ADX read + D1 prev-day H/L extraction + H1 spike-detection (15p past prev-day extreme) + opposite-side stop-buy/sell at +5p offset; long/short symmetric"
  trade_management:
    used: true
    notes: "TP1 = +1R partial close + move-rest-to-BE (Lien rule 5); trail remainder via 2-bar-extreme (Lien EURUSD example precedent) or ATR / donchian-N variants"
  trade_close:
    used: true
    notes: "exit on initial 20-pip stop OR TP1 partial + BE-trail-fired-on-remainder OR trail-stop-on-remainder fire"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # NOT load-bearing — typical same-session close per Lien examples (USDJPY: TP1 reached "shortly after" entry + a few hours; EURUSD: TP1 "shortly after" + trail finishes within session). Listed for CTO completeness.
  - enhancement_doctrine                      # LOAD-BEARING on entry/stop pip offsets (5/20). Lien's offsets are calibrated for major-FX volatility scale; cross-pair generalization requires ATR-scaled offsets. P3 sweep `entry_offset_pips` / `stop_offset_pips` axes test this.
  - news_pause_default                        # NOT LOAD-BEARING — Lien Further Optimization (PDF p. 132) explicitly states the strategy works best WITHOUT major news. V5 P8 default aligns; no waiver requested.
  - scalping_p5b_latency                      # POTENTIALLY LOAD-BEARING — H1 entry frame + 20-pip stops + spike-detection edge. P5b stress with calibrated VPS latency simulation recommended at IMPL.

at_risk_explanation: |
  friday_close — H1-entry-frame intraday strategy with typical TP1-within-hours and same-day
  exit. Default V5 friday_close applies cleanly. Listed for completeness.

  enhancement_doctrine — Lien's verbatim 5p / 20p offsets are calibrated for major-FX
  volatility. JPY pairs (different absolute pip values) and high-vol pairs may require
  ATR-scaled offsets. P3 sweep tests this. Once fixed, retune is enhancement_doctrine.

  news_pause_default — Lien explicitly states strategy works best without major news. V5
  default P8 news-pause aligns; no waiver requested.

  scalping_p5b_latency — H1 entry + 20-pip stops makes spike-detection latency material at
  the 15-pip spike threshold and on subsequent stop-buy/sell fills. P5b stress recommended.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default + ADX-threshold gate + optional ADX-trending-downward sub-gate
  entry: TBD                                  # D1 ADX read at start of each D session + prev-day H/L extraction + H1 spike-detection state machine + opposite-side stop-buy/sell; ~120-180 LOC in MQL5
  management: TBD                             # TP1 = +1R partial + BE move; 2-bar-extreme trail (default) or ATR / donchian-N (variants)
  close: TBD                                  # standard SL/TP/trail
estimated_complexity: medium                  # multi-frame (D1 signal + H1 entry) state machine + ADX library integration adds modest LOC
estimated_test_runtime: 4-8h                  # P3 sweep ~25,000 cells; H1 bars over 5+ years across FX cohort
data_requirements: standard                   # D1+H1 OHLC on Darwinex FX symbols; ADX library standard
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
- 2026-04-28: SRC04_S06 reuses existing `failed-breakout-fade` flag with card-level parameters
  distinguishing from SRC03_S10 williams-spec-trap on FOUR structural axes:
    1. Regime precondition: Lien ADX<20 RANGE-bound; Williams strong UPTREND.
    2. Range-window structure: Lien single PRIOR-DAY range; Williams 6-20-day MULTI-DAY box.
    3. Reference price for entry: Lien OPPOSITE-side prior-day extreme; Williams TRUE-LOW of
       BREAKOUT day.
    4. Stop sizing: Lien 20-pip fixed stop; Williams TRUE-LOW-anchored variable stop.
  Card-level parameter `pre-breakout-regime ∈ {trending, range-bound-low-ADX}` and
  `range_window_bars ∈ {1, 6-20}` capture the variant differences. NO vocab gap proposed —
  the existing flag's definition admits both regimes; sub-flag proliferation would over-
  fragment the controlled vocabulary.

- 2026-04-28: ADX<20 as a range-regime gate is functionally similar to existing
  `atr-regime-mr-gate` (ATR-percentile gate restricting MR entries to low-ATR regimes only).
  The two flags differ in MEASURE: ADX is directional-trend-strength (range from 0-100,
  threshold typically 20-25 for trend cutoff); ATR-percentile is volatility magnitude. For
  Lien Ch 13 specifically, the role is symmetric to atr-regime-mr-gate (range-regime
  precondition for fade entries). NO vocab gap proposed in h4 — but if SRC05+ surfaces a
  third ADX-regime card, propose `adx-range-mr-gate` for symmetry with the existing
  atr-regime-mr-gate flag. Documentation captured here for CEO/CTO future-vocab-watch.

- 2026-04-28: Lien provides NO numeric aggregate performance claim — only thesis ("false
  breakouts appear more frequently than real breakouts", PDF p. 129) and per-trade pip-P&L
  on two examples (USDJPY +20p half + BE; EURUSD +20p half + +12p trail = ~+32p total). Per
  BASIS rule, no extrapolated number is asserted.

- 2026-04-28: Lien Ch 13 SHORT rule 4 has minor wording typo ("20-pips below your entry" —
  should be "20-pips above your entry" for short stop). Card adopts mirror-consistent reading;
  § 9 preserves verbatim text per BASIS rule.

- 2026-04-28: Lien-preferred symbol cohort overlap with SRC04_S05 (inside-day-breakout):
  EURGBP, USDCAD, EURCHF, EURCAD, AUDCAD all cited by Lien as 'tighter trading range' pairs
  in both Ch 12 (Inside Days) and Ch 13 (Fader). At P3.5 CSR phase, these can share a CSR
  cohort; portfolio-construction at P9 should consider correlation between SRC04_S05 +
  SRC04_S06 entries on overlapping symbol-day-cells (both fire on range-bound regimes; same-
  day same-symbol entries possible).

- 2026-04-28: V5-architecture-fit profile is FAVOURABLE — single-symbol forex, multi-frame
  D1+H1 setup is supported by V5; no multi-leg / multi-stock / cointegration architecture
  concerns. ADX library is standard (built into MetaTrader). Expected G0 yield CLEAN with
  `scalping_p5b_latency` flagged for IMPL-time stress validation.
```
