# Strategy Card — Singh Fifth Element (H1/H4 MT4-MACD-histogram switch + 5th-bar entry)

## Card Header

```yaml
strategy_id: SRC06_S09
ea_id: TBD
slug: singh-fifth-element
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

strategy_type_flags: [trend-following, momentum]
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

> **singh-fifth-element (SRC06_S09 - H1/H4, MT4-MACD-zero-cross + 5th-bar entry)**
> 
> APPROVED
> Edge mechanism: MACD histogram zero-cross as momentum signal + 5th-bar patience filter to reduce false entries
> Portfolio fit: MACD-zero-cross mechanism is new to the pipeline; no near-duplicate
> Author claim: single-trade illustrations only
> 
> Implementation note: must use MT4 MACD definition (histogram = MACD line, not Appel-style). MT5 default MACD differs - framework must document the calculation explicitly. The "5th bar" specificity is a parameterization risk - flagged for P7 Quality-Tech overfit assessment.

### Flags carried forward

- MT4 vs MT5 MACD definition: must use MT4 definition (histogram = MACD line, not Appel-style); framework must document the calculation explicitly.
- P7 overfit watch: "5th bar" specificity is a parameterization risk; P7 Quality-Tech overfit assessment required.


## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7."
    location: "Chapter 8 'Strategies for Swing Traders' — Strategy 9: Fifth Element, PDF pp. 169-177. Indicator-block PDF p. 170; Strategy concept PDF p. 171; Long-trade-setup PDF p. 172; Short-trade-setup PDF p. 173; Strategy Roundup PDF p. 176."
    quality_tier: B
    role: primary
```

## 2. Concept

H1/H4 trend-confirmation strategy using the **MetaTrader 4 native MACD** (which is NOT the traditional Appel MACD; MT4's histogram represents only the MACD line = EMA(12) − EMA(26), NOT the difference between MACD line and signal). When MT4-MACD histogram crosses from negative to positive, wait for FOUR more positive bars to confirm sustained momentum, enter long on the OPENING of the 5th bar (hence "fifth element"). Mirror logic for shorts on histogram crossing positive-to-negative. Time-deterministic entry (always 5 bars after switch) is the strategy's distinctive feature: "you have ample time to catch a two-hour movie before heading home again to prepare for the trade!" (PDF p. 177).

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
- compute MT4-MACD = EMA(close, 12) - EMA(close, 26)            # MT4 histogram = MACD line value (not signal-diff)
- detect zero-crossing UP: just-closed bar's MACD > 0 AND prior bar's MACD < 0
- require subsequent FOUR consecutive closed bars with MACD > 0 (i.e., bars i+1, i+2, i+3, i+4 after the cross-bar i — total 5 positive bars including the cross)
- on the OPENING of bar i+5 (the "fifth element"), BUY at market
- SL = lowest low of the histogram-positive sequence (last visible low before/at the cross)
   ↔ author writes "Set the stop loss at the last low of the histogram" PDF p. 172
   = Lowest Low of bars [i, i+1, i+2, i+3, i+4]
- TP1 = Entry + (Entry - SL)                                     # R:R 1:1
- TP2 = Entry + 2 × (Entry - SL)                                 # R:R 1:2

SHORT:
- on closed H1 or H4 bar
- detect zero-crossing DOWN: just-closed bar's MACD < 0 AND prior bar's MACD > 0
- require subsequent FOUR consecutive closed bars with MACD < 0
- on the OPENING of bar i+5, SELL at market
- SL = "last high of the histogram" (PDF p. 175)
   = Highest High of bars [i, i+1, i+2, i+3, i+4]
- TP1 = Entry - (SL - Entry)
- TP2 = Entry - 2 × (SL - Entry)
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
- skip if any of bars [i+1..i+4] has MACD value crossing back to opposite sign (sequence broken; reset state)
- skip if SL distance from entry < 30 pips (insufficient room) or > 200 pips (SL too far, RR economics fail)
- skip if MACD value at bar i+4 is below average MACD value across [i..i+4] (momentum already fading)
- skip during major news releases (V5 default)
```

## 7. Trade Management Rules

```text
- one position per magic+symbol
- 50/50 partial close + BE move
- no pyramiding (single signal per cross-event)
- no gridding
- Friday Close enforced
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: macd_fast
  default: 12
  sweep_range: [8, 10, 12, 14]
- name: macd_slow
  default: 26
  sweep_range: [20, 24, 26, 30, 35]
- name: bars_after_cross_for_entry
  default: 5
  sweep_range: [3, 4, 5, 6, 7]
- name: tp1_rr
  default: 1.0
  sweep_range: [0.8, 1.0, 1.5]
- name: tp2_rr
  default: 2.0
  sweep_range: [1.5, 2.0, 3.0]
- name: tf
  default: H4
  sweep_range: [H1, H4]
```

## 9. Author Claims (verbatim)

```text
"The risk for this trade is 150 pips, and the reward is 300 pips if both targets are hit. The risk to reward ratio is 1:2, which yields a tidy 6% return if we take a 3% risk." (PDF p. 173 — illustrative single-trade long example, AUDUSD H4)

"The risk for this trade is 147 pips, and the reward is 294 pips if both targets are hit. The risk to reward ratio is 1:2, which yields a tidy 6% return if we take a 3% risk." (PDF p. 175 — illustrative single-trade short example, EURUSD H4)

"The fifth element is an excellent swing trading strategy for beginners. The beauty of this strategy is that it does not require you to monitor the market for a long time. It also signals you well in advance as to when the entry of a trade is about to take place." (PDF p. 176)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3
expected_dd_pct: TBD                           # 5-bar wait often misses the strongest part of move; estimate 10-15% DD
expected_trade_frequency: 20-50/year per symbol  # H4 MACD zero-crosses with valid 4-bar continuation: ~2-4/month
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5)

- [x] Strategy concept is mechanical (zero-cross + sequential continuation count fully rule-tight)
- [x] No ML required
- [x] No gridding, no martingale
- [x] Not scalping
- [x] Friday Close compatible (multi-day trades, accepts forced flat)
- [x] Source citation precise: PDF pp. 169-177
- [x] No near-duplicate (Davey/Williams/Lien/Chan have no MACD-zero-cross-with-bar-count entry)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "sequence-break detector + SL distance bounds + momentum-fading filter + news pause"
  trade_entry:
    used: true
    notes: "MT4-MACD zero-cross + 4-bar continuation; entry at OPEN of 5th bar"
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
  No hard rule at risk. Note: implementation must use MT4 MACD definition (histogram = MACD
  line, not Appel-style histogram = MACD-signal). MT5 default MACD differs; framework must
  document the MT4 calculation explicitly to avoid silent indicator drift between platforms.
```
