# Strategy Card — Singh Power Ranger (H1/H4 stochastic + range, trend-aligned)

## Card Header

```yaml
strategy_id: SRC06_S10
ea_id: TBD
slug: singh-power-ranger
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

strategy_type_flags: [range-trading, oscillator, mean-reversion]
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

> **singh-power-ranger (SRC06_S10 - H1/H4, stoch(10,3,3) trend-aligned range)**
> 
> APPROVED
> Edge mechanism: stochastic oversold/overbought reading within a trend-aligned range - standard momentum confirmation
> Portfolio fit: first stochastic-based EA in pipeline; adds indicator diversity
> Author claim: single-trade illustrations

### Flags carried forward

- No specific G0 flag carried; first stochastic-based EA in pipeline.


## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7."
    location: "Chapter 8 'Strategies for Swing Traders' — Strategy 10: Power Ranger, PDF pp. 177-184. Indicator-block PDF p. 177-178; Strategy concept PDF p. 179; Long-trade-setup PDF p. 179; Short-trade-setup PDF p. 182; Strategy Roundup PDF p. 184."
    quality_tier: B
    role: primary
```

## 2. Concept

Range-trade ALONG the prevailing trend direction using stochastic(10,3,3) oversold/overbought as the entry trigger. In an uptrend (price above declining trend line of higher-highs / higher-lows), buy when stochastic enters oversold (< 20) and crosses back above 20. In a downtrend, sell when stochastic enters overbought (> 80) and crosses back below 80. The author calls this "trading along with the market momentum and putting yourself in an advantageous position" (PDF p. 184) — i.e., not blind oversold-buy, but trend-aligned-oversold-buy.

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
- on closed H1 or H4 bar
- detect uptrend: linear regression slope of Close over last N bars > threshold (mechanizable form of "draw an uptrend line based on a series of higher highs and higher lows" PDF p. 179)
   OR equivalently: HighestHigh(last 20 bars) > HighestHigh(prior 20 bars) AND LowestLow(last 20 bars) > LowestLow(prior 20 bars)
- if Stochastic(10, 3, 3) %K and %D both < 20 on the most-recent oversold bar
- and on closed bar Stochastic %K crosses above 20 (oversold exit)
- determine support S and resistance R as recent local extremes within the trend's range (bounded box of last 20-30 bars)
- then BUY at next-bar open
- TP1 = S + 0.75 × (R - S)                          # 75% mark of range
- SL = Entry - (TP1 - Entry)                         # R:R 1:1 to TP1
- VALIDITY CHECK: if SL > S (above support), trade INVALID (per PDF p. 180: "the stop loss must be below the support level. If not, the trade is considered invalid")
- TP2 = Entry + 2 × (TP1 - Entry)                    # R:R 1:2 to TP2 (beyond range, breakout target)

SHORT:
- detect downtrend (mirror)
- if Stochastic(10, 3, 3) %K and %D both > 80
- and on closed bar Stochastic %K crosses below 80
- determine S and R
- then SELL at next-bar open
- TP1 = R - 0.75 × (R - S)                          # 25% from S, i.e., 75% mark from R
- SL = Entry + (Entry - TP1)
- VALIDITY: if SL < R (below resistance), INVALID
- TP2 = Entry - 2 × (Entry - TP1)
```

## 5. Exit Rules

```text
- 50% of position at TP1 (R:R 1:1), 50% at TP2 (R:R 1:2)
- After TP1 hit, move SL on remainder to entry (BE)
- SL handled by entry stop
- Friday Close enforced
```

## 6. Filters (No-Trade)

```text
- skip if trend slope below threshold (no clear trend; range strategy without trend bias is dangerous per author PDF p. 184)
- skip if stoch oversold/overbought condition has persisted > 8 bars (chop, not pullback)
- skip if range (R - S) < 20 pips (range too tight for SL/TP economics) or > 200 pips (entries too far from extremes)
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
- name: stoch_k
  default: 10
  sweep_range: [8, 10, 14, 18]
- name: stoch_d
  default: 3
  sweep_range: [3, 5]
- name: stoch_slowing
  default: 3
  sweep_range: [3, 5]
- name: oversold_level
  default: 20
  sweep_range: [15, 20, 25, 30]
- name: overbought_level
  default: 80
  sweep_range: [70, 75, 80, 85]
- name: trend_lookback_bars
  default: 30
  sweep_range: [20, 30, 40, 50]
- name: tp1_range_pct
  default: 0.75
  sweep_range: [0.5, 0.6, 0.75, 0.85]
- name: tf
  default: H1
  sweep_range: [H1, H4]
```

## 9. Author Claims (verbatim)

```text
"The risk for this trade is 42 pips, and the reward is 84 pips if both targets are hit. The risk to reward ratio is 1:2, which yields a tidy 6% return if we take a 3% risk." (PDF p. 181 — illustrative single-trade long example, EURUSD H1)

"The risk for this trade is 76 pips, and the reward is 152 pips if both targets are hit. The risk to reward ratio is 1:2, which yields a tidy 6% return if we take a 3% risk." (PDF p. 184 — illustrative single-trade short example, AUDUSD H1)

"This is an awesome range strategy as it allows us to take a range trade in the early stages of formation. The bonus is that it also allows us to take advantage of a second profit target in the event prices break out of a range and move into an early trend." (PDF p. 184)

"It doesn't mean that you should go long whenever the stochastic is at the oversold region or go short whenever the stochastic is at the overbought region. If you do so, you may end up selling on an uptrend or buying on a downtrend. Going against momentum in this way can be risky." (PDF p. 184)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3
expected_dd_pct: TBD                           # 10-15%; trend-flip after entry is the main loss path
expected_trade_frequency: 30-80/year per symbol
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5)

- [x] Strategy concept is mechanical (trend detection + stoch crosses + range bounds is fully rule-tight when "trend line" is mechanized as regression slope or HH/LL comparison)
- [x] No ML required
- [x] No gridding, no martingale
- [x] Not scalping
- [x] Friday Close compatible
- [x] Source citation precise: PDF pp. 177-184
- [x] No near-duplicate (Williams stochastic-based cards use 14-period stoch + different overbought/oversold rules; SRC04 has no stoch+range combo)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "trend-flatness filter + stoch persistence guard + range size bounds + invalidity check (SL not above support / below resistance)"
  trade_entry:
    used: true
    notes: "trend detection AND stoch oversold/overbought cross-back; entry at next-bar open"
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
  No hard rule at risk. Note: author's "draw uptrend line / downtrend line" must be mechanized
  as a deterministic computation (linear regression slope or HH/LL comparison over fixed
  lookback) — pure visual line-drawing is NOT mechanical and would fail the V5 mechanical-only
  hard rule.
```
