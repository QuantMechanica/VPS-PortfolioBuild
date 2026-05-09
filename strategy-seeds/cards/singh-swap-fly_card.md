# Strategy Card — Singh Swap and Fly (D1/W1 carry + three-soldiers/three-crows pattern)

## Card Header

```yaml
strategy_id: SRC06_S12
ea_id: TBD
slug: singh-swap-fly
status: APPROVED
created: 2026-05-09
created_by: Research
last_updated: 2026-05-09

# Dual-gate verdict (sourced from QUA-1059 thread, run 9713f33a, 2026-05-09;
# canonical QB record at processes/strategy_cards/g1_approved_2026-05-09.md sec 4)
g0_issue: QUA-1059
g0_reviewed_at: 2026-05-09
g0_reviewer: "CEO (per QUA-1110 directive; QUA-1059 disposition 2026-05-09T11:21:53Z accepting QB G1 batch + treating QUA-1059 thread as g0 source-of-truth)"
g0_verdict: APPROVED
g1_issue: QUA-1059
g1_reviewed_at: 2026-05-09
g1_reviewer: "Quality-Business (R1-R4 reputable-source check, batch-wide PASS for SRC06)"
g1_verdict: APPROVED
g1_verdict_record: "processes/strategy_cards/g1_approved_2026-05-09.md (sec 4)"

strategy_type_flags: [carry, position-trade, candlestick-pattern]
```
## Verdict Trail (QUA-1059)

QB G0 advisory + R1-R4 verdict rendered in QUA-1059 thread (run 9713f33a, 2026-05-09; QB comment 2026-05-09T11:02:19Z).
CEO G0 ratification recorded in QUA-1059 disposition (2026-05-09T11:21:53Z) and reaffirmed by QUA-1110 (this commit's authority).
Canonical QB record on origin/main: `processes/strategy_cards/g1_approved_2026-05-09.md` (sec 4), commit `07c2d2f9`.

### Source-level R1-R4 (batch-wide, applies to all 14 SRC06 cards)

- **R1 author identifiable**: PASS - Mario Singh, named author, Wiley-published (Wiley Trading series, ISBN 978-1-118-38551-7), CNBC-featured (Squawk Box / Capital Connection / Worldwide Exchange), founder FX1 Academy and Fullerton Markets.
- **R2 source verifiable**: PASS - ISBN confirmed; PDF on OWNER Google Drive (text-clean via pdftotext, 26.5 MB, 9187 lines); per-card page numbers cited verbatim from source.
- **R3 mechanical clarity**: PASS - each card has explicit Long/Short Trade Setup extracted verbatim from book's structured chapters; SL/TP/entry all rule-specified.
- **R4 no paywall bypass**: PASS - OWNER-supplied commercial PDF; no piracy.

Source verdict: **REPUTABLE** (T1 Tier B per `processes/qb_reputable_source_criteria.md`).
Author-claim band: **author-claimed**.

### Per-card verdict (verbatim QB excerpt from QUA-1059)

> **singh-swap-fly (SRC06_S12 - D1/W1, carry + three-soldiers/crows + BE-after-1R)**
> 
> APPROVED
> Edge mechanism: three-soldiers/crows candlestick momentum confirmation for carry entry; BE mechanic eliminates risk once momentum confirmed; carry-trade has theoretical basis in UIP deviation
> Portfolio fit: lien-carry-trade (SRC04_S07) is closest - both carry archetypes, but different entry triggers (pattern vs. deterioration) and different exit (BE-hold-for-swap vs. fixed TP); sufficiently distinct
> Author claim: "302 pips swap over 36 weeks" - author-claimed single-trade illustration, not backtest
> 
> **CEO action required:** friday_close = false exception is mandatory for this strategy's swap-accrual thesis to function. This exception requires CEO + OWNER ratification per V5 Hard Rules. At P9, pairwise correlation vs. lien-carry-trade must be checked before simultaneous deployment of both carry archetypes.

### Flags carried forward

- friday_close = false exception (V5 Hard Rule): BLOCKS P0 until CEO + OWNER ratify per QUA-1059 CEO-action item; mandatory for swap-accrual thesis.
- P9 pairwise correlation vs lien-carry-trade (SRC04_S07): must be checked before simultaneous deployment of both carry archetypes.


## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7."
    location: "Chapter 9 'Strategies for Position Traders' — Strategy 12: Swap and Fly, PDF pp. 192-199. Strategy concept PDF p. 193; Long-trade-setup PDF p. 194; Short-trade-setup PDF p. 196; Strategy Roundup PDF p. 197."
    quality_tier: B
    role: primary
  - type: book
    citation: "Lien, Kathy. (2009/2014). Day Trading and Swing Trading the Currency Market. Wiley. (SRC04 primary)."
    location: "Carry-trade conceptual ancestor (lien-carry-trade card SRC04_S07); Singh's strategy is a candlestick-trigger overlay on the same carry thesis."
    quality_tier: A
    role: supplement
```

## 2. Concept

Position-trader carry strategy: enter on a daily three-white-soldiers (long) or three-black-crows (short) candlestick pattern in a positive-swap currency pair, then move SL to break-even after price moves 1R in favor. Once at BE, the trade stays open indefinitely earning daily swap until price hits BE-stop. Author's example shows positive AUD/JPY swap of 1.2 pips/day — over 36 weeks (252 days) accumulates ~302 pips of swap with zero remaining risk after the BE move (PDF p. 195).

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - D1
  - W1
primary_target_symbols:
  - AUDJPY                                     # author's primary long example, "highest positive swaps" PDF p. 197
  - GBPAUD                                     # author's primary short example
  - any pair with strongly-positive swap on broker's platform
```

## 4. Entry Rules

```text
LONG:
- on closed D1 bar
- detect three-white-soldiers pattern: three consecutive bull candles where:
   each candle's Close > prior Close
   each candle's Open is within prior candle's body (no gap)
   each candle has body > 50% of bar range (limited upper shadow)
- and pair has POSITIVE swap on long side (broker swap rate query at entry)
- then BUY at next-bar (4th candle) open
- SL = recent significant low (e.g., LowestLow of last 10 bars, or last D1 swing-low)
- TP target = open-ended; trade managed via BE move (see § 5)

SHORT:
- on closed D1 bar
- detect three-black-crows pattern: three consecutive bear candles where:
   each candle's Close < prior Close
   each candle's Open within prior candle's body
   each candle has body > 50% of bar range
- and pair has POSITIVE swap on SHORT side
- then SELL at next-bar open
- SL = recent significant high (HighestHigh of last 10 bars, or last D1 swing-high)
```

## 5. Exit Rules

```text
- when price moves +1R in favor (i.e., distance equal to initial SL→Entry), move SL to entry price (BE)
- after BE move, trade is "risk-free" (only swap continues to accrue or BE-stop hits)
- final exit: BE-stop hits (price returns to entry from extended favorable territory)
   OR optional discretionary exit at 1:3 RR per author's note PDF p. 199
- Friday Close DEFAULT V5 = true would exit at Fri 21:00 every week, defeating the strategy's
   "swap accrues daily" thesis. STRATEGY REQUIRES `friday_close = false` exception per V5
   Hard Rule documentation. See § 12 hard_rules_at_risk.
```

## 6. Filters (No-Trade)

```text
- skip if pair's swap rate has been negative or near-zero (< 0.5 pips/day) for any of last 5 broker-rate snapshots
- skip if recent SL distance > 1000 pips (trade tying up too much margin to BE-out)
- skip if D1 ATR(14) > symbol's 60-day average × 1.5 (high-vol regime, pattern signal less reliable)
- skip during week containing FOMC, ECB, BoJ rate-decision (V5 default `news_pause_default` for major-central-bank events; carry pairs especially sensitive to rate surprises)
```

## 7. Trade Management Rules

```text
- one position per magic+symbol
- BE move at +1R; no further partial closes (full position rides on BE-stop after that)
- no pyramiding, no gridding
- Friday Close: STRATEGY REQUESTS EXCEPTION (`friday_close = false`); held positions to accrue swap continuously across weekends
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: pattern_body_pct_min
  default: 0.50
  sweep_range: [0.40, 0.50, 0.60, 0.70]
- name: sl_lookback_bars
  default: 10
  sweep_range: [5, 10, 15, 20]
- name: be_trigger_rr
  default: 1.0
  sweep_range: [0.5, 0.75, 1.0, 1.25, 1.5]
- name: full_exit_rr
  default: 3.0                                  # author's optional 1:3 exit
  sweep_range: [2.0, 3.0, 5.0, infinity]
- name: tf
  default: D1
  sweep_range: [D1, W1]
- name: swap_min_pips_per_day
  default: 1.0
  sweep_range: [0.5, 1.0, 2.0, 3.0]
```

## 9. Author Claims (verbatim)

```text
"The swap for holding a long AUD/JPY position was AUD12 for every standard lot. This is equivalent to 1.2 pips. The swap per week is 1.2 pips × 7 = 8.4 pips. The swap for 36 weeks is 8.4 pips × 36 = 302.4 pips." (PDF p. 195 — illustrative single-trade long example, AUD/JPY D1, trade hits BE after 36 weeks = 252 days)

"The swap for holding a short GBP/AUD position was AUD14 per standard lot, which was equivalent to 1.4 pips. The swap per week is 1.4 pips × 7 = 9.8 pips. The swap for 35 weeks is 9.8 pips × 35 = 343 pips." (PDF p. 196 — illustrative single-trade short example, GBP/AUD D1)

"Once the position hits breakeven, there is no more risk for the trade. Swap is continuously earned for every day that the trade is open." (PDF p. 195)

"For the long AUD/JPY trade, the stop loss was 570 pips. Hence, traders could have chosen to exit the trade entirely if the AUD/JPY was at a minimum of 1710 pips (570 × 3) above the entry price." (PDF p. 199 — optional discretionary 1:3 exit path)
```

**Research note:** swap rates are time-varying (broker-dependent and central-bank-driven). The author's 1.2 pips/day on AUD/JPY was the rate at his book's writing in 2012-2013. Current broker swap snapshots must be re-queried at P2/P3 — historic backtest must use broker's contemporaneous swap rates, not 2012's.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.5                               # high R:R if BE survives; low frequency
expected_dd_pct: TBD                           # losing trades = full SL distance (570 pips in author's example), so single-trade DD can be 5-15% account
expected_trade_frequency: 5-15/year per symbol  # D1 three-soldiers/three-crows in positive-swap pairs is rare
risk_class: medium                             # offset between long-hold-risk and risk-free-once-at-BE
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5)

- [x] Strategy concept is mechanical (3-soldiers/3-crows pattern + swap-rate gate is fully rule-tight)
- [x] No ML required
- [x] No gridding, no martingale
- [x] Not scalping
- [ ] Friday Close compatibility: **STRATEGY REQUIRES EXCEPTION** — see § 12; exception request to OWNER + CEO at G0 ratification
- [x] Source citation precise: PDF pp. 192-199
- [x] No near-duplicate (Lien lien-carry-trade is the conceptual ancestor — same carry-thesis but Lien uses indicator-trend confirmation; Singh uses candlestick-pattern. Mechanically distinct entry trigger; Lien card cited as `role: supplement`)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "swap-rate gate + ATR regime guard + central-bank-event blackout"
  trade_entry:
    used: true
    notes: "three-soldiers/three-crows pattern detection + positive-swap confirmation; entry at next-bar open"
  trade_management:
    used: true
    notes: "BE move at +1R; optional partial close at 1:3 RR per author"
  trade_close:
    used: true
    notes: "BE-stop hit (after BE move); optional 1:3 RR full close"
```

```yaml
hard_rules_at_risk:
  - friday_close
at_risk_explanation: |
  friday_close: this strategy explicitly holds positions for 35-36 weeks to accrue daily swap.
  V5 framework default `friday_close = true` (forced flat at Fri 21:00 broker time) breaks the
  thesis entirely — every week the position closes Fri evening and re-opens at Sun open with
  whatever gap exists. The carry-accrual benefit of 1.2-1.4 pips/day evaporates if swap is not
  earned over weekends (Wednesday triple-swap rule means weekend swap IS booked even though
  market is closed; strategy compatible with broker swap rules, NOT with Fri-flat enforcement).

  EXCEPTION REQUESTED: per V5 Hard-Rule documentation framework, a `friday_close = false` setting
  with documented swap-thesis rationale + crisis-window analysis (P5c) showing gap-risk over
  weekends is bounded. CEO + OWNER ratification required at G0; if denied, strategy is shelved
  with rationale.
```
