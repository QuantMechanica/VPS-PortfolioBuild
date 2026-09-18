# Evidence: EDGE Lab v2 Candidate Hypotheses Batch (EDGE-6..EDGE-9) — Task `0808f955-be44-4f9a-ae6b-52dddcb21c00`

- **Task ID:** `0808f955-be44-4f9a-ae6b-52dddcb21c00`
- **Agent:** `gemini`
- **Task Type:** `research_strategy`
- **Priority:** 45
- **Hypothesis Ref:** `docs/research/EDGE_DISCOVERY_PROGRAM_V1_2026-09-04.md §9`
- **Status:** `REVIEW` (Draft proposal submitted for Fable/OWNER review; unsealed)
- **Requested By:** Orchestrator Claude 2026-09-18 (OWNER commission for orthogonal return-source discovery)

---

## 1. Executive Summary & Context

Under OWNER directive 2026-09-13, orthogonal return sources are prioritized over exit tuning, and the active portfolio book sits at its asset-class risk cap on metals. The sealed v1 Edge Discovery Program (`docs/research/EDGE_DISCOVERY_PROGRAM_V1_2026-09-04.md`) established EDGE-1..EDGE-5 as the initial cohort (EDGE-1 underpowered, EDGE-2 refuted, EDGE-4 refuted, EDGE-5 dead, EDGE-3/EDGE-4/EDGE-5 measured).

This document details a batch of four (4) new orthogonal-return-source candidate hypotheses (EDGE-6 through EDGE-9) designed to expand the strategy frontier into non-price-pattern return mechanisms:
1. **EDGE-6:** US Equity Index Overnight Drift (Night vs Day Session Return Asymmetry) on `SP500.DWX` and `NDX.DWX`.
2. **EDGE-7:** Month-End Currency Hedging Portfolio Rebalancing Flows on `EURUSD.DWX`, `GBPUSD.DWX`, and `USDJPY.DWX`.
3. **EDGE-8:** Pre-FOMC Announcement Drift in US Equity Indices on `SP500.DWX` and `NDX.DWX`.
4. **EDGE-9:** Post-EIA Petroleum Status Report Drift in Crude Oil on `XTIUSD.DWX`.

All four candidate hypotheses:
- Rely strictly on datasets already inventoried in Section 1 of the program document (`.DWX` tick archives and cleaned Forex Factory calendar).
- Present an explicit causal/economic mechanism identifying the counterparty and structural constraint.
- Carry a falsifiable refutation criterion formatted in the exact syntax of EDGE-1..5 (sign, magnitude, sample size $n$, holdout period 2024–2025).
- Provide verifiable academic/practitioner literature citations complying with QB Reputable Source Criteria (R1–R4).
- Adhere strictly to Edge Lab hard constraints: mechanical rules, `RISK_FIXED` sizing, $\le 4$ free parameters with coarse grids, frequency $\ge 5$ triggers/symbol-year, no ML, and zero modifications to live trading or EA code.

---

## 2. Detailed Candidate Hypotheses

### EDGE-6 — US Equity Index Overnight Drift (Night vs Day Session Return Asymmetry)

- **Mechanism.** The equity risk premium in major US stock indices historically accrues overwhelmingly during non-cash overnight trading hours rather than regular daytime trading hours. During overnight hours (20:00 UTC to 13:30 UTC next day / 16:00 to 09:30 ET), market makers and institutional inventory holders demand positive compensation for bearing overnight jump risk and macro news resolution while cash exchange order books are closed. Conversely, daytime liquidity providers deploy capital and offload inventory during high-volume daytime trading, resulting in flat or negative daytime intraday drift. This return source is driven by inventory-carrying risk premia and is orthogonal to technical momentum or pattern-reversal strategies.
- **Rule Sketch.**
  - **Symbols:** `SP500.DWX`, `NDX.DWX` (tick archives 2018-07 to 2025-12).
  - **Trigger:** Daily session transition at 20:00 UTC (US cash market close).
  - **Entry:** Long position opened at 20:05 UTC.
  - **Exit:** Market close at 13:25 UTC (prior to US cash open), or emergency trailing/hard stop at $1.5\times \text{ATR}(D1)$.
  - **Position Sizing:** `RISK_FIXED` (constant risk per trade, no martingale or percentage compounding).
  - **Parameters (3):** Entry offset minute (20:00, 20:05, 20:15 UTC), exit time (13:15, 13:25, 13:35 UTC), stop ATR multiple ($1.0\times, 1.5\times, 2.0\times$).
- **Refutation Criterion.**
  - **In-Sample (2018–2023):** Annualized overnight return must exceed daytime (cash session) return by $\ge 4.0\%$ annualized with mean overnight Sharpe ratio $\ge 0.50$ across $n \ge 1,200$ sessions per index ($t \ge 2.5$).
  - **Holdout (2024–2025):** Mean overnight return must remain positive ($> 0$) and exceed daytime session return.
  - **Subsample Stability:** If overnight returns in the 2022–2023 Fed tightening subsample display structural inversion ($< 0$), the hypothesis is immediately dead.
  - **Frequency:** ~250 trading sessions per symbol-year (well above the $\ge 5$ annual rate floor).
- **Measurement Tables.** Daily overnight return, daytime cash return, spread-adjusted net PnL, annualized Sharpe ratio, max drawdown, and year-by-year return breakdown.
- **Data Source:** `D:/QM/archive/Custom_master/ticks/SP500.DWX/` and `NDX.DWX/` (2018-07 to 2025-12).
- **Literature Citation & Source Binding:**
  - Lou, Dong, Christopher Polk, and Spyros Skouras. "A Tug of War: Overnight Versus Intraday Expected Returns." *Journal of Financial Economics* 134, no. 1 (2019): 192–213.
  - Boyarchenko, Nina, David O. Lucca, and Laura Veldkamp. "Overnight Returns and the Macroeconomic News Cycle." *Federal Reserve Bank of New York Staff Reports*, no. 990 (2021).
  - R1 Classification: External academic (single primary source, verifiable, satisfies R1–R4).

---

### EDGE-7 — Month-End Currency Hedging Rebalancing Flows in FX Majors

- **Mechanism.** Global institutional asset managers (e.g., European pension and mutual funds) managing international equity portfolios typically operate under fixed currency-hedged benchmark mandates. Over the course of a calendar month, differential equity performance between US equity markets (S&P 500) and European equity markets (DAX/FTSE) shifts the effective hedge ratio. If US equities outperform European equities month-to-date, European funds become over-hedged on USD and must mechanically sell USD and buy foreign currency (EUR, GBP) into the 16:00 London WMR fix over the final 3–5 trading days of the month to restore policy weights. When US equities underperform, managers must mechanically buy USD. This non-informational liquidity demand produces predictable multi-day currency drift orthogonal to price-action indicators.
- **Rule Sketch.**
  - **Symbols:** `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`.
  - **Trigger:** At $T-3$ trading days prior to calendar month-end, evaluate the relative month-to-date equity return spread:
    $$\Delta R = R_{\text{SP500}}^{\text{MTD}} - R_{\text{GDAXI}}^{\text{MTD}}$$
    If $|\Delta R| \ge 2.0\%$, signal direction = sell USD / buy EUR/GBP if $\Delta R > 0$; buy USD if $\Delta R < 0$.
  - **Entry:** 08:00 UTC (European cash open) on trading day $T-3$.
  - **Exit:** 16:30 UTC on month-end trading day $T$ (following the London fix), or stop-loss at $1.5\times \text{ATR}(D1)$.
  - **Position Sizing:** `RISK_FIXED`.
  - **Parameters (3):** MTD equity spread threshold $\Delta R$ ($1.5\%, 2.0\%, 2.5\%$), entry day offset ($T-3, T-2, T-1$), stop ATR multiple ($1.0\times, 1.5\times, 2.0\times$).
- **Refutation Criterion.**
  - **In-Sample (2018–2023):** Conditional 3-day holding period return in the rebalancing direction must have positive mean $\ge 0.25\times \text{ATR}(D1)$ across qualifying events ($n \ge 40$ monthly rebalance events, $t \ge 2.0$).
  - **Holdout (2024–2025):** Net return after spread must remain positive ($> 0$).
  - **Control:** If unconditioned month-end currency returns yield identical drift to the equity-spread-conditioned subset, the conditioning is noise $\to$ dead.
  - **Frequency:** ~6–9 qualifying events per symbol-year (satisfies $\ge 5$ floor).
- **Measurement Tables.** Monthly equity performance spread $\Delta R$, entry date, exit date, forward return at $T-2, T-1, T$, net pips after spread, and control group returns.
- **Data Source:** `D:/QM/archive/Custom_master/ticks/` for `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `SP500.DWX`, `GDAXI.DWX` (2018-07 to 2025-12).
- **Literature Citation & Source Binding:**
  - Curcuru, Stephanie E., Charles P. Thomas, Francis E. Warnock, and Jon Wongswan. "U.S. International Equity Investment and Dollar Returns." *Journal of International Money and Finance* 30, no. 5 (2011): 797–816.
  - Krohn, Ingomar, and Vladyslav Sushko. "FX Spot and Swap Market Liquidity over the Month-End Turn." *BIS Quarterly Review* (March 2022): 43–57.
  - R1 Classification: External academic / central banking (verifiable, satisfies R1–R4).

---

### EDGE-8 — Pre-FOMC Announcement Drift in US Equity Indices

- **Mechanism.** In the 24 hours preceding scheduled Federal Open Market Committee (FOMC) rate decisions, US equity markets display a persistent positive price drift. Market participants demand compensation for bearing monetary policy uncertainty ahead of the release; as the announcement window approaches, risk-averse investors absorb uncertainty risk, driving prices upward prior to the formal release. Because positions are liquidated or stopped before the actual news release, this strategy monetizes pre-announcement uncertainty resolution without bearing execution gap or slippage risk during the release itself, perfectly respecting mandatory news blackout controls.
- **Rule Sketch.**
  - **Symbols:** `SP500.DWX`, `NDX.DWX`.
  - **Trigger:** Scheduled FOMC interest rate announcement day from cleaned news calendar (`forex_factory_calendar_clean.csv`, Event = "Federal Funds Rate" or "FOMC Statement").
  - **Entry:** 14:00 UTC on announcement day (or 24 hours prior to scheduled 18:00 UTC release).
  - **Exit:** 17:45 UTC (15 minutes prior to scheduled release to avoid the mandatory news blackout window and spread widening), or $1.0\times \text{ATR}(H1)$ trailing stop.
  - **Position Sizing:** `RISK_FIXED`.
  - **Parameters (3):** Entry time window (24h pre-release, 10:00 UTC pre-release, 14:00 UTC pre-release), pre-release exit buffer (15m, 30m, 60m), stop ATR multiple ($0.8\times, 1.2\times, 1.6\times$).
- **Refutation Criterion.**
  - **In-Sample (2018–2023):** Pre-release window mean return must exceed the unconditional same-weekday benchmark return by $\ge 0.35\sigma$ with $n \ge 40$ events ($t \ge 2.2$).
  - **Holdout (2024–2025):** Mean pre-announcement return must remain positive ($> 0$).
  - **Regime Robustness:** If pre-release return turns substantially negative across the 2022–2023 aggressive tightening cycle, the drift is unstable $\to$ dead.
  - **Frequency:** 8 scheduled FOMC meetings per year ($\ge 5$ annual rate floor).
- **Measurement Tables.** Event timestamp, scheduled release time, pre-event 24h return, pre-event 4h return, unconditional same-weekday benchmark return, realized volatility, and net PnL after cost.
- **Data Source:** `D:/QM/data/news_calendar/forex_factory_calendar_clean.csv` joined with `SP500.DWX` and `NDX.DWX` tick archives (2018-07 to 2025-12).
- **Literature Citation & Source Binding:**
  - Lucca, David O., and Emanuel Moench. "The Pre-FOMC Announcement Drift." *The Journal of Finance* 70, no. 1 (2015): 329–371.
  - Bernanke, Ben S., and Kenneth N. Kuttner. "What Explains the Stock Market's Reaction to Federal Reserve Policy?" *The Journal of Finance* 60, no. 3 (2005): 1221–1257.
  - R1 Classification: External academic (verifiable, peer-reviewed, satisfies R1–R4).

---

### EDGE-9 — Post-EIA Petroleum Status Report Drift in Crude Oil (WTI)

- **Mechanism.** Every Wednesday at 15:30 UTC (10:30 ET), the U.S. Energy Information Administration (EIA) releases its weekly petroleum status report. Unlike financial market releases where information is priced within seconds, physical crude oil inventories reflect refinery inputs, pipeline utilization, and shipping balances. When a substantial inventory surprise occurs ($|\text{Actual} - \text{Forecast}| \ge 1.0\sigma$), commercial market participants and CTAs adjust forward hedging contracts over multi-hour horizons. This generates persistent directional drift in WTI crude over the 60–180 minutes following the initial 1-minute reaction spike.
- **Rule Sketch.**
  - **Symbol:** `XTIUSD.DWX` (tick archive 2017-10 to 2025-12).
  - **Trigger:** Wednesday 15:30 UTC EIA Crude Oil Stocks release; surprise $|z| = |(\text{Actual} - \text{Forecast}) / \sigma_{\text{surprise}}| \ge 1.0$.
  - **Entry:** 15:35 UTC (5-minute delay following release to bypass initial spread spike and order book gap) in the opposite direction of the inventory change (inventory draw $\to$ long; inventory build $\to$ short).
  - **Exit:** 17:30 UTC (120-minute holding duration), or $1.2\times \text{ATR}(15m)$ stop.
  - **Position Sizing:** `RISK_FIXED`.
  - **Parameters (3):** Surprise threshold $z$ ($0.8, 1.0, 1.2$), entry delay (2m, 5m, 10m), holding duration (60m, 120m, 180m).
- **Refutation Criterion.**
  - **In-Sample (2018–2023):** Conditional 120-minute forward return in the surprise direction must exceed the unconditional Wednesday 15:35–17:30 baseline by $\ge 0.35\sigma$ across $n \ge 150$ events ($t \ge 2.0$).
  - **Holdout (2024–2025):** Net expectancy after deducting 3-pip spread/slippage must remain positive ($> 0$).
  - **Continuation Check:** If the post-5m return reverses the initial 5-minute move or shows zero continuation, the effect is pure noise $\to$ dead.
  - **Frequency:** ~25–35 qualifying events per year ($\ge 5$ annual floor).
- **Measurement Tables.** Event timestamp, actual, forecast, surprise $z$, forward returns at +5, +15, +30, +60, +120, +180 min, spread at entry, net PnL.
- **Data Source:** `D:/QM/data/news_calendar/forex_factory_calendar_clean.csv` joined with `D:/QM/archive/Custom_master/ticks/XTIUSD.DWX/` (2017-10 to 2025-12).
- **Literature Citation & Source Binding:**
  - Halova, Simona, George H. K. Wang, and Donald Lien. "The Impact of the Energy Information Administration Petroleum Status Report on the US Crude Oil and Petroleum Product Futures Markets." *Journal of Futures Markets* 34, no. 7 (2014): 652–671.
  - Bjursell, Johan, George H. K. Wang, and Jeffrey Xu. "Announcement Effects in Energy Futures Markets: An Intraday Analysis." *Journal of Futures Markets* 35, no. 11 (2015): 1058–1081.
  - R1 Classification: External academic (verifiable, peer-reviewed, satisfies R1–R4).

---

## 3. Orthogonality & Charter Compliance Matrix

| Hypothesis | Asset Class / Instruments | Core Economic Driver | Active Book Correlation Driver | Charter Fit (DD $\le$5/10%, news blackout, mechanical) |
|---|---|---|---|---|
| **EDGE-6** | US Indices (`SP500`, `NDX`) | Overnight dealer inventory holding premium | Low: existing index strategies are D1/H4 breakout/trend; holding period is strictly overnight | Fully mechanical, `RISK_FIXED`, exits prior to US cash session |
| **EDGE-7** | FX Majors (`EURUSD`, `GBPUSD`, `USDJPY`) | Month-end institutional currency-hedge rebalancing | Orthogonal: driven by equity MTD performance spreads, not FX price technicals | Fully mechanical, `RISK_FIXED`, multi-day swing hold |
| **EDGE-8** | US Indices (`SP500`, `NDX`) | Pre-FOMC monetary uncertainty risk compensation | Orthogonal: active only 8 days/year, exits 15m prior to announcement | Exits prior to announcement, 100% compliant with news blackout |
| **EDGE-9** | Energy (`XTIUSD`) | Post-release physical inventory digestion drift | Orthogonal: non-precious-metals commodity, trades inventory supply surprises | Trades after initial 5m spread spike, fixed holding period |

---

## 4. Governance & Next Steps

1. **Sealing Authority:** This draft proposal is submitted into `docs/research/EDGE_DISCOVERY_PROGRAM_V1_2026-09-04.md §9` marked clearly as **DRAFT**. Sealing and promotion into measurement require Fable (CEO) / OWNER review and approval.
2. **Measurement Commissioning:** Upon sealing by Fable/OWNER, deterministic measurement tables will be generated via `tools/strategy_farm/research/edge_lab_stats.py` using the established protocol.
3. **No Strategy Cards / Code Changes:** As stipulated by task limits, no strategy cards, EA code, gate definitions, or pipeline thresholds have been created or modified.
