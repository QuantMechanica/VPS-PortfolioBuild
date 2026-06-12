# Library Mining: Connors & Alvarez — Short-Term Trading Strategies That Work (2009)

**Date:** 2026-06-12  
**Miner:** Claude (library-mining task 7143e208)  
**Source file:** `C:/Users/Administrator/Downloads/100324184-Short-Term-Trading-Strategies-That-Work-by-Larry-Connors-and-Cesar-Alvarez.pdf`  
**Text cache:** `D:/QM/strategy_farm/source_cache/connors-short-term-strategies-2009.txt`  
**Extraction quality:** DEGRADED — the PDF is a scanned slide-deck (61 pages total). pypdf extracted 11KB of text from slide titles and bullet summaries. Full quantitative test data (exact profit factors, drawdowns, win rates) was NOT recoverable from this PDF via pypdf text extraction. Slides provide strategy rules in outline form but not the full statistical tables from the underlying book.
**Evidence type:** The slide deck summarizes IS backtests (1995–2007 per slide 2) but the numerical evidence is in the underlying full book, not the slides. Where specific statistics are known, they are drawn from existing cards in the pool that cite the same book.

---

## STEP 0 — DEDUP STATUS

**Full dedup search completed before any proposal.** Filename + content search results:

**Existing Connors cards in the pool (53 found):**
```
QM5_10061 connors-trin3-d1
QM5_10062 connors-cvr1-d1
QM5_10063 connors-cvr3-d1
QM5_10142 rsi2-sma (multiple)
QM5_10429 et-rsi2-es
QM5_10430 et-cum-rsi2
QM5_10523 mql5-larry-rsi2
QM5_11130 tm-vix-stretch (3-day VIX stretch)
QM5_11365 connors-rsi2-sma200-pullback-d1
QM5_11366 connors-double7s-sma200-d1
QM5_11395 connors-rsi2-sma200-pullback-h4
QM5_11396 connors-double7s-sma200-h4
QM5_11427 connors-rsi2-sma200-pullback-d1
QM5_11428 connors-double7s-sma200-d1
QM5_11497 connors-alvarez-double7s-sma200-d1
QM5_11498 connors-alvarez-cumulative-rsi2-sma200-d1
QM5_11564 connors-double7s-sma200-d1
QM5_11565 connors-3down-days-sma200-d1
QM5_11767 connors-double7s-200sma-d1
QM5_11768 connors-cumrsi2-200sma-d1
QM5_11881 connors-rsi2-mean-reversion
QM5_11882 connors-double-7s
QM5_1235 connors-rsi2
QM5_1242 connors-double7
QM5_1322 connors-rsi2-fx-port-d1
QM5_1325 connors-rsi2-fx-intraday-h1
QM5_1492 connors-vix-spike-reversal-h4
QM5_1505 connors-cumulative-rsi-h4
QM5_1511 connors-tps-time-price-score-h4
QM5_1527 connors-crsi-composite-h4
QM5_1530 connors-double-sevens-h4
QM5_1546 connors-multi-day-high-low-h4
QM5_9465 connors-rsi25-d1
QM5_9466 connors-r2-d1
QM5_9467 connors-crsi-pullback-d1
QM5_9468 connors-rsi4-3day-d1
QM5_9703 ff-rsi2-scalp-m15
QM5_9718 bandy-cumulative-rsi2-mr-index (Connors substrate)
QM5_9933 bandy-choppiness-index-sideways-rsi2-mr-index
QM5_9934 bandy-ulcer-index-spike-rsi2-mr-index
```

**Additionally covered via sourced proximity:**
- VIX Stretch (3 consecutive days): QM5_11130 covers the exact Connors VIX Stretches strategy (p.22 of slides)
- VIX RSI (RSI2 of VIX > 90): QM5_10062/10063 (CVR variants) and QM5_1492 cover VIX RSI variants
- TRIN 3-day: QM5_10061 (connors-trin3-d1) covers exact TRIN 3 days rule (p.24)
- Cumulative RSI: QM5_1505, QM5_11498, QM5_9718, QM5_11768 — four cards covering the Cumulative RSI variants
- Double 7's: QM5_11366, QM5_11428, QM5_11497, QM5_11564, QM5_11767, QM5_1242, QM5_1530, QM5_11882 — eight cards
- 3-down-days: QM5_11565 covers exactly this (consecutive closes below prior close + SMA200 filter)
- S&P Short (4+ up days below SMA200): QM5_11565 documents both the long and short sides of the Connors book

---

## Connors Book — Strategies Assessed Against Dedup

### Strategy 1: Buy Pullbacks Not Breakouts (multi-day down entry)

**DEDUP VERDICT: DUPLICATE (skip)**  
Covered by **QM5_11565** (connors-3down-days-sma200-d1) which explicitly cites Connors & Alvarez (2009), "Buy pullbacks" concept. Multiple variants in QM5_1235, QM5_11365, QM5_11427.

---

### Strategy 8 / Rule 9: 2-Period RSI Below 5 (SPY/Index, SMA200 filter)

**DEDUP VERDICT: DUPLICATE (skip)**  
Covered by **QM5_1235** (connors-rsi2), **QM5_11365** (connors-rsi2-sma200-pullback-d1), **QM5_11427** (same D1), **QM5_1322** (FX port), **QM5_9466** (connors-r2-d1), and ~10 more. The core RSI(2) < 5 entry + SMA200 filter + RSI(2) > 65 exit is among the most thoroughly covered concepts in the pool.

---

### Strategy 10: Cumulative RSI(2) (sum of 2-day RSI2 < 45)

**DEDUP VERDICT: DUPLICATE (skip)**  
Covered by **QM5_1505** (connors-cumulative-rsi-h4), **QM5_11498** (connors-alvarez-cumulative-rsi2-sma200-d1), **QM5_11768** (connors-cumrsi2-200sma-d1), **QM5_9718** (bandy-cumulative-rsi2-mr-index), and more.

---

### Strategy 11: Double 7's (SPY above SMA200; close at 7-day low = buy; 7-day high = sell)

**DEDUP VERDICT: DUPLICATE (skip)**  
Covered by **QM5_11366**, **QM5_11428**, **QM5_11497**, **QM5_11564**, **QM5_11767**, **QM5_1242**, **QM5_1530**, **QM5_11882** — eight cards from this exact source with this exact rule.

---

### VIX Strategies (Slide pp. 22–24): VIX Stretches, VIX RSI, TRIN

**DEDUP VERDICT: DUPLICATE (skip all three)**  
- VIX Stretches: **QM5_11130** (tm-vix-stretch) — exact 3-day VIX-above-SMA10-by-5% entry, RSI2 > 65 exit.
- VIX RSI: **QM5_10062** (connors-cvr1-d1), **QM5_10063** (connors-cvr3-d1), **QM5_1492** (connors-vix-spike-reversal-h4) cover RSI(2) of VIX > 90 variants.
- TRIN 3 days > 1.00: **QM5_10061** (connors-trin3-d1) — exact match.

---

### S&P Short Strategy (Slide p.26): SPY below SMA200, 4+ consecutive up closes, short on close, cover below SMA5

**DEDUP VERDICT: DUPLICATE (skip)**  
**QM5_11565** (connors-3down-days-sma200-d1) explicitly documents both the long pullback and the short "S&P Short" variant from Connors & Alvarez (2009). The card notes "Strategies 1-2 (Buy Pullbacks) + S&P Short (Strategy 26)" in the source_citation.

---

### End of Month Strategy (Slide p.20): Buy on specific calendar days (25, 24, 1, 27, 26 highest gain days)

**DEDUP VERDICT: NEAR-DUPLICATE — CONDITIONAL NEW**

The concept of end-of-month calendar effects in equity indices is covered by existing cards:
- **QM5_1131** (qp-payday-sp500) — payday effect
- **QM5_1049** (mcconnell-turn-of-month) — turn-of-month
- **QM5_1125** (unger-sp500-eom-pullback) — EOM pullback
- **QM5_1059** (jegadeesh-stm-reversal-indices) — short-term reversal

However, the Connors End of Month strategy has specific differentiating features:
1. Entry condition requires the stock/index to be above its 200-day SMA.
2. Enhanced variant: entry on days 25–30 ONLY IF the prior day was a down day (or 2+ consecutive down days).
3. Exit: next-bar market order (hold 1–3 days).
4. Original is applied to individual stocks + SPY, not just indices.

**Assessment:** The rule-complete version for the enhanced variant (down day filter on specific calendar days + SMA200 filter) is marginally differentiated from existing cards. However, given that:
- The PDF extraction was degraded and exact quantitative evidence is not available from this file.
- QM5_1131 and QM5_1049 already cover the structural concept adequately.
- The Connors version was tested IS only (1995–2007) — no OOS split documented in the slide deck.
- The specific "best day" ranking (25, 24, 1, 27...) is IS-optimized and likely unstable.

**VERDICT: REJECT** — The specific ranked calendar days are IS-optimized artifact; structural concept already covered by existing EOM cards. The down-day filter variant is too thin to justify a new card without the full quantitative evidence from the original book (which is not recoverable from the slide PDF).

---

### Rule 6: Buy-at-Close / Sell-at-Open Overnight Hold

**DEDUP VERDICT: NEAR-DUPLICATE — REJECT**

Connors slide p.16: "Buying SPY on close and selling on open gained 171.40 points (1995–2007) vs. buying open/selling close = -70.88." This documents the overnight drift premium in US equities.

Existing cards:
- **QM5_1130** (lou-polk-overnight-intraday) covers overnight vs. intraday asymmetry.
- **QM5_1159** (qp-spy-overnight-ma20) covers SPY overnight return with SMA filter.

The Connors "rule" here is an observation without a mechanical entry/exit/SL specification — it is not trade-complete as stated in the slides. The slide does not specify: which days to hold, any regime filter, or a stop. **REJECT — not rule-complete as extracted.**

---

### Rule 7: Intraday Pullback Entry (buy intraday dip vs. morning high)

**DEDUP VERDICT: REJECT — NOT RULE-COMPLETE**

Slide p.17: "The greater the intraday selloff, the better the performance over the next five days." No specific entry threshold, no SL, no symbol specification provided in the slides. Without the full book chapter text (not recoverable from this slide PDF), this cannot be mechanized to READY or NEEDS_SPEC standard. REJECT as-extracted.

---

## Summary Table

| Strategy | Book Pages (slides) | Dedup Verdict | Action |
|----------|-------------------|---------------|--------|
| Buy Pullbacks (3 down days) | pp. 45-46 | DUPLICATE (QM5_11565, QM5_11365 etc.) | skip |
| RSI(2) < 5 long | p. 53 | DUPLICATE (QM5_1235, QM5_11365 etc.) | skip |
| Cumulative RSI(2) | p. 54 | DUPLICATE (QM5_1505, QM5_11498 etc.) | skip |
| Double 7's | p. 55 | DUPLICATE (QM5_11366 et al. × 8 cards) | skip |
| VIX Stretches | p. 22 | DUPLICATE (QM5_11130) | skip |
| VIX RSI | p. 23 | DUPLICATE (QM5_10062/63, QM5_1492) | skip |
| TRIN 3-day | p. 24 | DUPLICATE (QM5_10061) | skip |
| S&P Short (4+ up days) | p. 26 | DUPLICATE (QM5_11565) | skip |
| End-of-Month calendar | p. 20 | REJECT (IS-optimized, no OOS, concept covered) | skip |
| Overnight hold rule | p. 16 | REJECT (not rule-complete in slides) | skip |
| Intraday pullback | p. 17 | REJECT (not rule-complete in slides) | skip |

**New proposals from this book: 0**  
**Duplicates found: 8**  
**Rejected (not rule-complete / insufficient evidence): 3**

---

## Key Findings for OWNER

1. **Connors is thoroughly mined.** With 40+ existing Connors-sourced cards, every strategy in the slide deck is either already in the pool or not rule-complete in the slide format.

2. **PDF quality is the limiting factor.** The Connors PDF is a scanned slide deck, not the full book. Slides contain outline-level rules but not the statistical tables (win rates, PF, drawdown, equity curves). If OWNER has access to the full-text version of this book, a second pass on the complete text would allow verification of exact parameters (e.g., RSI exit thresholds tested at 65 vs. 70 vs. 75).

3. **Connors systems that might be under-mined:** The full book reportedly contains chapters on High-Probability ETF Trading (5-period RSI on ETFs), PowerRatings for stocks, and the ConnorsRSI composite (RSI2 + streak RSI + percent rank). ConnorsRSI (CRSI) is covered by QM5_1527. The 5-period RSI variant for ETFs is potentially not covered — but without the full book text, the rule-complete spec cannot be confirmed.

4. **No new proposals warranted from this slide PDF.** Recommend acquiring the full-text version if deeper Connors mining is desired in the future.
