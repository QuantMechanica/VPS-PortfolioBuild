# Strategy Card — Singh Trend Rider (H1/H4 EMA12-cross-EMA36 + ADX(14) exit)

## Card Header

```yaml
strategy_id: SRC06_S07
ea_id: TBD
slug: singh-trend-rider
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

> **singh-trend-rider (SRC06_S07 - H1/H4, EMA(12,36) cross + ADX(14) open-ended exit)**
> 
> APPROVED
> Edge mechanism: EMA-cross entry + ADX momentum-waning exit; two independent confirmations
> Portfolio fit: closest existing = lien-perfect-order (SRC04_S09, EMA 7/21/89 perfect-order alignment); mechanism is sufficiently distinct - EMA(12/36) cross vs. perfect-order alignment; ADX open-ended exit vs. fixed-pip targets
> Author claim: "one of the most effective strategies" - author-claimed qualitative

### Flags carried forward

- Portfolio-fit note: distinct from lien-perfect-order despite EMA-family overlap (cross vs alignment; ADX exit vs fixed pips). No P9 dedup risk at G0; reconfirm at P9 correlation check.


## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7."
    location: "Chapter 8 'Strategies for Swing Traders' — Strategy 7: Trend Rider, PDF pp. 155-163. Indicator-block PDF pp. 156-157; Strategy concept PDF p. 157; Long-trade-setup PDF p. 158; Short-trade-setup PDF p. 160; Strategy Roundup PDF p. 162."
    quality_tier: B
    role: primary
  - type: book
    citation: "Lien, Kathy. (2009/2014). Day Trading and Swing Trading the Currency Market. Wiley. (SRC04 primary)."
    location: "ADX-based exit conceptual ancestor; Singh names Lien as mentor in Acknowledgments (PDF p. xix)"
    quality_tier: A
    role: supplement
```

## 2. Concept

H1/H4 trend-follower with EMA-cross entry trigger and ADX-based open-ended exit. Long when EMA(12) crosses above EMA(36) and price subsequently pulls back to touch the EMA(12); short when EMA(12) crosses below EMA(36) and price pulls back to touch the EMA(12). Critically, there is NO predetermined profit target — the trade rides the trend until ADX(14) crosses above 40 (momentum strong) and then drops back below 40 (momentum waning). Author claims this is "one of the most effective strategies in the swing traders' toolbox because there is no predetermined profit target" (PDF p. 162).

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
- if EMA(12) > EMA(36) on closed bar (cross has occurred)
- and price has subsequently retraced and just-closed bar's Low <= EMA(12) at any point during the bar (price touched EMA(12) from above)
- and EMA(12) > EMA(36) is still true at the touch bar
- then BUY at next-bar open
- SL = EMA(36) value at entry bar; CONSTRAINT: |Entry - SL| >= 30 pips (author-mandated minimum SL distance, PDF p. 159)
- TP = open-ended (managed by ADX exit, see § 5)

SHORT:
- on closed H1 or H4 bar
- if EMA(12) < EMA(36) on closed bar
- and just-closed bar's High >= EMA(12) at any point during the bar (price touched EMA(12) from below)
- and EMA(12) < EMA(36) is still true at the touch bar
- then SELL at next-bar open
- SL = EMA(36) value at entry bar; CONSTRAINT: |Entry - SL| >= 30 pips
- TP = open-ended (managed by ADX exit)
```

## 5. Exit Rules

```text
- ADX(14) exit trigger: when ADX(14) crosses above 40 (momentum confirmed strong) and subsequently drops back below 40, EXIT at next-bar open
- This is a STATE-MACHINE: track {momentum_strong = false} → set true when ADX(14) crosses above 40 → exit when ADX(14) crosses below 40 after momentum_strong is true
- SL handled by entry stop
- Friday Close enforced (V5 framework default; H1/H4 trades may hold for days/weeks; Fri 21:00 forced close required unless documented exception)
```

## 6. Filters (No-Trade)

```text
- skip if EMA(12) and EMA(36) are within 5 pips of each other at the cross bar (cross with no separation = false cross in chop)
- skip if ATR(14) is below symbol's 30-day average ATR by 30%+ (low-vol regime; trend-follow underperforms)
- skip if H4 candle range < 30 pips at entry bar (insufficient room for SL)
- skip during major news releases (V5 default; though H4 less news-sensitive than M5/M15)
```

## 7. Trade Management Rules

```text
- one position per magic+symbol
- no predetermined profit target (open-ended; ADX exit)
- no pyramiding (one entry per cross-event; if pullback fails and price re-extends without touching EMA(12), no re-entry on same cross)
- no gridding
- Friday Close enforced — closure at Fri 21:00 broker time will exit profitable trends prematurely; this is a known cost of V5 default that strategy must absorb (or seek explicit `friday_close = false` exception with QB rationale)
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: ema_fast
  default: 12
  sweep_range: [8, 10, 12, 14, 18]
- name: ema_slow
  default: 36
  sweep_range: [26, 30, 36, 42, 50, 60]
- name: adx_period
  default: 14
  sweep_range: [10, 14, 18, 21]
- name: adx_exit_threshold
  default: 40
  sweep_range: [25, 30, 35, 40, 45, 50]
- name: sl_min_distance_pips
  default: 30
  sweep_range: [20, 25, 30, 40, 50]
- name: tf
  default: H4
  sweep_range: [H1, H4]
```

## 9. Author Claims (verbatim)

```text
"The risk for this trade is 58 pips, and the reward is 316 pips. The risk to reward ratio is 1:5.4, which yields a whopping 16.2% return if we take a 3% risk." (PDF p. 159 — illustrative single-trade long example, EURUSD H4)

"The risk for this trade is 38 pips, and the reward is 155 pips. The risk to reward ratio is 1:4, which yields a decent 12% return if we take a 3% risk." (PDF p. 161 — illustrative single-trade short example, AUDUSD H1)

"The trend rider is one of the most effective strategies in the swing traders' toolbox because there is no predetermined profit target." (PDF p. 162)

"Trend following is statistically valid in the sense that every successful trader vouches for it. Additionally, because of the highly favorable risk to reward ratio of trend following strategies, one good trade can more than compensate for the losses incurred during a bad patch." (PDF p. 163)
```

**Research note:** Author's R-multiples (1:5.4 and 1:4) are single-trade illustrative examples; the strategy has highly variable per-trade R-multiples since profit target is open-ended. Aggregate win rate must be derived in V5 P2/P3.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.5                               # open-ended trend-follower with low win rate (~30-40%) and high R when winning
expected_dd_pct: TBD                           # consecutive cross-fakeout losses common in chop; estimate 12-20%
expected_trade_frequency: 30-80/year per symbol  # H4 EMA(12,36) cross-events with valid pullback: ~3-8/month per pair
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5)

- [x] Strategy concept is mechanical (EMA cross + ADX state machine fully rule-tight)
- [x] No ML required
- [x] No gridding, no martingale
- [x] Not scalping
- [x] Friday Close compatibility: open-ended trend-follower will absorb forced flat at Fri 21:00 (lost upside); no exception requested in initial card; revisit at P9 portfolio if statistically meaningful loss
- [x] Source citation precise: PDF pp. 155-163
- [x] No near-duplicate (Lien lien-perfect-order = MA stack alignment, not EMA cross; SRC04 has no ADX-state-exit card)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "EMA-separation guard at cross + ATR floor + news pause"
  trade_entry:
    used: true
    notes: "EMA cross then pullback-touch entry; entry at next-bar open"
  trade_management:
    used: true
    notes: "ADX(14) state-machine exit; tracks momentum_strong flag"
  trade_close:
    used: true
    notes: "Strategy_ExitSignal — ADX(14) crosses below 40 after having been above 40"
```

```yaml
hard_rules_at_risk:
  - friday_close
at_risk_explanation: |
  friday_close: open-ended trend-following holding multi-day positions; default Fri 21:00
  flat enforces premature exit on profitable trends. P9 portfolio analysis must quantify
  upside loss; if material, formal `friday_close = false` exception request to OWNER + CEO
  with statistical evidence. Until then, strategy operates with default `friday_close = true`.
```
