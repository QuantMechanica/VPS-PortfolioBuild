# Strategy Card — Singh Rapid-Fire (M1 EUR/USD trend-scalp)

## Card Header

```yaml
strategy_id: SRC06_S01
ea_id: TBD
slug: singh-rapid-fire
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

strategy_type_flags: [scalping, trend-following, momentum]
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

> **singh-rapid-fire (SRC06_S01 - M1 EURUSD, ParaSAR+SMA60 trend-scalp)**
> 
> APPROVED
> Edge mechanism: ParaSAR flip as momentum confirmation within SMA(60)-gated trend direction
> Portfolio fit: first scalping EA in pipeline - adds style diversity
> Author claim: "30-40 opportunities/day" - author-claimed illustrative
> 
> Flag carried to P5b: scalping_p5b_latency. Inverted R:R (SL 15pip > TP 10pip) - edge must come from win-rate, not R:R. Acceptable at G0; P3 must confirm positive expectancy.

### Flags carried forward

- scalping_p5b_latency: VPS-realistic latency stress mandatory at P5b before P9 deployment.
- inverted R:R (SL 15pip > TP 10pip): P3 must validate positive expectancy from win-rate, not R:R.
- news_pause_default (V5 hard-rule default): no exception requested.


## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7."
    location: "Chapter 6 'Strategies for Scalpers' — Strategy 1: Rapid-Fire Strategy, PDF pp. 111-118 (printed pp. 111-117). Indicator-block on PDF p. 112; Long-trade-setup PDF p. 114; Short-trade-setup PDF p. 116; Strategy Roundup PDF p. 117."
    quality_tier: B
    role: primary
```

## 2. Concept

Trend-scalping on the most-liquid forex pair on the smallest practical chart. Direction is gated by price-vs-SMA(60) on the M1 chart; entry is timed by Parabolic SAR flipping to the opposite side of price (SAR-flip-confirms-momentum). The author claims "30 to 40 trading opportunities for the rapid-fire strategy every day" (PDF p. 112).

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - M1
primary_target_symbols:
  - EURUSD                                     # author-prescribed only — "designed specifically for the EUR/USD, the most traded currency pair in the world" (PDF p. 113)
```

## 4. Entry Rules

```text
LONG:
- on closed M1 bar
- if Close > SMA(60) on closed bar
- and PSAR(step=0.02, max=0.2) prints below price (i.e., flipped from above-price to below-price on the just-closed bar)
- then BUY at next-bar open
- SL = Entry - 15 pips
- TP = Entry + 10 pips                         # author-fixed; risk-reward 1.5:1

SHORT:
- on closed M1 bar
- if Close < SMA(60) on closed bar
- and PSAR(step=0.02, max=0.2) prints above price (i.e., flipped from below-price to above-price on the just-closed bar)
- then SELL at next-bar open
- SL = Entry + 15 pips
- TP = Entry - 10 pips
```

## 5. Exit Rules

```text
- TP at 10 pips fixed, SL at 15 pips fixed (R:R 1.5:1, INVERTED — risk > reward)
- No trailing stop in source spec
- Friday Close enforced (V5 framework default; M1 trade hold typically minutes, no Fri 21:00 conflict)
```

## 6. Filters (No-Trade)

```text
- skip during major news releases (V5 default `news_pause_default`)
- skip if EURUSD spread > broker normal spread × 2 (M1 PSAR + 10-pip TP cannot survive widened spread)
- skip if M1 ATR < 1 pip (low-vol micro-range; PSAR will whipsaw)
- skip if SAR flipped on a bar where Close is within 1 pip of SMA(60) (false-close-on-MA filter)
```

## 7. Trade Management Rules

```text
- one position per magic+symbol (V5 default)
- no pyramiding, no gridding
- if a new opposite-direction signal fires while a position is open, exit existing position before evaluating new (author's discretion in roundup PDF p. 117: "Do you exit the previous trade before entering a new one, ignore any new trade signals until the current trade exits, or simply fire off whenever there is a trade signal?" — V5 chooses exit-then-evaluate to maintain `one_position_per_magic_symbol`)
- Friday Close enforced
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: psar_step
  default: 0.02
  sweep_range: [0.01, 0.015, 0.02, 0.025, 0.03]
- name: psar_max
  default: 0.2
  sweep_range: [0.1, 0.15, 0.2, 0.25, 0.3]
- name: sma_period
  default: 60
  sweep_range: [30, 45, 60, 75, 90, 120]
- name: tp_pips
  default: 10
  sweep_range: [6, 8, 10, 12, 15]
- name: sl_pips
  default: 15
  sweep_range: [10, 12, 15, 18, 20]
```

## 9. Author Claims (verbatim)

```text
"On average, there are about 30 to 40 trading opportunities for the rapid-fire strategy every day." (PDF p. 112)

"The risk for this trade is 15 pips, and the reward is 10 pips. The risk to reward ratio is 1.5:1, which yields a 2% return if we take a 3% risk." (PDF p. 115 — illustrative single-trade long example)

"The risk for this trade is 15 pips, and the reward is 10 pips. The risk to reward ratio is 1.5:1, which yields a 2% return if we take a 3% risk." (PDF p. 116 — illustrative single-trade short example)

"Remember, the rapid-fire strategy works best in a trending environment. It requires fast thinking and nimble reactions. It is most suitable for action-driven traders who can maintain their composure while in the thick of action." (PDF p. 117)
```

**Research note (per V5 BASIS):** the book contains no aggregate win-rate, no annualized return, no equity curve, no multi-trade backtest. The two R-multiple statements above are single-trade illustrative examples, not strategy-wide performance statistics. Any aggregate must be re-derived in V5 P2/P3.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.0                               # 1.5:1 SL:TP inverted; needs >60% win rate just to break even
expected_dd_pct: TBD                           # author provides no DD claim; high-frequency M1 → expect significant intraday DD; estimate 8-15%
expected_trade_frequency: 7500-10000/year      # 30-40 trades/day × 250 trading days = 7500-10000/year per author
risk_class: high                               # M1 + inverted R:R + no aggregate stats
gridding: false
scalping: true                                 # M1 → scalping_p5b_latency hard rule binds
ml_required: false
```

## 11. Strategy Allowability Check (V5)

- [x] Strategy concept is mechanical (PSAR + SMA cross is fully rule-tight; no discretion)
- [x] No ML required
- [x] No gridding, no martingale
- [x] Scalping → P5b VPS-realistic latency calibration MUST be planned (M1 + 10-pip TP highly latency-sensitive)
- [x] Friday Close compatible (M1 holds <60 min typically; no Fri 21:00 hold)
- [x] Source citation precise: PDF pp. 111-117, ISBN 978-1-118-38551-7
- [x] No near-duplicate of existing approved card (closest siblings are Chan QT pairs-MR which are statistical-arb on equities, not M1 forex trend-scalp; SRC04 Lien has no M1 strategy)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "spread guard + ATR floor + news pause; close-on-MA tolerance filter"
  trade_entry:
    used: true
    notes: "PSAR-flip + SMA(60)-side gating; entry at next-bar open"
  trade_management:
    used: false
    notes: "fixed SL/TP only; no trailing, no BE shift"
  trade_close:
    used: false
    notes: "exit by SL/TP only"
```

```yaml
hard_rules_at_risk:
  - scalping_p5b_latency
  - news_pause_default
at_risk_explanation: |
  scalping_p5b_latency: M1 timeframe + 10-pip fixed TP. Realistic VPS slippage (1-3 pips) +
  spread (0.8-1.5 pips on EURUSD) eats 20-40% of TP. P5b stress on VPS-realistic latency is
  mandatory. If the strategy fails P5b but passes P2/P3 on Model 4 every-tick backtests, this
  is the canonical "looks good in tester, dies on broker" warning case.

  news_pause_default: M1 trades are routinely killed by news-spike volatility; the 15-pip SL
  is below typical news-bar wick magnitude. V5 default `news_pause_default` should bind here;
  no documented exception requested.
```
