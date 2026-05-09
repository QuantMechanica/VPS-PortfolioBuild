# Strategy Card — Singh Trend Bouncer (H1/H4 BB pullback to MA12 + outer BB SL)

## Card Header

```yaml
strategy_id: SRC06_S08
ea_id: TBD
slug: singh-trend-bouncer
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

strategy_type_flags: [trend-following, pullback, mean-reversion-to-mean]
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

> **singh-trend-bouncer (SRC06_S08 - H1/H4, BB(12,2) pullback to MA-12)**
> 
> APPROVED
> Edge mechanism: pullback-to-MA trend-continuation entry; among the most robust documented FX edge mechanisms
> Portfolio fit: lien-dbb-pick-tops uses BB(20,2)/BB(20,1) double-band for range; singh-trend-bouncer uses BB(12,2)/BB(12,4) for trend pullback - different parameter family, different objective. Not a duplicate.
> Author claim: single-trade R-multiple illustrations only

### Flags carried forward

- Portfolio-fit note: different BB parameter family (BB(12,2)/BB(12,4) trend pullback) vs lien-dbb-pick-tops (BB(20,2)/BB(20,1) range). Not a duplicate; reconfirm at P9 correlation check.


## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7."
    location: "Chapter 8 'Strategies for Swing Traders' — Strategy 8: Trend Bouncer, PDF pp. 163-169. Indicator-block PDF p. 164; Strategy concept PDF p. 164; Long-trade-setup PDF p. 164; Short-trade-setup PDF p. 167; Strategy Roundup PDF p. 169."
    quality_tier: B
    role: primary
```

## 2. Concept

Trend-pullback entry using two Bollinger Bands sets at the same MA(12) but different deviations (Dev=2 inner, Dev=4 outer). Long signal: price touches the upper inner band (BB(12,2) upper) signaling momentum, then retraces back to MA(12); enter long on the touch of MA(12). SL is the outer lower band (BB(12,4) lower). Author identifies this as a way to trade the "ebb-and-flow" of a trend. Three profit targets at R:R 1:1, 1:2, 1:3 capture profit in stages.

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
LONG:
- track upward-momentum confirmed-flag M_up: set M_up = true when bar's High >= UpperBand(BB(12,2)) on a closed bar
- on closed H1 or H4 bar with M_up = true
- if just-closed bar's Low <= MA(12) value (price retraced down to MA(12))
- then BUY at next-bar open (after the touch confirmation)
- SL = LowerBand(BB(12,4)) at entry bar
- TP1 = Entry + (Entry - SL)                    # R:R 1:1
- TP2 = Entry + 2 × (Entry - SL)                # R:R 1:2
- TP3 = Entry + 3 × (Entry - SL)                # R:R 1:3
- on entry, reset M_up = false (single-pullback per momentum confirmation)

SHORT:
- track downward-momentum flag M_dn: set M_dn = true when bar's Low <= LowerBand(BB(12,2)) on a closed bar
- on closed H1 or H4 bar with M_dn = true
- if just-closed bar's High >= MA(12) value (price retraced up to MA(12))
- then SELL at next-bar open
- SL = UpperBand(BB(12,4)) at entry bar
- TP1 = Entry - (SL - Entry)
- TP2 = Entry - 2 × (SL - Entry)
- TP3 = Entry - 3 × (SL - Entry)
- on entry, reset M_dn = false
```

## 5. Exit Rules

```text
- 33% of position at TP1, 33% at TP2, 34% at TP3 (three-target structure per author)
- After TP1 hit, move SL on remainder to entry (BE) per V5 default
- After TP2 hit, move SL on remainder to TP1 level (lock in 1R gain) per V5 trade-management
- SL handled by entry stop
- Friday Close enforced
```

## 6. Filters (No-Trade)

```text
- M_up / M_dn flag must be set within last N bars (e.g., N=10) to count; otherwise touch is too stale
- skip if BB(12,4) bandwidth at entry > X pips (excessive range = SL too wide, RR economics break)
- skip if MA(12) and MA(36) are flat within ±5 pips over last 20 bars (no underlying trend; pullback fades)
- skip during major news releases (V5 default)
```

## 7. Trade Management Rules

```text
- one position per magic+symbol
- 33/33/34 partial close at TP1/TP2/TP3 with progressive BE+lock-in
- no pyramiding, no gridding
- Friday Close enforced
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: bb_period
  default: 12
  sweep_range: [10, 12, 14, 18, 21]
- name: bb_inner_dev
  default: 2.0
  sweep_range: [1.5, 1.75, 2.0, 2.25]
- name: bb_outer_dev
  default: 4.0
  sweep_range: [3.0, 3.5, 4.0, 4.5]
- name: momentum_flag_max_age_bars
  default: 10
  sweep_range: [5, 8, 10, 15, 20]
- name: tp1_rr
  default: 1.0
  sweep_range: [0.8, 1.0, 1.2]
- name: tp2_rr
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5]
- name: tp3_rr
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0, 5.0]
- name: tf
  default: H4
  sweep_range: [H1, H4]
```

## 9. Author Claims (verbatim)

```text
"The risk for this trade is 90 pips, and the reward is 270 pips if all three targets are hit. The risk to reward ratio is 1:3, which yields a tidy 9% return if we take a 3% risk." (PDF p. 167 — illustrative single-trade long example, GBPUSD H4)

"The risk for this trade is 46 pips, and the reward is 138 pips if all three targets are hit. The risk to reward ratio is 1:3, which yields a tidy 9% return if we take a 3% risk." (PDF p. 169 — illustrative single-trade short example, NZDUSD H1)

"Remember that smart money typically follows the trend. This strategy helps us to hop on board early when we identify the trend." (PDF p. 169)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4
expected_dd_pct: TBD                           # 10-15% likely; range-trapped pullback whipsaws are the main DD source
expected_trade_frequency: 40-100/year per symbol
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5)

- [x] Strategy concept is mechanical (BB inner/outer + state-flag is fully rule-tight)
- [x] No ML required
- [x] No gridding, no martingale
- [x] Not scalping
- [x] Friday Close compatible
- [x] Source citation precise: PDF pp. 163-169
- [x] No near-duplicate (Lien lien-channels uses fixed channels, not BB-pullback; Chan AT chan-at-bb-pair is stat-arb on equity pair spread)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "trend-flat detector + bandwidth guard + flag-staleness filter + news pause"
  trade_entry:
    used: true
    notes: "two-stage: BB(12,2) outer-band touch sets M_up/M_dn flag; subsequent MA(12) retest fires entry"
  trade_management:
    used: true
    notes: "three-target partial close with progressive BE/lock-in"
  trade_close:
    used: false
    notes: "exit by SL/TP only"
```

```yaml
hard_rules_at_risk: []
at_risk_explanation: |
  No hard rule at risk. Compatible with V5 framework defaults.
```
