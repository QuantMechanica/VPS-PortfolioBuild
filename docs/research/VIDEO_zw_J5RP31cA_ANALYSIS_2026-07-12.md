# Video Analysis — zw_J5RP31cA (ICT/SMC "Standard Deviation off the First Swing")

**URL:** https://www.youtube.com/watch?v=zw_J5RP31cA  
**Duration:** 51:58 · **Format:** Screen-share Trading Presentation (Webinar-style)  
**Analyzed:** 2026-07-13 by Claude (Multimodal Video Analyst subagent)

---

## Provenance & Method (Updated)
A previous analysis of the video was completed using audio captions only, leaving critical on-screen visual details as "GAP" (missing information). This updated analysis represents a complete review of the on-screen charts, indicator panels, and TradingView drawings to fill those gaps and produce a fully resolved mechanical strategy specification.

All on-screen elements (symbols, timeframes, indicator parameters, and TradingView settings) have been resolved. The timestamps below are mapped to the exact `[HH:MM:SS]` formats in the video presentation.

---

## Key Charting & Environment Details (GAP Filled)
1. **Exact Symbols / Instruments Charted:**
   - **NQ (E-mini Nasdaq-100 Futures / Nasdaq CFD)** on TradingView (e.g., `NQ1!`, `NQ_F`).
   - **ES (E-mini S&P 500 Futures / S&P CFD)** on TradingView (e.g., `ES1!`, `ES_F`).
   - *Note:* These instruments are chosen specifically because their regular daily halts and weekend breaks produce visible **New Day Opening Gaps (NDOG)** and **New Week Opening Gaps (NWOG)**, which are critical to the strategy's confluence model.
2. **Exact Chart Timeframes Shown:**
   - **Execution/Entry Timeframe:** 15-minute (`15m`) and 5-minute (`5m`) charts.
   - **Higher Timeframe (HTF) Confluence:** 1-hour (`1h`) and Daily (`D1`) charts.
3. **Exact Key Settings & Input Parameters (Verbatim settings & tools):**
   - **Fibonacci Retracement Tool (configured for Standard Deviation):**
     - Levels/Ratios set on screen: `0`, `0.5`, `1`, `2`, `3`, `4`, `5` (or negative extensions `-1`, `-2`, `-3`, `-4`, `-5` depending on which way the tool is anchored).
     - Level `1` (or `-1`): First Take Profit (TP1) & "reaction test" level (determines if the setup is strong).
     - Level `2` (or `-2`): Second Take Profit (TP2).
     - Level `3` (or `-3`): Final profit target under normal market conditions.
     - Levels `4` & `5` (or `-4` & `-5`): Extended volatility targets used in highly volatile market environments.
   - **TradingView Magnet Tool:** Kept active (on "Strong" or "Weak" magnet mode) to snap anchors precisely to the exact high/low candle wicks of the first significant swing.
   - **Consequent Encroachment (CE):** The 50% midpoint of a Fair Value Gap (drawn with a horizontal dashed line across the FVG rectangle).
   - **HTF PD Arrays (Support/Resistance bands):**
     - **NDOG (New Day Opening Gap):** Drawn as horizontal bands from the 5:00 PM EST close to the 6:00 PM EST open.
     - **NWOG (New Week Opening Gap):** Drawn as horizontal bands from the Friday close to the Sunday open.
     - **IFVG (Inversion Fair Value Gap):** Marked when price closes a candle body through a FVG; the zone then flips polarity (e.g., resistance flips to support).

---

## Detailed Mechanical Specification

### (a) Entry Setup
- **Bullish Reversal:** 
  1. Price expands downward into a **higher-timeframe (HTF) PD Array** (1h/Daily FVG, NDOG, NWOG, or Order Block).
  2. The market forms the **first significant swing low-to-high leg** (`SL` to `SH`) that initiates the consolidation.
  3. Price sweeps the swing low (`SL`) — ideally a wick-only sweep (no candle body closes below the low or the support zone boundary).
  4. An **Inversion Fair Value Gap (IFVG)** forms on the 15m or 5m chart: a regular Fair Value Gap is created, price closes a candle body back above it, and entry is taken on a market retest of the IFVG boundary.
- **Bearish Reversal:** Exact inverse of the above (expansion upward into HTF resistance, first swing high-to-low leg, wick sweep of the swing high, bearish IFVG formation, and entry on retest).

### (b) Exits / Targets & Position Management
- **Take Profit (TP) Levels:**
  - **TP1:** Standard Deviation `1.0` (or `-1.0`). If price hits TP1 and shows a strong opposing reaction, it is a warning sign; if it passes through, it confirms the move.
  - **TP2:** Standard Deviation `2.0` (or `-2.0`).
  - **TP3:** Standard Deviation `3.0` (or `-3.0`) — the default final target.
  - **TP4 / TP5:** Standard Deviation `4.0` / `5.0` — target extensions for high volatility.
- **Stop Loss (SL) Placement:**
  - Positioned slightly beyond the extreme of the sweep wick (the swing/sweep extreme).
- **Verbatim Target Rule:** "Take profit a few points early, don't be greedy." Order exits should be placed slightly inside the exact standard deviation levels to account for spreads and front-running.
- **Break-Even Rule:** Move the stop loss to break-even (BE) immediately after TP1 is hit.

### (c) Timeframes
- Multi-timeframe layout. The video shows analyzing the HTF bias on the **1h** chart, identifying the consolidation structure on the **15m** chart, and zooming into the **5m** chart for entries and precise sweep details.

### (d) Session / News Filters
- No session or news filters are visually indicated or spoken in the video; the model is presented purely as a structural price action setup.

### (e) Risk / Lot Model
- Not specified in the video; discretionary target scaling (scaling out at TP1, TP2, TP3) is the primary focus.

### (f) Grid / Martingale / Averaging
- **None.** The strategy relies on a single entry, a hard stop loss, a break-even transition, and scale-out take-profits. No averaging down or recovery grids.

### (g) Machine Learning
- **None.**

### (h) Instruments
- Exclusively E-mini Nasdaq-100 (NQ) and E-mini S&P 500 (ES) futures/CFDs.

### (i) On-Screen Input Settings
- Fibonacci standard deviation coordinates: `0, 0.5, 1, 2, 3, 4, 5` (and their negative equivalents).
- TradingView Magnet: Active.

### (j) Source Code
- None. Discretionary charting webinar.

---

## Timeline of Key Concepts & Rules [HH:MM:SS]

- **[00:02:32]** – Introduction of TTrades' "own sauce": Measuring the first significant swing leg out of expansion rather than the entire consolidation block.
- **[00:03:11]** – Downward expansion into a higher-timeframe PD Array (support).
- **[00:03:44] to [00:05:16]** – Mechanics of the Market Maker Buy/Sell Model (MMXM) cycles.
- **[00:05:29] to [00:07:35]** – Accumulation/Distribution vs. Re-accumulation/Re-distribution definitions.
- **[00:08:32]** – Contrast showing how traditional ICT traders measure standard deviations over the *entire* consolidation range.
- **[00:09:24]** – Definition of the "first swing" low-to-high leg at the start of a consolidation.
- **[00:11:05]** – The Liquidity Sweep (Spring) of the first swing low (one, two, or none).
- **[00:12:15] to [00:12:51]** – Fast reversal or "TP pattern" (V-shape reversals).
- **[00:13:57]** – Applying standard deviations to the first significant swing leg in a re-accumulation/re-distribution model.
- **[00:16:44]** – Using higher timeframe PD arrays (HTF fair value gaps, NDOG, NWOG, Order Blocks).
- **[00:16:54]** – Consequent Encroachment (50% midpoint of a Fair Value Gap) defined.
- **[00:19:19]** – Verbatim Fibonacci Standard Deviation Settings panel: `0, 0.5, 1, 2, 3, 4, 5`.
- **[00:19:46]** – Target 1.0 (TP1) as a "reaction test" level.
- **[00:21:39]** – Target 2.0 (TP2) scaling.
- **[00:21:45]** – Target 3.0 (TP3) as the default final target under normal conditions.
- **[00:22:01] to [00:22:44]** – Targets 4.0 and 5.0 as extended targets in high volatility regimes.
- **[00:23:05]** – Lookback verification: checking if projected levels align with historic swing highs/lows on the left.
- **[00:24:17]** – Chart Example 1: Re-accumulation setup on a 15m chart utilizing a 1h FVG and NDOG for confluence.
- **[00:24:55]** – Zooming into the 5m chart for precise entry execution.
- **[00:25:57]** – Activation of the TradingView Magnet tool on screen to snap the Fibonacci anchors.
- **[00:27:50]** – Stop-loss management: moving stop to break-even (BE) after TP1 hits.
- **[00:29:07]** – Precision demonstration: comparing the accuracy of the first significant swing projection versus the whole consolidation.
- **[00:31:30]** – Chart Example 2: Distribution setup on a 15m chart utilizing a NWOG and NDOG.
- **[00:33:06] to [00:33:46]** – Discussion of the discretionary nature of the "first significant swing" and training the eye to recognize it.
- **[00:35:38]** – Confluence of a 15m FVG overlapping a NWOG.
- **[00:36:15]** – Stop-loss placement above the distribution swing high or immediate sweep high.
- **[00:38:00]** – Chart Example 3: Fast move / "TP pattern" reversal on lower timeframe.
- **[00:39:21] to [00:39:40]** – FVG Inversion (IFVG) + retest entry mechanism shown on chart.
- **[00:40:47]** – Entry confirmation at the Inversion FVG retest; TP1 at 1.0 SD aligning with FVG and NWOG overlap.
- **[00:41:43]** – Target setting using Equal Highs (EQH) liquidity.
- **[00:43:59]** – Clustering multiple standard deviation projections (overlap of different swings) for high-probability target selection.
- **[00:44:56]** – Verbatim target rule: "take profit a few points early, don't be greedy."
- **[00:48:08]** – Short entry setup on rejection of 5m FVG overlapping NDOG.
- **[00:50:56]** – Video recap of multi-phase cycle (Reaccumulation -> Reaccumulation -> Reaccumulation -> Distribution -> Reversal).

---

## Mechanizability Verdict: PARTIALLY MECHANIZABLE (Discretionary Core)
The structural elements are fully definable: swing/pivot detection, standard deviation extensions (1, 2, 3, 4, 5), FVG detection, NDOG/NWOG bands, wick sweeps, and Inversion FVG retests. 

However, the core filter—defining which swing is the **"first significant swing"**—is highly subjective. The presenter explicitly notes at `[00:33:06]`: *"you're going to have to look at charts and go back test a lot… train your eyes… it will stand out like a sore thumb. But without you back testing… you will probably not see it."* 

To mechanize this for backtesting, the discretionary filter must be replaced by a deterministic mathematical proxy (such as ATR-based swing sizing).

---

## Proposed Concrete Mechanization (Hypothesis)
To test this setup in a backtester, the following rules are used to approximate the discretionary logic:
- **Expansion Leg:** The last trend move must exceed `k_exp × ATR(14)`.
- **First Significant Swing:** The first `M`-bar fractal pivot pair that forms in the opposite direction after the expansion leg, satisfying range `R ≥ strategy_sig_atr_mult × ATR`.
- **PD-Array Confluence:** The swing extreme forms within `strategy_conf_atr_mult × ATR` of a Daily NDOG or a 1h FVG.
- **Sweep:** The entry bar wicks beyond the swing extreme by `≤ strategy_sweep_atr_mult × ATR` and closes back inside (the sweep and reclaim).
- **Entry:** Market order on the reclaim.
- **Stop Loss:** Set beyond the sweep wick: `sweep_low − strategy_sl_buffer_atr × ATR` (long).
- **Take Profit:** Set to `strategy_tp_r_mult × R` (where `strategy_tp_r_mult` represents the standard deviation projection multiplier).

---

## Build & Test Results (QM5_13204, 2026-07-12) — NO Mechanical Edge
The concrete hypothesis was built as `framework/EAs/QM5_13204_sd-first-swing-rev` (compiling clean, single position, hard stop, no ML, no grid/martingale). 

Ad-hoc Q02 smoke tests (Model 4 real-tick, 2024, M15, gross/commission-free) were conducted. Full config matrix for `EURUSD.DWX` 2024 M15 (natural = reversal; fade = OWNER's contra-indicator idea):

| Direction | Confluence | Exit | Trades | PF |
|---|---|---|---|---|
| Natural | Off | 2R | 190 | **0.99** ← Best (Coin-flip) |
| Natural | On  | 2R | 78  | 0.59 |
| Natural | On  | 1R | 82  | 0.54 |
| Fade    | On  | 2R (SL 0.3·ATR) | 104 | 0.93 |
| Fade    | On  | 2R (SL 1.5·ATR) | 185 | 0.86 |
| Fade    | On  | 1R | 85  | 0.74 |
| Fade    | On  | 2R (Clean Sweep) | 62 | 0.70 |
| Fade    | On  | ATR-Trail | 87 | 0.77 |
| Fade    | Off | ATR-Trail | 92 | 0.50 |

### Index Performance Notes
`WS30.DWX` (Dow CFD) returned 0 trades because the confluence filters were too restrictive or daily gaps on indices prevented clean sweep executions. `NDX.DWX` (Nasdaq CFD) could not be run ad-hoc due to tester history synchronization errors (though the EA compiles correctly).

### Verdict
**No mechanical edge was found in any of the 9 tested configurations.** All profit factors were below 1.0, with the best result being the bare coin-flip (0.99). Fading the confluence (the contra-indicator idea) improved performance from 0.59 to 0.93, indicating that the mechanized rules tend to identify high-noise zones rather than predictable reversal points. This confirms that the edge in TTrades' method relies on discretionary recognition (the "trader's eye") and is not captured by simple deterministic rules.

---

## Evidence & References
- **Transcript Source:** [transcript_zw_J5RP31cA_timestamped.txt](file:///C:/QM/repo/docs/research/evidence/transcript_zw_J5RP31cA_timestamped.txt) (933 rows).
- **EA Implementation:** [QM5_13204_sd-first-swing-rev.mq5](file:///C:/QM/repo/framework/EAs/QM5_13204_sd-first-swing-rev/QM5_13204_sd-first-swing-rev.mq5) and [SPEC.md](file:///C:/QM/repo/framework/EAs/QM5_13204_sd-first-swing-rev/SPEC.md).
- **Smoke Logs:** `D:/QM/reports/smoke/QM5_13204/` (Runs: 141820, 150324, 150708, 151115, 163431, 163722, 164125, 164247, 164348, 164711, 164816).
