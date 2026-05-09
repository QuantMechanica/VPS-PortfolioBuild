# Strategy Card — Singh Guppy Burst (M5 GBP/JPY 3hr-NY-close-to-Asia-open range bracket)

## Card Header

```yaml
strategy_id: SRC06_S15
ea_id: TBD
slug: singh-guppy-burst
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

strategy_type_flags: [breakout, time-of-day, range-bracket]
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

> **singh-guppy-burst (SRC06_S15 - M5 GBPJPY, NY-close-to-Asia-open range bracket)**
> 
> APPROVED
> Edge mechanism: session-transition liquidity asymmetry bracket on the most volatile major FX pair; OCA pending-order structure is mechanically clean
> Portfolio fit: FIRST time-of-day bracket EA in pipeline; adds GBPJPY yen-cross exposure; M5 time-window limits capital commitment
> Author claim: "30-40 pip ranges typical" - author-claimed illustrative
> 
> DST handling for 17:00 NY reference (EST vs. EDT clock-shift) = P0 implementation concern, not G0 blocker.

### Flags carried forward

- P0 implementation concern (CTO): DST handling for 17:00 NY reference (EST vs EDT clock-shift). Not a G0 blocker.


## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7."
    location: "Chapter 10 'Strategies for Mechanical Traders' — Strategy 15: Guppy Burst, PDF pp. 217-223. Strategy concept PDF p. 218; Long-trade-setup PDF p. 218; Short-trade-setup PDF p. 221; Strategy Roundup PDF p. 222."
    quality_tier: B
    role: primary
```

## 2. Concept

Time-of-day breakout-bracket on M5 GBP/JPY ("guppy" is forex slang for GBP/JPY). After the US market close (5 P.M. New York time = 17:00 NY), there is a 3-hour quiet window before Asian markets open. Strategy: at 5 P.M. NY (= 00:00 on FXPRIMUS broker time per author, which is GMT+5 broker), measure the high/low range of those first 3 hours; place pending buy-stop at the high and pending sell-stop at the low. SL of one pending order is the opposite end of the range; TP is 2× the range distance (R:R 1:2). When one pending fills, cancel the other.

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - M5
primary_target_symbols:
  - GBPJPY                                     # author-prescribed only — "the guppy burst method applies only to the GBP/JPY" (PDF p. 218)
```

## 4. Entry Rules

```text
At 17:00 NY time = US market close (= 22:00 GMT during EST winter, 21:00 GMT during EDT summer):
- start tracking the next 3 hours of M5 candles for GBP/JPY
- at 20:00 NY time (= 3 hours later), compute:
   range_high = HighestHigh of M5 bars in [17:00 NY, 20:00 NY]
   range_low  = LowestLow  of M5 bars in [17:00 NY, 20:00 NY]
   range_pips = range_high - range_low
- place TWO pending orders simultaneously:
   PENDING BUY-STOP at range_high
       SL = range_low (so SL distance = range_pips)
       TP = range_high + 2 × range_pips
   PENDING SELL-STOP at range_low
       SL = range_high (SL distance = range_pips)
       TP = range_low - 2 × range_pips
- ORDER MANAGEMENT: when ONE pending order fills, IMMEDIATELY DELETE the other pending
- pending order expiry: end of the same 24-hour broker day (e.g., 00:00 NY next day) — neither side fired? Cancel both.
```

## 5. Exit Rules

```text
- TP at 2× range distance, SL at opposite end of range (R:R 1:2)
- No partial close, no trailing — the strategy is a clean bracketed breakout
- Friday Close enforced (M5 trades hold typically <12 hours, but Fri-eve setup means the bracket would span Fri evening into Sat — V5 should not even arm the bracket on Fri evening; only Mon-Thu evenings)
```

## 6. Filters (No-Trade)

```text
- skip if range_pips < 15 pips (range too tight; spread eats RR economics)
- skip if range_pips > 200 pips (range too wide; SL too painful, RR economics still 1:2 but absolute risk too large for one trade)
- skip on Friday evening (do not arm the bracket where pending fills could trigger over weekend gap)
- skip if broker time-zone offset is uncertain at 17:00 NY (DST handling required — see § 12)
- skip during major news releases scheduled for the 3-hour quiet window or the breakout-window (V5 default)
```

## 7. Trade Management Rules

```text
- one position per magic+symbol (only one of two pendings can fill; the other is cancelled on first fill)
- no pyramiding, no gridding
- Friday Close enforced + DO-NOT-ARM-ON-FRI-EVE filter
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: range_window_hours
  default: 3
  sweep_range: [2, 3, 4, 5]
- name: range_start_offset_from_ny_close
  default: 0
  sweep_range: [-1, 0, 1, 2]                   # NY close ±1h tolerance for DST/broker-time variance
- name: tp_range_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5, 3.0]
- name: range_min_pips
  default: 15
  sweep_range: [10, 15, 20, 30]
- name: range_max_pips
  default: 200
  sweep_range: [150, 200, 300]
```

## 9. Author Claims (verbatim)

```text
"The risk for this trade is 30 pips, and the reward is 60 pips. The risk to reward ratio is 1:2, which yields a tidy 6% return if we take a 3% risk." (PDF p. 220 — illustrative single-trade long example, GBPJPY M5)

"The risk for this trade is 21 pips, and the reward is 42 pips. The risk to reward ratio is 1:2, which yields a tidy 6% return if we take a 3% risk." (PDF p. 221 — illustrative single-trade short example, GBPJPY M5)

"This strategy is suitable for traders who are available during a specific time of the day to execute the trade during the three-hour gap." (PDF p. 222)

"The forex market is relatively quiet during this time and tends to move in a gentle yet predictable manner. The market then springs to life again when the Asian market opens. The guppy burst seeks to identify the trading range during this 3-hour window and anticipate a potential breakout of the trading range." (PDF p. 217-218)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3                               # 1:2 RR with ~40-45% win rate
expected_dd_pct: TBD                           # consecutive non-fill or whipsaw weeks possible; estimate 8-12%
expected_trade_frequency: 100-200/year         # ~5 setups per week × ~50 weeks (excluding Fri-eve and holidays)
risk_class: medium
gridding: false
scalping: false                                # M5 with 30-pip TP is breakout-bracket, NOT scalping per V5 definition (5-pip TPs)
ml_required: false
```

## 11. Strategy Allowability Check (V5)

- [x] Strategy concept is mechanical (time-of-day window + range bracket is fully rule-tight)
- [x] No ML required
- [x] No gridding, no martingale
- [x] Not scalping (RR 1:2 with 20-50 pip TPs)
- [x] Friday Close compatible (with DO-NOT-ARM-ON-FRI-EVE filter)
- [x] Source citation precise: PDF pp. 217-223
- [x] No near-duplicate (Lien lien-inside-day-breakout uses D1 inside day, not 3hr intraday window; Williams 8wk-box is multi-week consolidation)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "Fri-eve filter + range-size bounds + news pause + DST-adjusted time gate"
  trade_entry:
    used: true
    notes: "two-side pending bracket at the 17:00-20:00 NY range high/low"
  trade_management:
    used: true
    notes: "cancel-other-pending-on-first-fill; no further partial closes"
  trade_close:
    used: false
    notes: "exit by SL/TP only"
```

```yaml
hard_rules_at_risk: []
at_risk_explanation: |
  No hard rule at risk in normal operation. Implementation note: V5 broker time is Darwinex
  NY-Close convention (GMT+2 outside US DST, GMT+3 during US DST per memory
  `project_qm_broker_time`). 17:00 NY = 22:00 GMT in winter = 23:00 GMT in summer ALWAYS = 00:00
  broker time at Darwinex (the broker rolls midnight at 17:00 NY by definition). The 3-hour
  range window is therefore 00:00-03:00 broker time → trading window starts at 03:00 broker.
  This DST handling is a TIMEZONE_AWARENESS question for P1 build, not a strategy-design issue.
```
