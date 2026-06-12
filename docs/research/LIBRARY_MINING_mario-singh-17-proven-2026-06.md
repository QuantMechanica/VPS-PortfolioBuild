# Library Mining — Mario Singh: 17 Proven Currency Trading Strategies (2013)

**Mined:** 2026-06-12  
**Task:** 7143e208-5a5c-4c0a-a142-e168b25bedf7  
**Source file:** `C:/Users/Administrator/Downloads/17 Proven Currency Trading Strategies - How to Profit in the Forex Market 2013.pdf`  
**Extraction:** `D:/QM/strategy_farm/source_cache/singh-17-proven-strategies.txt` (422,151 bytes, 274 pages)  
**Author:** Mario Singh — professional trader, educator, founder of First Class Forex Funds; John Wiley & Sons 2013.

---

## Source Assessment (R1–R4)

**R1 — Track record:** Singh is a professional FX educator; book published by Wiley. Track record evidence for individual strategies is limited — Singh presents hypothetical backtests and conceptual performance. Some strategies are industry-standard (EMA crossovers, Bollinger Bands); others are Singh originals. Treat as medium-R1 source (educator/practitioner, not academic study). **PARTIAL PASS.**

**R2 — Mechanical:** Strategies vary. Most H1/H4 trend strategies are fully mechanical. Scalp and news-dependent strategies are partially discretionary. **PASS** for strategies 7–9, 13, 16.

**R3 — Data available:** FX pairs and select indices/metals on .DWX infrastructure. **PASS.**

**R4 — No ML:** Fixed indicator rules throughout. **PASS.**

---

## All 17 Strategies: Systematic Review

### Strategies 1–6: Scalp / Fundamental / Intraday (SKIP / NOT MECHANICAL)

| # | Name | TF | Verdict | Reason |
|---|------|----|---------|--------|
| 1 | 3-10-1 Short-Term Scalp | M1/M5 | SKIP | TF too short; scalp-only; ~200+ trades/day per symbol |
| 2 | JLTP Low High Scalp | M5/M15 | SKIP | Requires realtime pivot identification; scalp |
| 3 | IFTTT (If-This-Then-That) | M1 | SKIP | Correlated pair entry using tick-correlation; HFT-adjacent |
| 4 | The Daily Dose | H1/H4 | BORDERLINE | Stochastic(14,3) + price near daily high/low; mostly mechanical but subjective "significant level" identification; see note |
| 5 | The Big Picture | D1 | NOT MECHANICAL | News event anticipation + fundamental bias; no indicator triggers |
| 6 | Just the Facts | D1/W1 | NOT MECHANICAL | Fundamental macroeconomic analysis; no price trigger |

**Note on Strategy 4 (Daily Dose):** The rule is: "When Stochastic(14,3) crosses from oversold territory (< 20) in an established daily uptrend, enter long." The "established daily uptrend" requires a discretionary judgment call on the D1 chart. If the trend condition is replaced with a mechanical filter (e.g., price above EMA(50) on D1), this becomes mechanical. Flagged as candidate for future mechanization — low priority given existing stochastic card coverage.

---

### Strategy 7: Trend Rider — EMA 12/36 + ADX(14) > 40 (H1/H4 Swing)

**Mechanism:**
- Trend filter: ADX(14) > 40 (strong trend present)
- Direction: EMA(12) crosses above EMA(36) → bullish bias; EMA(12) crosses below EMA(36) → bearish bias
- Entry: On the first pullback to EMA(12) after the crossover, confirmed by ADX still > 40
- Stop: Below EMA(36) (long) or above EMA(36) (short)
- Exit: Crossover in opposite direction, or trailing stop at EMA(12)
- Timeframe: H1 or H4
- Symbols: Any liquid FX pair

**Dedup search:** `EMA.*12.*36 | ema12.*36 | trend.rider` → 0 existing cards  
**Verdict: NEW** — No EMA(12/36) crossover card exists. ADX>40 threshold (not >25) makes this a high-strength-trend filter variant.

---

### Strategy 8: Trend Bouncer — BB(12, Dev2) / BB(12, Dev4) Double Band (H4 Mean-Reversion)

**Mechanism:**
- Two Bollinger Bands on same MA(12): BB(12, 2σ) inner + BB(12, 4σ) outer
- Long setup: Price touches or closes below BB(12, 4σ) lower band, then next bar closes back above BB(12, 2σ) lower band → long
- Short setup: Price touches or closes above BB(12, 4σ) upper band, then next bar closes back below BB(12, 2σ) upper band → short
- Stop: Below/above the BB(12, 4σ) extreme that triggered the signal
- Target: BB(12, 0σ) midline (the MA(12) itself)
- Timeframe: H4 (also viable on H1)

**Dedup search — existing double-BB cards:**

| Card | Setup |
|------|-------|
| QM5_11476 `lien-k-double-bb-trend-h1` | Kathy Lien: MA(20, 1σ) + MA(20, 2σ); trend-following (enter on BB1 breakout with BB2 as target) |
| QM5_11887 `lien-double-bollinger-bands-regime` | Kathy Lien: MA(20, 2σ) regime + pullback entry; H4 trend |
| QM5_11889 `lien-xtreme-fade-double-bb-adx` | Kathy Lien: MA(20, 3σ) + MA(20, 2σ); ADX<25; M15 fade |

**Verdict: VARIANT** — Singh uses period 12 (vs Lien's 20) and Dev4 outer band (vs Lien's 3σ max). The 4σ outer band is extreme (~99.994% of returns within it) — a much rarer trigger than Lien's 3σ. Different MA period + Dev4 = meaningfully distinct parameterization.

---

### Strategy 9: Fifth Element — MACD 5 Consecutive Histogram Bars (H1/H4)

**Mechanism:**
- MACD with standard parameters (12, 26, 9) or Singh's preferred (5, 26, 9) variant
- Trigger: 5 consecutive MACD histogram bars all in the same direction (all positive or all negative) and each bar larger in absolute value than the previous
- Long: 5 consecutive growing positive histogram bars → long at next bar open
- Short: 5 consecutive growing negative histogram bars → short at next bar open
- Stop: ATR(14) × 1.5 below/above entry
- Exit: When histogram reverses direction (first bar smaller than previous, or sign change)
- Timeframe: H1 or H4

**Dedup search — existing MACD histogram cards:**

| Card | Mechanism |
|------|-----------|
| QM5_1260 `hopwood-macd-hist-zero-h1` | MACD histogram zero-line cross |
| QM5_1911 `elder-macd-histogram-hook-h4` | Elder's hook: first reversal bar in established MACD histogram direction |

**Verdict: VARIANT** — Neither existing card uses the "5 consecutive growing bars" momentum continuation rule. Elder's hook is a reversal trigger; Hopwood's zero-cross is a trend change. Singh's Fifth Element is a momentum acceleration entry (continuation). Sufficiently distinct.

---

### Strategy 10: Power Ranger — Stochastic + Trendline (H1/H4)

**Mechanism:** Enter long when price bounces off an ascending trendline and Stochastic(14,3) turns up from oversold. Requires manual trendline drawing.

**Verdict: SKIP** — Trendline drawing is discretionary and not MT5-backtestable via standard indicators. Cannot produce a mechanical card.

---

### Strategy 11: The Pendulum — Support/Resistance Range (H1/H4)

**Mechanism:** Identify horizontal S/R levels visually; enter mean-reversion trades when price reaches the extremes.

**Verdict: SKIP** — Range identification is discretionary.

---

### Strategy 12: Swap and Fly — Three White Soldiers/Crows + Positive Carry (D1/W1)

**Mechanism:** Three white soldiers candlestick pattern + positive overnight swap (carry trade component). Enter long on currency pair with highest positive swap.

**Verdict: SKIP** — On .DWX backtest symbols, swap = $0 (hard rule: no invented swap values). The carry component is the differentiating feature; without it this is a generic three-white-soldiers pattern already partially covered by `QM5_10620_mql5-crows-rsi.md`.

---

### Strategy 13: Commodity Correlation — Oil → CAD, Gold → USD (D1)

**Mechanism:**
- **Oil-CAD link:** WTI crude oil 20-day ROC > 0 → AUD/CAD or CAD/JPY long (CAD strengthens when oil rises); ROC < 0 → short
- **Gold-USD link:** Gold 20-day ROC > 0 → bearish USD bias (EUR/USD, GBP/USD, AUD/USD long); ROC < 0 → USD strengthening, fade
- Entry: When commodity ROC signal aligns with currency pair bar close direction, enter at next open
- Stop: ATR(14) × 2 on the currency pair
- Exit: When commodity ROC signal reverses (crosses zero)
- Timeframe: D1

**Dedup search:** `commodity.*corr | oil.*cad | cad.*oil | gold.*dxy` → 0 existing cards  
**Verdict: NEW** — Zero commodity-driven cross-asset correlation cards. This is a multi-instrument signal (USOIL.DWX or XTIUSD price ROC triggering FX entries).

**Implementation note:** Requires MT5 multi-symbol data access — the EA must read USOIL/XAUUSD price data to generate signals for the FX/CAD pair. Feasible in MQL5 using `CopyRates()` with non-chart symbol. Flag for builder: USOIL.DWX availability on factory terminals must be verified.

---

### Strategy 14: Siamese Twins — China Economic Data → AUD (D1)

**Mechanism:** When China manufacturing PMI or trade data releases surprise positively → buy AUD pairs (AUD/USD, AUD/JPY). Fundamental trigger.

**Verdict: SKIP** — Fundamental/news-based. Not mechanical in the backtest sense. No MT5 indicator can operationalize "China PMI surprise."

---

### Strategy 15: Guppy Burst — GBP/JPY M5 Range Breakout

**Mechanism:** Define the 3-hour range for GBP/JPY in the hours after US close (~22:00–01:00 broker time); trade breakout of that range on M5.

**Verdict: BORDERLINE / SKIP** — M5 timeframe is at the edge of our pipeline's practical range. GBP/JPY is highly volatile and spread-sensitive at M5. The strategy would generate hundreds of signals per year but requires M5 tick data precision and low-spread execution. The DXZ/FTMO "no HFT" constraint does not specifically ban M5, but the practical slippage and spread cost on GBP/JPY M5 at .DWX (typically 3–5 pips) would erode most of the edge. **Flag for later evaluation with actual M5 cost data — not a priority now.**

---

### Strategy 16: English Breakfast Tea — GBP/USD M15 Session Directional Bias

**Mechanism:**
- At **04:15 broker time** (approx. Asian session midpoint): record the direction of the current M15 candle (bullish or bearish)
- At **08:15 broker time** (approx. London pre-open): record the direction of the current M15 candle
- If both candles are in the **same direction**: take a position in that direction at the 08:30 broker-time bar open (London session open)
- If candles are in **opposite directions**: no trade (conflicting bias)
- Stop: Below/above the 08:15 reference candle low/high
- Exit: Fixed 30-pip target or 17:00 broker-time EOD close

**Dedup search — London open / breakfast cards:**

| Card | Mechanism |
|------|-----------|
| QM5_11410 `london-free-breakfast-asian-range-breakout-m15` | Asian session range box → London breakout |
| QM5_11450 `london-breakfast-asian-range-m15` | Asian range high/low → M15 breakout |
| QM5_11749 `london-breakfast-asia-box-breakout` | Same family |

**Verdict: VARIANT** — All 3 existing London breakfast cards are Asian range-box breakouts (high/low of the Asian session). Singh Strategy 16 uses a **directional bias comparison** (agreement of two specific candles at 04:15 and 08:15) rather than an Asian range extremes breakout. The mechanism is genuinely different — it's a candle-direction correlation signal, not a range boundary breakout.

**Implementation note:** Broker time reference is critical. Times are Singh's — verify against DXZ broker time convention (GMT+2 outside US DST, GMT+3 during US DST). The 04:15 and 08:15 times are stated as broker local time and must be adjusted for DST transitions.

---

### Strategy 17: Good Morning Asia — USD/JPY D1 Direction

**Verdict: DUPLICATE ×4** — Fully covered by 4 existing Good Morning Asia cards in `cards_approved/`. No action needed.

---

## Summary Dedup Table

| Strategy | Verdict | Proposal slug |
|----------|---------|---------------|
| 1–3 (scalp/correlation) | SKIP | — |
| 4 (Daily Dose) | BORDERLINE | Possible future mechanization |
| 5–6 (fundamental) | SKIP (not mechanical) | — |
| 7 Trend Rider | NEW | `singh-trend-rider-ema1236-adx40-h1` |
| 8 Trend Bouncer | VARIANT | `singh-trend-bouncer-bb12-dev4-h4` |
| 9 Fifth Element | VARIANT | `singh-fifth-element-macd5bar-h1` |
| 10 Power Ranger | SKIP (discretionary) | — |
| 11 The Pendulum | SKIP (discretionary) | — |
| 12 Swap and Fly | SKIP (.DWX swap=$0) | — |
| 13 Commodity Correlation | NEW | `singh-commodity-correlation-oil-cad-d1` |
| 14 Siamese Twins | SKIP (fundamental) | — |
| 15 Guppy Burst | BORDERLINE | Flag for M5 cost review |
| 16 English Breakfast Tea | VARIANT | `singh-english-breakfast-gbpusd-m15` |
| 17 Good Morning Asia | DUPLICATE ×4 | — |

---

## Card Proposals (4 total)

### Proposal 1: `singh-trend-rider-ema1236-adx40-h1` (NEW)

```yaml
slug: singh-trend-rider-ema1236-adx40-h1
source: "Singh, M. (2013). 17 Proven Currency Trading Strategies. Wiley."
source_citation: "Singh (2013), Chapter 9 — The Trend Rider, pp. ~105–122"
edge_type: trend
period: H1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX]
expected_trades_per_year_per_symbol: 25
```

**Entry:** ADX(14) > 40 confirmed. EMA(12) crosses above EMA(36) → long; EMA(12) crosses below EMA(36) → short. Enter on first pullback bar that touches EMA(12) after crossover with ADX still > 40.  
**Stop:** EMA(36) level at time of entry.  
**Exit:** Opposite EMA crossover or ADX(14) drops below 25.

---

### Proposal 2: `singh-trend-bouncer-bb12-dev4-h4` (VARIANT of QM5_11889)

```yaml
slug: singh-trend-bouncer-bb12-dev4-h4
source: "Singh, M. (2013). 17 Proven Currency Trading Strategies. Wiley."
source_citation: "Singh (2013), Chapter 10 — The Trend Bouncer, pp. ~123–140"
edge_type: mean-reversion
period: H4
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX]
expected_trades_per_year_per_symbol: 20
```

**Entry (long):** Price bar closes below BB(12, 4σ) lower band. Next bar closes back above BB(12, 2σ) lower band → long at close of that bar.  
**Entry (short):** Mirror: close above BB(12, 4σ) upper, next bar close below BB(12, 2σ) upper → short.  
**Stop:** 1 ATR(14) beyond the BB(12, 4σ) band that was touched.  
**Target:** BB(12, 0σ) = MA(12) midline.

---

### Proposal 3: `singh-fifth-element-macd5bar-h1` (VARIANT of QM5_1911)

```yaml
slug: singh-fifth-element-macd5bar-h1
source: "Singh, M. (2013). 17 Proven Currency Trading Strategies. Wiley."
source_citation: "Singh (2013), Chapter 11 — The Fifth Element, pp. ~141–160"
edge_type: trend
period: H1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX]
expected_trades_per_year_per_symbol: 35
```

**Entry:** MACD(12,26,9) histogram: 5 consecutive bars all in the same direction with each bar having absolute value ≥ the previous bar → enter long (if all positive) or short (if all negative) at next bar open.  
**Stop:** ATR(14) × 1.5 from entry.  
**Exit:** First histogram bar that is smaller in absolute value than its predecessor (momentum decay), or histogram sign change.

---

### Proposal 4: `singh-commodity-correlation-oil-cad-d1` (NEW)

```yaml
slug: singh-commodity-correlation-oil-cad-d1
source: "Singh, M. (2013). 17 Proven Currency Trading Strategies. Wiley."
source_citation: "Singh (2013), Chapter 14 — Commodity Correlations, pp. ~185–200"
edge_type: trend
period: D1
target_symbols: [CADJPY.DWX, AUDUSD.DWX, EURUSD.DWX]
expected_trades_per_year_per_symbol: 15
```

**Signal symbols (multi-instrument):** USOIL.DWX (for CAD link) and XAUUSD.DWX (for USD link)

**Rules (Oil-CAD pair example):**
- Compute USOIL ROC(20) = `(Close[0] - Close[20]) / Close[20]`
- If ROC(20) > 0 AND CADJPY bar closes bullish → long CADJPY
- If ROC(20) < 0 AND CADJPY bar closes bearish → short CADJPY
- Stop: ATR(14) × 2 on CADJPY
- Exit: USOIL ROC(20) crosses from positive to negative (or reverse)

**Builder note:** EA must call `CopyRates("USOIL.DWX", ...)` to access commodity data. Verify USOIL.DWX availability and commission model on factory terminals before building. If USOIL.DWX is not available, XTIUSD.DWX may be the correct symbol — check broker symbol registry.

---

### Borderline: Strategy 16 English Breakfast Tea (VARIANT)

This strategy is cardable but requires verifying the broker-time reference (04:15 and 08:15 broker local time vs. GMT). Once times are confirmed against DXZ broker time model, this becomes a clean M15 GBP/USD session-filter card with a novel mechanism (directional agreement, not range breakout). Recommend as a follow-on card after the four proposals above.

---

## Recommendation

Priority order: Proposal 1 (Trend Rider) > Proposal 3 (Fifth Element) > Proposal 2 (Trend Bouncer) > Proposal 4 (Commodity Correlation). Commodity Correlation has highest novelty but requires infrastructure verification (USOIL.DWX availability).
