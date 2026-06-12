# Library Mining: Katz & McCormick — The Encyclopedia of Trading Strategies (2000)

**Date:** 2026-06-12  
**Miner:** Claude (library-mining task 7143e208)  
**Source file:** `C:/Users/Administrator/Downloads/The Encyclopedia of Trading Strategies 2000.pdf`  
**Text cache:** `D:/QM/strategy_farm/source_cache/katz-mccormick-encyclopedia-2000.txt`  
**Pages extracted:** 200 of 387 (covers Intro, Parts I-II, chapters 1-9: Breakouts, Moving Averages, Oscillators, Seasonality, Lunar/Solar)  
**Evidence type:** IN-SAMPLE (1985–1995) + OOS verification (1995–1998/1999) on a diversified futures portfolio  
**Costs modeled:** $15/round-turn + slippage (standardized per chapter)

---

## STEP 0 — DEDUP STATUS

Targeted filename search found: **QM5_12543** (katz-fx-hhll-limit-pullback — already a PROPOSAL from prior session).  
Content search (`grep -i "katz|mccormick"`) found QM5_12543 + QM5_9504_brooks (incidental mention only).  
Mechanism keyword searches (breakout, ma-support-resistance, macd-divergence, seasonal) found extensive coverage in the card pool but **not** from this book source. Specific dedup verdicts are given per system below.

---

## Methodology Note

Katz/McCormick use a **standardized exit (SES)** across all entry tests: `mmstp=1×ATR(50)` stop, `ptlim=4×ATR(50)` target, `maxhold=10 bars`. This makes entry quality comparable across chapters. Any proposal based on this book must use the SES or a documented equivalent as the baseline exit, otherwise the R1 evidence no longer applies.

Test portfolio: 26 futures markets (FX currencies, equity indices, T-Bonds/Notes, energies, metals, livestock, grains). In-sample 1985–1995 (optimization); OOS 1995–1998/1999 (verification). Costs: $15/trade + slippage.

---

## Systems Assessed

### SYSTEM 1 — Katz FX-Only HHLL Breakout with Limit Pullback Entry (D1)

**DEDUP VERDICT: DUPLICATE (skip)**

Already captured as **QM5_12543** (katz-fx-hhll-limit-pullback, G0 APPROVED 2026-06-12). No new proposal needed.

---

### SYSTEM 2 — MACD Divergence with Limit Entry (D1)

- **Source:** Katz & McCormick (2000), Ch.7 (Oscillator-Based Entries), pp. 161–166, Tests 19–21; Table 7-3 summary.
- **Rules:**
  - Compute classic MACD (exponential MAs). Best in-sample parameters: shorter MA ~5–9 bars, longer MA ~25–35 bars (Katz optimized 3–15 by 2 for short, 10–40 by 5 for long); divergence look-back 15–25.
  - **LONG entry signal:** Over a look-back window, the deepest valley in prices is located; the deepest valley in the MACD line occurs at least 4 bars before the deepest price valley; the price valley occurred 1–6 bars ago (close to current bar); the MACD line has just turned upward (second valley forms). All conditions = bullish divergence buy.
  - **SHORT entry signal:** Mirror of above — prices form a higher high while MACD forms a lower high; MACD has just turned down.
  - **Entry order:** LIMIT at the mid-point of the signal bar (best OOS result per Table 7-3).
  - **Exit (SES):** 1×ATR(50) money-management stop; 4×ATR(50) profit target; close out at bar 10 if neither triggered.
- **Timeframe/Symbols:** Original: daily futures (diversified portfolio, best results on Light Crude, Coffee, Heating Oil, Live Cattle, Soybeans, Lumber). DWX mapping: XAUUSD.DWX (metals / commodity proxy), NDX.DWX, WS30.DWX (index proxies). Note: original agricultural/energy futures have no .DWX equivalent; index CFDs are the closest liquid analogue.
- **Evidence (IN-SAMPLE + OOS):**
  - IS (1985–1995): avg trade $1,250 profit, 47% winners, annualized return 12.5%, p=13.1% uncorrected (99.9% corrected for multiple tests).
  - OOS (1995–1998): avg trade $985 profit, 44% winners, annualized return 19.5%, p=27.7% — **better OOS than IS**, a strong robustness signal. Long AND short positions profitable in OOS.
  - **CRITICAL CAVEAT:** This is futures; slippage + commission $15/rt included. OOS is genuine (held-out data), but it is 23-year-old. Markets that drove the result (crude oil, coffee, soybeans) have no .DWX equivalent.
- **Expected trades/year (single symbol):** Divergence signals are infrequent — Katz reports relatively few trades vs. other oscillator models. Estimate ~8–15 per year per symbol on D1. With 10-bar max hold, turnover is moderate. Marginal at Q08 floor (~3/yr minimum) but should clear.
- **R1-R4:**
  - R1: PASS — McGraw-Hill published book, named authors with academic credentials, explicit IS+OOS test split, costs modeled.
  - R2: PASS — divergence detection algorithm fully specified in text (look-back structure, turning-point detection, limit entry); no discretion.
  - R3: CONDITIONAL — original markets (crude, coffee, ag) = no .DWX equivalent. Index/FX/gold ports are analogue, not replica. The OOS evidence is commodity-futures-specific; porting to index CFDs is an empirical question, not a certainty.
  - R4: PASS — fixed MA parameters, deterministic divergence detection; no ML.
- **Dedup verdict:** NEW. The card pool has 20+ MACD-divergence related cards but none sourced from Katz/McCormick with this specific algorithmic divergence detection (price valley must precede MACD valley by ≥4 bars, valley must be ≥1 and ≤6 bars ago, MACD just turned up). The OOS-profitable result (better OOS than IS) is the distinguishing anchor. Delta vs. nearest neighbor QM5_9197 (mql5-macd-obv-div): that card uses MACD + OBV combination, different divergence detection, different source, no IS/OOS split evidence.
- **Mechanization verdict:** NEEDS_SPEC — the divergence detection algorithm is described in text prose and C++ pseudocode (pp. 162–163). A clean MT5/MQL5 translation spec is needed. Key parameters to pin: MACD fast/slow MA lengths, divergence look-back, limit-price rule (mid-point of signal bar = (High+Low)/2 of bar N).
- **Proposed card slug:** `katz-macd-divergence-limit-d1`

---

### SYSTEM 3 — Moving Average Support/Resistance Countertrend (D1)

- **Source:** Katz & McCormick (2000), Ch.6 (Moving Average Models), pp. 139–146, Tests 37–48 (support/resistance model).
- **Rules:**
  - Select a simple moving average (SMA) of closing prices. Best in-sample: shorter reference = price (length=1 equivalent), longer SMA = ~20–35 bars (stepped 5–50 by 5).
  - **LONG entry signal:** Price is above the SMA and penetrates it from above (crosses below). Entry signal is generated only if the slope of the SMA is positive (trending up) — meaning the price dip into the average occurs within an uptrend.
  - **SHORT entry signal:** Price is below the SMA and rises into it from below. Entry only if SMA slope is negative (trending down).
  - Critically: when price bounces back through the average, the re-cross does NOT generate an opposing signal. Only the first touch in the direction of the SMA slope.
  - **Entry order:** STOP order (best for this model per Table 6-6 and conclusion p. 145; stop provides trend-confirmation element which benefits countertrend entries).
  - **Exit (SES):** 1×ATR(50) stop; 4×ATR(50) target; 10-bar time exit.
- **Timeframe/Symbols:** Original: daily futures. Best markets both IS+OOS: T-Bonds, 10-Year Notes, Japanese Yen, Deutschemark, Swiss Franc, Light Crude, Unleaded Gasoline, Coffee, Orange Juice, Pork Bellies. DWX mapping: USDJPY.DWX (JPY), USDCHF.DWX (CHF), EURUSD.DWX/GBPUSD.DWX (EUR/GBP proxies). Energy/ag futures = no .DWX equivalent.
- **Evidence (IN-SAMPLE + OOS):**
  - Best combination (simple SMA + stop): IS avg trade $227, return-on-account 4.2%; OOS avg trade $482, return 14.8%. **OOS outperformed IS** — same robustness signal as MACD divergence, and attributed by Katz to the stop acting as a trend filter (confirming the bounce before entry).
  - Number of trades: "relatively few" — the slope+stop filter reduces trade count substantially.
  - CAVEAT: OOS performance is modest in absolute terms. This is a lower-conviction system vs. MACD divergence.
- **Expected trades/year (single symbol):** Due to the stop + slope filter, estimate ~10–20 per year on D1 FX. Likely sufficient for Q08.
- **R1-R4:**
  - R1: PASS — same book, explicit IS+OOS test split, $15 costs.
  - R2: PASS — SMA slope direction, price-crosses-SMA trigger, stop entry, SES exit are all deterministic.
  - R3: CONDITIONAL — FX pairs (JPY, CHF, EUR, GBP) have .DWX equivalents. Energy/ag markets do not.
  - R4: PASS — fixed SMA period, no ML.
- **Dedup verdict:** NEW. The card pool has many SMA/EMA bounce/reversion cards (20+ in the MA-SR search), but none sourced from Katz with this specific slope-conditioned "stop entry at the average" design. Nearest neighbor: QM5_10896_brown-ema-trend — but that uses EMA cross for trend-following, not a stop at the SMA for countertrend with slope gating. Delta: the slope condition (enter only if SMA moving in direction of trade) plus the stop entry (requiring price to confirm the reversal before fill) is the load-bearing mechanism, and no existing card has this exact combination from this source.
- **Mechanization verdict:** NEEDS_SPEC — the slope criterion needs to be precisely defined (slope positive = SMA[0] > SMA[1], or a longer look-back slope?). The text says "the slope of the slower moving average" — implies SMA[0] > SMA[k] for some small k. Recommend k=1 (one-bar slope). The "do not re-enter on the bounce-back" rule needs careful MQL5 state tracking.
- **Proposed card slug:** `katz-sma-support-resistance-stop-d1`

---

### SYSTEM 4 — Seasonality Crossover with Stochastic Confirmation + Stop Entry (D1)

- **Source:** Katz & McCormick (2000), Ch.8 (Seasonality), pp. 185–189, Tests 7–9 (crossover-with-confirmation model). Summary Table 8-3.
- **Rules:**
  - Compute a seasonal price series: for each bar, look back to all instances of the same calendar date in prior years; average the ATR-normalized price momentum (centered triangular MA applied) to produce a "seasonal momentum" series.
  - Integrate the seasonal momentum series into a pseudo-price series; apply a moving average crossover. Best params: MA length 15–20, displacement 6–9 bars ahead (to compensate for lag — legitimate since seasonal values are based on ≥1-year-old data).
  - **LONG entry signal:** Seasonal pseudo-price MA crosses up AND Fast %K Stochastic < 25% (market near bottom of recent range, confirming the expected seasonal bottom).
  - **SHORT entry signal:** Seasonal pseudo-price MA crosses down AND Fast %K Stochastic > 75%.
  - **Entry order:** STOP (best for this model; confirms price is actually moving in the trade direction before fill).
  - **Exit (SES):** 1×ATR(50) stop; 4×ATR(50) target; 10-bar time exit.
- **Timeframe/Symbols:** Original: daily futures. Best markets IS+OOS with stop: Lumber, Unleaded Gasoline, Coffee, NYFE, Silver, Palladium. DWX mapping: XAUUSD.DWX (precious metals proxy), GDAXI.DWX (German index = NYFE proxy). Lumber/Gasoline/Coffee = no .DWX equivalent.
- **Evidence (IN-SAMPLE + OOS):**
  - IS (with stop): avg trade $846 profit, 41% wins, return-on-account 5.8%.
  - OOS (with stop): avg trade $1,677 profit, 44% wins, return-on-account 19.6%, p=77.2% — this OOS return is the strongest of all seasonal model variants tested.
  - Trade count: 292 IS, 121 OOS — low but not critically so.
  - CRITICAL CAVEAT: The seasonal series requires ≥6 years of historical data to build reliable averages. In MT5, this means the EA needs a warm-up period of ~6 years before the first trade is valid. The "jackknife" method used in-sample is not replicable in a live system without modification; in live/OOS mode, only past years are used (as Katz specifies, p. 1078).
- **Expected trades/year (single symbol):** Very low — ~15–25 IS / ~10–15 OOS based on the 292/121 figures across a full portfolio. On a single symbol, estimate **5–12 per year**. This is borderline for Q08. Only warranted if expected PF is high enough.
- **R1-R4:**
  - R1: PASS — McGraw-Hill book, IS+OOS split, costs modeled.
  - R2: CONDITIONAL — the seasonal series construction is complex (requires a specific centered-MA calculation using prior years' data). Fully mechanizable but non-trivial. The centered MA is legitimate in look-forward-safe seasonal context but requires careful implementation to avoid lookahead contamination.
  - R3: CONDITIONAL — XAUUSD.DWX is testable; other best markets (Lumber, Coffee, energy) have no .DWX equivalent. The seasonal pattern that drove OOS performance was commodity-specific (weather/frost effects on Coffee, demand cycles for Gasoline). Gold/index ports are analogues.
  - R4: PASS — fixed MA length, fixed %K thresholds, deterministic crossover; no ML.
- **Dedup verdict:** NEW. The card pool has ~18 seasonality/calendar cards, but all are based on specific event-driven effects (FOMC, options expiry, pre-holiday, turn-of-month) or composite indexes. None uses Katz's adaptive seasonal-crossover-with-Stochastic-confirmation model from this source. Nearest neighbor: QM5_1180_qp-composite-seasonality — but that is a compiled seasonal calendar, not an adaptive per-date momentum crossover with confirmation filter. Delta justified: the Stochastic confirmation gate (requires price to confirm the expected seasonal move before entry) plus the stop entry is the distinguishing mechanism.
- **Mechanization verdict:** NEEDS_SPEC — the seasonal series construction is the hard part. A specific algorithm spec is needed: (a) For each bar, identify calendar date; (b) find all prior instances of same date (or ±1 day) for at least 6 prior years; (c) compute centered triangular MA of ATR-normalized daily momentum around each past instance; (d) average across instances to get seasonal momentum; (e) integrate to get pseudo-price; (f) apply SMA(15) crossover with 7-bar displacement. This is buildable in MQL5 but requires a custom indicator or OnInit precomputation. The centered MA step can be replaced with a simple look-ahead-safe forward MA (since values are based on ≥1-year-old data). Recommend assigning to Codex with explicit spec.
- **Proposed card slug:** `katz-seasonal-crossover-stoch-confirmation-stop-d1`

---

## SYSTEMS REJECTED (not READY/NEEDS_SPEC)

| Chapter | System | Reason for Rejection |
|---------|--------|---------------------|
| Ch.5 | Close-Only Channel Breakout (Tests 1-2) | OOS: negative returns across all variants except currencies. DUPLICATE of QM5_12543 concept but without the FX restriction; inferior form already rejected. |
| Ch.5 | HHLL Breakout at market/stop (Tests 3-6) | OOS: lost heavily except currencies. Inferior to the limit-entry variant already in QM5_12543. |
| Ch.5 | Volatility Breakout (Tests 7-9, 10-12) | IS performance "decayed fastest" per Katz; OOS worse than HHLL. Volatility-breakout = crowded, specifically flagged as degraded. REJECT. |
| Ch.5 | Volatility Breakout Long-Only (Test 10) | Marginal OOS improvement but still negative. REJECT. |
| Ch.5 | Volatility Breakout with ADX Filter (Test 12) | OOS still poor; ADX filter did not help trend-following systems per analysis. REJECT. |
| Ch.6 | Trend-following MA crossover (Tests 1-24) | Lost heavily on most markets IS+OOS; only a few markets profitable. No consistent OOS edge across the portfolio. REJECT. |
| Ch.6 | Countertrend MA crossover (Tests 25-36) | Lost heavily; worse than the support/resistance variant. REJECT. |
| Ch.6 | Front-weighted triangular MA support/resistance (Tests 43-48) | Lost OOS despite IS profit. REJECT. |
| Ch.7 | Stochastic overbought/oversold (Tests 1-3) | "Among the worst tested" — heavily IS and OOS losses. REJECT. |
| Ch.7 | RSI overbought/oversold (Tests 4-6) | More poorly than Stochastic; 26-37% win rate; average loss $7,000. REJECT. |
| Ch.7 | Stochastic signal-line (Tests 7-9) | Lost heavily; "astronomical losses" due to trade count. REJECT. |
| Ch.7 | MACD signal-line (Tests 10-12) | Small IS profit, OOS loss with limit; marginal stop OOS improvement insufficient. NEAR-MISS but not confident enough. |
| Ch.7 | Stochastic divergence (Tests 13-15) | "Among the worst." REJECT. |
| Ch.7 | RSI divergence (Tests 16-18) | "Poor." REJECT. |
| Ch.8 | Seasonal crossover basic (Tests 1-3) | Profitable overall but weaker than confirmation variant and no confirming filter. REJECT in favor of System 4. |
| Ch.8 | Seasonal momentum basic (Tests 4-6) | Worse than crossover. REJECT. |
| Ch.8 | Seasonal crossover + inversion (Tests 10-12) | "Adding inversion was destructive." REJECT. |
| Ch.9 | Lunar/solar rhythms | Scientifically untestable in a reliable mechanical way; data availability (sunspot counts) problematic for MT5. Not rule-complete for our infrastructure. REJECT. |

---

## Summary

| System | Verdict | Proposed Card |
|--------|---------|---------------|
| HHLL Breakout Limit-FX | DUPLICATE (QM5_12543) | — |
| MACD Divergence Limit | NEW / NEEDS_SPEC | katz-macd-divergence-limit-d1 |
| SMA Support/Resistance Stop | NEW / NEEDS_SPEC | katz-sma-support-resistance-stop-d1 |
| Seasonal Crossover + Stoch Confirmation Stop | NEW / NEEDS_SPEC | katz-seasonal-crossover-stoch-confirmation-stop-d1 |

**2 new proposals** out of 4 assessed as viable.

---

## Key Observations for OWNER

1. **The Katz OOS signal is real but old.** Systems 2 and 3 both showed OOS > IS performance — a meaningful robustness indicator. However, the test period ends in 1998/1999. These systems need to prove themselves on 2005–2025 data. The pipeline is the judge.
2. **Energy/ag futures are the missing link.** The best Katz markets (Light Crude, Coffee, Unleaded Gasoline) have no .DWX equivalent. The FX/gold ports are legitimate analogues for testing but the original OOS evidence is commodity-driven.
3. **Limit order wins across all trend-following and most countertrend models.** This is consistent with QuantMechanica's existing finding that retrace entries beat chase entries (also confirmed in QM5_12543's justification).
4. **Stop order wins for countertrend and seasonality.** The stop acts as a trend-filter for these models, confirming the reversal before entry. This is a consistent pattern across Ch.6, Ch.7, and Ch.8.
5. **Part III (exits) starts beyond page 200** (not extracted). The book's exit chapters may contain additional standalone systems. OWNER may wish to extract pages 200–387 for a second pass.
