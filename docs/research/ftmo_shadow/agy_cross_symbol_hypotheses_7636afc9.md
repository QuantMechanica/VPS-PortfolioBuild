# Antigravity Original Cross-Symbol & Multi-Condition Hypotheses (Track B)
## Dense, Session-Flat, Low-Overlap Candidates for the FTMO Shadow Book

- **Authority:** `OWNER-DEC-FTMO-FULL-THROTTLE-20260921` (`docs/ops/evidence/2026-09-21_ftmo_full_throttle_override/owner_directive_verbatim.md`), sections 11, 12, 13, 15, 19, 27, 28; modifying `OWNER-DEC-FTMO-DUAL-TRACK-20260921` and `OWNER-DEC-FTMO-FINAL-MEGA-20260921`.
- **Task ID:** `7636afc9-dd11-4b29-813c-4e5d193755c5` (Short ID: `7636afc9`).
- **Assigned Agent:** Gemini (Antigravity CLI research lane).
- **Date & Timestamp:** 2026-09-21T21:00:00Z.
- **Repository Scope:** Read-only research deliverable; no EA code mutation; zero factory hours consumed.
- **Deliverable File:** `docs/research/ftmo_shadow/agy_cross_symbol_hypotheses_7636afc9.md`.

---

## 1. Adversarial Post-Mortem of Family B2 (and B1 / B3 / C1)

Across families B1 (8 hypotheses, 22 cells), B2 (8 hypotheses, 14 cells), B3 (3 hypotheses, 16 cells), and C1 (1 hypothesis, 8 cells), exactly **0 of 60 evaluated cells survived the conservative fill model** under the Selection (SEL) bar. In family B2 specifically (`velocity_family_f4_b2_0921.json`), every single index cell was marked `CLEAR_REJECT`. 

An unsparing post-mortem reveals four structural points of failure in our initial H-AG assumptions:

```
+---------------------------------------------------------------------------------------------------------+
|                                    B2 POST-MORTEM ROOT CAUSE BREAKDOWN                                   |
+-------------------+---------------------------------------+---------------------------------------------+
| Failure Dimension | Flawed Assumption in H-AG Suite       | Realized Market & Execution Reality         |
+-------------------+---------------------------------------+---------------------------------------------+
| 1. Stop Scale     | Local M5/M15 swing stops & fixed pts  | Cost-dominated: median cost 20-50% of R;     |
|    (Catastrophic) | (e.g. 20 pt trap buffer, 0.2 H1 ATR)  | median hold collapsed to 4-5 min (NDX/SP)   |
|                   |                                       |                                             |
| 2. Mechanism Sign | Opening-range and gap mean-reversion  | Cash open is an institutional momentum      |
|    (Severe)       | fades (H-AG1, H-B1)                   | drive; fading lost -1.20R/trade on SP500    |
|                   |                                       |                                             |
| 3. Signal Density | Complex multi-filter conjuncts        | Starvation: 0.03-0.05 trades/bd (40-60      |
|    (Severe)       | (gap >= 0.4 ATR AND 50% wick reversal)| trades in 4.5 years) vs 0.40 target         |
|                   |                                       |                                             |
| 4. Noise Window   | Entries at 09:35-09:45 ET into the    | Maximum spread expansion, book imbalance,   |
|    (Moderate)     | immediate cash-open auction cross     | and retail churn; stops swept instantly     |
+-------------------+---------------------------------------+---------------------------------------------+
```

### 1.1 The Stop-Scale Catastrophe (Cost Domination)
In H-AG1 (NDX/SP500) and H-AG4 (WS30/NDX), stop losses were anchored to M5 swing extremes plus tight buffers (e.g., 20 points on WS30, ~10-15 points on NDX, 2-4 points on SP500). Under the F2 conservative execution model (half-spread + slippage at entry, gap-through charged on stops, 1.0 index pt round-trip cost prior):
- On `H-AG1|SP500.DWX`, median cost was $0.2257R$. Net $E[R]$ was $-1.2026R$ with a Profit Factor of $0.010$ and median hold time of **4.0 minutes**!
- On `H-AG1|NDX.DWX`, median hold was **5.0 minutes**, net $E[R] = -0.3697R$, $PF = 0.259$.
- On `H-AG4|WS30.DWX`, stops were breached rapidly, yielding $E[R] = -0.5538R$, $PF = 0.173$, median hold 29 min.
**Implication:** Intraday index mechanics cannot survive on M5-scale stops. Any index sleeve must anchor stop loss to at least **$0.35 \times \text{cash-session ATR}(14)$ or $\ge 0.50 \times H1\text{-ATR}$** (yielding minimum stops of $\ge 35$ NDX points, $\ge 12$ SP500 points, $\ge 120$ WS30 points). If a stop is tighter than 5× round-trip friction, random bid/ask oscillation terminates the trade before any edge can express itself.

### 1.2 Wrong-Signed Mechanism: The Cash-Open Fade Fallacy
H-AG1 and H-B1 hypothesized that overnight imbalances unwind immediately after 09:30 ET via retail exhaustion. The data delivered an unambiguous refutation:
- Fading the cash open was the single worst-performing concept across all 60 cells.
- The 09:30–10:00 ET window is not retail mean-reversion; it is institutional price discovery where institutional benchmark execution algorithms (TWAP/VWAP programs, index arbitrageurs, sector baskets) inject massive directional volume. 
- When an index moves strongly in the first 15 minutes, trying to fade it at bar 3 (09:45 ET) is stepping in front of a freight train.
- Conversely, the only cells exhibiting positive gross drift were continuation cells (B1 H-B2 on GDAXI $+0.10R$, NDX $+0.04R$; B2 H-AG2 NDX validation $+0.0487R$, $PF = 1.11$).
**Implication:** The opening impulse must be treated as a directional regime filter or momentum continuation, **never a counter-trend fade**, unless confirmed by an exogenous multi-market structural exhaustion.

### 1.3 The Density Dilemma: Over-Conditioning vs Signal Starvation
H-AG5 (COMEX Gold sweep), H-AG6 (USDJPY equity transmission), and H-AG8 (GBPUSD/EURUSD WMR fix) produced only 40 to 58 trades over 1,175 business days (densities between $0.034$ and $0.049\text{ trades/bd}$). 
- In H-AG5, requiring an Asia/London range, followed by a sweep of $\ge 1.0\text{ USD}$, followed by a $\ge 50\%$ wick close-back, all before 09:00 ET, eliminated 96% of trading days.
- In H-AG6, requiring both SP500 and USDJPY to simultaneously breach $0.20 \times D1\text{-ATR}$ in the first 30 minutes occurred on fewer than 5% of days.
**Implication:** We cannot stack multiple arbitrary single-symbol price-action qualifiers (wicks, exact point thresholds) to filter noise. Instead, density must be preserved ($\ge 0.40\text{ trades/bd}$) by using **broad structural state filters** on a reference market (e.g. Reference Index Trend Regime $> MA50$) paired with a clean mechanical breakout trigger on the execution market.

### 1.4 Noise Window: The 09:30–10:00 Trap
Trading at 09:30–09:45 ET forces execution into peak volatility where spreads widen and M1 bar ranges expand by $300\%$. Entering at 10:00 ET (the close of the Initial Balance) or 10:15 ET reduces spread drag, allows the reference market to establish an unambiguous trend, and eliminates opening auction noise.

---

## 2. The Cross-Symbol Paradigm Shift

Single-symbol intraday setups fail because an individual asset's M5/M15 chart cannot differentiate between:
1. **Isolated order-flow noise** (a single fund rebalancing, sweeping local liquidity), and
2. **Systemic macro liquidity flow** (real capital moving across asset classes).

Cross-symbol conditioning resolves this. If the S&P 500, Dow Jones, and DAX are simultaneously trending upward on closed bars, a breakout on the Nasdaq is supported by institutional beta, not local noise. If Gold rallies while Silver refuses to confirm (metals divergence), or if Gold rallies while USDJPY strengthens (real yields rising), the move is suspect.

Per OWNER directives §11–13, the hypotheses below employ **multi-condition, multi-symbol rules**:
- **Reference Market Condition:** Evaluated strictly on **closed bars** prior to the trade execution window (zero look-ahead).
- **Execution Market Trigger:** Market entry at the open of the bar immediately following signal confirmation.
- **Stop Loss:** Scaled strictly to macro volatility ($\ge 0.35 \times \text{cash ATR}$ or $\ge 0.50 \times H1\text{-ATR}$).
- **Exit:** Strictly session-flat prior to 16:30 America/New_York (0% overnight inventory).

---

## 3. Suite of Twelve Original Cross-Symbol Hypotheses

The twelve hypotheses below cover the four mandated domains of the OWNER §12 map:
1. **Indices:** H-CS01, H-CS02, H-CS03, H-CS04
2. **Metals:** H-CS05, H-CS06, H-CS07, H-CS08
3. **FX:** H-CS09, H-CS10, H-CS11
4. **Energy & Commodities:** H-CS12

```
+-----------------------------------------------------------------------------------------------------------+
|                                    CROSS-SYMBOL HYPOTHESIS MASTER MAP                                     |
+---------+--------------------+------------------+------------------+-----+---------------+----------------+
| ID      | Domain Mapping     | Execution Market | Reference Market | TF  | NY Window ET  | Target Density |
+---------+--------------------+------------------+------------------+-----+---------------+----------------+
| H-CS01  | DAX -> US Open     | SP500.DWX        | GDAXI.DWX        | M15 | 09:30 - 15:45 | 0.42 / bd      |
| H-CS02  | SP500 -> NDX       | NDX.DWX          | SP500.DWX        | M15 | 10:00 - 15:45 | 0.48 / bd      |
| H-CS03  | WS30/NDX -> SP500  | SP500.DWX        | WS30 & NDX       | M15 | 10:15 - 15:45 | 0.38 / bd      |
| H-CS04  | Overnight -> Cash  | NDX.DWX          | SP500.DWX        | M30 | 10:00 - 15:45 | 0.45 / bd      |
| H-CS05  | Silver -> Gold     | XAUUSD.DWX       | XAGUSD.DWX       | M15 | 08:30 - 13:30 | 0.40 / bd      |
| H-CS06  | USDJPY -> Gold     | XAUUSD.DWX       | USDJPY.DWX       | M15 | 09:30 - 14:00 | 0.35 / bd      |
| H-CS07  | London -> NY Gold  | XAUUSD.DWX       | London Fix (XAU) | M15 | 08:30 - 13:00 | 0.44 / bd      |
| H-CS08  | Metals Divergence  | XAGUSD.DWX       | XAUUSD.DWX       | M15 | 09:00 - 15:00 | 0.36 / bd      |
| H-CS09  | Equities -> USDJPY | USDJPY.DWX       | SP500.DWX        | M15 | 10:00 - 15:45 | 0.42 / bd      |
| H-CS10  | London -> NY FX    | EURUSD.DWX       | GBPUSD.DWX       | M15 | 08:30 - 16:00 | 0.50 / bd      |
| H-CS11  | USD Basket -> Fix  | GBPUSD.DWX       | EURUSD & USDJPY  | M5  | 10:15 - 11:15 | 0.38 / bd      |
| H-CS12  | WTI Oil -> CAD     | USDCAD.DWX       | XTIUSD.DWX       | M15 | 09:00 - 16:00 | 0.41 / bd      |
+---------+--------------------+------------------+------------------+-----+---------------+----------------+
```

---

### Hypothesis H-CS01: European Afternoon Cash Trend Transmission to US Open
- **HYPOTHESIS_ID:** `H-CS01_DAX_SP500_MOMENTUM_TRANSMISSION`
- **ECONOMIC_RATIONALE:** The Frankfurt/European equity session (GDAXI) has traded for 6.5 hours by the time the US cash equity market opens (09:30 ET / 15:30 CET). Institutional global equity allocators who accumulate or liquidate risk in Europe transmit their order flow to US broad-market index futures (S&P 500). If the DAX establishes a clean directional afternoon trend prior to 09:30 ET without exhaustion, the US cash open inherits this macro momentum, driving continuation in the S&P 500.
- **SYMBOLS:** `GDAXI.DWX` (reference), `SP500.DWX` (execution).
- **EXECUTION_SYMBOL:** `SP500.DWX`.
- **REFERENCE_SYMBOLS:** `GDAXI.DWX`.
- **TIMEFRAME:** M15.
- **SESSION:** New York Cash Session (09:30–15:45 America/New_York).
- **ENTRY_RULE:** 
  1. *Reference Condition (Closed Bars):* On `GDAXI.DWX`, measure European afternoon return from 07:00 ET (13:00 CET) to 09:15 ET (15:15 CET, completed closed bar).
     $$\Delta_{\text{DAX}} = \text{Close}_{\text{09:15 ET}} - \text{Open}_{\text{07:00 ET}}$$
     Qualify if $|\Delta_{\text{DAX}}| \ge 0.30 \times ATR(14, D1_{\text{DAX}})$ AND `GDAXI` 09:15 ET close is on the trending side of its 20-bar M15 SMA.
  2. *Execution Trigger:* On `SP500.DWX`, evaluate the first 15-minute cash bar (09:30–09:45 ET). If the 09:45 ET bar closes in the same direction as $\Delta_{\text{DAX}}$ with a body $\ge 40\%$ of its range:
  3. *Entry:* Execute market order at open of the 09:45 ET bar (filled at 09:45:00 open $+ \text{half\_spread} + \text{slippage}$).
- **STOP_RULE:** Structural ATR stop. Stop distance $= \max(0.40 \times ATR(14, D1_{\text{SP500}}), \text{Low/High of 09:30–09:45 bar})$. Minimum stop floor: $8.0\text{ index points}$ ($> 8\times$ round-trip friction).
- **EXIT_RULE:** 
  - Profit Target: $1.75 \times \text{Stop Distance}$ (limit order).
  - Time Exit: Mandatory market flat at 15:45 America/New_York (no overnight holding).
- **RISK_RULE:** $1,000\text{ USD}$ fixed risk per trade ($1.0\%$ in prescreen; $0.25\%$ in portfolio integration). Max 1 trade per day.
- **EXPECTED_BOOK_ROLE:** Fills the missing NY cash-session index role; generates positive drift during 10:00–15:45 ET.
- **EXPECTED_OVERLAP:** Zero overlap with incumbent swing sleeves (10403, 10700, 10706, 11422, 41219); zero overlap with Tokyo USDJPY (13213).
- **COST_SENSITIVITY:** Low. Minimum stop $\ge 8.0$ SP500 points vs $0.8$ pt spread+slip prior ($< 10\%$ cost drag).
- **FALSIFICATION_TEST:** Run against randomized DAX returns (scramble DAX direction relative to SP500). If true DAX alignment does not outperform scrambled DAX by $\ge +0.10R$ net $E[R]$, the cross-market transmission hypothesis is falsified.
- **DISCOVERY_SAMPLE:** 2018-07-02 to 2022-12-31 (1,175 business days).
- **VALIDATION_SAMPLE:** 2023-01-01 to 2025-12-31 (782 business days).

---

### Hypothesis H-CS02: S&P Broad-Market Breadth Lead on Tech Momentum Breakout
- **HYPOTHESIS_ID:** `H-CS02_SP500_BREADTH_LEAD_NDX_BREAKOUT`
- **ECONOMIC_RATIONALE:** The S&P 500 represents broad market capitalization (500 components), whereas the Nasdaq 100 is concentrated in mega-cap technology. Tech breakouts that occur while the broader market is lagging or declining frequently fail due to lack of market breadth. Conversely, when the S&P 500 breaks out of its 30-minute Initial Balance (09:30–10:00 ET) and confirms broad institutional buying, high-beta tech (NDX) experiences violent momentum expansion. Using the S&P 500 as an institutional permission filter filters out false tech breakouts.
- **SYMBOLS:** `SP500.DWX` (reference), `NDX.DWX` (execution).
- **EXECUTION_SYMBOL:** `NDX.DWX`.
- **REFERENCE_SYMBOLS:** `SP500.DWX`.
- **TIMEFRAME:** M15.
- **SESSION:** New York Cash Session (10:00–15:45 America/New_York).
- **ENTRY_RULE:** 
  1. *Reference Condition (Closed Data):* Define the S&P 500 Initial Balance range $IB_{\text{SP}} = [\text{Low}_{\text{09:30-10:00}}, \text{High}_{\text{09:30-10:00}}]$. At 10:15 ET (close of bar 3), check if `SP500.DWX` closed above $High(IB_{\text{SP}}) + 0.05 \times ATR(14, D1_{\text{SP500}})$ (for longs) or below $Low(IB_{\text{SP}}) - 0.05 \times ATR(14, D1_{\text{SP500}})$ (for shorts).
  2. *Execution Trigger:* On `NDX.DWX`, the 10:15 ET bar must also close outside its own 09:30–10:00 Initial Balance in the same direction, with body $\ge 50\%$ of range.
  3. *Entry:* Market entry at the open of the 10:30 ET bar (at 10:15:00 server open).
- **STOP_RULE:** Stop placed at the midpoint of the NDX Initial Balance (09:30–10:00 range), with a hard minimum floor of $0.35 \times ATR(14, D1_{\text{NDX}})$ (typically 45–70 NDX points).
- **EXIT_RULE:** 
  - Profit Target: $1.75 \times \text{Stop Distance}$.
  - Trail: If profit reaches $+1.0R$, move stop to Breakeven $+ 5\text{ NDX points}$.
  - Time Exit: Mandatory market flat at 15:45 America/New_York.
- **RISK_RULE:** $1,000\text{ USD}$ fixed risk per trade. Max 1 trade per day.
- **EXPECTED_BOOK_ROLE:** High-velocity NY afternoon momentum engine; shifts P80 days-to-payout left.
- **EXPECTED_OVERLAP:** Zero position overlap with incumbent portfolio.
- **COST_SENSITIVITY:** Very Low. Stop scale $\approx 50\text{ points}$; FTMO spread+slip prior $= 1.5\text{ points}$ ($< 3\%$ cost-to-risk ratio).
- **FALSIFICATION_TEST:** Remove the S&P 500 filter (execute on NDX IB break alone, identical to failed H-AG2). If the dual-index condition does not improve $PF$ by $\ge 0.25$ over the standalone NDX break, the breadth-lead thesis is falsified.
- **DISCOVERY_SAMPLE:** 2018-07-02 to 2022-12-31.
- **VALIDATION_SAMPLE:** 2023-01-01 to 2025-12-31.

---

### Hypothesis H-CS03: Industrial vs Tech Divergence Catch-Up (Dow & Nasdaq -> S&P 500)
- **HYPOTHESIS_ID:** `H-CS03_INDEX_TRIANGLE_DIVERGENCE_CATCHUP`
- **ECONOMIC_RATIONALE:** The Dow Jones (WS30, value/cyclical) and Nasdaq (NDX, growth/tech) represent the two ideological wings of US equities. The S&P 500 is the composite. When both the Dow and the Nasdaq establish simultaneous directional momentum in the first 45 minutes of cash trading (10:15 ET), the S&P 500 is statistically compelled to converge toward their joint direction due to index arbitrage and ETF basket balancing (SPY vs QQQ + DIA). If the S&P has lagged the move, entering the S&P captures low-risk, mechanical index convergence.
- **SYMBOLS:** `WS30.DWX` (reference), `NDX.DWX` (reference), `SP500.DWX` (execution).
- **EXECUTION_SYMBOL:** `SP500.DWX`.
- **REFERENCE_SYMBOLS:** `WS30.DWX`, `NDX.DWX`.
- **TIMEFRAME:** M15.
- **SESSION:** New York Cash Session (10:15–15:45 America/New_York).
- **ENTRY_RULE:** 
  1. *Reference Condition (Closed Data at 10:15 ET):*
     - On `WS30.DWX`, normalized return since 09:30 open: $R_{\text{WS}} = (\text{Close}_{\text{10:15}} - \text{Open}_{\text{09:30}}) / ATR(14, D1_{\text{WS}})$.
     - On `NDX.DWX`, normalized return since 09:30 open: $R_{\text{NDX}} = (\text{Close}_{\text{10:15}} - \text{Open}_{\text{09:30}}) / ATR(14, D1_{\text{NDX}})$.
     - Condition: $\text{sign}(R_{\text{WS}}) == \text{sign}(R_{\text{NDX}})$ AND $|R_{\text{WS}}| \ge 0.20$ AND $|R_{\text{NDX}}| \ge 0.20$. Both wings are strongly aligned.
  2. *Execution Trigger:* On `SP500.DWX`, normalized return $R_{\text{SP}} = (\text{Close}_{\text{10:15}} - \text{Open}_{\text{09:30}}) / ATR(14, D1_{\text{SP}})$.
     - Condition: $\text{sign}(R_{\text{SP}}) == \text{sign}(R_{\text{WS}})$ but $|R_{\text{SP}}| \le 0.50 \times \min(|R_{\text{WS}}|, |R_{\text{NDX}}|)$ (S&P has lagged the wings).
  3. *Entry:* Market order at open of 10:30 ET bar in the direction of the joint move.
- **STOP_RULE:** Extreme of the 09:30–10:15 ET S&P range against the position, with a minimum stop of $0.35 \times ATR(14, D1_{\text{SP500}})$ ($\ge 12\text{ index points}$).
- **EXIT_RULE:** 
  - Profit Target: When S&P normalized return matches the average of the wings ($R_{\text{SP}} \ge 0.85 \times \frac{R_{\text{WS}} + R_{\text{NDX}}}{2}$), or $1.5 \times \text{Stop Distance}$.
  - Time Exit: Flat at 15:45 America/New_York.
- **RISK_RULE:** $1,000\text{ USD}$ fixed risk per trade. Max 1 trade per day.
- **EXPECTED_BOOK_ROLE:** High win-rate index convergence engine.
- **EXPECTED_OVERLAP:** Zero overnight risk; zero overlap with FX/Gold sleeves.
- **COST_SENSITIVITY:** Low. Minimum stop $\ge 12$ points vs $0.8$ pt spread prior.
- **FALSIFICATION_TEST:** Test with $R_{\text{WS}}$ and $R_{\text{NDX}}$ opposed (one positive, one negative). If opposed wings produce similar returns on S&P, the arbitrage convergence mechanism is invalid.
- **DISCOVERY_SAMPLE:** 2018-07-02 to 2022-12-31.
- **VALIDATION_SAMPLE:** 2023-01-01 to 2025-12-31.

---

### Hypothesis H-CS04: Overnight Globex Inventory Imbalance Conditioning NY Cash Trend
- **HYPOTHESIS_ID:** `H-CS04_GLOBEX_INVENTORY_CASH_EXPANSION`
- **ECONOMIC_RATIONALE:** Globex overnight session (18:00–09:15 ET) inventory represents foreign institutional and hedge fund positioning. When the overnight S&P 500 session is substantially one-sided (e.g. overnight range entirely above or below the prior day's cash close) and does NOT mean-revert during the first 30 minutes of cash trading, overnight inventory is "trapped" on the right side of the market, forcing institutional buy/sell programs to chase prices into the cash session. This releases strong momentum in high-beta Nasdaq.
- **SYMBOLS:** `SP500.DWX` (reference), `NDX.DWX` (execution).
- **EXECUTION_SYMBOL:** `NDX.DWX`.
- **REFERENCE_SYMBOLS:** `SP500.DWX`.
- **TIMEFRAME:** M30.
- **SESSION:** New York Cash Session (10:00–15:45 America/New_York).
- **ENTRY_RULE:** 
  1. *Reference Condition (Closed Data prior to 09:30 ET):*
     - On `SP500.DWX`, compute Globex session range (18:00–09:15 ET).
     - Net overnight drift $\Delta_{\text{ON}} = \text{Open}_{\text{09:30}} - \text{Close}_{\text{prior\_cash}}$.
     - Require $|\Delta_{\text{ON}}| \ge 0.35 \times ATR(14, D1_{\text{SP500}})$.
  2. *Cash Acceptance Trigger (at 10:00 ET close):*
     - The first 30-min cash bar (09:30–10:00 ET) on `SP500.DWX` must close in the direction of $\Delta_{\text{ON}}$ (no immediate gap fill).
  3. *Execution Trigger:* On `NDX.DWX`, the 09:30–10:00 ET bar must also close in the direction of $\Delta_{\text{ON}}$.
  4. *Entry:* Execute market order on `NDX.DWX` at the open of the 10:00 ET bar.
- **STOP_RULE:** Stop placed at the opposite extreme of the 09:30–10:00 NDX bar. Minimum stop floor $= 0.40 \times ATR(14, D1_{\text{NDX}})$ (min 50 points).
- **EXIT_RULE:** 
  - Profit Target: $2.0 \times \text{Stop Distance}$.
  - Time Exit: Mandatory close at 15:45 America/New_York.
- **RISK_RULE:** $1,000\text{ USD}$ fixed risk per trade. Max 1 trade per day.
- **EXPECTED_BOOK_ROLE:** Trend-day harvester; provides large R-multiple wins on true momentum days.
- **EXPECTED_OVERLAP:** Zero overlap with incumbent book.
- **COST_SENSITIVITY:** Very Low. Stop is macro-scale (50–90 NDX points).
- **FALSIFICATION_TEST:** Evaluate performance when the first 30-minute cash bar closes *against* the overnight drift (gap-fill days). If continuation performs equally well on gap-fill days, the "trapped inventory" thesis is falsified.
- **DISCOVERY_SAMPLE:** 2018-07-02 to 2022-12-31.
- **VALIDATION_SAMPLE:** 2023-01-01 to 2025-12-31.

---

### Hypothesis H-CS05: High-Beta Silver Lead Confirmation of COMEX Gold Breakout
- **HYPOTHESIS_ID:** `H-CS05_SILVER_BETA_CONFIRMATION_GOLD`
- **ECONOMIC_RATIONALE:** Silver (XAGUSD) is a higher-beta, lower-liquidity industrial precious metal that frequently leads Gold (XAUUSD) during major liquidity-driven or inflationary breakouts. When Gold attempts a breakout of its European morning range (03:00–08:00 ET) at the COMEX pit open (08:20 ET), false breakouts are rampant if Gold is moving in isolation. However, if Silver has already broken its corresponding European range by a wider margin ($\ge 1.5\times$ Gold's relative percentage move), institutional demand for precious metals is authenticated, triggering high-probability momentum in Gold.
- **SYMBOLS:** `XAGUSD.DWX` (reference), `XAUUSD.DWX` (execution).
- **EXECUTION_SYMBOL:** `XAUUSD.DWX`.
- **REFERENCE_SYMBOLS:** `XAGUSD.DWX`.
- **TIMEFRAME:** M15.
- **SESSION:** COMEX NY Cash Open (08:30–13:30 America/New_York).
- **ENTRY_RULE:** 
  1. *Reference Range (03:00–08:00 ET):* Compute high and low of the 03:00–08:00 ET window for both `XAUUSD.DWX` and `XAGUSD.DWX`.
  2. *Silver Lead Condition (Closed Bar at 08:30 ET):*
     - On `XAGUSD.DWX`, the 08:15–08:30 ET bar closes outside its 03:00–08:00 range by at least $0.20 \times ATR(14, H1_{\text{XAG}})$.
  3. *Gold Trigger (Closed Bar at 08:30 ET):*
     - `XAUUSD.DWX` 08:15–08:30 ET bar closes outside its 03:00–08:00 range in the same direction.
  4. *Entry:* Market order at the open of the 08:30 ET bar on `XAUUSD.DWX`.
- **STOP_RULE:** Stop loss $= 0.75 \times ATR(14, H1_{\text{XAU}})$ (typically $\$8.00 - \$14.00\text{ USD}$ on Gold). Never tighter than $\$6.00\text{ USD}$.
- **EXIT_RULE:** 
  - Profit Target: $1.5 \times \text{Stop Distance}$.
  - Time Exit: Mandatory flat at 13:30 America/New_York (COMEX pit settlement window).
- **RISK_RULE:** $1,000\text{ USD}$ fixed risk per trade. Max 1 trade per day.
- **EXPECTED_BOOK_ROLE:** Session-flat Gold alpha; replaces fragile single-symbol Gold sweep rules (H-AG5, H-B7).
- **EXPECTED_OVERLAP:** Position overlap with QM5_10700 and QM5_10403 on breakout days, but **zero overnight inventory** and flat by 13:30 ET.
- **COST_SENSITIVITY:** Low. Minimum stop $\ge \$6.00$ vs $0.44\text{ USD}$ FTMO spread prior ($< 8\%$ friction).
- **FALSIFICATION_TEST:** Test Gold breakouts when Silver is diverging (e.g. Gold breaks high, Silver breaks low). If Gold breakout performance is identical regardless of Silver's state, cross-metal confirmation is disproven.
- **DISCOVERY_SAMPLE:** 2018-07-02 to 2022-12-31.
- **VALIDATION_SAMPLE:** 2023-01-01 to 2025-12-31.

---

### Hypothesis H-CS06: Real Yield / USDJPY Risk-Off Transmission to COMEX Gold
- **HYPOTHESIS_ID:** `H-CS06_USDJPY_YIELD_TRANSMISSION_GOLD`
- **ECONOMIC_RATIONALE:** Gold is an inverse proxy for US real yields and global risk appetite. USDJPY is the purest FX expression of US-Japan yield differentials and macro carry risk. A sharp drop in USDJPY during the morning NY session reflects falling US Treasury yields and risk-off sentiment. When USDJPY breaks downward out of its London range during the NY morning, institutional safe-haven demand flows into COMEX Gold. Conversely, USDJPY surging higher indicates rising yields and dollar demand, creating severe headwinds for Gold longs.
- **SYMBOLS:** `USDJPY.DWX` (reference), `XAUUSD.DWX` (execution).
- **EXECUTION_SYMBOL:** `XAUUSD.DWX`.
- **REFERENCE_SYMBOLS:** `USDJPY.DWX`.
- **TIMEFRAME:** M15.
- **SESSION:** New York Morning Window (09:30–14:00 America/New_York).
- **ENTRY_RULE:** 
  1. *Reference Condition (Closed Data at 09:45 ET):*
     - On `USDJPY.DWX`, compute net return from 08:00 to 09:45 ET.
     - Require $|\Delta_{\text{UJ}}| \ge 0.30 \times ATR(14, H1_{\text{UJ}})$ ($\ge 25\text{ pips}$).
  2. *Execution Trigger on Gold:*
     - If $\Delta_{\text{UJ}} < -0.30 \times H1\text{-ATR}$ (USDJPY dropping sharply, yields plunging):
       - `XAUUSD.DWX` must close above its 20-bar M15 SMA at 09:45 ET.
       - Enter **BUY** on `XAUUSD.DWX` at the 10:00 ET bar open.
     - If $\Delta_{\text{UJ}} > +0.30 \times H1\text{-ATR}$ (USDJPY surging, yields rising):
       - `XAUUSD.DWX` must close below its 20-bar M15 SMA at 09:45 ET.
       - Enter **SELL** on `XAUUSD.DWX` at the 10:00 ET bar open.
- **STOP_RULE:** Stop loss $= 0.80 \times ATR(14, H1_{\text{XAU}})$ from entry. Minimum floor $\$7.00\text{ USD}$.
- **EXIT_RULE:** 
  - Profit Target: $1.5 \times \text{Stop Distance}$.
  - Time Exit: Mandatory flat at 14:00 America/New_York.
- **RISK_RULE:** $1,000\text{ USD}$ fixed risk per trade. Max 1 trade per day.
- **EXPECTED_BOOK_ROLE:** Macro hedge for incumbent USDJPY Tokyo sleeve (13213); provides orthogonal Gold returns.
- **EXPECTED_OVERLAP:** Downside co-movement with 10700/10403 is low because this sleeve enters only on active USDJPY impulse days.
- **COST_SENSITIVITY:** Low. Minimum stop $\ge \$7.00$ on Gold.
- **FALSIFICATION_TEST:** Randomize USDJPY directional signal (+1 / -1). If true USDJPY yield transmission does not yield positive alpha over randomized USDJPY signals, the macro transmission link is false.
- **DISCOVERY_SAMPLE:** 2018-07-02 to 2022-12-31.
- **VALIDATION_SAMPLE:** 2023-01-01 to 2025-12-31.

---

### Hypothesis H-CS07: London AM/PM Benchmark Fix Drift into COMEX Gold Continuation
- **HYPOTHESIS_ID:** `H-CS07_LONDON_FIX_DRIFT_COMEX_CONTINUATION`
- **ECONOMIC_RATIONALE:** The LBMA Gold Price is determined twice daily (10:30 London / 05:30 ET, and 15:00 London / 10:00 ET). The net institutional drift between the London open (03:00 ET) and the London PM fix (10:00 ET) represents commercial bullion bank positioning. When bullion banks accumulate heavily into the London PM fix (driving price up by $\ge 0.50 \times H1\text{-ATR}$), the COMEX cash session (10:00–13:00 ET) continues this physical flow as US institutional desks take over liquidity provision.
- **SYMBOLS:** `XAUUSD.DWX` (execution & self-reference across London/NY regimes).
- **EXECUTION_SYMBOL:** `XAUUSD.DWX`.
- **REFERENCE_SYMBOLS:** `XAUUSD.DWX` (London morning regime).
- **TIMEFRAME:** M15.
- **SESSION:** COMEX NY Cash Window (10:15–13:30 America/New_York).
- **ENTRY_RULE:** 
  1. *Reference Regime (Closed Data 03:00–10:00 ET):*
     - Measure London session drift: $\Delta_{\text{London}} = \text{Close}_{\text{10:00 ET}} - \text{Open}_{\text{03:00 ET}}$.
     - Require $|\Delta_{\text{London}}| \ge 0.60 \times ATR(14, D1_{\text{XAU}})$ (a decisive London trend day).
  2. *Execution Trigger:* At the close of the 10:15 ET bar (first bar after London PM fix completion):
     - The 10:15 ET bar must close in the direction of $\Delta_{\text{London}}$.
  3. *Entry:* Execute market order in direction of $\Delta_{\text{London}}$ at open of 10:30 ET bar.
- **STOP_RULE:** Structural stop $= \max(0.60 \times ATR(14, H1_{\text{XAU}}), |\text{High}_{\text{09:45-10:15}} - \text{Low}_{\text{09:45-10:15}}|)$. Minimum stop $\$8.00\text{ USD}$.
- **EXIT_RULE:** 
  - Profit Target: $1.5 \times \text{Stop Distance}$.
  - Time Exit: Mandatory flat at 13:30 America/New_York.
- **RISK_RULE:** $1,000\text{ USD}$ fixed risk per trade. Max 1 trade per day.
- **EXPECTED_BOOK_ROLE:** Replaces failed H-B7 and H-B7r with an economically grounded benchmark continuation thesis.
- **EXPECTED_OVERLAP:** Low; trades only on high-displacement London days ($\approx 0.44\text{ trades/bd}$).
- **COST_SENSITIVITY:** Low. Minimum stop $\ge \$8.00$.
- **FALSIFICATION_TEST:** Fading the London move (trading against $\Delta_{\text{London}}$) must produce negative expectancy ($E[R] < -0.10R$). If fading performs equally, the institutional flow persistence is non-existent.
- **DISCOVERY_SAMPLE:** 2018-07-02 to 2022-12-31.
- **VALIDATION_SAMPLE:** 2023-01-01 to 2025-12-31.

---

### Hypothesis H-CS08: Precious Metals Ratio Statistical Arbitrage Mean Reversion
- **HYPOTHESIS_ID:** `H-CS08_METALS_RATIO_EXTREME_REVERSION`
- **ECONOMIC_RATIONALE:** Gold and Silver share fundamental monetary and inflation factors; their price ratio ($\text{Ratio} = \text{Price}_{\text{XAU}} / \text{Price}_{\text{XAG}}$) is heavily cointegrated. During London morning liquidity imbalances, the ratio occasionally stretches beyond its 20-day rolling Bollinger Band ($\pm 2.2\sigma$) due to disparate order sizes. Because Silver is more volatile and elastic, the mean reversion during the liquid New York open (09:00–15:00 ET) expresses predominantly through rapid catch-up in Silver.
- **SYMBOLS:** `XAUUSD.DWX` (reference), `XAGUSD.DWX` (execution).
- **EXECUTION_SYMBOL:** `XAGUSD.DWX`.
- **REFERENCE_SYMBOLS:** `XAUUSD.DWX`.
- **TIMEFRAME:** M15.
- **SESSION:** New York Morning & Afternoon (09:00–15:00 America/New_York).
- **ENTRY_RULE:** 
  1. *Reference Calculation (Closed Bars at 09:00 ET):*
     - Construct rolling ratio: $R_t = \text{Close}_{\text{XAU}, t} / \text{Close}_{\text{XAG}, t}$ on M15 bars over the last 20 trading days (1,920 bars).
     - Compute Z-score of ratio: $Z_t = (R_t - \mu_R) / \sigma_R$.
  2. *Condition at 09:00 ET:*
     - If $Z_t \ge +2.2$ (Gold expensive relative to Silver): Institutional reversion dictates Silver outperformance. Enter **BUY** on `XAGUSD.DWX` at the 09:15 ET open.
     - If $Z_t \le -2.2$ (Silver expensive relative to Gold): Enter **SELL** on `XAGUSD.DWX` at the 09:15 ET open.
- **STOP_RULE:** Stop loss on `XAGUSD.DWX` $= 0.75 \times ATR(14, H1_{\text{XAG}})$ (typically $\$0.35 - \$0.60\text{ USD}$ on Silver). Minimum stop $\$0.30\text{ USD}$.
- **EXIT_RULE:** 
  - Profit Target: When $Z_t$ crosses back inside $\pm 0.5\sigma$, or $1.75 \times \text{Stop Distance}$.
  - Time Exit: Mandatory close at 15:00 America/New_York.
- **RISK_RULE:** $1,000\text{ USD}$ fixed risk per trade. Max 1 trade per day.
- **EXPECTED_BOOK_ROLE:** True market-neutral relative-value engine; very low correlation to directional equity or Gold trends.
- **EXPECTED_OVERLAP:** Zero overlap with incumbent book (no Silver exposure in incumbent).
- **COST_SENSITIVITY:** Moderate. Silver spread on FTMO is $\approx 2.5 - 3.5\text{ cents}$; minimum stop is $30\text{ cents}$ ($< 10\%$ cost ratio).
- **FALSIFICATION_TEST:** Test with $Z$-score bands randomized or inverted ($Z \in [-0.5, +0.5]$). Reversion edge must concentrate strictly at the extremes ($|Z| \ge 2.2$).
- **DISCOVERY_SAMPLE:** 2018-07-02 to 2022-12-31.
- **VALIDATION_SAMPLE:** 2023-01-01 to 2025-12-31.

---

### Hypothesis H-CS09: Equity Cash Open Risk-On Transmission to USDJPY
- **HYPOTHESIS_ID:** `H-CS09_EQUITY_IMPULSE_USDJPY_MOMENTUM`
- **ECONOMIC_RATIONALE:** Under standard macro regimes, equity market strength represents global risk appetite, driving carry-trade inflows that weaken the Japanese Yen and push USDJPY higher. When the US equity market (SP500) opens with a strong, sustained institutional push in the first 30 minutes (09:30–10:00 ET), the FX market responds with a lag. Trading USDJPY in the direction of the S&P 500 cash-open impulse captures this cross-asset carry transmission.
- **SYMBOLS:** `SP500.DWX` (reference), `USDJPY.DWX` (execution).
- **EXECUTION_SYMBOL:** `USDJPY.DWX`.
- **REFERENCE_SYMBOLS:** `SP500.DWX`.
- **TIMEFRAME:** M15.
- **SESSION:** New York Cash Session (10:00–15:45 America/New_York).
- **ENTRY_RULE:** 
  1. *Reference Condition on S&P 500 (Closed Data at 10:00 ET):*
     - Measure S&P 500 Initial Balance impulse: $\Delta_{\text{SP}} = \text{Close}_{\text{10:00 ET}} - \text{Open}_{\text{09:30 ET}}$.
     - Require $|\Delta_{\text{SP}}| \ge 0.25 \times ATR(14, D1_{\text{SP500}})$ with the 10:00 bar closing near its extreme (body $\ge 50\%$ of range).
  2. *Execution Trigger on USDJPY:*
     - At 10:00 ET, check if `USDJPY.DWX` 09:45–10:00 bar confirmed direction: $\text{sign}(\text{Close}_{\text{10:00}} - \text{Open}_{\text{09:45}}) == \text{sign}(\Delta_{\text{SP}})$.
  3. *Entry:* Enter market order on `USDJPY.DWX` at the open of the 10:15 ET bar in the direction of $\Delta_{\text{SP}}$.
- **STOP_RULE:** Stop loss $= 0.60 \times ATR(14, H1_{\text{UJ}})$ (typically $25 - 40\text{ pips}$). Minimum stop floor: $22\text{ pips}$ ($> 15\times$ FTMO spread+slip prior).
- **EXIT_RULE:** 
  - Profit Target: $1.5 \times \text{Stop Distance}$.
  - Time Exit: Mandatory flat at 15:45 America/New_York.
- **RISK_RULE:** $1,000\text{ USD}$ fixed risk per trade. Max 1 trade per day.
- **EXPECTED_BOOK_ROLE:** High-density session-flat FX momentum engine.
- **EXPECTED_OVERLAP:** Zero time overlap with incumbent QM5_13213 (which trades Tokyo 03:00–06:00 server time and is flat by early London).
- **COST_SENSITIVITY:** Extremely Low. USDJPY spread on FTMO is $\approx 1.0\text{ pip}$; stop is $\ge 22\text{ pips}$ ($< 5\%$ cost drag).
- **FALSIFICATION_TEST:** Run during declared risk-off regimes (VIX $> 30$ or SP500 below 200-day MA). If carry transmission inverts during crisis regimes, confirm regime-gating parameter.
- **DISCOVERY_SAMPLE:** 2018-07-02 to 2022-12-31.
- **VALIDATION_SAMPLE:** 2023-01-01 to 2025-12-31.

---

### Hypothesis H-CS10: European Currency Relative Momentum Continuation into NY Overlap
- **HYPOTHESIS_ID:** `H-CS10_EUR_GBP_RELATIVE_MOMENTUM_OVERLAP`
- **ECONOMIC_RATIONALE:** EURUSD and GBPUSD share the common USD quote leg and European macroeconomic proximity. During the London morning session (03:00–08:00 ET), macroeconomic surprises create persistent directional trends. When both EURUSD and GBPUSD establish strong, joint directional momentum into the 08:30 ET US economic release / London overlap window, institutional order flow from London continues to dictate the trend through the NY morning. Selecting EURUSD (lower spread, tighter execution) when confirmed by GBPUSD eliminates false FX chop.
- **SYMBOLS:** `GBPUSD.DWX` (reference), `EURUSD.DWX` (execution).
- **EXECUTION_SYMBOL:** `EURUSD.DWX`.
- **REFERENCE_SYMBOLS:** `GBPUSD.DWX`.
- **TIMEFRAME:** M15.
- **SESSION:** London / New York Overlap (08:30–16:00 America/New_York).
- **ENTRY_RULE:** 
  1. *Reference Condition (Closed Data 03:00–08:15 ET):*
     - On `GBPUSD.DWX`: $\Delta_{\text{GBP}} = \text{Close}_{\text{08:15}} - \text{Open}_{\text{03:00}}$. Require $|\Delta_{\text{GBP}}| \ge 0.35 \times ATR(14, D1_{\text{GBP}})$.
     - On `EURUSD.DWX`: $\Delta_{\text{EUR}} = \text{Close}_{\text{08:15}} - \text{Open}_{\text{03:00}}$. Require $|\Delta_{\text{EUR}}| \ge 0.35 \times ATR(14, D1_{\text{EUR}})$.
     - Alignment: $\text{sign}(\Delta_{\text{GBP}}) == \text{sign}(\Delta_{\text{EUR}})$. Both European majors are aggressively moving against or with the Dollar.
  2. *Retracement Qualifier:* In the 08:00–08:30 ET pre-NY window, EURUSD has retraced $\le 38.2\%$ of its London move.
  3. *Entry:* Market order at the open of the 08:30 ET bar in the direction of the London trend.
- **STOP_RULE:** Stop loss $= 0.65 \times ATR(14, H1_{\text{EUR}})$ (typically $25 - 35\text{ pips}$). Minimum stop floor: $20\text{ pips}$.
- **EXIT_RULE:** 
  - Profit Target: $1.5 \times \text{Stop Distance}$.
  - Time Exit: Mandatory flat at 16:00 America/New_York.
- **RISK_RULE:** $1,000\text{ USD}$ fixed risk per trade. Max 1 trade per day.
- **EXPECTED_BOOK_ROLE:** High-density, robust FX session-flat alpha; immune to overnight swap drag.
- **EXPECTED_OVERLAP:** Zero overnight risk; independent from incumbent D1 swing sleeves.
- **COST_SENSITIVITY:** Extremely Low. EURUSD spread is $0.8 - 1.0\text{ pip}$ vs $25\text{ pip}$ stop ($< 4\%$ drag).
- **FALSIFICATION_TEST:** Test when GBPUSD and EURUSD are divergent (one up, one down). Divergent days must fail to produce profitable continuation ($PF < 1.0$).
- **DISCOVERY_SAMPLE:** 2018-07-02 to 2022-12-31.
- **VALIDATION_SAMPLE:** 2023-01-01 to 2025-12-31.

---

### Hypothesis H-CS11: WMR 16:00 London Fix Multi-Currency Pre-Hedge
- **HYPOTHESIS_ID:** `H-CS11_WMR_FIX_MULTI_CURRENCY_PRE_HEDGE`
- **ECONOMIC_RATIONALE:** The 16:00 London fix (11:00 America/New_York) is the dominant global benchmark for institutional portfolio equity rebalancing. When international asset managers rebalance global equity portfolios, cross-border FX hedging flows peak between 10:15 and 10:55 ET. If the broad Dollar (measured across EURUSD, GBPUSD, and USDJPY) exhibits a persistent directional imbalance leading into 10:15 ET, fix execution desks push GBPUSD in the direction of the required fix flow until 10:59 ET, followed by an immediate post-fix stall.
- **SYMBOLS:** `EURUSD.DWX` (reference), `USDJPY.DWX` (reference), `GBPUSD.DWX` (execution).
- **EXECUTION_SYMBOL:** `GBPUSD.DWX`.
- **REFERENCE_SYMBOLS:** `EURUSD.DWX`, `USDJPY.DWX`.
- **TIMEFRAME:** M5.
- **SESSION:** WMR Pre-Fix Window (10:15–11:05 America/New_York).
- **ENTRY_RULE:** 
  1. *Synthetic Dollar Basket Condition (Closed Bars 09:30–10:15 ET):*
     - Define Dollar Index return proxy: $\Delta_{\text{USD}} = -0.50 \times \Delta\%_{\text{EUR}} - 0.30 \times \Delta\%_{\text{GBP}} + 0.20 \times \Delta\%_{\text{JPY}}$ over the 09:30–10:15 ET window.
     - Require $|\Delta_{\text{USD}}| \ge 0.15\%$ (a clean pre-fix Dollar trend).
  2. *Execution Trigger on GBPUSD:*
     - At the 10:15 ET bar close, if $\Delta_{\text{USD}} > +0.15\%$ (Dollar demand): Enter **SELL** on `GBPUSD.DWX`.
     - If $\Delta_{\text{USD}} < -0.15\%$ (Dollar supply): Enter **BUY** on `GBPUSD.DWX`.
  3. *Entry:* Market order at open of 10:20 ET bar.
- **STOP_RULE:** Structural stop $= 0.40 \times ATR(14, H1_{\text{GBP}})$ (min $18\text{ pips}$).
- **EXIT_RULE:** 
  - Time Exit: **Mandatory market exit at 11:05 America/New_York** (immediately following the 16:00 London / 11:00 ET fix window). No overnight holding; maximum hold 45 minutes.
  - Profit Target: $1.25 \times \text{Stop Distance}$.
- **RISK_RULE:** $1,000\text{ USD}$ fixed risk per trade. Max 1 trade per day.
- **EXPECTED_BOOK_ROLE:** Short-duration institutional flow harvester.
- **EXPECTED_OVERLAP:** Zero overnight inventory; completely uncorrelated with incumbent swing sleeves.
- **COST_SENSITIVITY:** Low. Minimum stop $\ge 18\text{ pips}$ vs $1.2\text{ pip}$ spread.
- **FALSIFICATION_TEST:** Shift the trade window by 1 hour (execute at 11:15–12:05 ET post-fix). If the edge persists after the fix has closed, the WMR institutional rebalancing thesis is falsified.
- **DISCOVERY_SAMPLE:** 2018-07-02 to 2022-12-31.
- **VALIDATION_SAMPLE:** 2023-01-01 to 2025-12-31.

---

### Hypothesis H-CS12: NYMEX WTI Crude Oil Cash Momentum Transmission to USDCAD
- **HYPOTHESIS_ID:** `H-CS12_WTI_MOMENTUM_USDCAD_TRANSMISSION`
- **ECONOMIC_RATIONALE:** Canada is a major net energy exporter; the Canadian Dollar (CAD) is heavily tethered to West Texas Intermediate crude oil (XTIUSD / WTI). The NYMEX energy open occurs at 09:00 ET. When oil experiences a heavy directional volume surge between 09:00 and 10:00 ET, commercial hedgers and commodity funds immediately rebalance CAD inventory. Because oil volatility is high and FX is liquid, a decisive move in crude oil transmits an inverse impulse to USDCAD (rising oil strengthens CAD $\rightarrow$ drops USDCAD).
- **SYMBOLS:** `XTIUSD.DWX` (reference), `USDCAD.DWX` (execution).
- **EXECUTION_SYMBOL:** `USDCAD.DWX`.
- **REFERENCE_SYMBOLS:** `XTIUSD.DWX`.
- **TIMEFRAME:** M15.
- **SESSION:** NYMEX / NY Cash Session (10:00–16:00 America/New_York).
- **ENTRY_RULE:** 
  1. *Reference Oil Impulse (Closed Data 09:00–10:00 ET):*
     - On `XTIUSD.DWX`, compute return: $\Delta_{\text{Oil}} = \text{Close}_{\text{10:00}} - \text{Open}_{\text{09:00}}$.
     - Require $|\Delta_{\text{Oil}}| \ge 0.50 \times ATR(14, H1_{\text{Oil}})$ ($\ge \$0.60 - \$1.00\text{ USD}$ on oil).
  2. *Execution Trigger on USDCAD:*
     - If $\Delta_{\text{Oil}} \ge +0.50 \times H1\text{-ATR}$ (Oil surging): Enter **SELL** on `USDCAD.DWX` at the 10:15 ET bar open.
     - If $\Delta_{\text{Oil}} \le -0.50 \times H1\text{-ATR}$ (Oil plunging): Enter **BUY** on `USDCAD.DWX` at the 10:15 ET bar open.
- **STOP_RULE:** Stop loss $= 0.65 \times ATR(14, H1_{\text{CAD}})$ (typically $25 - 35\text{ pips}$). Minimum floor: $20\text{ pips}$.
- **EXIT_RULE:** 
  - Profit Target: $1.5 \times \text{Stop Distance}$.
  - Time Exit: Mandatory flat at 16:00 America/New_York.
- **RISK_RULE:** $1,000\text{ USD}$ fixed risk per trade. Max 1 trade per day.
- **EXPECTED_BOOK_ROLE:** Commodity-FX transmission sleeve; diversifies away from index/gold risk.
- **EXPECTED_OVERLAP:** Incumbent sleeve QM5_11422 trades USDCAD on D1 (swing). This sleeve is **strictly session-flat** (0% overnight), targeting intraday transmission.
- **COST_SENSITIVITY:** Very Low. FTMO USDCAD spread is $1.2\text{ pips}$ vs $25\text{ pip}$ stop ($< 5\%$ drag).
- **FALSIFICATION_TEST:** Test during OPEC meeting blackout dates and macro oil inventory release days (Wednesday EIA 10:30 ET). If transmission fails outside scheduled inventory releases, the edge is news-dependent rather than institutional flow.
- **DISCOVERY_SAMPLE:** 2018-07-02 to 2022-12-31.
- **VALIDATION_SAMPLE:** 2023-01-01 to 2025-12-31.

---

## 4. Adversarial Attack on Each Hypothesis

Per Requirement 3, every hypothesis must face an adversarial challenge targeting its specific vulnerability (microstructure, execution friction, look-ahead risk, regime dependence, and `.DWX` custom history data artifacts).

```
+---------------------------------------------------------------------------------------------------------------+
|                                      ADVERSARIAL ATTACK & SURVIVAL AUDIT                                      |
+---------+--------------------------------------------------+---------------------+----------------------------+
| ID      | Primary Structural Attack Vector                 | Severity of Threat  | Paper Survival Verdict     |
+---------+--------------------------------------------------+---------------------+----------------------------+
| H-CS01  | Euro close liquidity vacuum at 11:30 ET          | Moderate            | SURVIVES (macro confirmed) |
| H-CS02  | Tech mega-cap decoupling (Mag-7 earnings days)   | Low                 | SURVIVES (strongest index) |
| H-CS03  | Index chop / triangle paralysis in range regimes | High                | FRAGILE (needs trend gate) |
| H-CS04  | Globex synthetic history gap artifact in .DWX    | High                | HIGH RISK (data artifact)  |
| H-CS05  | Silver illiquidity spike widening spread         | Moderate            | SURVIVES (metals lead)     |
| H-CS06  | BoJ intervention headline whipsaws               | High                | FRAGILE (headline risk)    |
| H-CS07  | COMEX opening auction re-pricing shock           | Moderate            | SURVIVES (benchmark flow)  |
| H-CS08  | Long-term structural drift in Gold/Silver ratio  | High                | HIGH RISK (trend runaway)  |
| H-CS09  | Risk-on / Yield regime decoupling                | Moderate            | SURVIVES (FX momentum)     |
| H-CS10  | US 08:30 ET NFP/CPI release gap-through          | Severe              | FRAGILE (blackout critical)|
| H-CS11  | Micro-scale 45m hold; cost drag in low-vol years | Severe              | HIGH RISK (cost sensitive) |
| H-CS12  | US-Canada monetary policy divergence dominance   | Moderate            | SURVIVES (petrodollar link)|
+---------+--------------------------------------------------+---------------------+----------------------------+
```

### Detailed Attack Analysis:

1. **Attack on H-CS01 (DAX -> S&P 500):**
   - *Attack:* The European cash market closes at 11:30 ET (17:30 CET). At 11:30 ET, European liquidity evaporates, frequently causing a sharp mid-day reversal ("lunchtime lull") in US indices. A continuation trade entered at 09:45 ET might reach $+0.8R$ by 11:15 ET only to be stopped out during the European fix unwind.
   - *Paper Verdict:* **SURVIVES**. The trade incorporates an ATR-scale stop ($\ge 8$ pts) that withstands normal 11:30 ET chop, and targets institutional momentum that spans the full US morning.

2. **Attack on H-CS02 (S&P 500 -> NDX Breakout):**
   - *Attack:* Mega-cap technology (Apple, Microsoft, Nvidia) often moves independently of the other 493 S&P stocks during earnings cycles. If tech is dumping on earnings while the other sectors rally, the S&P 500 IB breakout condition will signal LONG while the Nasdaq collapses, creating an immediate stop-out.
   - *Paper Verdict:* **SURVIVES**. The rule requires *both* S&P and NDX to break their respective Initial Balances in the same direction. If tech decouples, NDX will not break its IB, and no trade is triggered. This is our mathematically cleanest index candidate.

3. **Attack on H-CS03 (Dow & Nasdaq -> S&P 500):**
   - *Attack:* Look-ahead and synchronization risk. S&P 500 often moves *faster* than the Dow; days where the Dow and Nasdaq have moved by $0.20 \times D1\text{-ATR}$ while S&P has moved $\le 0.10 \times D1\text{-ATR}$ are rare low-volatility anomalies. When S&P lags, it may not be "lagging"—it may be pinned by conflicting internal sector rotations (energy up, tech down).
   - *Paper Verdict:* **FRAGILE**. Survives only if an explicit sector-variance filter is added.

4. **Attack on H-CS04 (Globex Overnight -> NY Cash):**
   - *Attack:* **Severe `.DWX` custom history artifact risk**. The `.hcc` history files in MT5 for `SP500.DWX` and `NDX.DWX` are CFD broker feeds. Overnight Globex bar density between 18:00 and 03:00 ET is notoriously sparse in retail CFD feeds, with missing ticks and artificial holiday gaps. Calculating an accurate overnight range on broker CFDs without a centralized CME futures feed risks generating phantom signals.
   - *Paper Verdict:* **HIGH RISK**. While the economic logic is sound, broker data artifacts make backtest verification dangerous.

5. **Attack on H-CS05 (Silver -> Gold Breakout):**
   - *Attack:* Silver's bid-ask spread widens dramatically on FTMO during the pre-market (08:00–08:30 ET), frequently exceeding 5–8 cents. A false breakout on Silver caused by thin liquidity could drag Gold into a bad trade.
   - *Paper Verdict:* **SURVIVES**. Silver is used *only as a reference condition* on closed M15 bars; execution occurs on Gold (`XAUUSD.DWX`), which enjoys massive COMEX liquidity and tight spreads ($0.44\text{ USD}$).

6. **Attack on H-CS06 (USDJPY -> Gold):**
   - *Attack:* Headline risk and BoJ intervention. USDJPY moves during NY morning are often driven by US interest rate headlines or Bank of Japan verbal intervention. When BoJ intervenes, USDJPY collapses, but Gold does NOT rally because the move is Yen-specific, not a drop in US real yields.
   - *Paper Verdict:* **FRAGILE**. Subject to false positives on Yen-isolated policy days.

7. **Attack on H-CS07 (London Fix -> COMEX Gold):**
   - *Attack:* Mean-reversion at the COMEX pit open. B1 H-B7 and B2 H-B7r demonstrated that naive London-to-NY drift fades can lose money in both directions due to bid/ask churn.
   - *Paper Verdict:* **SURVIVES**. Unlike H-B7 (which used tight stops and entered blindly at 09:30), H-CS07 requires a massive London displacement ($\ge 0.60 \times D1\text{-ATR}$), enters *after* the 10:00 London PM fix, and uses a structural $\$8.00\text{ USD}$ stop.

8. **Attack on H-CS08 (Metals Ratio Mean Reversion):**
   - *Attack:* **Regime trending and runaway risk**. The Gold/Silver ratio can trend in one direction for 18 consecutive months (e.g. during monetary panics, Gold vastly outperforms Silver). An oscillator entering at $+2.2\sigma$ can suffer catastrophic drawdown if the ratio expands to $+4.5\sigma$.
   - *Paper Verdict:* **HIGH RISK**. Cointegration breaks down during macro stress; mean-reversion without a physical arbitrage mechanism is dangerous.

9. **Attack on H-CS09 (Equities -> USDJPY):**
   - *Attack:* Regime decoupling. When inflation fears spike, equities fall (higher discount rates) while USDJPY rises (higher US yields). The equity-to-carry transmission assumes a standard "risk-on = higher yields" regime.
   - *Paper Verdict:* **SURVIVES**. The 10:00 ET qualifier checks whether USDJPY is *actively moving in sync* with equities before entering.

10. **Attack on H-CS10 (EURUSD / GBPUSD Overlap):**
    - *Attack:* 08:30 ET US macro releases (NFP, CPI, Retail Sales) occur exactly at the planned entry bar. Entering at 08:30:00 risks the exact H-V4 execution disaster (massive slippage, spread blow-out).
    - *Paper Verdict:* **FRAGILE**. **Mandatory condition:** Must strictly enforce the framework 30-minute news blackout. On release days, entry must be delayed to 09:00 ET.

11. **Attack on H-CS11 (WMR Fix Pre-Hedge):**
    - *Attack:* **Cost and duration vulnerability**. A 45-minute holding period (10:20 to 11:05 ET) leaves virtually zero room for error. If the fix flow does not materialize immediately, spread drag eats the trade. B2 H-AG8 died with an $E[R]$ of $-0.11R$ to $-0.30R$ on similar mechanics.
    - *Paper Verdict:* **HIGH RISK**. Extremely vulnerable to cost drag under the conservative fill model.

12. **Attack on H-CS12 (WTI Oil -> USDCAD):**
    - *Attack:* Divergence between US and Canadian monetary policy. If the Bank of Canada is cutting rates while the Fed is holding, USDCAD will rally regardless of what oil does.
    - *Paper Verdict:* **SURVIVES**. By requiring oil displacement to exceed $0.50 \times H1\text{-ATR}$ in the immediate 09:00–10:00 ET window, the strategy trades acute intraday commercial petrodollar flow, which temporarily overrides macro policy differentials.

---

## 5. Ranking by Expected Marginal Book Value & The 5 to Kill First

### 5.1 Marginal Book Value Ranking Framework
Per OWNER directives §1–§3, candidates are ranked not by standalone Sharpe, but by their ability to reduce **$P80\text{ days to first net payout}$** while preserving payout probability:
$$\text{Expected Marginal Book Value (MBV)} \propto \text{Density} \times \text{Structural Robustness} \times \text{Book Independence}$$
- **Density:** Must approach $\ge 0.40\text{ trades/bd}$.
- **Structural Robustness:** Large stop scale relative to spread ($> 10\times$), clean closed-bar mechanics, immunity to broker data artifacts.
- **Book Independence:** True orthogonality to the incumbent XAU swing cluster (10403, 10700, 41219) and USDJPY Tokyo sleeve (13213).

```
+---------------------------------------------------------------------------------------------------------------+
|                                    COMPREHENSIVE CANDIDATE RANKING TABLE                                      |
+------+--------+--------------------+---------+---------+-------------+--------------+-------------------------+
| Rank | ID     | Domain             | Density | Robust  | Indep. vs   | Expected MBV | Recommended Action      |
|      |        |                    | Est./bd | (Cost)  | Incumbent   | Score (1-10) |                         |
+------+--------+--------------------+---------+---------+-------------+--------------+-------------------------+
|  1   | H-CS02 | SP500 -> NDX       | 0.48    | 9.5     | High (10)   | 9.2 / 10     | PRIORITY 1: F2 Code     |
|  2   | H-CS01 | DAX -> SP500       | 0.42    | 9.0     | High (10)   | 8.8 / 10     | PRIORITY 2: F2 Code     |
|  3   | H-CS05 | Silver -> Gold     | 0.40    | 8.5     | Moderate (6)| 8.2 / 10     | PRIORITY 3: F2 Code     |
|  4   | H-CS09 | Equities -> USDJPY | 0.42    | 9.5     | High (9)    | 8.1 / 10     | PRIORITY 4: F2 Code     |
|  5   | H-CS12 | WTI -> USDCAD      | 0.41    | 9.0     | High (9)    | 7.9 / 10     | PRIORITY 5: F2 Code     |
|  6   | H-CS07 | London -> NY Gold  | 0.44    | 8.0     | Moderate (6)| 7.4 / 10     | PRIORITY 6: F2 Code     |
|  7   | H-CS10 | London -> NY FX    | 0.50    | 7.5     | High (9)    | 7.2 / 10     | PRIORITY 7: F2 Code     |
+------+--------+--------------------+---------+---------+-------------+--------------+-------------------------+
|  8   | H-CS06 | USDJPY -> Gold     | 0.35    | 6.5     | Moderate (7)| 5.8 / 10     | KILL 5: Headline risk   |
|  9   | H-CS03 | Index Divergence   | 0.38    | 6.0     | High (10)   | 5.4 / 10     | KILL 4: Sector conflict |
| 10   | H-CS04 | Overnight Globex   | 0.45    | 5.0     | High (10)   | 4.6 / 10     | KILL 3: CFD data relic  |
| 11   | H-CS08 | Metals Ratio Rev.  | 0.36    | 4.5     | High (10)   | 3.8 / 10     | KILL 2: Trend runaway   |
| 12   | H-CS11 | WMR Fix Basket     | 0.38    | 3.0     | High (9)    | 2.5 / 10     | KILL 1: Cost/churn trap |
+------+--------+--------------------+---------+---------+-------------+--------------+-------------------------+
```

---

### 5.2 The Five Candidates to Kill First (And Why)

Per Requirement 4, the research discipline requires killing weak ideas immediately before wasting F2 compute or MT5 factory capacity:

1. **KILL FIRST: H-CS11 (WMR 16:00 London Fix Multi-Currency Basket)**
   - *Why:* **Cost-dominated micro-duration trap.** A 45-minute trade window under the conservative fill model is a guaranteed repeat of the H-AG8 failure. Under FTMO spreads and the mandatory 5× spread stop-floor, transaction costs eat $> 30\%$ of gross expectancy. Institutional fixing flows are heavily front-run by bank algorithmic execution and cannot be cleanly extracted on retail CFD feeds.
2. **KILL SECOND: H-CS08 (Gold/Silver Price Ratio Statistical Arbitrage)**
   - *Why:* **Runaway trend risk without physical redemption.** Retail CFDs do not permit physical arbitrage. When the macro regime shifts (e.g. acute recession or war), the Gold/Silver ratio can expand relentlessly for months, blowing through statistical $2.2\sigma$ bands. Mean reversion on ratios without cointegration stability produces fat-tailed catastrophic losses.
3. **KILL THIRD: H-CS04 (Overnight Globex Inventory Conditioning NY Cash)**
   - *Why:* **`.DWX` Custom History Data Relic.** Retail MT5 custom history (`.hcc`) for index CFDs frequently lacks consistent overnight liquidity ticks, containing synthetic broker-generated spread widens and weekend gap anomalies. Backtesting Globex ranges on CFD history introduces massive look-ahead and unauthenticatable provenance risks.
4. **KILL FOURTH: H-CS03 (Index Triangle Divergence Catch-Up)**
   - *Why:* **Sector rotation false signals.** When the Dow and Nasdaq move in the same direction but S&P lags, it is almost always driven by deep internal market cross-currents (e.g. defensive healthcare rallying with tech while financials crater). The S&P does not "catch up"—it stays in equilibrium with its weighted components.
5. **KILL FIFTH: H-CS06 (Real Yield / USDJPY Risk-Off Transmission to Gold)**
   - *Why:* **Bank of Japan intervention and currency-isolated shocks.** USDJPY volatility is increasingly driven by domestic Japanese monetary policy statements and unilateral FX interventions rather than US real Treasury yields. Using USDJPY as a proxy for Gold demand introduces unmodelable political headline risk.

---

## 6. The Top Surviving Candidates for Immediate F2 Mechanization

The top five surviving candidates represent genuine, economically robust cross-market engines capable of delivering dense, session-flat velocity:

1. **`H-CS02` (SP500 Breadth Lead -> NDX Momentum Breakout):**
   - *The Flagship Index Candidate.* Resolves the H-AG2 failure by using the 500-stock S&P Initial Balance break to authenticate broad-market buying before entering high-beta Nasdaq. Large stop ($> 50\text{ pts}$), macro holding time (2–4 hours), zero overnight swap, high density ($\approx 0.48\text{ trades/bd}$).
2. **`H-CS01` (DAX Afternoon Trend -> S&P 500 US Cash Open):**
   - *The Inter-Continental Transmission Engine.* Uses 6.5 hours of established European cash equity volume to predict the direction of the US cash open. Eliminates the catastrophic open-fade sign error of H-AG1.
3. **`H-CS05` (Silver High-Beta Lead -> COMEX Gold Breakout):**
   - *The Precious Metals Alpha Sleeve.* Replaces failed single-symbol Gold sweep rules by requiring Silver to authenticate institutional liquidity flow before entering Gold. Macro stop ($\ge \$8.00\text{ USD}$), session-flat by 13:30 ET.
4. **`H-CS09` (Equities Cash Open -> USDJPY Risk-On Momentum):**
   - *The Cross-Asset Carry Sleeve.* Captures institutional capital moving into equity risk assets transmitting to Yen selling. Trades during the liquid NY morning window; completely independent from incumbent Tokyo USDJPY sleeve (13213).
5. **`H-CS12` (WTI Crude Oil Cash Open -> USDCAD Transmission):**
   - *The Petrodollar Momentum Sleeve.* Exploits physical commodity flow at the NYMEX 09:00 ET open driving the Canadian Dollar. Provides an entirely new commodity-FX return stream with zero overlap with equities or gold.

---

## 7. Deliverable Conclusion & Router Verdict

- **Deliverable Path:** `C:/QM/repo/docs/research/ftmo_shadow/agy_cross_symbol_hypotheses_7636afc9.md`.
- **Task Verdict:** `12 cross-symbol hypotheses generated; top 5 ranked (H-CS02, H-CS01, H-CS05, H-CS09, H-CS12); 5 killed (H-CS11, H-CS08, H-CS04, H-CS03, H-CS06); post-mortem complete`.
- **Next Step:** Deliverable ready for Codex review / F2 prescreen Python integration under the conservative fill model.
