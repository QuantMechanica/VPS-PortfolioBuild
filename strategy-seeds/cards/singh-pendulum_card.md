# Strategy Card — Singh Pendulum (H1/H4 range bounce — 10% off S/R entry)

## Card Header

```yaml
strategy_id: SRC06_S11
ea_id: TBD
slug: singh-pendulum
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

strategy_type_flags: [range-trading, mean-reversion]
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

> **singh-pendulum (SRC06_S11 - H1/H4, range 10%-bounce from S/R boundary)**
> 
> APPROVED
> Edge mechanism: enter at 10% of range from boundary, targeting 50% and 90% levels - range-expansion bet
> Portfolio fit: range-bounce thesis is distinct from all current pipeline cards; mechanizable with N-bar high/low
> Author claim: single-trade examples

### Flags carried forward

- No specific G0 flag carried; mechanizable with N-bar high/low.


## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7."
    location: "Chapter 8 'Strategies for Swing Traders' — Strategy 11: The Pendulum, PDF pp. 185-190. Strategy concept PDF p. 185-186; Long-trade-setup PDF p. 186; Short-trade-setup PDF p. 188; Strategy Roundup PDF p. 190."
    quality_tier: B
    role: primary
```

## 2. Concept

Pure-price-action range trade: identify support S and resistance R within an established trading range, wait for price to bounce 10% of the range off S (or R), then enter long (or short). Targets are 50% (TP1) and 90% (TP2) of the range from the entry side. Author calls it "pendulum" because price swings back and forth like a pendulum within the range. Distinguishes from S10 Power Ranger by being "in the later stages of a range formation" (PDF p. 185) — i.e., for confirmed-mature ranges, not early ones.

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - H1
  - H4
primary_target_symbols: [EURUSD, USDJPY, GBPUSD, USDCHF, USDCAD, AUDUSD, NZDUSD]
```

## 4. Entry Rules

```text
LONG (bounce off support):
- on closed H1 or H4 bar
- identify resistance R and support S within last N bars (e.g., N=40); range = R - S
- require range to be MATURE: at least 3 prior touches of S OR R in the lookback window
- if just-closed bar's Low <= S (touched/crossed support during the bar)
- and just-closed bar's Close >= S + 0.10 × (R - S) (closed above the 10% mark off support)
- then BUY at next-bar open
- Entry approx = S + 0.10 × (R - S)
- TP1 = S + 0.50 × (R - S)                                # 50% mark of range
- TP2 = S + 0.90 × (R - S)                                # 90% mark of range
- SL = Entry - (TP1 - Entry)                               # R:R 1:1 to TP1
   author specifies "Use risk to reward ratio of 1:1 to set the stop loss" (PDF p. 186)

SHORT (bounce off resistance):
- on closed H1 or H4 bar
- if just-closed bar's High >= R
- and just-closed bar's Close <= R - 0.10 × (R - S)
- then SELL at next-bar open
- Entry approx = R - 0.10 × (R - S)
- TP1 = R - 0.50 × (R - S)
- TP2 = R - 0.90 × (R - S)
- SL = Entry + (Entry - TP1)
```

## 5. Exit Rules

```text
- 50% of position at TP1 (R:R 1:1), 50% at TP2 (R:R 1:roughly 2 depending on entry placement)
- After TP1 hit, move SL on remainder to entry (BE)
- SL handled by entry stop
- Friday Close enforced
```

## 6. Filters (No-Trade)

```text
- skip if range < 50 pips (too tight for the 10%/50%/90% structure)
- skip if range > 300 pips (too wide; pendulum analogy weakens, breakout risk grows)
- skip if range was last established > 60 bars ago (stale range)
- skip if no clear range (e.g., HighestHigh and LowestLow drift > 30% over the lookback — trend, not range)
- skip during major news releases (V5 default)
```

## 7. Trade Management Rules

```text
- one position per magic+symbol
- 50/50 partial close + BE on remainder
- no pyramiding, no gridding
- Friday Close enforced
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: range_lookback_bars
  default: 40
  sweep_range: [30, 40, 50, 70, 100]
- name: range_min_touches
  default: 3
  sweep_range: [2, 3, 4]
- name: bounce_pct
  default: 0.10
  sweep_range: [0.05, 0.08, 0.10, 0.15, 0.20]
- name: tp1_pct
  default: 0.50
  sweep_range: [0.40, 0.50, 0.60]
- name: tp2_pct
  default: 0.90
  sweep_range: [0.80, 0.85, 0.90, 1.00]
- name: range_min_pips
  default: 50
  sweep_range: [30, 50, 70, 100]
- name: range_max_pips
  default: 300
  sweep_range: [200, 300, 400, 500]
- name: tf
  default: H4
  sweep_range: [H1, H4]
```

## 9. Author Claims (verbatim)

```text
"The risk for this trade is 108 pips, and the reward is 216 pips if both targets are hit. The risk to reward ratio is 1:2, which yields a tidy 6% return if we take a 3% risk." (PDF p. 188 — illustrative single-trade long example, AUDUSD H4)

"The risk for this trade is 82 pips, and the reward is 164 pips if both targets are hit. The risk to reward ratio is 1:2, which yields a tidy 6% return if we take a 3% risk." (PDF p. 190 — illustrative single-trade short example, GBPUSD H4)

"The power ranger strategy and the pendulum strategy work perfectly together. You can use the power ranger strategy to identify and trade the range in its early stage of formation, then apply the pendulum strategy to trade the later portion of the range." (PDF p. 190)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3
expected_dd_pct: TBD                           # range-breakout = catastrophic loss path; estimate 10-15% DD
expected_trade_frequency: 30-80/year per symbol
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5)

- [x] Strategy concept is mechanical (range identification mechanized as N-bar lookback with touch-count requirement)
- [x] No ML required
- [x] No gridding, no martingale
- [x] Not scalping
- [x] Friday Close compatible
- [x] Source citation precise: PDF pp. 185-190
- [x] No near-duplicate (Lien lien-channels uses Donchian-style fixed channels, not 10%-off-S/R bounce; Lien lien-fader uses indicator-divergence not bounce-pct)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "range size bounds + maturity (touch-count) + drift detector for trend-vs-range + news pause"
  trade_entry:
    used: true
    notes: "10%-off-S/R bounce after S/R touch; entry at next-bar open"
  trade_management:
    used: true
    notes: "50/50 partial close + BE on remainder"
  trade_close:
    used: false
    notes: "exit by SL/TP only"
```

```yaml
hard_rules_at_risk: []
at_risk_explanation: |
  No hard rule at risk. Mechanical range identification using N-bar lookback + touch-count
  is fully rule-tight; original author's "identify resistance and support" can be implemented
  without discretionary line-drawing.
```
