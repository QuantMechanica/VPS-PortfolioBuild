# Library Mining: BetterSystemTrader Episode 45 — Andrea Unger Interview

**Source file:** `C:/Users/Administrator/Downloads/347678472-BetterSystemTrader-Episode45-AndreaUnger.pdf`  
**Text cache path:** (inline — full transcript supplied to extraction agent)  
**Mined:** 2026-06-12  
**Miner:** claude-sonnet-4-6 (headless)  
**Dedup gate:** All candidate rules checked against 36 existing `unger-*` library cards (slugs enumerated below).

---

## 1. Source Description

BetterSystemTrader.com Episode 45 is a 10-page transcript of an audio interview between host Andrew Swanscott and Andrea Unger, the only four-time World Cup Trading Championships winner (2008, 2009, 2010, 2012 Q4). The episode focuses on Unger's **trigger-first, setup-second** methodology — the inverse of the conventional setup-trigger-order approach.

**Content profile:** The interview is a methodology philosophy discussion. Unger describes *how he thinks about* pattern classification and strategy development, not finished mechanical systems. He mentions:

- A library of ~40 base patterns and 130+ extended patterns he built over 15 years
- Three pattern families: volatility/indecision patterns, directional/expansion patterns, neutral candlestick patterns
- One named, partially parameterised example (the "daily factor" body-to-range ratio)
- Time-of-day entry windows (using DAX as a qualitative example, not quantitative)
- Exit methodology philosophy (timed exits, fixed SL/TP, end-of-day)
- Market character commentary (E-mini S&P = mean-reverting, DAX = trend-following; index asymmetry long vs short; FX symmetry long vs short)

**Author credibility (R1):** Very high. Unger is a four-time WCTC winner and a primary source for the existing 36-card Unger library.

---

## 2. Dedup Gate — Existing Unger Cards

The following 36 slugs are on record. Any candidate from this interview is checked against this set.

```
unger-larry-williams-vola-breakout
unger-orb-index
unger-bollinger-fx-meanrev
unger-inside-day-bias-dax
unger-friday-close-reversal-fx
unger-donchian-channel-tf
unger-gold-intraday-bias
unger-sp500-pivot-trend
unger-nasdaq-pullback-tf
unger-nasdaq-3pm-breakout
unger-gold-bb-breakout
unger-gold-prev-session-breakout
unger-crude-ma-crossover
unger-crude-inventory-release
unger-crude-donchian160
unger-crude-prevday-meanrev
unger-index-holiday-long
unger-sp500-eom-pullback
unger-dax-overnight-bias
unger-dax-false-break-reversal
unger-dax-gap-reversal
unger-dax-adx-low-breakout
unger-gold-session-breakout-tf
unger-gold-keltner-meanrev
unger-crude-round-number-tf
unger-nasdaq-priorclose-expansion
unger-dax-4h-high-breakout
unger-nasdaq-atr-spike-short
unger-crude-intraday-bias
unger-nasdaq-close-channel
unger-dax-bb-multiday
unger-gold-donchian-bias
unger-gold-linreg-trend
unger-dax-overnight-bias
alpha-unger-method
legend-unger-breakout
```

---

## 3. Extractability Assessment

### 3.1 Scanning for IF/THEN/EXIT structures

The interview was scanned for any statement that, together with minimal inference, could be expressed as:

> IF [measurable condition on price/indicator/time] THEN [enter long/short at price level] EXIT [when condition]

**Result: One fragment contains a partial mechanical rule. All other content is methodology commentary.**

---

### Fragment A — Indecision Day Body-to-Range Filter (partial rule)

**Verbatim source (page 6):**

> "One of my favourite patterns is actually the so-called daily factors more than 50 percent. I take the whole session of the day. I measure the total range of a daily bar and I measure the size of the body, the distance between open to close of the market. If the ratio between the body and the range is smaller than 50 percent, 0.5, normally the trend-following entries are more effective… after indecision day, we have higher possibility to get a decision in a certain direction. The extreme case is Doji, so after the Doji, you have maybe a stronger move."

**Extractable rule kernel:**

```
DEFINE indecision_day:
  body_ratio = ABS(Close[1] - Open[1]) / (High[1] - Low[1])
  indecision_day = (body_ratio < 0.50)

FILTER: if indecision_day == TRUE → bias LONG or SHORT trend entries on next session
INVERSE: if body_ratio > 0.50 → counter-trend (mean-reversion) entries are preferable
```

**What is missing for a complete card:**
- No entry trigger specified (entry level: breakout of what level? prior high/low? open?)
- No exit rule (number of bars? fixed SL/TP? end of day?)
- No symbol specified (Unger mentions DAX and E-mini S&P contextually but does not tie them to this rule)
- No timeframe specified beyond "daily bar" as the condition bar

**Completeness verdict: INCOMPLETE — filter fragment only, not a standalone strategy.**

---

### Fragment B — Time-of-Day Entry Windows (qualitative only)

**Verbatim source (page 5):**

> "From 8:00 to 10:30 or things like that in the morning, normally the entries are not very effective because the market is a little bit randomly driven… I wait until a certain moment in time and I say okay from 10:30 to for example 1 o'clock afternoon, I can enter and then I stop again for the next couple of hours… they start again considering my entries after 3:00 PM up to 5:00, 6:00 PM."

**Assessment:** Unger explicitly flags that these are illustrative examples ("These are just examples. They're not strict numbers."). The times given (10:30, 13:00, 15:00–17:00/18:00) are for the DAX. No trigger, no exit, no threshold. The concept of time-of-day windows is already present in the existing card `unger-inside-day-bias-dax`.

**Completeness verdict: INCOMPLETE — qualitative illustration, not parameterised. Covered by existing card.**

---

### Fragment C — Symmetric FX vs Asymmetric Index Entries

**Verbatim source (page 7):**

> "On index futures, I believe that the behaviour of the market is different from long to short… on index futures, I accept lack of symmetrical patterns for my long or short entries… while for example on forex currency pairs, I always look for total symmetry in the patterns because I don't see any reason why the US dollar should go up in a different way rather than down."

**Assessment:** Design principle for long/short rule symmetry — not a mechanical rule. Useful operational guidance (FX cards should mirror long/short rules; index cards may legitimately use asymmetric rules) but generates no extractable IF/THEN structure.

**Completeness verdict: METHODOLOGY — not extractable.**

---

### Fragment D — E-mini S&P Mean Reversion vs DAX Trend Following

**Verbatim source (page 2):**

> "E-mini S&P is a classical mean reverting market. DAX Future, which is still an index future is more a trend following."

**Assessment:** Market character generalisation — widely known in the literature and already implicit in the existing cards (`unger-sp500-pivot-trend`, `unger-dax-adx-low-breakout`, etc.). No mechanical rule.

**Completeness verdict: METHODOLOGY — not extractable.**

---

### Fragment E — Average Trade as Primary Robustness Metric

**Verbatim source (page 6):**

> "The first metric I look at is the average trade, so that I know how robust the trades are… if I have on the E-mini S&P 500, and I'm going to trade off $10 for example. I know that I'm going nowhere."

**Assessment:** Evaluation heuristic — average trade size must exceed expected transaction costs. This is a Q04 gate principle and is already in the pipeline. Not a strategy rule.

**Completeness verdict: METHODOLOGY — not extractable.**

---

## 4. Card Proposals

**None.**

The interview contains zero complete mechanical rules. The one rule fragment (Fragment A, Indecision Day body-to-range filter) is mechanically expressible but lacks an entry trigger, exit logic, and symbol mapping. It cannot be promoted to a strategy card without additions that are not sourced from this interview.

---

## 5. Dedup Verdicts Summary

| Fragment | Verdict | Basis |
|----------|---------|-------|
| A — Indecision Day body < 0.50 filter | INCOMPLETE — not cardable | Missing entry trigger, exit, symbol |
| B — DAX time-of-day windows | DUPLICATE (methodology) | Covered by `unger-inside-day-bias-dax`; Unger explicitly disavows the numbers as examples |
| C — FX symmetry / Index asymmetry | METHODOLOGY | No IF/THEN structure |
| D — SP500 mean-rev, DAX trend | METHODOLOGY | Widely known; already reflected in existing cards |
| E — Average trade robustness heuristic | METHODOLOGY | Pipeline evaluation principle, not a strategy rule |

---

## 6. R1–R4 Assessment (source-level)

| Criterion | Score | Notes |
|-----------|-------|-------|
| R1 — Author track record | PASS | Four-time WCTC winner; primary source author |
| R2 — Mechanical rules present | FAIL | No complete IF/THEN/EXIT rules in transcript |
| R3 — Parameter specificity | FAIL | Only one threshold mentioned (0.50 body ratio); all others are qualitative or explicitly flagged as illustrative |
| R4 — Independent evidence | N/A | No performance figures cited; no CSV/report referenced |

**Overall source verdict: DEAD — no extractable mechanical rules meeting the card proposal standard.**

---

## 7. Disposition

No strategy cards are generated from this source. The Indecision Day filter fragment (body-to-range < 0.50) is noted as a valid candidate *filter* for attachment to future mean-reversion cards (particularly on index and FX daily setups). If such a card is built from a different source that supplies the entry trigger and exit logic, this fragment from Unger may be cited as corroborating evidence for the filter gate.

The existing 36-card Unger library is not expanded by this source.

---

*End of document.*
