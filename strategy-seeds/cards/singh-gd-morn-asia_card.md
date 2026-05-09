# Strategy Card — Singh Good Morning Asia (D1 USD/JPY follow previous-day's bull-or-bear)

## Card Header

```yaml
strategy_id: SRC06_S17
ea_id: TBD
slug: singh-gd-morn-asia
status: DRAFT
created: 2026-05-09
created_by: Research
last_updated: 2026-05-09

strategy_type_flags: [time-of-day, momentum, follow-through]
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Singh, Mario. (2013). 17 Proven Currency Trading Strategies: How to Profit in the Forex Market. Wiley Trading. Singapore: John Wiley & Sons Singapore Pte. Ltd. ISBN 978-1-118-38551-7."
    location: "Chapter 10 'Strategies for Mechanical Traders' — Strategy 17: Good Morning Asia, PDF pp. 228-233. Strategy concept PDF p. 229; Long-trade-setup PDF p. 229; Short-trade-setup PDF p. 231; Strategy Roundup PDF p. 233."
    quality_tier: B
    role: primary
```

## 2. Concept

D1 momentum-follow-through on USD/JPY: at the daily roll (5 P.M. NY = beginning of Asian session = open of next D1 candle), check whether the just-closed daily candle was a BULL candle (Close > Open) or a BEAR candle (Close < Open). If bull, go LONG at the D1 open — riding the momentum into Asia. If bear, go SHORT. SL is the previous day's low (long) or high (short). TP is HALF the SL distance, giving an INVERTED R:R 2:1 (risk 2 to make 1). Author rationale: USD/JPY follows US-market sentiment into Asian session; Japan is the only Asian major currency, USD/JPY is most-liquid Asian-session pair (PDF p. 229).

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - D1
primary_target_symbols:
  - USDJPY                                     # author-prescribed only — "this strategy applies only to the USD/JPY" (PDF p. 229)
```

## 4. Entry Rules

```text
At each D1 candle's open (= 17:00 NY = 22:00/23:00 UTC = 00:00 broker NY-Close time):

LONG:
- precondition: just-closed D1 candle has Close > Open (bull candle)
- then BUY USD/JPY at the new D1 candle's open price
- SL = LowOfPrevDailyCandle
- ENFORCED MINIMUM SL distance: if (Entry - SL) < 30 pips, shift SL down so Entry - SL = 30 pips (author-mandated, PDF p. 230)
- TP = Entry + (Entry - SL) / 2                       # HALF SL distance (R:R 2:1 INVERTED — risk 2x reward)

SHORT:
- precondition: just-closed D1 candle has Close < Open (bear candle)
- then SELL USD/JPY at new D1 open
- SL = HighOfPrevDailyCandle
- ENFORCED MINIMUM SL distance: if (SL - Entry) < 30 pips, shift SL up so SL - Entry = 30 pips
- TP = Entry - (SL - Entry) / 2
```

## 5. Exit Rules

```text
- Single TP at SL_distance / 2 (R:R 2:1 INVERTED)
- No partial close
- SL handled by entry stop
- Friday Close enforced V5 default; D1 trade may hold 1-3 days, forced flat at Fri 21:00 cuts winners but is acceptable
- author also notes optional discretionary intraday close — V5 implements only the rule-tight TP/SL exit
```

## 6. Filters (No-Trade)

```text
- skip if just-closed D1 is a doji (|Close - Open| < 5 pips) — no clear direction
- skip if SL would be > 200 pips (excessive risk per trade given inverted R:R)
- skip during major BoJ rate decisions or US FOMC Wednesdays (V5 default `news_pause_default`)
- skip if USDJPY weekly ATR is below 60-day average × 0.7 (extreme low-vol regime; momentum thesis weakens)
```

## 7. Trade Management Rules

```text
- one position per magic+symbol
- no partial close, no trailing
- no pyramiding (only one entry per daily candle event)
- no gridding
- Friday Close enforced
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: doji_threshold_pips
  default: 5
  sweep_range: [3, 5, 8, 10, 15]
- name: sl_min_distance_pips
  default: 30
  sweep_range: [20, 25, 30, 40, 50]
- name: sl_max_distance_pips
  default: 200
  sweep_range: [150, 200, 250, 300]
- name: tp_sl_ratio
  default: 0.5                                  # TP = 0.5 × SL distance, R:R 2:1 INVERTED
  sweep_range: [0.3, 0.5, 0.75, 1.0, 1.5]
- name: bullbear_definition
  default: "close_vs_open"                      # author's definition; alternative: close vs prev-close
  sweep_range: ["close_vs_open", "close_vs_prev_close", "close_vs_midpoint"]
```

## 9. Author Claims (verbatim)

```text
"The risk for this trade is 106 pips, and the reward is 53 pips. The risk to reward ratio is 2:1, which yields a 1.5% return if we take a 3% risk." (PDF p. 230 — illustrative single-trade long example, USDJPY D1)

"The risk for this trade is 80 pips, and the reward is 40 pips. The risk to reward ratio is 2:1, which yields a 1.5% return if we take a 3% risk." (PDF p. 232 — illustrative single-trade short example, USDJPY D1)

"This strategy is suitable for traders with very little time to monitor the market. Furthermore, it does not require any complex market analysis. The entry time is predictable because the market is entered at a fixed time of the day, every single day." (PDF p. 233)

"Good morning Asia centers on the USD/JPY for three reasons: 1. The United States and Japan are the largest and third largest economies in the world respectively. 2. The USD/JPY is the second most traded currency pair in the world, right after the EUR/USD. 3. Japan is the first country in Asia where markets open. Hence, ample liquidity on the USD/JPY allows traders to execute long and short positions easily." (PDF p. 233)
```

**Research note (BASIS):** The R:R 2:1 INVERTED structure is unusual; author makes no aggregate-win-rate claim. For PF >= 1.0 with R:R = 0.5:1, win rate must exceed 67%. P2 baseline backtest will quickly tell whether the 67%+ win rate is realistic on USDJPY D1 follow-through; if not, this card fails P2 and is killed.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.0                               # 2:1 SL:TP inverted; needs >67% win rate to break even
expected_dd_pct: TBD                           # 10-15%; consecutive bear-after-bull-day flips would hurt
expected_trade_frequency: 250/year              # roughly one signal per trading day (excluding doji-skips)
risk_class: high                               # inverted R:R + no win-rate claim from author
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5)

- [x] Strategy concept is mechanical (close-vs-open candle classification + previous-day-extreme SL is fully rule-tight)
- [x] No ML required
- [x] No gridding, no martingale
- [x] Not scalping (D1)
- [x] Friday Close compatible (D1 trades may hold 1-3 days)
- [x] Source citation precise: PDF pp. 228-233
- [x] No near-duplicate (Williams TDOM-bias is day-of-month bias, not previous-day-direction follow; Williams TDW-bias is day-of-week bias)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "doji filter + SL-distance bounds + central-bank-event blackout + ATR floor"
  trade_entry:
    used: true
    notes: "previous D1 candle bull/bear classification at daily roll; entry at next D1 open"
  trade_management:
    used: false
    notes: "fixed SL/TP, no BE move, no partial close"
  trade_close:
    used: false
    notes: "exit by SL/TP only"
```

```yaml
hard_rules_at_risk: []
at_risk_explanation: |
  No hard rule at risk in normal operation. The inverted R:R 2:1 (risk 2 to make 1) is unusual
  but not against any V5 hard rule — it's a P2 economics question, not a hard-rule question.
  V5 P2 baseline will quickly determine if win rate justifies the inverted RR; if not, card is
  killed pre-P3 with documented author-illustration-vs-aggregate-stats discrepancy.

  V5 broker time is Darwinex NY-Close convention; D1 candles roll at 17:00 NY which IS the
  daily roll (00:00 broker time by Darwinex definition). Implementation is timezone-clean
  for D1 entries.
```
