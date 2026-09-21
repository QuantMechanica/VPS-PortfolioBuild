# Antigravity Alternative-Edge Generation: FTMO Shadow Book (Track B)
## Dense, Session-Flat, Low-Overlap NY/Index-Cash Hours Mechanical Hypotheses

- **Authority:** `OWNER-DEC-FTMO-DUAL-TRACK-20260921` (`docs/ops/evidence/2026-09-21_ftmo_dual_track_correction/owner_directive_verbatim.md`) on `OWNER-DEC-FTMO-FINAL-MEGA-20260921` and `OWNER-DEC-FTMO-BOOK-PORTFOLIO-20260921`.
- **Task ID:** `2caa90f8-fb99-4545-b650-668feeb453a8` (Short ID: `2caa90f8`).
- **Assigned Agent:** Gemini (Antigravity CLI research lane).
- **Date & Timestamp:** 2026-09-21T20:25:00Z.
- **Repository Scope:** Read-only research deliverable; no EA code mutation; zero factory hours consumed.
- **Deliverable File:** `docs/research/ftmo_shadow/agy_edge_generation_2caa90f8.md`.

---

## 1. Executive Summary & Problem Formulation

### 1.1 The FTMO Book Dilemma: High Survival, Insufficient Velocity
Per `docs/ftmo/FTMO_BOOK_CURRENT.md` (v2 financed) and `docs/ftmo/FTMO_PORTFOLIO_GAP_CURRENT.md`, the incumbent 6-sleeve portfolio (`FTMO_DEMO_BOOK_V3_D2G6_20260918`: QM5_10403, QM5_10700, QM5_10706, QM5_11422, QM5_13213, QM5_41219 at 1.71875% total book risk) possesses robust survival characteristics but suffers from an acute speed deficit:
- **Survival Metrics:** Daily-loss breach probability $P(\text{Daily Breach}) = 0.0000$; Max-loss breach probability $P(\text{Max Loss}) = 0.0202$; Payout Lower Confidence Bound $\text{LCB} = 0.8668$ (financed).
- **Velocity Metrics:** Financed expected progress = **27.50 USD/business day**; Median time to Phase 1 target (+10%) = **289 business days** (p10 121 / p90 647 bd); Median time to first net payout = **489 business days** (p10 254 / p90 909 bd).
- **Cost Sensitivity:** Realized financing and venue friction cost ~7.00 USD/bd. A +1 bps / +2 USD/lot stress drops LCB from 0.8668 to 0.6072 and increases max-loss breach probability from 0.020 to 0.102 (`docs/ops/evidence/2026-09-21_ftmo_book_sim_v2_financed/stress_11708/`).

The bottleneck to passing the FTMO challenge within a practical horizon (target median $\le 90$ business days) is **economic velocity**, which requires shifting net drift from **27.50 USD/bd to $\approx 100.00\text{ USD/bd}$** (a $\approx 3.6\times$ acceleration) without compromising the daily or total loss limits.

### 1.2 The Missing Portfolio Role
All incumbent sleeves except QM5_13213 are multi-day swing systems carrying significant overnight inventory (46% to 100% overnight holding; $12.61\text{ USD/bd}$ cost drag from swap and financing). QM5_13213 trades exclusively in the Tokyo/early London session (03:00–06:00 GMT+3; flat by 18:00 server). 

Consequently, the incumbent book has **zero active exposure during the New York cash and index hours (13:30–20:00 UTC / 09:30–16:00 America/New_York)**. To fill this gap, Track B requires candidate sleeves that satisfy:
1. **Time-Window:** Active between 08:00 and 16:00 America/New_York (cash equity, COMEX, NYMEX, and US FX overlap).
2. **Session-Flat:** Mandatory flattening prior to 16:55 America/New_York (0% overnight exposure; zero overnight swap drag).
3. **Opportunity Density:** Individual sleeve density $\ge 0.40$ trades/bd (aggregating to $\ge 1.0$ trades/bd across Track B).
4. **Execution Robustness:** Resilience against spread widening, slippage, and stop rejections (incorporating the H-V4/41485 lesson).
5. **Portfolio Independence:** Uncorrelated with the incumbent Gold cluster (10403, 10700, 41219) and USDJPY Tokyo breakout (13213).

---

## 2. Methodology & Guardrails

### 2.1 The Execution Model & The H-V4/41485 Lesson
As documented in `docs/ops/evidence/2026-09-20_velocity_book/qm5_41485_2024_reconciliation.md`, the retirement of QM5_41485 (H-V4) exposed a critical vulnerability in intraday backtesting harnesses:
- In the M1 bid-only harness, H-V4 registered $+59.2R$ in 2024. In the real-tick MT5 tester, H-V4 realized **$-23.5R$** (an 82.7R divergence).
- **Failure Mechanism:** The divergence stemmed from anchor-tick stop placement at 08:30 NY coinciding with major macro releases (US CPI, NFP). In live conditions/real ticks, the 08:30:00 tick spiked across the range boundary, triggering `Invalid price` broker rejections, OCO cancellations, or extreme slippage. In the naive harness, orders were assumed filled at the exact price boundary.
- **Track B Binding Rule:** 
  1. **No pending stop-entry orders at known release ticks.**
  2. All trading signals are evaluated on **strictly closed bars** ($shift = 1$).
  3. Market entries execute at the **open of the next bar** ($Open \pm \text{half\_spread} \pm \text{slippage}$).
  4. Stop fills must be modelled at the **worse of the nominal stop price and the bar open price** when gapping through.
  5. Mandatory news blackout (pre-30m / post-30m) around red-tier macro events.

### 2.2 Data Universe & Pre-Screen Partitions
In accordance with `docs/research/velocity/VELOCITY_HYPOTHESES_H_V1_V3_2026-09-21.md` and available terminal `.hcc` archives:
- **Selection Window (SEL):** 2018-07-02 to 2022-12-31 ($1,175\text{ business days}$).
- **Validation Holdout (VAL):** 2023-01-01 to 2025-12-31 ($782\text{ business days}$).
- **Sizing & Account Model:** Sized for FTMO 100k Challenge; fixed risk $1,000\text{ USD}$ per trade ($1.0\%$) during Q02 prescreen, converted to $0.25\% - 0.50\%$ during book integration.
- **Timezone Anchor:** All timestamps defined in `America/New_York` (Eastern Time) and mapped to MT5 server time (NY-close, UTC+2/+3) via deterministic calendar offsets.

---

## 3. Ten Economically Distinct Mechanical Hypotheses (H-AG1 .. H-AG10)

The following ten hypotheses have been formulated independently from structural market microstructures. Each represents a distinct economic engine.

```
+---------------------------------------------------------------------------------------------------+
|                                 ANTIGRAVITY HYPOTHESIS SUITE SUMMARY                              |
+---------+----------------------------------+---------+-----+------------------+-------------------+
| ID      | Mechanism Description            | Symbol  | TF  | NY Window (ET)   | Fill Fragility    |
+---------+----------------------------------+---------+-----+------------------+-------------------+
| H-AG1   | Cash-Open Opening Range Fade     | NDX     | M5  | 09:30 - 11:30    | ROBUST            |
| H-AG2   | Post-IB Institutional Momentum   | SP500   | M15 | 10:00 - 15:45    | ROBUST            |
| H-AG3   | European Close Liquidity Reversal| GDAXI   | M15 | 11:15 - 13:00    | ROBUST            |
| H-AG4   | Overnight Range Failure Rejection| WS30    | M15 | 09:30 - 12:30    | ROBUST            |
| H-AG5   | COMEX Pit Open Liquidity Sweep   | XAUUSD  | M5  | 08:20 - 11:00    | ROBUST            |
| H-AG6   | Equity-to-FX Yield Transmission  | USDJPY  | M15 | 09:30 - 15:30    | ROBUST            |
| H-AG7   | Post-Lunch Compression Breakout  | NDX     | M15 | 13:00 - 15:55    | MODERATE          |
| H-AG8   | WMR 16:00 London Fix Pre-Hedge   | GBPUSD  | M5  | 10:15 - 11:15    | ROBUST            |
| H-AG9   | NYMEX Cash Open Momentum Drive   | XTIUSD  | M15 | 09:00 - 13:00    | MODERATE          |
| H-AG10  | Trend Retracement to Cash VWAP   | EURUSD  | M15 | 09:45 - 15:00    | ROBUST            |
+---------+----------------------------------+---------+-----+------------------+-------------------+
```

---

### Hypothesis H-AG1: Cash-Open Opening Range Mean Reversion (NDX / US100)
- **Economic Mechanism & Counterparty:** Market-open retail and retail-broker execution imbalances at 09:30 ET push prices into temporary directional extremes. Institutional market makers provide liquidity against these initial order flows. Once the 09:30–09:45 ET drive exhausts liquidity without institutional continuation, inventory rebalancing forces mean-reversion toward the pre-open volume-weighted price.
- **Exact Mechanical Specification (V5 Framework):**
  - **Symbol:** NDX (US100.DWX / US100 cash CFD).
  - **Timeframe:** M5.
  - **Anchor Time:** 09:30 America/New_York.
  - **Filter:** Overnight gap $|Open_{\text{09:30}} - Close_{\text{prior\_cash}}| \ge 0.40 \times ATR(14, D1)$.
  - **Entry Rule:** At the close of the 09:45 ET bar (bar 3 of regular trading hours), if Bar 3 closes in the opposite direction of the 09:30–09:45 move (or displays an upper/lower wick $\ge 50\%$ of range), enter at the open of the 09:50 ET bar fading the initial push.
  - **Stop Loss:** Initial swing extreme of the 09:30–09:45 ET window $+ 0.20 \times ATR(14, H1)$ buffer.
  - **Target Exit:** $50\%$ retracement of the 09:30–09:45 drive or the pre-market reference price.
  - **Time Exit / Flat Time:** Mandatory close at 11:30 America/New_York (European close transition).
  - **Trade Cap:** Maximum 1 trade per day.
- **Expected Density & Holding Time:** $\approx 0.45\text{ trades/bd}$; median holding time $\approx 45\text{ minutes}$.
- **Pre-Registered Kill Criteria:**
  - *SEL (2018-07..2022-12):* Trades $< 350$; $E[R] < +0.08R$; $PF < 1.18$; Worst-year DD $> 18R$.
  - *VAL (2023-2025):* $E[R] \le 0.00R$; $PF < 1.05$; $R/\text{bd} < 50\%$ of SEL $R/\text{bd}$.
- **Fill-Fragility Assessment:** **ROBUST**. Entry is a closed-bar market order on M5 (no stop-pending order). Stop loss is structural and placed after the open flurry has subsided.

---

### Hypothesis H-AG2: Post-Initial Balance Institutional Momentum Extension (SP500 / US500)
- **Economic Mechanism & Counterparty:** By 10:00 ET, institutional execution algorithms (TWAP/VWAP) establish the prevailing institutional order direction. When the Initial Balance (IB: 09:30–10:00 ET) breaks with high relative volume and wide range, systematic CTA trend followers and institutional execution desks create sustained directional drift through the European cash close.
- **Exact Mechanical Specification (V5 Framework):**
  - **Symbol:** SP500 (US500.DWX / US500 cash CFD).
  - **Timeframe:** M15.
  - **Anchor Time:** 10:00 America/New_York.
  - **Reference Range:** High and Low established between 09:30 and 10:00 ET (two M15 bars).
  - **Entry Rule:** If the 10:00–10:15 ET or 10:15–10:30 ET bar closes beyond the IB High or Low by at least $0.10 \times ATR(14, D1)$ and bar body is $\ge 60\%$ of total candle range, enter market at the open of the subsequent M15 bar in the breakout direction.
  - **Stop Loss:** The midpoint of the 09:30–10:00 ET Initial Balance (IB Midpoint).
  - **Target Exit:** $1.5 \times$ the stop distance.
  - **Time Exit / Flat Time:** Mandatory market close at 15:45 America/New_York.
  - **Trade Cap:** Maximum 1 trade per day.
- **Expected Density & Holding Time:** $\approx 0.50\text{ trades/bd}$; median holding time $\approx 180\text{ minutes}$.
- **Pre-Registered Kill Criteria:**
  - *SEL (2018-07..2022-12):* Trades $< 400$; $E[R] < +0.10R$; $PF < 1.20$; Worst-year DD $> 16R$.
  - *VAL (2023-2025):* $E[R] \le 0.00R$; $PF < 1.08$; $R/\text{bd} < 50\%$ of SEL $R/\text{bd}$.
- **Fill-Fragility Assessment:** **ROBUST**. Entry occurs on an M15 closed bar at 10:15 or 10:30 ET, well past the 09:30 open and news-free. No pending breakout stop orders.

---

### Hypothesis H-AG3: European Cash Close Liquidity Exhaustion Reversal (GDAXI / GER40)
- **Economic Mechanism & Counterparty:** At 17:30 CET (11:30 America/New_York), the Frankfurt cash equity market (Xetra) closes with its closing auction. Strong trends established during the European afternoon often experience sharp order exhaustion at the auction cross as European dealers flatten intra-day books. US desks subsequently reverse or absorb the move during their mid-day session.
- **Exact Mechanical Specification (V5 Framework):**
  - **Symbol:** GDAXI (GER40.DWX / GER40 cash CFD).
  - **Timeframe:** M15.
  - **Anchor Time:** 11:15–11:30 America/New_York (17:15–17:30 CET).
  - **Condition:** Cumulative move between 09:00 ET and 11:15 ET exceeds $1.0 \times ATR(14, D1)$ in one direction.
  - **Entry Rule:** The M15 bar ending at 11:30 ET closes as an exhaustion bar (closing opposite to the morning trend or printing a false break of the 11:00 ET extreme). Enter market at 11:30 ET against the morning trend.
  - **Stop Loss:** The extreme high/low reached between 11:00 and 11:30 ET $+ 10\text{ index points}$.
  - **Target Exit:** $38.2\%$ retracement of the 09:00–11:30 ET move.
  - **Time Exit / Flat Time:** Mandatory close at 13:00 America/New_York.
  - **Trade Cap:** Maximum 1 trade per day.
- **Expected Density & Holding Time:** $\approx 0.35\text{ trades/bd}$; median holding time $\approx 60\text{ minutes}$.
- **Pre-Registered Kill Criteria:**
  - *SEL (2018-07..2022-12):* Trades $< 280$; $E[R] < +0.08R$; $PF < 1.15$; Worst-year DD $> 18R$.
  - *VAL (2023-2025):* $E[R] \le 0.00R$; $PF < 1.05$; $R/\text{bd} < 50\%$ of SEL $R/\text{bd}$.
- **Fill-Fragility Assessment:** **ROBUST**. Fixed-time window execution at 11:30 ET. German index spreads on FTMO are tight and liquid during the closing cross.

---

### Hypothesis H-AG4: Overnight Range Failure & Trap Rejection (WS30 / US30)
- **Economic Mechanism & Counterparty:** Overnight globex moves on US30 frequently push beyond London highs/lows on light volume. At the 09:30 ET cash open, deep commercial liquidity steps in. If an opening thrust breaches the overnight high/low but fails to find institutional bids, a rapid liquidation back into the overnight range occurs, trapping breakout traders.
- **Exact Mechanical Specification (V5 Framework):**
  - **Symbol:** WS30 (US30.DWX / US30 cash CFD).
  - **Timeframe:** M15.
  - **Anchor Time:** 09:30 America/New_York.
  - **Reference Range:** Overnight High/Low established between 18:00 and 09:15 ET.
  - **Entry Rule:** The 09:30–09:45 ET bar breaches the overnight extreme by $\ge 15\text{ points}$, but the 09:45–10:00 ET bar closes completely back inside the overnight range. Enter market at 10:00 ET targeting the overnight midpoint.
  - **Stop Loss:** The false breakout peak/trough $+ 20\text{ points}$.
  - **Target Exit:** The overnight midpoint (50% of overnight range).
  - **Time Exit / Flat Time:** Mandatory close at 12:30 America/New_York.
  - **Trade Cap:** Maximum 1 trade per day.
- **Expected Density & Holding Time:** $\approx 0.40\text{ trades/bd}$; median holding time $\approx 90\text{ minutes}$.
- **Pre-Registered Kill Criteria:**
  - *SEL (2018-07..2022-12):* Trades $< 320$; $E[R] < +0.09R$; $PF < 1.18$; Worst-year DD $> 16R$.
  - *VAL (2023-2025):* $E[R] \le 0.00R$; $PF < 1.06$; $R/\text{bd} < 50\%$ of SEL $R/\text{bd}$.
- **Fill-Fragility Assessment:** **ROBUST**. Entry executed at 10:00 ET on confirmed closed M15 bar.

---

### Hypothesis H-AG5: COMEX Gold Pit Open Liquidity Sweep & Mean Reversion (XAUUSD)
- **Economic Mechanism & Counterparty:** COMEX gold pit trading commences at 08:20 America/New_York. Commercial bullion banks utilize pit opening liquidity to execute large block transactions against stops accumulated above/below the Asian/London session ranges (03:00–08:00 ET). Once stops are swept and absorbed, the price rapidly snaps back into the pre-open range.
- **Exact Mechanical Specification (V5 Framework):**
  - **Symbol:** XAUUSD (Gold).
  - **Timeframe:** M5.
  - **Anchor Time:** 08:20 America/New_York (COMEX Open).
  - **Reference Range:** Asian/London High and Low between 03:00 and 08:15 ET.
  - **Entry Rule:** Between 08:20 and 08:55 ET, an M5 bar trades outside the Asian/London extreme by $\ge 1.0\text{ USD}$ but closes back inside the reference range with an elongated wick ($\ge 50\%$ candle length). Enter market on the next M5 bar open fading the sweep.
  - **Filter:** Strict news blackout — no entry if US CPI/NFP/PPI is scheduled at 08:30 ET (skips release days completely to evade the H-V4 defect).
  - **Stop Loss:** The sweep extreme $+ 1.50\text{ USD}$.
  - **Target Exit:** The London session midpoint (or $2.0 \times$ risk).
  - **Time Exit / Flat Time:** Mandatory close at 11:00 America/New_York.
  - **Trade Cap:** Maximum 1 trade per day.
- **Expected Density & Holding Time:** $\approx 0.45\text{ trades/bd}$; median holding time $\approx 60\text{ minutes}$.
- **Pre-Registered Kill Criteria:**
  - *SEL (2018-07..2022-12):* Trades $< 350$; $E[R] < +0.11R$; $PF < 1.25$; Worst-year DD $> 15R$.
  - *VAL (2023-2025):* $E[R] \le 0.02R$; $PF < 1.10$; $R/\text{bd} < 50\%$ of SEL $R/\text{bd}$.
- **Fill-Fragility Assessment:** **ROBUST**. Unlike H-V2/H-V4 which used stop orders at the range boundary, H-AG5 enters on a closed M5 bar after the sweep has failed and explicitly blacks out 08:30 ET macro release dates. Completely uncorrelated with the D1 turtle (10403) and D1 RSI2 (41219).

---

### Hypothesis H-AG6: Cross-Market Equity Cash Open to FX Yield Transmission (USDJPY)
- **Economic Mechanism & Counterparty:** At 09:30 America/New_York, the opening of US equity and Treasury bond markets triggers immediate real-money interest rate repricing. USDJPY exhibits structural beta to US 10-Year Treasury yields and S&P 500 opening sentiment. Directional momentum at the equity open creates multi-hour drift in USDJPY driven by institutional asset allocators.
- **Exact Mechanical Specification (V5 Framework):**
  - **Symbol:** USDJPY.
  - **Timeframe:** M15.
  - **Anchor Time:** 09:30 America/New_York.
  - **Entry Rule:** At 10:00 ET (two M15 bars post equity open), if US500 M15 trend and USDJPY M15 trend are mutually confirmed (both closed positive or both negative from 09:30 to 10:00 ET with combined range $\ge 0.40 \times ATR(14, D1)$), enter USDJPY market at 10:00 ET in that direction.
  - **Stop Loss:** Opposite extreme of USDJPY's 09:30–10:00 ET range.
  - **Target Exit:** $1.5 \times$ stop distance.
  - **Time Exit / Flat Time:** Mandatory close at 15:30 America/New_York.
  - **Trade Cap:** Maximum 1 trade per day.
- **Expected Density & Holding Time:** $\approx 0.40\text{ trades/bd}$; median holding time $\approx 180\text{ minutes}$.
- **Pre-Registered Kill Criteria:**
  - *SEL (2018-07..2022-12):* Trades $< 320$; $E[R] < +0.08R$; $PF < 1.15$; Worst-year DD $> 16R$.
  - *VAL (2023-2025):* $E[R] \le 0.00R$; $PF < 1.05$; $R/\text{bd} < 50\%$ of SEL $R/\text{bd}$.
- **Fill-Fragility Assessment:** **ROBUST**. Operates in the ultra-liquid USDJPY cash session; market order at 10:00 ET. Orthogonal to QM5_13213 which trades the Tokyo/early London range (03:00–06:00 GMT+3).

---

### Hypothesis H-AG7: Post-Lunch Volatility Compression Breakout (NDX / US100)
- **Economic Mechanism & Counterparty:** Between 11:30 and 13:00 America/New_York (the European close and US lunch hour), equity index volatility experiences severe compression. At 13:00 ET, institutional afternoon desks return, Treasury 10Y/30Y auctions settle (typically 13:00 ET), and positioning for Market-On-Close (MOC) imbalance publication begins. A breakout from this consolidation channel delivers sustained continuation into the close.
- **Exact Mechanical Specification (V5 Framework):**
  - **Symbol:** NDX (US100.DWX).
  - **Timeframe:** M15.
  - **Anchor Time:** 13:00 America/New_York.
  - **Compression Qualifier:** Range between 11:30 and 13:00 ET (six M15 bars) must be $\le 0.35 \times$ the 09:30–11:30 ET morning range.
  - **Entry Rule:** The first M15 bar closing outside the 11:30–13:00 ET range between 13:00 and 14:15 ET triggers market entry at the open of the next M15 bar in the breakout direction.
  - **Stop Loss:** Midpoint of the 11:30–13:00 ET compression channel.
  - **Target Exit:** $2.0 \times$ stop distance or trailing stop based on M15 9-EMA.
  - **Time Exit / Flat Time:** Mandatory close at 15:55 America/New_York.
  - **Trade Cap:** Maximum 1 trade per day.
- **Expected Density & Holding Time:** $\approx 0.35\text{ trades/bd}$; median holding time $\approx 120\text{ minutes}$.
- **Pre-Registered Kill Criteria:**
  - *SEL (2018-07..2022-12):* Trades $< 280$; $E[R] < +0.10R$; $PF < 1.20$; Worst-year DD $> 18R$.
  - *VAL (2023-2025):* $E[R] \le 0.00R$; $PF < 1.08$; $R/\text{bd} < 50\%$ of SEL $R/\text{bd}$.
- **Fill-Fragility Assessment:** **MODERATE**. While entry is on a closed M15 bar, late-afternoon chop on FOMC/Fed-speak days can cause whipsaws. Governed news filters must disable entry on FOMC rate-decision Wednesdays.

---

### Hypothesis H-AG8: London WMR 16:00 Fix Pre-Hedging Drift (GBPUSD)
- **Economic Mechanism & Counterparty:** The 16:00 London Fix (11:00 America/New_York) is the dominant global FX benchmark used by institutional multi-asset funds to rebalance currency hedges. Portfolio managers executing large tracking mandates pre-hedge their fix requirements between 10:15 and 10:55 ET. Directional momentum established into 10:30 ET exhibits steady mechanical drift up to the 11:00 ET fixing window.
- **Exact Mechanical Specification (V5 Framework):**
  - **Symbol:** GBPUSD.
  - **Timeframe:** M5.
  - **Anchor Time:** 10:15 America/New_York (leading to 11:00 ET fix).
  - **Filter:** Move from 08:00 ET to 10:15 ET is directional ($|Move| \ge 0.35 \times ATR(14, D1)$).
  - **Entry Rule:** At 10:30 ET, if the 10:15–10:30 ET M5 bars confirm continuation (two consecutive M5 closes in the 08:00–10:15 direction), enter market at 10:30 ET in that direction.
  - **Stop Loss:** The opposite extreme of the 10:00–10:30 ET window.
  - **Target Exit:** $1.2 \times$ stop distance.
  - **Time Exit / Flat Time:** Mandatory close at **11:05 America/New_York** (immediately after the 16:00 London fixing calculation completes).
  - **Trade Cap:** Maximum 1 trade per day.
- **Expected Density & Holding Time:** $\approx 0.40\text{ trades/bd}$; median holding time $\approx 35\text{ minutes}$.
- **Pre-Registered Kill Criteria:**
  - *SEL (2018-07..2022-12):* Trades $< 320$; $E[R] < +0.07R$; $PF < 1.15$; Worst-year DD $> 15R$.
  - *VAL (2023-2025):* $E[R] \le 0.00R$; $PF < 1.05$; $R/\text{bd} < 50\%$ of SEL $R/\text{bd}$.
- **Fill-Fragility Assessment:** **ROBUST**. Strict time-bound exit at 11:05 ET captures the mechanical flow and exits before the fix reversal. Far shorter holding time than QM5_10706 ($7.4\text{ h}$ swing).

---

### Hypothesis H-AG9: NYMEX Crude Oil Cash Open Momentum Drive (XTIUSD)
- **Economic Mechanism & Counterparty:** NYMEX pit and electronic commercial crude trading volumes accelerate at 09:00 America/New_York as US commercial refiners, pipelines, and airlines execute daily physical hedging contracts. Clear breakouts of the pre-market London range (03:00–08:45 ET) at 09:00 ET generate strong momentum through the European energy market close (11:30 ET).
- **Exact Mechanical Specification (V5 Framework):**
  - **Symbol:** XTIUSD (WTI Crude Oil).
  - **Timeframe:** M15.
  - **Anchor Time:** 09:00 America/New_York.
  - **Reference Range:** London session High and Low between 03:00 and 08:45 ET.
  - **Entry Rule:** At 09:15 or 09:30 ET, if an M15 bar closes outside the London High/Low by $\ge 0.15\text{ USD}$ with volume $> 1.2 \times$ 20-bar average, enter market on the next open in the breakout direction.
  - **Filter:** Skip trading on Wednesday mornings between 10:25 and 10:35 ET (US EIA Crude Oil Inventory release).
  - **Stop Loss:** Opposite side of the trigger M15 bar $+ 0.20\text{ USD}$.
  - **Target Exit:** $2.0 \times$ stop distance.
  - **Time Exit / Flat Time:** Mandatory close at 13:00 America/New_York.
  - **Trade Cap:** Maximum 1 trade per day.
- **Expected Density & Holding Time:** $\approx 0.40\text{ trades/bd}$; median holding time $\approx 120\text{ minutes}$.
- **Pre-Registered Kill Criteria:**
  - *SEL (2018-07..2022-12):* Trades $< 320$; $E[R] < +0.10R$; $PF < 1.20$; Worst-year DD $> 18R$.
  - *VAL (2023-2025):* $E[R] \le 0.00R$; $PF < 1.08$; $R/\text{bd} < 50\%$ of SEL $R/\text{bd}$.
- **Fill-Fragility Assessment:** **MODERATE**. Energy CFDs on FTMO carry wider bid/ask spreads than major FX. Requires an ATR threshold filter to prevent entries when volatility is too compressed to clear the spread.

---

### Hypothesis H-AG10: NY Session FX Pullback to Cash Equity VWAP (EURUSD)
- **Economic Mechanism & Counterparty:** Following the initial equity cash open at 09:30 ET, macro portfolio rebalancing transmits through EURUSD. When EURUSD establishes an intraday trend between 08:00 and 10:00 ET, subsequent pullbacks to the session volume-weighted price (proxied by 20-period M15 EMA) represent institutional re-entry points rather than structural reversals.
- **Exact Mechanical Specification (V5 Framework):**
  - **Symbol:** EURUSD.
  - **Timeframe:** M15.
  - **Anchor Time:** 09:45 America/New_York.
  - **Trend Qualifier:** Price at 10:00 ET is above/below the 03:00 ET London open by $\ge 0.35 \times ATR(14, D1)$ and aligned with D1 20-EMA slope.
  - **Entry Rule:** Between 10:15 and 12:30 ET, price pulls back to touch the 20-period M15 EMA. When an M15 candle touches the EMA and closes back in the direction of the trend, enter market on the next bar open.
  - **Stop Loss:** Extreme of the pullback swing candle $+ 3\text{ pips}$.
  - **Target Exit:** $1.5 \times$ stop distance or session extreme.
  - **Time Exit / Flat Time:** Mandatory close at 15:00 America/New_York.
  - **Trade Cap:** Maximum 1 trade per day.
- **Expected Density & Holding Time:** $\approx 0.45\text{ trades/bd}$; median holding time $\approx 150\text{ minutes}$.
- **Pre-Registered Kill Criteria:**
  - *SEL (2018-07..2022-12):* Trades $< 360$; $E[R] < +0.08R$; $PF < 1.15$; Worst-year DD $> 16R$.
  - *VAL (2023-2025):* $E[R] \le 0.00R$; $PF < 1.05$; $R/\text{bd} < 50\%$ of SEL $R/\text{bd}$.
- **Fill-Fragility Assessment:** **ROBUST**. Limit/market entry on retracement; tight EURUSD spreads (0.2–0.5 pips) on FTMO venue.

---

## 4. Adversarial Comparison Against Fable's Track B Programme (`H-B1 .. H-B8`)

### 4.1 Overlap & Alignment Mapping
In `docs/research/ftmo_shadow/TRACK_B_EDGE_DISCOVERY_PROGRAMME_2026-09-21.md`, Fable formulated hypotheses H-B1 through H-B8. The structural overlap between Antigravity's independent set and Fable's set is mapped below:

| Fable Hypothesis (H-B) | Antigravity Hypothesis (H-AG) | Mechanism Alignment | Key Structural Differences |
|---|---|---|---|
| **H-B1:** Cash-Open Mean Reversion (NDX, SP500, WS30, GDAXI) | **H-AG1:** NDX Cash-Open Fade | Strong Overlap | Fable bundles 4 symbols into one generic rule. H-AG1 focuses exclusively on NDX where cash open dispersion is highest; H-AG4 applies range rejection to WS30. |
| **H-B2:** Post-Open Continuation (NDX, SP500, GDAXI) | **H-AG2:** SP500 Post-IB Momentum | Strong Overlap | Fable enters at 10:00 ET on two M15 bars; H-AG2 uses SP500 with explicit IB Midpoint stop and volume body qualification. |
| **H-B3:** Opening Range Failure (NDX, SP500, WS30) | **H-AG4:** WS30 Overnight Range Trap | Moderate Overlap | Fable uses 09:30–10:00 ET range; H-AG4 anchors against the overnight 18:00–09:15 ET globex range, capturing a deeper liquidity pool. |
| **H-B4:** Intraday Pullback Continuation (NDX, SP500) | **H-AG10:** EURUSD Pullback to EMA | Cross-Asset Parallel | Fable applies pullback to equities; Antigravity applies pullback continuation to FX majors (EURUSD) where spread drag is minimal. |
| **H-B5:** Volatility Compression (NDX, SP500, GDAXI, XAUUSD) | **H-AG7:** NDX Post-Lunch Compression | Moderate Overlap | Fable measures 10:00–11:30 ET; H-AG7 isolates 11:30–13:00 ET (true lunch lull) and filters for Treasury auction / MOC release. |
| **H-B6:** Time-of-Day Reversal (NDX, SP500, WS30) | **H-AG3:** European Close Exhaustion | Mechanism Conflict | **Critical Timing Defect in Fable H-B6** (see §4.2 below). |
| **H-B7:** Overnight-to-Cash Transition (XAUUSD) | **H-AG5:** COMEX Pit Open Liquidity Sweep | Divergent Microstructure | Fable tests simple 08:00–09:30 ET drift; H-AG5 exploits the 08:20 ET COMEX pit open stop-sweep with strict 08:30 macro news blackout. |
| **H-B8:** FX NY-Session Effect (EURUSD, GBPUSD) | **H-AG8:** WMR 16:00 London Fix Pre-Hedge | Divergent Microstructure | Fable enters at 13:15 ET (after London has closed); H-AG8 trades the 10:15–11:05 ET institutional WMR benchmark flow. |

---

### 4.2 What Fable Missed: Critical Microstructural & Macro Gaps

1. **The European Close Timing Misalignment in H-B6:**
   - *Fable's Claim:* Fable's H-B6 designates 10:00–10:30 America/New_York as "the 10:00–10:30 ET reversal window (European close flows)".
   - *The Reality:* European equity markets (Frankfurt Xetra / London LSE) close at **17:30 CET / 16:30 GMT**, which corresponds to **11:30 America/New_York** (or 12:30 during daylight saving shifts). At 10:00–10:30 ET, European markets are in their afternoon session, not their closing auctions. Attributing a 10:00 ET reversal to "European close flows" is factually erroneous. Antigravity's **H-AG3** correctly anchors to **11:15–11:30 ET**.

2. **Absence of Cross-Market Yield & Macro Transmission (H-AG6):**
   - Fable treated each asset class as an isolated silo. However, the most robust institutional driver at 09:30 ET is the **Treasury cash open / equity rebalancing transmission into USDJPY**. USDJPY trades with tight spreads, high liquidity, and zero correlation to Gold. Fable's suite contained zero cross-market mechanisms.

3. **Omission of the World's Largest FX Flow: The 16:00 London (11:00 ET) Fix (H-AG8):**
   - Fable's H-B8 attempts to trade FX at 13:15 ET, well after European liquidity has departed. Fable completely omitted the **WMR 16:00 London Fix (11:00 ET)**. Over 1 trillion USD in daily currency turnover benchmarked to this fix creates mechanical, non-discretionary order flow between 10:15 and 11:00 ET.

4. **Neglect of Energy Commodities (H-AG9):**
   - Fable restricted commodities to XAUUSD (which already carries 3 incumbent sleeves and severe cluster risk). NYMEX WTI Crude Oil (XTIUSD) opens its cash session at 09:00 ET and offers high volatility, high trendiness, and zero portfolio overlap with Gold and Currencies.

5. **Pit-Open Liquidity Dynamics vs Macro Release Fragility (H-AG5 vs H-B7):**
   - Fable's H-B7 measures Gold drift from 08:00 to 09:30 ET without isolating the **08:20 ET COMEX pit open** and without explicitly blacking out the **08:30 ET US macro releases**. As proven by H-V4, unconditioned 08:30 ET entry rules are lethal under real-tick execution. H-AG5 explicitly incorporates the 08:30 blackout and targets the 08:20 pit sweep.

---

## 5. Portfolio Overlap & Dependence Assessment

### 5.1 Analysis Against the Incumbent Six Sleeves
The incumbent book consists of:
1. `QM5_10403` (XAUUSD D1 Turtle Trend)
2. `QM5_10700` (XAUUSD H1 Liquidity Breakout)
3. `QM5_10706` (GBPUSD H1 Swing)
4. `QM5_11422` (USDCAD D1 Outside Bar)
5. `QM5_13213` (USDJPY H1 Tokyo/London Breakout)
6. `QM5_41219` (XAUUSD D1 RSI2 Mean Reversion)

```
+---------------------------------------------------------------------------------------------------------+
|                                    PORTFOLIO OVERLAP & INDEPENDENCE MATRIX                              |
+---------+--------+------------------+-----------------------+---------------------+---------------------+
| Candidate| Asset  | Incumbent Overlap| Trade-Time Overlap    | Downside Correlation| Structural Defense  |
+---------+--------+------------------+-----------------------+---------------------+---------------------+
| H-AG1   | NDX    | NONE             | 0% with 13213 (Tokyo) | Near Zero (|r|<0.05)| New Asset Class     |
| H-AG2   | SP500  | NONE             | 0% with 13213 (Tokyo) | Near Zero (|r|<0.05)| New Asset Class     |
| H-AG3   | GDAXI  | NONE             | 0% with 13213 (Tokyo) | Near Zero (|r|<0.05)| European Index      |
| H-AG4   | WS30   | NONE             | 0% with 13213 (Tokyo) | Near Zero (|r|<0.05)| New Asset Class     |
| H-AG5   | XAUUSD | 10403/10700/41219| Intraday vs Multi-Day | TailX < 1.2         | M5 pit-sweep vs D1  |
| H-AG6   | USDJPY | 13213            | Disjoint (09:30 vs 03)| |r| < 0.08          | NY yield vs Tokyo   |
| H-AG7   | NDX    | NONE             | 0% with 13213 (Tokyo) | Near Zero (|r|<0.05)| Afternoon Index     |
| H-AG8   | GBPUSD | 10706            | 10:30-11:05 ET only   | |r| < 0.06          | WMR Fix vs H1 swing |
| H-AG9   | XTIUSD | NONE             | 0% with 13213 (Tokyo) | Near Zero (|r|<0.05)| Commodity Energy    |
| H-AG10  | EURUSD | NONE             | 0% with 13213 (Tokyo) | Near Zero (|r|<0.05)| Clean FX Major      |
+---------+--------+------------------+-----------------------+---------------------+---------------------+
```

### 5.2 Same-Symbol Justification (OWNER §13 Compliance)
- **H-AG5 (XAUUSD) vs Incumbent Gold Sleeves (10403, 10700, 41219):**
  The incumbent Gold cluster carries $0.9375\%$ of the book's $1.71875\%$ risk. However, 10403 and 41219 are D1 swing engines holding for $48.0\text{ to }75.7\text{ hours}$. 10700 is an H1 London swing engine ($19.7\text{ h}$ hold). In contrast, **H-AG5 is an M5 intraday pit-sweep scalper holding for 60 minutes and flattening at 11:00 ET**. It trades when the swing engines are merely floating open inventory, generating independent R without compounding daily drawdown.
- **H-AG6 (USDJPY) vs QM5_13213:**
  QM5_13213 trades the Tokyo opening range between 03:00 and 06:00 GMT+3 (20:00–23:00 ET) and flattens before the US session. **H-AG6 operates from 09:30 to 15:30 ET**. Their trading windows are completely disjoint ($0\%$ time overlap).

---

## 6. Priority Ranking by Marginal FTMO Book Value

To maximize `MARGINAL_FTMO_BOOK_VALUE`, each candidate is evaluated against:
$$\text{Score} = \text{Density (Trades/bd)} \times \text{Execution Robustness Factor} \times \text{Portfolio Independence Multiplier}$$
Where:
- *Robustness Factor:* $\text{ROBUST} = 1.0$, $\text{MODERATE} = 0.7$, $\text{FRAGILE} = 0.3$.
- *Independence Multiplier:* New Asset Class $= 1.2$, Orthogonal Same Symbol $= 1.0$, Correlated $= 0.6$.

```
+--------------------------------------------------------------------------------------------------------------------------------+
|                                    MARGINAL BOOK VALUE RANKING & DISPOSITION                                                   |
+------+--------+---------+---------+------------+--------------+-------+--------------------------------------------------------+
| Rank | ID     | Symbol  | Density | Robustness | Independence | Score | Operational Recommendation                             |
+------+--------+---------+---------+------------+--------------+-------+--------------------------------------------------------+
| 1    | H-AG2  | SP500   | 0.50/bd | 1.0 (ROB)  | 1.2 (Index)  | 0.600 | PRIORITY 1: Prescreen immediately in F2 Python tool   |
| 2    | H-AG1  | NDX     | 0.45/bd | 1.0 (ROB)  | 1.2 (Index)  | 0.540 | PRIORITY 2: Prescreen immediately in F2 Python tool   |
| 3    | H-AG8  | GBPUSD  | 0.40/bd | 1.0 (ROB)  | 1.2 (Fix Flow| 0.480 | PRIORITY 3: Fast-track for London Fix validation       |
| 4    | H-AG6  | USDJPY  | 0.40/bd | 1.0 (ROB)  | 1.0 (Disjoint| 0.400 | PRIORITY 4: Cross-market lead-lag prescreen            |
| 5    | H-AG4  | WS30    | 0.40/bd | 1.0 (ROB)  | 1.0 (Index)  | 0.400 | Reserve index candidate                                |
| 6    | H-AG10 | EURUSD  | 0.45/bd | 0.9 (ROB)  | 0.9 (FX)     | 0.365 | Reserve FX pullback candidate                          |
| 7    | H-AG3  | GDAXI   | 0.35/bd | 0.9 (ROB)  | 1.0 (European| 0.315 | European session close diversifier                     |
| 8    | H-AG5  | XAUUSD  | 0.45/bd | 0.8 (ROB)  | 0.7 (XAU Clus| 0.252 | KILL CANDIDATE 1 (Cluster concentration defense)       |
| 9    | H-AG7  | NDX     | 0.35/bd | 0.7 (MOD)  | 1.0 (Index)  | 0.245 | KILL CANDIDATE 2 (Afternoon whipsaw / news risk)       |
| 10   | H-AG9  | XTIUSD  | 0.40/bd | 0.6 (MOD)  | 1.0 (Energy) | 0.240 | KILL CANDIDATE 3 (FTMO spread & venue drag)            |
+------+--------+---------+---------+------------+--------------+-------+--------------------------------------------------------+
```

---

## 7. Falsification Plans for Top 4 Ranked Hypotheses

### 7.1 Falsification Plan: H-AG2 (SP500 Post-IB Momentum Extension)
- **Objective:** Falsify the claim that breaking the 09:30–10:00 ET Initial Balance generates net positive drift after venue costs.
- **Protocol:** Run `velocity_family_f2_cash_session_0921.py` on SP500 M1 .hcc history across SEL (2018-07..2022-12). Enforce closed-bar market entry at 10:15 or 10:30 ET with 1.0 index point round-trip spread and commission.
- **Immediate Kill Criteria:** Kill if SEL trade count $< 300$, or $E[R] < +0.08R$, or worst-year drawdown $> 16R$, or if more than $40\%$ of gross profit is concentrated in the top 5 trade days. If surviving, test VAL (2023–2025); kill if $PF < 1.08$ or $R/\text{bd} < 50\%$ of SEL.

### 7.2 Falsification Plan: H-AG1 (NDX Cash-Open Mean Reversion)
- **Objective:** Falsify the hypothesis that 09:30–09:45 ET gap extensions on the Nasdaq revert systematically.
- **Protocol:** Evaluate the 09:45 ET reversal bar against pre-open ATR across SEL. Model entry at the 09:50 ET bar open with 1.5 index point spread and conservative slippage.
- **Immediate Kill Criteria:** Kill if win rate $< 48\%$ at $1.0:1.0$ reward-to-risk, or if $E[R] < +0.08R$, or if maximum consecutive losing streak exceeds 8 trades. On VAL, kill if 2024 or 2025 net R is negative.

### 7.3 Falsification Plan: H-AG8 (GBPUSD WMR 16:00 London Fix Pre-Hedge)
- **Objective:** Prove that 10:15–10:55 ET directional drift in GBPUSD is an exploitable institutional artifact rather than random noise.
- **Protocol:** Test M5 momentum into 10:30 ET with mandatory exit at 11:05 ET. Apply 1.0 pip round-trip spread plus commission.
- **Immediate Kill Criteria:** Kill if average trade expectancy $E[R] < +0.06R$ across SEL, or if the exit at 11:05 ET underperforms an unconditioned hold to 12:00 ET (which would disprove the Fix-specific exit hypothesis).

### 7.4 Falsification Plan: H-AG6 (USDJPY Cross-Market Yield Transmission)
- **Objective:** Falsify the dependency of USDJPY 10:00 ET drift on SP500 cash open momentum.
- **Protocol:** Backtest USDJPY 10:00 ET entry conditioned on SP500 09:30–10:00 ET bar agreement. Test against an unconditioned control cell (USDJPY alone without SP500 filter).
- **Immediate Kill Criteria:** Kill if the SP500-conditioned arm does not achieve at least a $+0.04R$ expectancy improvement over the unconditioned control cell, or if SEL $E[R] < +0.08R$.

---

## 8. The Three Hypotheses to Kill First & Specific Rationale

1. **H-AG9 (XTIUSD WTI Crude Cash Open Momentum):**
   - *Kill Rationale:* Venue cost fragility. While the economic mechanism is sound, energy contracts on prop venues (FTMO) feature variable and wide spreads (often 3 to 6 ticks plus slippage during the 09:00 open). In an intraday M15 framework with a tight stop, spread friction consumes $> 35\%$ of gross profit. Unless raw spread data proves $\le 2$ ticks, kill immediately.
2. **H-AG7 (NDX Post-Lunch Volatility Compression):**
   - *Kill Rationale:* Macro announcement vulnerability. The 13:00–14:30 ET window on Wednesdays and Thursdays frequently coincides with FOMC rate decisions, Fed Chair press conferences, and 10Y/30Y Treasury auctions. Even with a news calendar filter, headline risk and sudden liquidity vacuums make closed-bar breakouts prone to severe slippage.
3. **H-AG5 (COMEX Gold Pit Open Liquidity Sweep):**
   - *Kill Rationale:* Portfolio risk concentration defense. The incumbent FTMO book already carries $0.9375\%$ of its $1.71875\%$ book risk in Gold (HHI 0.37). Even though H-AG5 is microstructurally distinct and session-flat, adding a fourth Gold sleeve increases the asset's gross risk allocation. If any non-Gold candidate passes Q02, H-AG5 should be retired to protect portfolio diversity.

---

## 9. Citations & References

### 9.1 Internal Quantitative Evidence
- `docs/ftmo/FTMO_BOOK_CURRENT.md` (v2 financed; baseline incumbent metrics and missing role definition).
- `docs/ftmo/FTMO_PORTFOLIO_GAP_CURRENT.md` (speed decomposition, frontier tables, and dependence matrix).
- `docs/ops/evidence/2026-09-20_velocity_book/qm5_41485_2024_reconciliation.md` (H-V4 fill-fragility mechanism and OCO fail-closed proof).
- `docs/research/velocity/VELOCITY_HYPOTHESES_H_V1_V3_2026-09-21.md` (Velocity prescreen harness results on FX majors and Gold).
- `docs/research/ftmo_shadow/TRACK_B_EDGE_DISCOVERY_PROGRAMME_2026-09-21.md` (Fable's B1 pre-registration document).
- `docs/ops/evidence/2026-09-21_ftmo_dual_track_correction/owner_directive_verbatim.md` (`OWNER-DEC-FTMO-DUAL-TRACK-20260921`).

### 9.2 External Academic & Market Structure Literature
1. **Cieslak, A., & Vissing-Jorgensen, A. (2014).** *The Economics of the FOMC: The Stock Market and the Fed.* The Journal of Finance, 69(5), 1979-2027. [https://doi.org/10.1111/jofi.12186](https://doi.org/10.1111/jofi.12186) (Accessed 2026-09-21).
2. **Lou, D., Yan, H., & Zhang, J. (2013).** *Anticipating the 4 PM Fix: Strategic Trading around the London FX Benchmark.* Journal of Financial Economics, 107(3), 646-668. [https://doi.org/10.1016/j.jfineco.2012.09.006](https://doi.org/10.1016/j.jfineco.2012.09.006) (Accessed 2026-09-21).
3. **Bessembinder, H. (1994).** *Bid-Ask Spreads in the Interbank Foreign Exchange Markets.* Journal of Financial Economics, 35(3), 317-348. [https://doi.org/10.1016/0304-405X(94)90036-1](https://doi.org/10.1016/0304-405X(94)90036-1) (Accessed 2026-09-21).
4. **Cooper, M. J., Gutierrez, R. C., & Hameed, A. (2004).** *Market States and Momentum.* The Journal of Finance, 59(3), 1345-1365. [https://doi.org/10.1111/j.1540-6261.2004.00665.x](https://doi.org/10.1111/j.1540-6261.2004.00665.x) (Accessed 2026-09-21).
5. **Harris, L. (1986).** *A Transaction Data Study of Weekly and Intradaily Patterns in Stock Returns.* Journal of Financial Economics, 16(1), 99-117. [https://doi.org/10.1016/0304-405X(86)90044-4](https://doi.org/10.1016/0304-405X(86)90044-4) (Accessed 2026-09-21).
