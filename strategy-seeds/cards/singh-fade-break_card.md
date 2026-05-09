# Strategy Card — Singh Fade the Break (M15/M30 false-break-candle reversal at S/R)

## Card Header

```yaml
strategy_id: SRC06_S03
ea_id: TBD
slug: singh-fade-break
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

strategy_type_flags: [mean-reversion, breakout-fade]
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

> **singh-fade-break (SRC06_S03 - M15/M30, false-break candle reversal at S/R)**
> 
> APPROVED
> Edge mechanism: institutional-trap / false-break reversal - documented FX microstructure
> Portfolio fit: first counter-breakout archetype in pipeline; no near-duplicate
> Author claim: mechanistic (price-structure based), no statistical claim to flag

### Flags carried forward

- No specific G0 flag carried; mechanistic archetype.


## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7."
    location: "Chapter 7 'Strategies for Day Traders' — Strategy 3: Fade the Break, PDF pp. 125-131. Strategy concept PDF p. 126; Long-trade-setup PDF p. 127; Short-trade-setup PDF p. 129; Strategy Roundup PDF p. 131."
    quality_tier: B
    role: primary
```

## 2. Concept

Counter-trade a false-break of a horizontal support/resistance level on M15 or M30. When a candle's wick breaks beyond an identified S/R level but the candle closes back inside the range (a "false-break candle"), enter at the next-bar open in the opposite direction of the wick. The strategy bets that institutional traders trapped retail breakout-buyers/sellers and the price will reverse back into the range. Per author: "fade the break helps us to turn these traps into opportunities" (PDF p. 131).

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - M15
  - M30
primary_target_symbols: [EURUSD, USDJPY, GBPUSD, USDCHF, USDCAD, AUDUSD, NZDUSD]   # author lists "seven major currency pairs" PDF p. 126
```

## 4. Entry Rules

```text
LONG (fade a false-break-down through support):
- on closed M15 or M30 bar
- identify a horizontal support level S (e.g., recent N-bar low forming a 2-touch support)
- if just-closed bar's Low < S (wick broke support)
- and just-closed bar's Close > S (closed back above support — "false-break candle")
- and just-closed bar is a bull candle (Close > Open)
- then BUY at next-bar open
- SL = (Low of false-break candle) - 5 pips
- TP1 = Entry + (Entry - SL)                                # R:R 1:1
- TP2 = Entry + 2 × (Entry - SL)                            # R:R 1:2

SHORT (fade a false-break-up through resistance):
- on closed M15 or M30 bar
- identify a horizontal resistance level R (e.g., recent N-bar high forming a 2-touch resistance)
- if just-closed bar's High > R (wick broke resistance)
- and just-closed bar's Close < R (closed back below resistance — "false-break candle")
- and just-closed bar is a bear candle (Close < Open)
- then SELL at next-bar open
- SL = (High of false-break candle) + 5 pips
- TP1 = Entry - (SL - Entry)                                # R:R 1:1
- TP2 = Entry - 2 × (SL - Entry)                            # R:R 1:2
```

## 5. Exit Rules

```text
- 50% of position at TP1 (R:R 1:1), 50% at TP2 (R:R 1:2) — author-prescribed two-target structure (PDF p. 127, p. 130)
- SL handled by entry stop
- After TP1 hit, move SL on remaining 50% to entry (BE) per V5 framework standard partial-close pattern (V5 default; author does not explicitly specify but is the standard interpretation)
- Friday Close enforced (M15/M30 day-trade; positions intended to exit same session)
```

## 6. Filters (No-Trade)

```text
- skip if just-closed bar's wick break of S/R is < 1 pip (must be a meaningful break, not a quote-flicker)
- skip if just-closed bar's body < 30% of bar's range (must be a decisive close-back-inside, not a doji/spinning-top false signal)
- skip if S/R level was first established within last 10 bars (need maturity)
- skip during major news releases (V5 default `news_pause_default`)
```

## 7. Trade Management Rules

```text
- one position per magic+symbol
- partial close at TP1 + BE on remainder (per § 5)
- no pyramiding, no gridding
- Friday Close enforced
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: sr_lookback_bars
  default: 50
  sweep_range: [20, 30, 50, 70, 100]
- name: sr_min_touches
  default: 2
  sweep_range: [2, 3]
- name: sl_buffer_pips
  default: 5
  sweep_range: [2, 3, 5, 7, 10]
- name: tp1_rr
  default: 1.0
  sweep_range: [0.8, 1.0, 1.2, 1.5]
- name: tp2_rr
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5, 3.0]
- name: tf
  default: M15
  sweep_range: [M15, M30]
- name: min_break_pips
  default: 1
  sweep_range: [0.5, 1, 2, 3]
```

## 9. Author Claims (verbatim)

```text
"The risk for this trade is 28 pips, and the reward is 56 pips if both targets are hit. The risk to reward ratio is 1:2, which yields a tidy 6% return if we take a 3% risk." (PDF p. 129 — illustrative single-trade long example, EURUSD M30)

"The risk for this trade is 22 pips, and the reward is 44 pips if both targets are hit. The risk to reward ratio is 1:2, which yields a tidy 6% return if we take a 3% risk." (PDF p. 130 — illustrative single-trade short example, GBPUSD M15)

"Remember that false breaks are traps to catch day traders off guard. However, fade the break helps us to turn these traps into opportunities." (PDF p. 131)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                               # author-implied 1:2 R:R; even at 40% win rate PF~1.3
expected_dd_pct: TBD                           # no author DD claim; counter-trend strategy in strong-trend regimes likely 8-12% DD
expected_trade_frequency: 100-200/year per symbol  # M15/M30 false-breaks at major S/R: maybe 2-4/week per pair; 7 pairs → variable
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5)

- [x] Strategy concept is mechanical (S/R as recent-N-extrema with 2-touch confirmation; false-break is rule-tight close-vs-level)
- [x] No ML required
- [x] No gridding, no martingale
- [x] Not scalping (M15/M30)
- [x] Friday Close compatible (day-trade horizon)
- [x] Source citation precise: PDF pp. 125-131
- [x] No near-duplicate (Williams smash-day card has bar-pattern fade but uses end-of-day not S/R-wick)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "news pause + S/R-maturity + min-break-pips + body-size filter"
  trade_entry:
    used: true
    notes: "false-break-candle close detection at recent-N-extrema; entry at next-bar open"
  trade_management:
    used: true
    notes: "partial close 50% at TP1, BE on remainder, full close at TP2"
  trade_close:
    used: false
    notes: "exit by SL/TP only"
```

```yaml
hard_rules_at_risk: []
at_risk_explanation: |
  No hard rule at risk. Strategy is fully compatible with V5 framework defaults
  (M15/M30 day-trade, single-position, no scalping, no news during entry window, 1:2
  RR with built-in partial-close lifecycle).
```
