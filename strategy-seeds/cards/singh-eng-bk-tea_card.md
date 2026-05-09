# Strategy Card — Singh English Breakfast Tea (M15 GBP/USD London-direction reverse at 08:30 London)

## Card Header

```yaml
strategy_id: SRC06_S16
ea_id: TBD
slug: singh-eng-bk-tea
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

strategy_type_flags: [time-of-day, mean-reversion, fade]
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

> **singh-eng-bk-tea (SRC06_S16 - M15 GBPUSD, London-open direction reverse at 08:30 London)**
> 
> APPROVED
> Edge mechanism: London-open mean-reversion after pre-open drift - one of the most studied intraday FX microstructure effects
> Portfolio fit: FIRST London-open strategy in pipeline; adds time-of-day MR dimension distinct from trend-following concentration
> Author claim: single-trade R-multiple examples; three-TP structure (1:1, 1:2, 1:3) is clean

### Flags carried forward

- No specific G0 flag carried; three-TP structure (1:1, 1:2, 1:3) is clean and deterministic.


## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7."
    location: "Chapter 10 'Strategies for Mechanical Traders' — Strategy 16: English Breakfast Tea, PDF pp. 223-228. Strategy concept PDF p. 224; Long-trade-setup PDF p. 224; Short-trade-setup PDF p. 226; Strategy Roundup PDF p. 227."
    quality_tier: B
    role: primary
```

## 2. Concept

Time-of-day mean-reversion on M15 GBP/USD around the London market open (08:30 London time). Author observes that GBP/USD has a tendency to REVERSE direction at 08:30 London time after pre-open drift. Specifically: compare the M15 close price at 04:15 London with the M15 close price at 08:15 London (a 4-hour interval ending 15 minutes before the 08:30 trade trigger). If 08:15 close < 04:15 close (drift was DOWN), go LONG at 08:30 open (fade the down-drift). If 08:15 close > 04:15 close (drift was UP), go SHORT. SL fixed 30 pips, three TPs at 30, 60, 90 pips (R:R 1:1, 1:2, 1:3).

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - M15
primary_target_symbols:
  - GBPUSD                                     # author-prescribed only — "this strategy is applied to the GBP/USD only" (PDF p. 224)
```

## 4. Entry Rules

```text
At 08:30 London time (= 03:30 NY winter, 04:30 NY summer; broker time = 09:30 in EST winter / 10:30 in EDT summer for FXPRIMUS GMT+1; for Darwinex NY-Close GMT+2/+3 = 09:30 broker winter / 10:30 broker summer):

LONG:
- on the 08:30 London M15 candle's open (= the bar that closes at 08:45 London)
- precondition: M15 close price at 04:15 London > M15 close price at 08:15 London
   (i.e., GBP/USD drifted DOWN over the 04:15→08:15 window)
- then BUY at the open of the 08:30 London M15 candle
- SL = Entry - 30 pips                                # author-fixed
- TP1 = Entry + 30 pips                                # R:R 1:1
- TP2 = Entry + 60 pips                                # R:R 1:2
- TP3 = Entry + 90 pips                                # R:R 1:3

SHORT:
- on the 08:30 London M15 candle's open
- precondition: M15 close price at 04:15 London < M15 close price at 08:15 London
   (drifted UP)
- then SELL at the open of the 08:30 London M15 candle
- SL = Entry + 30 pips
- TP1 = Entry - 30 pips
- TP2 = Entry - 60 pips
- TP3 = Entry - 90 pips
```

## 5. Exit Rules

```text
- 33% of position at TP1 (R:R 1:1), 33% at TP2 (R:R 1:2), 34% at TP3 (R:R 1:3)
- After TP1 hit, move SL on remainder to entry (BE)
- After TP2 hit, move SL on remainder to TP1 level (lock in 1R)
- SL handled by entry stop
- Friday Close enforced (M15 trade typically resolves within London session)
```

## 6. Filters (No-Trade)

```text
- skip if 04:15 close == 08:15 close (no directional drift)
- skip if absolute drift |04:15 close - 08:15 close| < 10 pips (drift too small; fade signal weak)
- skip during major news releases at 08:00-08:30 London (UK GDP, BoE rate decision, etc. — V5 default)
- skip if M15 ATR is below symbol's 30-day average ATR by 30%+ (low-vol regime; 30-pip SL exposure relative to 90-pip TP unfavorable)
- skip if it's a UK bank holiday (London market closed; the 08:30 reversal hypothesis depends on London open)
```

## 7. Trade Management Rules

```text
- one position per magic+symbol
- 33/33/34 partial close + progressive BE/lock-in
- no pyramiding (one signal per day at 08:30 London, max)
- no gridding
- Friday Close enforced
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: pre_open_window_hours
  default: 4                                    # 04:15 → 08:15 = 4-hour window
  sweep_range: [2, 3, 4, 5, 6]
- name: signal_min_drift_pips
  default: 10
  sweep_range: [5, 10, 15, 20, 30]
- name: sl_pips
  default: 30
  sweep_range: [20, 25, 30, 40, 50]
- name: tp1_pips
  default: 30
  sweep_range: [20, 30, 40]
- name: tp2_pips
  default: 60
  sweep_range: [40, 60, 80]
- name: tp3_pips
  default: 90
  sweep_range: [60, 90, 120, 150]
- name: entry_time_london
  default: "08:30"
  sweep_range: ["08:00", "08:15", "08:30", "08:45", "09:00"]
```

## 9. Author Claims (verbatim)

```text
"When the GBP/USD trends in one direction from 04:15 hours to 08:30 hours London time, it has a tendency to move in the other direction after 08:30 hours." (PDF p. 224)

"The risk for this trade is 30 pips, and the reward is 90 pips if all three targets are hit. The risk to reward ratio is 1:3, which yields a tidy 9% return if we take a 3% risk." (PDF p. 225 — illustrative single-trade long example, GBPUSD M15)

"The risk for this trade is 30 pips, and the reward is 90 pips if all three targets are hit. The risk to reward ratio is 1:3, which yields a tidy 9% return if we take a 3% risk." (PDF p. 226 — illustrative single-trade short example, GBPUSD M15)

"With its clear-cut rules and mechanical execution, the English breakfast tea method eliminates the guesswork in terms of strategy direction." (PDF p. 227)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3                               # 1:3 RR if all three targets hit; reality is partial fills, 35-45% any-target-hit rate
expected_dd_pct: TBD                           # 8-12%; failed reversal days = full 30-pip loss
expected_trade_frequency: 200-250/year          # ~1 valid setup per trading day, 250 trading days minus drift-too-small skips
risk_class: medium
gridding: false
scalping: false                                # M15 + 30-pip TP1
ml_required: false
```

## 11. Strategy Allowability Check (V5)

- [x] Strategy concept is mechanical (time-of-day-bound close-comparison is fully rule-tight)
- [x] No ML required
- [x] No gridding, no martingale
- [x] Not scalping
- [x] Friday Close compatible (intraday close)
- [x] Source citation precise: PDF pp. 223-228
- [x] No near-duplicate (Williams Monday-oops uses Mon-only, not London-open daily; Lien channels not time-bound)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "drift-magnitude floor + UK bank holiday check + news pause + ATR floor"
  trade_entry:
    used: true
    notes: "single daily 08:30-London entry conditional on 04:15→08:15 drift sign; entry at bar open"
  trade_management:
    used: true
    notes: "33/33/34 partial close with progressive BE/lock-in"
  trade_close:
    used: false
    notes: "exit by SL/TP only"
```

```yaml
hard_rules_at_risk: []
at_risk_explanation: |
  No hard rule at risk. DST handling required: 08:30 London is the strategy's time anchor;
  during UK BST (late March to late October) this is 07:30 UTC; during UK GMT (winter) it is
  08:30 UTC. Darwinex broker-time GMT offset (+2 winter / +3 summer per V5 broker time
  convention) means broker-clock entry time varies between summers and winters. Implementation
  must use a timezone-aware time anchor referenced to London civil time, NOT to a fixed broker
  hour. SETUP_DATA_MISMATCH risk if implemented as fixed broker hour.
```
