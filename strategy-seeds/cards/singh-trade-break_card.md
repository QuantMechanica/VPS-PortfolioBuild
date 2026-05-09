# Strategy Card — Singh Trade the Break (M15/M30 breakout-candle continuation at S/R)

## Card Header

```yaml
strategy_id: SRC06_S04
ea_id: TBD
slug: singh-trade-break
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

strategy_type_flags: [breakout, momentum, trend-following]
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

> **singh-trade-break (SRC06_S04 - M15/M30, close-through breakout continuation)**
> 
> APPROVED
> Edge mechanism: candle-close-through-S/R breakout continuation - standard directional microstructure
> Portfolio fit: logical complement to S03 on same timeframe; no near-duplicate at M15/M30 scale
> Author claim: mechanistic; SL at 60% of candle range is deterministic

### Flags carried forward

- No specific G0 flag carried; mechanistic archetype, deterministic SL rule.


## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7."
    location: "Chapter 7 'Strategies for Day Traders' — Strategy 4: Trade the Break, PDF pp. 131-137. Strategy concept PDF p. 132; Long-trade-setup PDF p. 132; Short-trade-setup PDF p. 135; Strategy Roundup PDF p. 137."
    quality_tier: B
    role: primary
```

## 2. Concept

Continuation breakout: when a candle CLOSES (not wicks) above/below an established support/resistance level, take the breakout in the direction of the close. The defining feature vs S03 (Fade the Break) is that S/R must be CLOSED through, not just wicked. SL is placed at 60% of the prior range — author's claim is that "we do not expect prices to fall back below that point" (PDF p. 132).

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - M15
  - M30
primary_target_symbols: [EURUSD, USDJPY, GBPUSD, USDCHF, USDCAD, AUDUSD, NZDUSD]
```

## 4. Entry Rules

```text
LONG (continuation through resistance):
- on closed M15 or M30 bar
- identify support S and resistance R using at least 2 lows + 2 highs (range = R - S)
- if just-closed bar's Close > R (closed above resistance)
- then BUY at next-bar open                                  # the "breakout candle"
- SL = R - 0.6 × (R - S)                                     # 60% mark of prior range below resistance
- TP1 = Entry + (Entry - SL)                                 # R:R 1:1
- TP2 = Entry + 2 × (Entry - SL)                             # R:R 1:2

SHORT (continuation through support):
- on closed M15 or M30 bar
- identify support S and resistance R
- if just-closed bar's Close < S (closed below support)
- then SELL at next-bar open
- SL = S + 0.6 × (R - S)                                     # 60% mark of prior range above support
- TP1 = Entry - (SL - Entry)
- TP2 = Entry - 2 × (SL - Entry)
```

## 5. Exit Rules

```text
- 50% of position at TP1 (R:R 1:1), 50% at TP2 (R:R 1:2) — author-prescribed two-target structure
- SL handled by entry stop
- After TP1 hit, move SL on remainder to entry (BE) per V5 framework default
- Friday Close enforced
```

## 6. Filters (No-Trade)

```text
- skip if range = (R - S) < threshold (range too small; SL ends up too tight after 60% computation)
- skip if range > threshold (range too wide; SL too far, RR economics break)
- skip if breakout candle Close-vs-R distance < 1 pip (slow drift over level, not impulsive break)
- skip if 2-low / 2-high S/R was established < 10 bars ago (immature levels)
- skip during major news releases (V5 default)
```

## 7. Trade Management Rules

```text
- one position per magic+symbol
- partial close 50% at TP1, BE on remainder, full close at TP2
- no pyramiding, no gridding
- Friday Close enforced
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: sr_lookback_bars
  default: 50
  sweep_range: [30, 50, 70, 100, 150]
- name: sl_range_pct
  default: 0.6
  sweep_range: [0.4, 0.5, 0.6, 0.7, 0.8]
- name: tp1_rr
  default: 1.0
  sweep_range: [0.8, 1.0, 1.5]
- name: tp2_rr
  default: 2.0
  sweep_range: [1.5, 2.0, 3.0]
- name: tf
  default: M15
  sweep_range: [M15, M30]
- name: min_close_break_pips
  default: 1
  sweep_range: [0.5, 1, 2, 3, 5]
- name: range_min_pips
  default: 20
  sweep_range: [15, 20, 30, 40]
- name: range_max_pips
  default: 100
  sweep_range: [80, 100, 150, 200]
```

## 9. Author Claims (verbatim)

```text
"The risk for this trade is 44 pips, and the reward is 88 pips if both targets are hit. The risk to reward ratio is 1:2, which yields a tidy 6% return if we take a 3% risk." (PDF p. 134 — illustrative single-trade long example, AUDUSD M15)

"The risk for this trade is 31 pips, and the reward is 62 pips if both targets are hit. The risk to reward ratio is 1:2, which yields a tidy 6% return if we take a 3% risk." (PDF p. 137 — illustrative single-trade short example, AUDUSD M15)

"With these two strategies [Fade the Break and Trade the Break], we can take a trade regardless of market direction." (PDF p. 137)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3                               # 1:2 RR breakouts typically 35-45% win rate → PF ~1.2-1.4
expected_dd_pct: TBD                           # no author DD claim; choppy regimes likely 8-15% DD
expected_trade_frequency: 80-150/year per symbol  # closed breakouts at major S/R are less frequent than wick-breaks
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5)

- [x] Strategy concept is mechanical
- [x] No ML required
- [x] No gridding, no martingale
- [x] Not scalping
- [x] Friday Close compatible
- [x] Source citation precise: PDF pp. 131-137
- [x] No near-duplicate (Lien lien-20day-breakout = D1 20-day high; this is M15/M30 intraday S/R-close breakout; mechanically distinct)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "range-min/max guard + S/R-maturity + close-distance filter + news pause"
  trade_entry:
    used: true
    notes: "S/R close-through detection; entry at next-bar open"
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
  No hard rule at risk. Fully compatible with V5 framework defaults.
```
