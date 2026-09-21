---
ea_id: QM5_41486
parent_ea_id: QM5_11563
slug: connors-rsi2-sma200-mean-reversion-d1-v2
type: second_chance_retest_draft
source_id: 278c6e13-0726-5779-83fe-a38f5a2e480f
source_citation: "Larry Connors & Cesar Alvarez, 'Short-Term Trading Strategies That Work' (TradingMarkets Publishing, 2009), Strategies 8-9 (The 2-Period RSI)."
sources:
  - "[[sources/connors-larry-short-term-trading-strategies-that-work]]"
concepts:
  - "[[concepts/rsi2-mean-reversion]]"
  - "[[concepts/sma200-trend-filter]]"
  - "[[concepts/oversold-pullback-buy]]"
indicators:
  - RSI(2)
  - SMA(200)
  - ATR(14)
period: D1
timeframe: D1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX]
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 8
expected_trade_frequency: "D1 RSI(2) extreme gated by the SMA200 regime filter and no-Friday rule; conservative joint estimate 5-10 trades/year/symbol."
expected_pf: 1.5
expected_dd_pct: 5.0
last_updated: 2026-09-21
split_from_task: b0ef5d66-5947-4d79-ad72-02f2caee04cb
second_chance_reason: INFRA_FAIL
second_chance_status: ELIGIBLE_FOR_RECONSIDERATION
venue_hypothesis: "FTMO (owner directive §31): D1 mean-reversion, low-swap FX majors; role = FTMO book candidate"
g0_approval_reasoning: "Fable 2026-09-21 Track C RUN_NOW (OWNER-DEC-FTMO-FULL-THROTTLE-20260921 sections 4, 17): Second-Chance v2 of QM5_11563 under a NEW identity per the accepted revision b0ef5d66 (clean rerun, never reopen the old verdict); R1 PASS Connors-Alvarez 2009 book lineage; R2 PASS deterministic RSI(2)/SMA200/A"
card_sha256: 3138b898f4aa3bc5e521f037878f827b90384e71dcb6f63a5b62a57cc1ce805b
---

# PENDING_B0EF5D66 Connors — RSI(2) + SMA(200) Mean Reversion (D1, FX Rerun)

## Second-Chance Retest Review Draft (Wave 1: INFRA_FAIL)

This strategy card is an append-only second-chance retest draft for origin strategy `QM5_11563` (`connors-rsi2-sma200-mean-reversion-d1`), commissioned under the Strategy Second-Chance Programme (`docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md` §5.1, task `b0ef5d66-5947-4d79-ad72-02f2caee04cb`).

Historical evidence:
- Q06 on GBPUSD.DWX achieved **Profit Factor 1.57, 94 trades, drawdown $4,370.07** (work item `4ece110d-6033-48c3-89cc-96db30741d8a`).
- Terminal failure was strictly infrastructural (`INFRA_FAIL`): Q08 INVALID twice due to context / calendar validation defects (`79a120af` DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT, `44c01339` DSR_V2_TRADE_OUTSIDE_SEALED_CALENDAR).
- The trading thesis was never rejected on economic grounds. Lineage is strictly **NEW**; historical verdicts and work items remain immutable read-only evidence.
- A permanent numeric EA ID will be atomically minted via `farmctl reserve-ea-ids` by the build/intake controller upon card approval.

---

## Duplicate Fingerprint & Approved Twin Resolution

This strategy draft is distinct from approved card `QM5_11365_connors-rsi2-sma200-pullback-d1`. While `QM5_11365` was approved on 2026-05-23 as a card draft only and was never compiled or executed in `farm_state.sqlite` (0 work items), `QM5_11563` was the active implementation that successfully advanced through Q02, Q03, Q05, Q06 (PF 1.57, 94 trades on GBPUSD), and Q07 before hitting an infrastructure context validation defect at Q08 (`INFRA_FAIL`). This draft differs from `QM5_11365` by incorporating the full DSR single-configuration contract (`qm-dsr-single-configuration`), explicit Friday flattening, and strict sealed-calendar constraints to guarantee Q08 reproducibility. If approved, `QM5_11563`'s clean rerun succeeds `QM5_11365` as the governed implementation of the Connors RSI(2) D1 mean reversion thesis.

---

## 1. Source & Attribution

- **Authors:** Larry Connors & Cesar Alvarez
- **Title:** *Short-Term Trading Strategies That Work: A Quantified Guide to Trading Stocks and ETFs* (TradingMarkets Publishing, 2009), Strategies 8–9 "The 2-Period RSI".
- **Source UUID:** `278c6e13-0726-5779-83fe-a38f5a2e480f`
- **Source Class:** External published book (qualifies under R1; no internal QM-RESEARCH mint prerequisite).

---

## 2. Theoretical Mechanism & Edge Thesis

- **Structural Cause:** When an underlying instrument trades in a defined macroeconomic trend (established by `Close > SMA(200)` for long positions or `Close < SMA(200)` for short positions), extreme short-term counter-trend price velocity (measured by a 2-period RSI dropping below 10 or exceeding 90) reflects transient liquidity depletion and temporary order-flow imbalances.
- **Persistence:** Institutional participants rebalance into prevailing macro trend directions; liquidity providers step into exhausted pullbacks, creating a high-probability mean-reversion snapback toward intermediate fair value.
- **Venue Fit (FTMO & DXZ):** Daily bar execution on major low-spread FX pairs (EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX) avoids intra-day noise and broker spread slippage. Clean holding duration (typically 2–5 days) with mandatory weekend flattening and news blackouts strictly respects FTMO daily loss (<=5%) and total loss (<=10%) constraints.

---

## 3. Mechanical Trading Rules

### Universe & Timeframe
- **Symbols:** `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`
- **Timeframe:** `D1` (Daily)
- **Spread Cap:** 15 pips

### Entry Logic
- **LONG Entry Condition:**
  1. `iClose(NULL, PERIOD_D1, 1) > iMA(NULL, PERIOD_D1, 200, 0, MODE_SMA, PRICE_CLOSE, 1)` (uptrend regime filter)
  2. `iRSI(NULL, PERIOD_D1, 2, PRICE_CLOSE, 1) < 10.0` (deeply oversold extreme)
  3. No Friday entry: `DayOfWeek() != 5`
  - Action: Buy at open of the next D1 bar (or close of signal bar).
- **SHORT Entry Condition (Symmetric adaptation):**
  1. `iClose(NULL, PERIOD_D1, 1) < iMA(NULL, PERIOD_D1, 200, 0, MODE_SMA, PRICE_CLOSE, 1)` (downtrend regime filter)
  2. `iRSI(NULL, PERIOD_D1, 2, PRICE_CLOSE, 1) > 90.0` (deeply overbought extreme)
  3. No Friday entry: `DayOfWeek() != 5`
  - Action: Sell at open of the next D1 bar (or close of signal bar).

### Exit Logic
- **LONG Exit:**
  - `iRSI(NULL, PERIOD_D1, 2, PRICE_CLOSE, 0) > 65.0` -> Close long position on next open.
- **SHORT Exit:**
  - `iRSI(NULL, PERIOD_D1, 2, PRICE_CLOSE, 0) < 35.0` -> Close short position on next open.

### Risk Management & Stop Loss
- **Safety Hard Stop:** `2.0 * iATR(NULL, PERIOD_D1, 14, 1)` from entry price, with an absolute cap of `150 pips`.
- **Position Sizing:** Fixed risk per trade:
  - Backtest: `RISK_FIXED = 1000`, `RISK_PERCENT = 0` (Build Guardrail compliance).
  - Live / Forward Demo: `RISK_FIXED = 0`, `RISK_PERCENT = 0.5%`.
- **Position Capacity:** Maximum 1 open position per magic number / symbol at any time. No martingale, no grid, no pyramiding, no averaging into losing positions.

### News & Framework Guardrails
- **News Compliance:** `QM_NEWS_COMPLIANCE_DXZ`
- **News Temporal Mode:** `QM_NEWS_TEMPORAL_PRE30_POST30`
- **News Min Impact:** `high`
- **News Stale Max Hours:** `336` (Build Guardrail hard rule: NEVER > 336).
- **Weekend Close:** `qm_friday_close_enabled = true`, broker hour 21.

---

## 4. FTMO Fit & Venue Hypothesis

The strategy is structured to satisfy FTMO prop evaluation and DXZ portfolio rules within the Edge Lab charter design box:
- **Drawdown Compliance:** Fixed risk per trade ($1,000 in backtest, 0.5% in forward live) ensures daily risk remains well below the 5% daily loss limit (5% daily limit) and the 10% total drawdown limit (10% total drawdown limit).
- **News Blackout Window:** Mandatory news blackout filtering around high-impact events (`qm_news_stale_max_hours = 336`, `QM_NEWS_TEMPORAL_PRE30_POST30`).
- **Horizon & Execution:** D1 swing execution (holding 2-5 days), matching the swing horizon (H1-D1) specified in the Edge Lab design box.

---

## 5. Falsification / Kill Criteria

This strategy is falsified — and should be retired rather than re-parameterized — if any of the following occur during Q02–Q08 testing:
1. **Unprofitable Mean Reversion Alpha:** Realized profit factor across full-history backtest on target pairs is <= 1.15 net of broker costs, indicating RSI(2) extremes do not generate tradeable edge after trend filtering.
2. **Deficient Trade Cadence:** Joint trade count across target pairs is < 5 trades/year/symbol, falsifying the expected cadence required for statistical significance.
3. **Severe Trend Continuation Penalty:** Drawdown on trending false-breakouts exceeds 2.0x ATR before exit trigger fires, violating the bounded risk assumption.
4. **News Window Slippage:** Greater than 10% of trades trigger within 30 minutes of high-impact events, failing the news blackout requirement.

---

## 6. Q08 and Q11 Crisis & News Risk

- **Q08 Stress Testing & Crisis Regimes:** The 200-day SMA regime filter provides primary crisis protection: during extended equity or currency crashes (e.g. 2008 Lehman collapse, 2020 COVID shock), price remains below the SMA(200), entirely suppressing long dip-buying and preventing catching falling knives. The safety hard stop at 2.0 * ATR (150-pip cap) bounds single-trade tail losses. Weekend flattening (`qm_friday_close_enabled = true`) prevents weekend gap risk.
- **Q11 News & Event Replay:** High-impact macro releases (Fed rate decisions, US CPI, non-farm payrolls) can induce sharp 1-day candles that push RSI(2) to extremes. The mandatory fail-closed news filter (`QM_NEWS_TEMPORAL_PRE30_POST30`) suppresses entry during high-impact news windows, ensuring trades capture genuine behavioral exhaustion rather than post-release re-pricing trends.
- **DSR Sealed-Calendar Context Validity:** The explicit DSR single-configuration contract below locks all parameters and eliminates optimization search (`research_trial_count = 0`), preventing recurrence of `DSR_V2_MUTABLE_OR_RELATIVE_CONTEXT` and `DSR_V2_TRADE_OUTSIDE_SEALED_CALENDAR` defects.

---

## 7. R1–R4 Gate Evaluation

| Criterion | Status | Technical Rationale |
|---|---|---|
| **R1 Track Record** | TIER_C (PASS) | Larry Connors & Cesar Alvarez: established quantitative authors and market practitioners. Single-source lineage. |
| **R2 Mechanical** | PASS | Exact formulas: `iRSI(2)`, `iMA(SMA, 200)`, `iATR(14)`. Pure MT5-native indicator calls without discretionary rules. |
| **R3 Data Available** | PASS | Complete D1 bar history exists for `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX` across 2017–2025. |
| **R4 No ML in EA** | PASS | Fixed mathematical thresholds (10/90, 65/35, 2.0x ATR); no machine learning, no neural nets, no runtime model weights. |

---

## 8. DSR Single-Configuration Declaration

To prevent recurrence of the Q08 context and calendar hold defects, this strategy card incorporates the explicit DSR single-configuration contract.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "PENDING_B0EF5D66",
  "origin_ea_id": "QM5_11563",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_friday_close_enabled": "true",
    "qm_friday_close_hour_broker": "21",
    "qm_magic_slot_offset": "1",
    "qm_news_compliance": "QM_NEWS_COMPLIANCE_DXZ",
    "qm_news_min_impact": "high",
    "qm_news_mode_legacy": "QM_NEWS_OFF",
    "qm_news_stale_max_hours": "336",
    "qm_news_temporal": "QM_NEWS_TEMPORAL_PRE30_POST30",
    "qm_rng_seed": "42",
    "qm_stress_reject_probability": "0.0",
    "strategy_atr_period": "14",
    "strategy_atr_sl_mult": "2.0",
    "strategy_no_friday_entry": "true",
    "strategy_rsi_entry_long": "10.0",
    "strategy_rsi_entry_short": "90.0",
    "strategy_rsi_exit_long": "65.0",
    "strategy_rsi_exit_short": "35.0",
    "strategy_rsi_period": "2",
    "strategy_sl_cap_pips": "150",
    "strategy_sma_period": "200",
    "strategy_spread_cap_pips": "15"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "symbol": "GBPUSD.DWX",
  "timeframe": "D1"
}
```

---

## Pipeline History

| Gate | Status | Note |
|------|--------|------|
| G0   | DRAFT  | Append-only second-chance card draft under task `b0ef5d66-5947-4d79-ad72-02f2caee04cb` (Wave 1 INFRA_FAIL retest). Updated with complete Edge Lab charter sections (Falsification, Q08/Q11 Risk, FTMO Fit, Approved Twin Resolution). |
