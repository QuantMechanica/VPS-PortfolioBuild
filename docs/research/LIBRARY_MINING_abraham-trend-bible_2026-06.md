# Library Mining: The Trend Following Bible (Abraham, 2013)

**Mined:** 2026-06-12
**Source file:** Andrew Abraham, *The Trend Following Bible* (2013), Wiley Trading
**Extraction:** Chapters 6, 7, 8 (Trend Breakout System, Trend Retracement System, parameter tables, verbatim rules)
**Author:** Andrew Abraham — principal of Abraham Trading Company; CTA with a track record dating to 1988; publishes audited performance on BarclayHedge.

---

## Source Assessment (R1–R4)

**R1 — Track record:** Abraham has an audited multi-decade CTA track record (Abraham Trading Company, ~1988–present). The book is published by Wiley Trading (major academic/practitioner press). The systems described are what Abraham himself trades. **PASS.**

**R2 — Mechanical:** Both the Trend Breakout System and the Trend Retracement System are fully algorithmic with explicit parameter values. Entry, exit, stop, and sizing rules are stated in quantitative terms. The universe filter (smoothed ROC) has a verbatim MetaStock formula. **PASS.**

**R3 — Data availability:** D1 (daily bars). Applicable to our XAUUSD.DWX, NDX.DWX, WS30.DWX, and major FX pairs. The book targets commodity futures, but the rules are parameter-specified and transferable. **PASS.**

**R4 — No ML:** All rules are fixed-parameter technical indicators. No optimization or machine learning. **PASS.**

**Backtest evidence:** The book provides NO quantified backtest results. Chapters 7 and 8 contain only hypothetical chart examples with an explicit disclaimer: "hypothetical trades have severe limitations and are used for educational purposes only." No return, drawdown, Sharpe, or win-rate statistics are reported. This materially lowers conviction but does not block card creation — the R1 CTA track record partially compensates. Cards should be treated as "rule-complete, evidence-pending" and must earn their keep at Q02–Q08.

---

## Dedup Gate

Existing cards searched for overlapping patterns:

| Pattern | Existing cards | Notes |
|---------|---------------|-------|
| `*donchian*` | 4 | Donchian channel breakout covered |
| `*turtle*20*` | 3 | 20-day breakout covered (same Donchian logic) |
| `*macd.*filter\|macd.*trend` | 11 | MACD as trend filter — used as a secondary filter elsewhere |
| `*retracement*` | 2 | Generic; neither is Abraham's two-timeframe pullback with 2-bar stop |
| `*atr.*trail\|trail.*atr` | 9 | ATR trailing stop — widely covered |
| `*roc.*rank\|rank.*roc` | 0 | Smoothed ROC universe ranking — NOT carded |
| `*elder.*force\|force.*index` | 0 | Elder Force Index as retracement oscillator — NOT carded |
| `*two.bar.*stop\|2.bar.*stop` | 0 | Two-bar stop rule — NOT carded |

Key finding: the **Trend Retracement System** is genuinely novel in the card library — no existing card implements the Elder Force Index / Oscillator Rec as a retracement detector on the lower timeframe combined with a two-bar stop entry. The **Trend Breakout System** overlaps substantially with existing 20-day Donchian / Turtle cards but has two distinguishable differences: (1) the smoothed three-period ROC universe rank as a mandatory pre-filter, and (2) the 39-period ATR trailing stop (vs. the canonical 14 or 20).

---

## System 1: Trend Breakout System — Complete Rules

### Universe Filter (pre-filter, Step 1)

Rank all candidate markets by a three-period smoothed Rate of Change on the **weekly** timeframe:

```
SmoothROC = ROC(Close, 2) + ROC(Close, 5) + ROC(Close, 7)  [all weekly bars]
             ────────────────────────────────────────────
                                    3
```

Trade only the top-N strongest (for longs) or bottom-N weakest (for shorts). "Strongest" = highest SmoothROC; "weakest" = lowest SmoothROC.

*Note: Abraham does not specify N. In our single-symbol per-EA architecture, interpret this filter as: only take a long if weekly SmoothROC > 0 (the symbol is trending up on the weekly), and only take a short if weekly SmoothROC < 0.*

### Entry (Steps 1–3)

- **Entry signal:** Buy stop at X-bar high; sell stop at X-bar low (daily bars).
  - Abraham's classic reference: X = 20 (Donchian). Parameter is explicitly stated as subjective.
  - Shorter X = more false breakouts; longer X = later entry.
- **MACD direction gate:** Only take longs when daily MACD is above zero and rising. Only take shorts when daily MACD is below zero and falling. (Standard 12/26/9 MACD; parameters not specified by Abraham, implies defaults.)
- **Risk gate:** Calculate breakout risk = (X-bar high) − (Y-bar low) in dollar terms. If this risk exceeds 1% of core equity, skip the trade.

### Stop Rules

**Initial (hard) stop:**
- Long: Y-bar low (the lookback low that defines risk). Placed immediately on fill.
- Short: X-bar high (the lookback high).
- Abraham's classic reference: Y = 10 (Donchian pair: X=20, Y=10). Parameter is subjective.

**Trailing ATR stop (replaces hard stop once trade moves in favor):**
- Calculated as: ATR(39) × multiplier (multiplier not specified by Abraham; typical range 2–3×).
- *Implementation note: Abraham states he uses "a multiple of the average true range away from the current price." He does not publish the multiplier. For the card, use 2× ATR(39) as the default — consistent with the Turtle 2N convention and the risk budget.*
- The trailing stop moves in favor of the position; it never moves against it.
- Switch from hard stop to ATR trailing stop when the ATR stop becomes tighter than the hard stop.

### Position Sizing (Abraham's rule)

Risk 1% of core equity per trade, sized by the hard stop distance:

```
Units = (0.01 × Account) / (Entry − Hard Stop)
```

### Portfolio-Level Rules

These are portfolio-management rules; not directly implementable in a single-EA MT5 strategy but documented for completeness:

| Rule | Value |
|------|-------|
| Max long positions | 10 |
| Max short positions | 10 |
| Max sector exposure (risk) | 5% of portfolio |
| Max open trade equity vs core equity | 20% |
| Max dollar risk per futures contract | $2,500 (commodity futures specific) |

---

## System 2: Trend Retracement System — Complete Rules

Abraham's retracement system is a multi-timeframe pullback system. It uses the same seven pre-trade filters as the breakout system (MACD direction, risk %, sector limits, etc.) but replaces the Donchian breakout entry with a two-timeframe pullback pattern.

### Step 1 — Higher Timeframe Trend

Identify trend direction on the **weekly** timeframe using either:
- Weekly MACD position vs zero line (above = uptrend; below = downtrend), or
- 20-period EMA slope on weekly bars.

*For our infrastructure (daily-bar EAs): compute both MACD and EMA on weekly bars synthesized from daily data, or load the weekly timeframe directly using MT5's PERIOD_W1.*

### Step 2 — Entry Timeframe Retracement Signal

On the **daily** timeframe, wait for the **Elder Force Index** (Abraham calls it "Oscillator Rec" or "Retracement Osc") to cross the zero line in the opposite direction from the higher-timeframe trend:

- **Long setup:** Weekly MACD above zero (uptrend). Daily Elder Force Index crosses **below** zero (pullback confirmed).
- **Short setup:** Weekly MACD below zero (downtrend). Daily Elder Force Index crosses **above** zero (pull-up confirmed).

**Elder Force Index formula (for reference):**

```
Elder Force Index(1) = Volume × (Close_today − Close_yesterday)
EFI_EMA = EMA(EFI(1), period)   [period typically 2 or 13; Abraham uses a smoothed version]
```

*Note: Abraham refers to this as "Oscillator Rec" which appears to be a proprietary MetaStock version of the Elder Force Index. The standard Elder Force Index uses EMA smoothing. In MT5, implement as: EFI = EMA(Volume × (Close − Close[1]), 2) or EMA(same, 13). The zero-crossing is the signal; the exact smoothing period affects sensitivity but not the logic.*

### Step 3 — Entry Execution

Once the retracement oscillator has crossed the zero line (Step 2 confirmed), place a **stop order** at 0.001% (one tick equivalent) beyond the **prior two-bar extreme**:

- **Long:** Place buy stop at `High[1]` or `High[2]` (whichever is higher) + 0.001%.
  - Update the buy stop on each new bar: recalculate two-bar high.
  - Cancel the buy stop if the weekly MACD turns negative.
  - Enter on fill.
- **Short:** Place sell stop at `Low[1]` or `Low[2]` (whichever is lower) − 0.001%.
  - Update the sell stop on each new bar: recalculate two-bar low.
  - Cancel the sell stop if the weekly MACD turns positive.
  - Enter on fill.

### Stop Rules for Retracement

**Initial (hard) stop:**
- Long: One tick below the two-bar low at entry (`Low[1]` and `Low[2]` whichever is lower − 0.001%).
- Short: One tick above the two-bar high at entry.
- Hard stop remains in place until the ATR trailing stop becomes tighter.

**Trailing ATR stop:** Same as Breakout System — ATR(39) × 2 (default multiplier), trailing in favor.

**Position sizing:**

```
Units = (0.01 × Account) / (Entry − Hard Stop)
```

*Example from book: Account $100,000, entry $52.10, two-bar low $50.00 → hard stop $49.95 → risk per share = $2.15 → units = 465.*

### Cancellation Rule

An open buy stop (waiting for retracement fill) is cancelled if the weekly MACD reverses to negative before the stop is filled. An open sell stop is cancelled if the weekly MACD reverses to positive.

---

## Parameter Summary

| Parameter | Breakout System | Retracement System |
|-----------|----------------|-------------------|
| Entry lookback (high/buy) | X days; default 20 | N/A (stop order above 2-bar high) |
| Entry lookback (low/stop) | Y days; default 10 | 2-bar low/high for hard stop |
| Universe filter | Weekly SmoothROC (periods 2, 5, 7) | Same |
| Trend filter | Daily MACD > 0 (long) or < 0 (short) | Weekly MACD > 0 or < 0 |
| Retracement oscillator | Not used | Elder Force Index (daily), zero-cross |
| Entry offset | Breakout of X-day high/low | 2-bar extreme + 0.001% |
| ATR period (trailing stop) | 39 | 39 |
| ATR multiplier | 2× (Abraham unspecified; default) | 2× (same) |
| Hard stop (initial) | Y-day low for longs | 2-bar low for longs |
| Risk per trade | 1% of core equity | 1% of core equity |

---

## Dedup Verdicts

| Item | Verdict | Reasoning |
|------|---------|-----------|
| Trend Breakout System core (X-day high entry, Y-day exit) | DUPLICATE | Fully covered by QM5_10272, QM5_11781, QM5_11879 (20-day Turtle variants) |
| Smoothed ROC three-period weekly universe rank | NEW filter | Not present in any existing card as a standalone entry gate |
| MACD zero-line direction filter on entry timeframe | DUPLICATE filter | Used as secondary filter in existing cards; not novel alone |
| ATR(39) trailing stop (vs standard ATR(14) or ATR(20)) | VARIANT | Period difference is meaningful — 39 is ~2.7× slower than Wilder(14); worth parameterizing |
| Trend Retracement System (Elder Force Index + two-bar stop + weekly MACD) | NEW | No existing card implements this multi-timeframe pullback structure |
| Two-bar stop rule | NEW | Not carded anywhere; the 2-bar lookback for hard stop placement is a distinct risk element |

---

## Card Proposals

---

### Proposal 1: `abraham-trend-retracement-d1-w1` (NEW)

**Dedup verdict:** NEW. No existing card combines Elder Force Index zero-cross on D1 with weekly MACD trend filter and two-bar stop entry. The closest cards (generic MACD pullback variants) do not use Elder Force Index and do not have the two-bar stop or the weekly MACD cancellation rule.

**Priority:** HIGH. This is the most distinctive Abraham system. It is the only proposal here with no structural duplicate in the card library.

```yaml
slug: abraham-trend-retracement-d1-w1
source: "Abraham, A. (2013). The Trend Following Bible. Wiley Trading."
source_citation: "Abraham (2013), Chapter 8 — Trading the Trend: Retracements, pp. 120–145"
edge_type: trend_pullback
period: D1
higher_tf: W1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, USDJPY.DWX, XAUUSD.DWX, NDX.DWX]
expected_trades_per_year_per_symbol: 8-15
```

**Entry rules:**

1. Weekly MACD (standard 12/26/9, computed on W1 bars): must be above zero and rising for longs; below zero and falling for shorts.
2. Daily Elder Force Index (EFI) confirmation:
   - Long: Daily EFI crosses below zero (pullback detected).
   - Short: Daily EFI crosses above zero (pull-up detected).
   - EFI = EMA(Volume × (Close − Close[1]), 2) or EMA(same, 13).
3. Place stop order: buy stop at `max(High[1], High[2]) × 1.00001` for longs; sell stop at `min(Low[1], Low[2]) × 0.99999` for shorts.
4. Update stop every bar until filled or weekly MACD reverses.
5. Cancel stop order if weekly MACD reverses before fill.

**Stop loss:**

- Hard stop (placed on fill): `min(Low[1], Low[2]) × 0.99999` for longs; `max(High[1], High[2]) × 1.00001` for shorts.
- ATR(39) trailing stop replaces hard stop once in profit; trail by 2× ATR(39).

**Position sizing:**

```
Lots = (Account × 0.01) / (|Entry − Hard Stop| × TickValue / TickSize)
```

**Exit:**

- Primary: ATR(39) trailing stop hit.
- Secondary: Weekly MACD reversal (cross below zero for longs; above zero for shorts) closes the position.

**Builder notes:**

- Elder Force Index requires volume. MT5 tick volume is available on FX pairs. Use `iVolume(symbol, PERIOD_D1, ...)` for the volume series.
- Weekly MACD must be loaded from PERIOD_W1 explicitly (do not synthesize from daily data).
- The 2-bar lookback for the stop order means: bar index [1] and [2] from the current bar (yesterday and day before yesterday), not the current incomplete bar.
- ATR(39) is significantly slower than the standard ATR(14). It will hold positions through normal volatility. Builder should verify that the ATR trailing stop actually moves before ATR(14)-based stops would be reached.
- Abraham does not specify an ATR multiplier. Use 2.0 as default; expose as an EA parameter `ATR_Multiplier` with range 1.5–3.0 for sensitivity testing.

---

### Proposal 2: `abraham-breakout-atr39-trail-d1` (VARIANT)

**Dedup verdict:** VARIANT. The entry logic (20-day Donchian breakout, 10-day exit) is a duplicate of existing cards. The differentiating element is the **ATR(39) trailing stop** combined with the **smoothed weekly ROC universe filter**. The combination is not carded. This card tests whether Abraham's slower ATR period and ROC pre-filter improve performance on the existing breakout skeleton.

**Priority:** MEDIUM. Justified as a controlled variant only if QM5_11781 (canonical System 1 D1) passes Q04. If the base breakout fails at cost-adjusted walk-forward, this variant is unlikely to rescue it. Hold until base card clears Q04.

```yaml
slug: abraham-breakout-atr39-trail-d1
source: "Abraham, A. (2013). The Trend Following Bible. Wiley Trading."
source_citation: "Abraham (2013), Chapter 6–7 — The Complete Robust Trading Plan, pp. 95–115"
edge_type: trend
period: D1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX, WS30.DWX]
expected_trades_per_year_per_symbol: 10-20
```

**Entry rules:**

1. Weekly Smoothed ROC gate (computed on W1 bars):
   - `SmoothROC = (ROC(Close, 2) + ROC(Close, 5) + ROC(Close, 7)) / 3`
   - Long entries: SmoothROC > 0 only.
   - Short entries: SmoothROC < 0 only.
2. Daily MACD direction gate: above zero for longs; below zero for shorts.
3. Entry: price breaks above 20-day high (long) or below 20-day low (short) on daily bar close.

**Stop loss:**

- Initial hard stop: 10-day low for longs; 10-day high for shorts. Placed on fill.
- ATR(39) trailing stop: replaces hard stop when it becomes tighter. Trail at 2× ATR(39).

**Exit:**

- ATR(39) trailing stop.
- No time-based or MACD-reversal exit (entry MACD filter is one-way; does not generate exit signals).

**Builder notes:**

- Weekly SmoothROC requires PERIOD_W1 data. Compute ROC as: `(Close_W1[0] - Close_W1[n]) / Close_W1[n] × 100`.
- ROC periods 2, 5, 7 on W1 = lookback of 2, 5, and 7 weekly bars respectively.
- The key difference from QM5_11781 is the ROC pre-filter (weekly directional bias) and the ATR(39) vs ATR(14) or 10-day-exit trailing stop. Tag these differences prominently in the SPEC.md.
- Expose `ATR_Period` (default 39), `ATR_Multiplier` (default 2.0), `Breakout_Bars` (default 20), and `Stop_Bars` (default 10) as EA parameters.

---

## Proposals Not Made

| Item | Reason Excluded |
|------|----------------|
| Portfolio-level rules (max 10 longs/shorts, 5% sector, 20% open equity, $2,500 max contract risk) | Portfolio construction rules — belong in Q11 portfolio layer, not in a single-EA card. Not actionable at EA level in MT5. |
| MACD direction filter as standalone card | Duplicate — already used as a filter in multiple existing MACD-family cards. Not novel. |
| Risk sizing formula (1% of equity / stop distance) | Standard percent-risk sizing — already implemented in the framework as RISK_PERCENT mode. Not a card-worthy proposal. |
| S&P 500 200-day EMA stock filter (long only above, short-biased below) | Stocks-universe only; not applicable to DWX FX/index universe. |

---

## Recommendation

**Priority 1:** Build `abraham-trend-retracement-d1-w1`. It is the only genuinely novel system from this book and the most mechanically distinct from anything currently in the library. If the Elder Force Index is unavailable as a built-in MT5 indicator, it must be coded from first principles (see formula above) — straightforward given that it requires only volume and close prices.

**Priority 2:** Hold `abraham-breakout-atr39-trail-d1` until the base 20-day breakout family (QM5_11781 et al.) shows positive Q04 results. The ROC filter and ATR(39) stop are not expected to rescue a structurally unprofitable breakout; they are refinements that add value on top of a proven base.
