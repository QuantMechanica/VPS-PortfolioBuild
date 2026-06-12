# Library Mining: Unger — Forex Strategies (Axiory Brochure + BetterSystemTrader Ep. 045)

**Date:** 2026-06-12
**Miner:** Claude (library-mining task 7143e208)
**Slug:** unger-forex-strategies
**Source files:**
- `C:/Users/Administrator/Downloads/484404695-forex-strategies-by-andrea-unger.pdf` (7 pages)
- `C:/Users/Administrator/Downloads/347678472-BetterSystemTrader-Episode45-AndreaUnger.pdf` (10 pages)

---

## Step 0 — Mandatory Dedup Check

**Existing unger-* cards in cards_approved:** 36 cards (QM5_1061–QM5_5001 range)

Mechanisms already carded:
- larry-williams-vola-breakout, orb-index, bollinger-fx-meanrev, inside-day-bias-dax,
  friday-close-reversal-fx, donchian-channel-tf, gold-intraday-bias, sp500-pivot-trend,
  nasdaq-pullback-tf, nasdaq-3pm-breakout, gold-bb-breakout, gold-prev-session-breakout,
  crude-ma-crossover, crude-inventory-release, crude-donchian160, crude-prevday-meanrev,
  index-holiday-long, sp500-eom-pullback, dax-overnight-bias, dax-false-break-reversal,
  dax-gap-reversal, dax-adx-low-breakout, gold-session-breakout-tf, gold-keltner-meanrev,
  crude-round-number-tf, nasdaq-priorclose-expansion, dax-4h-high-breakout,
  nasdaq-atr-spike-short, crude-intraday-bias, nasdaq-close-channel, dax-bb-multiday,
  gold-donchian-bias, gold-linreg-trend, **unger-daily-factor-indecision-pattern** (QM5_11891),
  alpha-unger-method (QM5_3002), legend-unger-breakout (QM5_5001)

**QM5_11891** already covers the exact "daily factor" pattern disclosed in BST Ep. 045.

---

## Source 1: `484404695-forex-strategies-by-andrea-unger.pdf`

### Nature of Document

7-page Axiory broker marketing brochure titled "Forex Strategies by Andrea Unger."
Produced for the Axiory MultiTrader managed-account platform. **Not a book.**
No entry/exit rules disclosed anywhere. Black-box portfolio products only.

### Content Summary

**UngerTrading SOFTPATH** (conservative risk):
- Portfolio of 6 automatic systems on EURUSD only
- Timeframes: M5 (2 systems), M15 (3 systems), H1 (1 system)
- Mechanisms: "breakout of important levels" + reversal signals — no parameters given
- Stops: fixed pip SL + time exits + trailing exits
- Max drawdown in closed positions: 8% (acts as circuit breaker)
- Capital Guard: −20%
- Average yearly profit (backtest 2004–2013): 21.7%; Max DD: −11.9%

**UngerTrading ACHIEVER** (average risk):
- Same 6 systems, higher sizing (0.3 lots/$10k max vs 0.2)
- Max drawdown in closed positions: 30%; Capital Guard: −35%
- Average yearly profit: 67.5%; Max DD: −28.1%

### Rule-Completeness Assessment

**R2 FAIL — not rule-complete.** No indicator parameters, no entry thresholds,
no stop distances, no target levels are published. This is a signal-provider
marketing document. Parameters are described only as "volatility-based" and
"price-pattern-based" without any numerical specifics.

### IS vs OOS Candor

The backtest period (2004–2013) equals the strategy development window — no held-out
OOS period reported. No walk-forward validation. PF, Sharpe, trade count not disclosed.

### Verdict: 0 new proposals — NOT MINABLE

---

## Source 2: `347678472-BetterSystemTrader-Episode45-AndreaUnger.pdf`

### Nature of Document

10-page transcript of BetterSystemTrader podcast Episode 045 (~2016), hosted by
Andrew Swanscott. Conversational Q&A — Unger discusses his setup/trigger development
philosophy, not specific strategies.

### Rule-Complete Disclosures

Only **one** fully specified rule appears in the transcript (pages 6–7):

> "I take the whole session of the day. I measure the total range of a daily bar and
> I measure the size of the body, the distance between open to close of the market.
> If the ratio between the body and the range is smaller than 50 percent, 0.5,
> normally the trend-following entries are more effective."

This is the **Daily Factor / Indecision-Then-Trend** pattern — the body/range ratio
filter of 0.5 with breakout entry on the next session.

**DUPLICATE — already carded as QM5_11891 (unger-daily-factor-indecision-pattern)**
That card fully mechanizes this exact disclosure (ATR SL/TP, 5-bar time stop, 10 DWX
forex majors, symmetric long/short). Nothing new can be added.

### Additional Conceptual Content (non-minable)

- "40 basic patterns" (undisclosed specifics): volatility/expansion patterns,
  directional patterns, neutral patterns (inside bar, outside bar, gap)
- Trigger-first approach: find entry level, then test which setups improve results
- E-mini S&P = mean-reverting; DAX = trend-following (conceptual market character)
- Intraday bias strategies: test if a market is systematically bullish/bearish during
  specific intraday windows (mentions DAX 10:30–13:00 as example, non-binding)
- Forex pairs should be traded with mirror-symmetric long/short patterns
- Holding period typically 1–7 days; longer makes patterns irrelevant
- Exits tested via timed bars, end-of-day, or equal SL/TP to measure directional edge

None of these are rule-complete — no parameters, no thresholds, no stop/target levels
are given. Implementing any of them requires choosing parameters Unger did not disclose.

### IS vs OOS Candor

The podcast is conversational discussion of development methodology. No performance
figures are given, so no IS/OOS assessment is possible or required.

---

## Summary

| Source | Pages | Rule-Complete Systems Found | Verdict |
|--------|-------|-----------------------------|---------|
| 484404695 (Axiory brochure) | 7 | 0 — black-box portfolio product | NOT MINABLE |
| 347678472 (BST Ep. 045 transcript) | 10 | 1 (Daily Factor) | DUPLICATE → QM5_11891 |

**NEW: 0 | VARIANT: 0 | DUPLICATE: 1**

---

## Action: None Required

The "daily factor" system from BST Episode 045 is fully carded (QM5_11891, APPROVED).
The Axiory brochure contains no extractable rules.

The remaining gap in Unger coverage — if any — lies in his published books
("The Unger Method" / Italian editions) which are not available in the Downloads folder.
The 36 existing unger-* cards likely cover the main strategies from those books,
based on the breadth of mechanisms (ORB, Donchian, BB, Keltner, session breakout,
intraday bias, DAX/Gold/Crude/Nasdaq/SP500 variants) already captured.

**Recommendation:** Close this mining run. Reopen only if OWNER provides Unger's
published book text for comparison against the existing 36 cards.
