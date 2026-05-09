# Strategy Card — Singh Piranha (M5 GBP/USD Bollinger range mean-reversion)

## Card Header

```yaml
strategy_id: SRC06_S02
ea_id: TBD
slug: singh-piranha
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

strategy_type_flags: [scalping, mean-reversion]
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

> **singh-piranha (SRC06_S02 - M5 GBPUSD, BB(12,2) range mean-reversion)**
> 
> APPROVED
> Edge mechanism: Bollinger Band touch mean-reversion in ranging FX session
> Portfolio fit: first MR-scalp archetype; M5 adds short-cycle exposure
> Author claim: "15-20 opportunities/day" - author-claimed illustrative
> 
> Flag carried to P5b: scalping_p5b_latency. Inverted R:R (TP 5pip < SL 10pip). Regime filter (BB bandwidth check) is mandatory and present in card. Author explicitly warns "fails badly in strong trend"; card addresses this.

### Flags carried forward

- scalping_p5b_latency: VPS-realistic latency stress mandatory at P5b before P9 deployment.
- inverted R:R (TP 5pip < SL 10pip): mandatory BB bandwidth regime filter present in card; P3 to validate.
- Author warning "fails badly in strong trend" addressed by regime filter; P3 stress to confirm.


## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7."
    location: "Chapter 6 'Strategies for Scalpers' — Strategy 2: Piranha Strategy, PDF pp. 118-124 (printed pp. 118-124). Indicator-block PDF p. 118; Long-trade-setup PDF p. 120; Short-trade-setup PDF p. 122; Strategy Roundup PDF p. 123."
    quality_tier: B
    role: primary
```

## 2. Concept

Range mean-reversion on M5 GBP/USD using Bollinger Bands(12, 2) as the touch-trigger. When price touches the lower band, fire long with 5-pip TP and 10-pip SL (R:R 2:1 INVERTED). When price touches the upper band, fire short. Author calls them "small frequent bites" — like piranha. "On average, there are about 15 to 20 trading opportunities for the piranha strategy every day" (PDF p. 118).

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - M5
primary_target_symbols:
  - GBPUSD                                     # author-prescribed only — "designed for the cable, which is the nickname for the currency pair GBP/USD" (PDF p. 119)
```

## 4. Entry Rules

```text
LONG:
- on closed M5 bar
- if bar's Low <= LowerBand of BollingerBands(period=12, dev=2) on the same bar (or High touched the band intra-bar)
- and not in news blackout (per author's "avoid trading this strategy at times of major news releases during the U.S. and U.K. trading hours" PDF p. 119)
- then BUY at next-bar open
- SL = Entry - 10 pips
- TP = Entry + 5 pips                          # R:R 2:1 INVERTED

SHORT:
- on closed M5 bar
- if bar's High >= UpperBand of BollingerBands(period=12, dev=2) on the same bar
- and not in news blackout
- then SELL at next-bar open
- SL = Entry + 10 pips
- TP = Entry - 5 pips
```

## 5. Exit Rules

```text
- TP at 5 pips fixed, SL at 10 pips fixed
- No trailing stop in source spec
- Friday Close enforced (V5 default; M5 holds typically <30 min)
```

## 6. Filters (No-Trade)

```text
- author-mandated: skip during major US and UK news releases (PDF p. 119: "avoid trading this strategy at times of major news releases during the U.S. and U.K. trading hours")
- skip if BB(12,2) bandwidth < threshold (range too tight; trades fire too often, eat spread)
- skip if BB(12,2) bandwidth > threshold (market trending strongly, range strategy fails — author's roundup confirms PDF p. 124: "as this strategy was designed primarily for range trading, it fails badly when the market goes into a strong trend")
- skip if GBPUSD spread > 2 pips (5-pip TP cannot survive)
```

## 7. Trade Management Rules

```text
- one position per magic+symbol
- author's roundup directive (PDF p. 124): "once your trade hits a stop loss […] look for a trade that is in the opposite direction of your stop-loss trade" — interpret as a regime-flip signal, not as fade-the-stop. V5 implementation: after consecutive SL hits in same direction, evaluate trend-flip filter before next entry.
- no pyramiding, no gridding
- Friday Close enforced
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: bb_period
  default: 12
  sweep_range: [8, 10, 12, 14, 16, 20]
- name: bb_dev
  default: 2.0
  sweep_range: [1.5, 1.75, 2.0, 2.25, 2.5]
- name: tp_pips
  default: 5
  sweep_range: [3, 4, 5, 6, 8, 10]
- name: sl_pips
  default: 10
  sweep_range: [6, 8, 10, 12, 15]
```

## 9. Author Claims (verbatim)

```text
"On average, there are about 15 to 20 trading opportunities for the piranha strategy every day." (PDF p. 118)

"The risk for this trade is 10 pips, and the reward is 5 pips. The risk to reward ratio is 2:1, which yields us a 1.5% return if we take a 3% risk." (PDF p. 122 — illustrative single-trade long example)

"The risk for this trade is 10 pips, and the reward is 5 pips. The risk to reward ratio is 2:1, which yields us a 1.5% return if we take a 3% risk." (PDF p. 122 — illustrative single-trade short example)

"As this strategy was designed primarily for range trading, it fails badly when the market goes into a strong trend." (PDF p. 124)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.0                               # 2:1 SL:TP inverted; requires >67% win rate to break even
expected_dd_pct: TBD                           # no author DD claim; range-strategy in trend = catastrophic streaks
expected_trade_frequency: 3750-5000/year       # 15-20 trades/day × 250 days
risk_class: high                               # M5 + inverted R:R + author-acknowledged trend-fail mode
gridding: false
scalping: true                                 # M5 GBPUSD with 5-pip TP → scalping_p5b_latency
ml_required: false
```

## 11. Strategy Allowability Check (V5)

- [x] Strategy concept is mechanical (BB-touch is fully rule-tight)
- [x] No ML required
- [x] No gridding, no martingale
- [x] Scalping → P5b VPS-realistic latency calibration MUST be planned (M5 + 5-pip TP)
- [x] Friday Close compatible (M5 holds typically <30 min)
- [x] Source citation precise: PDF pp. 118-124
- [x] No near-duplicate (Chan AT chan-at-bb-pair = stat-arb on equity pair spread, not M5 single-pair range trade)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "news pause + BB-bandwidth regime filter + spread guard + trend-fail regime detector"
  trade_entry:
    used: true
    notes: "BB(12,2) band-touch entry; long at lower-band touch, short at upper-band touch; entry at next-bar open"
  trade_management:
    used: false
    notes: "fixed SL/TP only"
  trade_close:
    used: false
    notes: "exit by SL/TP only"
```

```yaml
hard_rules_at_risk:
  - scalping_p5b_latency
  - news_pause_default
at_risk_explanation: |
  scalping_p5b_latency: M5 + 5-pip fixed TP. With GBPUSD typical spread 1.0-1.8 pips + VPS
  slippage 1-2 pips, real-broker net TP shrinks to 1-3 pips. P5b stress mandatory.

  news_pause_default: author explicitly mandates pausing during US and UK news releases
  (PDF p. 119). V5 default already binds here; no documented exception. Strategy compatible
  with `news_pause_default = true`.
```
