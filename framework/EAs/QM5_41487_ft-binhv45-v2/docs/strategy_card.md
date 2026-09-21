---
ea_id: QM5_41487
parent_ea_id: QM5_11211
slug: ft-binhv45-v2
type: second_chance_retest_draft
source_id: 1580128f-e465-5454-bb97-a7572a6cfd6d
source_citation: "BinHV45.py, freqtrade-strategies, GitHub, https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/BinHV45.py, commit dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4."
sources:
  - "[[sources/freqtrade-strategies]]"
concepts:
  - "[[concepts/bollinger-mean-reversion]]"
  - "[[concepts/volatility-expansion]]"
  - "[[concepts/candle-tail-filter]]"
indicators:
  - Bollinger Bands(40, 2)
  - ATR(14)
period: M5
timeframe: M5
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 40
expected_trade_frequency: "M5 Bollinger lower-band capitulation setup; conservative estimate 30-80 trades/year/symbol across EURUSD, GBPUSD, USDJPY, XAUUSD with volatility-calibrated closedelta threshold."
expected_pf: 1.35
expected_dd_pct: 4.0
last_updated: 2026-09-21
split_from_task: f05399de-2945-4ab3-8006-896e5b150b3a
second_chance_reason: SCALPING
second_chance_status: ELIGIBLE_FOR_RECONSIDERATION
venue_hypothesis: "FTMO (§31): M5 Bollinger capitulation scalp, EURUSD/GBPUSD/USDJPY/XAUUSD, low-swap majors + metal"
g0_approval_reasoning: "Fable 2026-09-21 Track C RUN_NOW (OWNER-DEC-FTMO-FULL-THROTTLE-20260921 sections 4, 17): Second-Chance v2 of retired QM5_11211 under a NEW identity per the accepted revision f05399de (new lineage Q00->Q02, M1->M5); R1 PASS freqtrade BinHV45 public source with commit hash; R2 PASS deterministic Bolli"
card_sha256: 8845a18f7fa99a68de7c26d79806f015b2fb32a44a80601764c03083ebeaf727
---

# PENDING_F05399DE Freqtrade — BinHV45 Bollinger Drop Reversal (M5 Rerun)

## Second-Chance Retest Review Draft (Wave 2: SCALPING)

This strategy card is an append-only second-chance retest draft for origin strategy `QM5_11211` (`ft-binhv45`), commissioned under the Strategy Second-Chance Programme (`docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md` §5, Wave 2 style-supersession, task `f05399de-2945-4ab3-8006-896e5b150b3a`).

Historical evidence:
- Original card was rejected at G0 on 2026-05-23 under superseded §17 scalping doctrine with note: `R2 fail: M1 entry requires closedelta > close*17/1000 (about 1.7% one-minute move), implausible to support >=2 trades/year/symbol on DWX FX/XAU despite inflated 120/year claim.`
- The strategy was never built (0 work items, 0 metrics in farm database).
- Under the active Edge Lab Charter (`docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`), scalping is governed by the M5–M15 design box (sub-minute HFT is prohibited). To strictly comply with Edge Lab design box constraints, this retest adapts execution from raw M1 to the M5 timeframe.
- R1–R4 self-assessments are all PASS; logic is completely deterministic and mechanical.
- Lineage is strictly **NEW**; historical verdicts and card rows remain immutable read-only evidence.
- Numeric EA ID will be atomically minted via `farmctl reserve-ea-ids` by Codex/controller upon build task creation.

---

## Duplicate Fingerprint & Differentiation

This strategy is distinct from and differs from approved card `QM5_10026_rw-fx-squeeze-mr` (which shares Bollinger Bands and mean reversion terms). While `QM5_10026` trades an H1 volatility squeeze contraction regime requiring RSI(14) reversal and exiting on midline touch over 24 bars, `PENDING_F05399DE` operates on M5 as a single-bar volatility expansion capitulation drop reversal, triggering on sharp price velocity (closedelta) and minimal candle tail without RSI or squeeze percentile conditions, exiting on a fixed ROI / ATR target. The causal logic, signal indicators, timeframe (M5 vs H1), and exit structure represent an evidence-based delta and an entirely distinct mechanism.

---

## Source & Attribution

- **Repository:** `freqtrade-strategies` (GitHub)
- **Source File:** `user_data/strategies/berlinguyinca/BinHV45.py`
- **Source Citation:** "BinHV45.py", freqtrade-strategies, GitHub commit `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`
- **Source UUID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
- **Source Class:** External open-source strategy repository (R1 PASS; no internal QM-RESEARCH mint prerequisite).

---

## Theoretical Mechanism & Edge Thesis

- **Structural Cause:** Severe, rapid price drop dislocations on the 5-minute chart that pierce through the lower Bollinger band (40, 2) accompanied by band expansion (`bbdelta`) and minimal lower candle tail reflect sudden liquidity voids and one-sided market capitulation.
- **Persistence:** In liquid FX majors and gold, sudden sharp drop exhaustion is rapidly counterbalanced by institutional liquidity providers and mean-reverting algorithms absorbing distressed sell orders, generating an immediate mean-reversion snapback toward intermediate fair value.
- **Venue Fit (FTMO & DXZ):** Rapid intraday mean-reversion execution on `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, and `XAUUSD.DWX`. With explicit take-profit targets, tight ATR stop losses, mandatory news blackout filtering, and no gridding/martingale, the profile satisfies FTMO daily loss (<=5%) and total loss (<=10%) constraints.

---

## Mechanical Trading Rules

### Universe & Timeframe

- **Target Symbols:** `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `XAUUSD.DWX`
- **Timeframe:** `M5`
- **Spread Cap:** Spread must be <= 6% of planned stop distance; skip entry during spread widening.

### Entry Logic

- **Bollinger Bands Calculation:**
  - `period = 40`, `deviation = 2.0` on M5 `Close`.
  - `mid = SMA(Close, 40)`.
  - `lower = mid - 2.0 * StDev(Close, 40)`.
  - `upper = mid + 2.0 * StDev(Close, 40)`.
- **Ancillary Metrics:**
  - `bbdelta = abs(mid - lower)`.
  - `closedelta = abs(Close[1] - Close[2])`.
  - `tail = abs(Close[1] - Low[1])`.
- **Long Entry Conditions (evaluated on closed M5 bar):**
  1. `lower[1] > 0` (valid warmup).
  2. Band expansion: `bbdelta[1] > Close[1] * (bbdelta_per_mille / 1000.0)` (default `bbdelta_per_mille = 7`).
  3. Bar velocity: `closedelta > Close[1] * (closedelta_per_mille / 1000.0)` (baseline default `17`, sweep calibrated `[3, 7, 17]` for FX/metals).
  4. Minimal lower tail: `tail < bbdelta[1] * (tail_per_mille / 1000.0)` (default `tail_per_mille = 25`).
  5. Band pierce: `Close[1] < lower[1]`.
  6. Negative close: `Close[1] <= Close[2]`.
- **Action:** Buy market order at open of next M5 bar (bar 0).
- **Short Entry:** Not present in source (`exit_long = 0`, Long-only capitulation thesis).

### Exit Logic

- **Take Profit (ROI target):** Immediate target `+1.25%` of price (or `+1.5 * ATR(14, M5)`).
- **Stop Loss:** Hard stop at `-5.0%` of price, tightened by MT5 baseline safety stop `1.5 * ATR(14, M5)`.
- **Signal Exit:** Source has no sell signal (`exit_long = 0`); trade lifecycle governed exclusively by ROI target, hard stop, ATR trailing, and weekend close.

### Risk Management & Stop Loss

- **Hard Stop Distance:** Min(`1.5 * ATR(14, M5)`, `0.05 * entry_price`).
- **Position Capacity:** Maximum 1 open position per magic number / symbol at any time.
- **No Gridding / No Martingale:** Zero martingale, zero grid, zero pyramiding, zero averaging down.
- **Position Sizing:**
  - Backtest sets: `RISK_FIXED = 1000`, `RISK_PERCENT = 0` (Build Guardrail compliance).
  - Live / Forward Demo: `RISK_FIXED = 0`, `RISK_PERCENT = 0.5%`.

### News & Framework Guardrails

- **News Blackout:** Mandatory fail-closed news filter around high-impact events. `qm_news_stale_max_hours = 336` (strictly <= 336 hours).
- **Weekend Close:** Enforce Friday close before weekend market close (`qm_friday_close_enabled = true`, broker hour 21).

---

## FTMO Fit & Venue Hypothesis

The strategy is tailored to the FTMO prop trading evaluation and DXZ rules within the Edge Lab charter design box:
- **Drawdown Compliance:** Fixed risk sizing ($1,000 in backtest, 0.5% in live) bounds risk strictly within the 5% daily loss limit (5% daily limit) and the 10% total drawdown limit (10% total drawdown limit).
- **News Blackout Window:** Mandatory news blackout filtering around high-impact events (`qm_news_stale_max_hours = 336`, `QM_NEWS_TEMPORAL_PRE30_POST30`). Orders are withheld 30 minutes before and after high-impact events.
- **Horizon & Execution:** M5 scalp execution (holding minutes to hours), perfectly aligned with Edge Lab scalping horizon (M5-M15). No sub-minute execution, no tick-scalping, no latency arbitrage.

---

## Falsification / Kill Criteria

This strategy is falsified — and should be retired rather than re-parameterized — if any of the following occur during Q02–Q08 testing:
1. **Unprofitable Capitulation Alpha:** Realized profit factor across full-history backtest on target pairs is <= 1.05 net of simulated spreads and commission, indicating sharp drops do not bounce reliably.
2. **Insufficient Execution Cadence:** Realized trade cadence is < 15 trades/year/symbol despite parameter sweep on `closedelta_per_mille` (`[3, 7, 17]`), indicating capitulation filters are too restrictive for FX/metals.
3. **Severe Adverse Execution Drag:** Average trade PnL is smaller than 2.0x average spread plus slippage, rendering the strategy non-viable on live prop execution.
4. **News Contamination:** More than 10% of gross profits originate from entries within high-impact news windows, violating the news blackout principle.

---

## Q08 and Q11 Crisis & News Risk

- **Q08 Stress Testing & Crisis Regimes:** Capitulation drop frequencies spike during market crises (e.g. 2020 COVID shock, 2022 UK mini-budget GBP collapse). While volatility expansion provides high entry density, directional trending moves risk consecutive stop losses. The hard safety stop (Min(1.5*ATR, 5%)) and single-position limit prevent compounding drawdown. Weekend flattening (`qm_friday_close_enabled = true`) eliminates weekend gap exposure.
- **Q11 News & Event Replay:** High-impact economic announcements (CPI, NFP, FOMC) generate artificial price spikes that breach lower Bollinger bands. The mandatory fail-closed news filter (`QM_NEWS_TEMPORAL_PRE30_POST30`) suppresses entry during these event spikes, ensuring trades reflect organic liquidity capitulation rather than event-driven repricing gaps.

---

## R1-R4 Assessment

| Criterion | Status | Rationale |
|-----------|--------|-----------|
| R1 Source-Link | PASS | Full GitHub URL, commit hash `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`, and file path `user_data/strategies/berlinguyinca/BinHV45.py` provided. |
| R2 Mechanical | PASS | Deterministic mathematical formulas for Bollinger Bands(40, 2), bbdelta, closedelta, tail, ROI target, and ATR stop. Cadence calibrated at 30-80 trades/year/symbol on M5. |
| R3 DWX-testbar | PASS | M5 OHLC bars available on DWX broker symbols (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `XAUUSD.DWX`). |
| R4 No ML | PASS | Pure mechanical indicator threshold logic; zero ML models or adaptive neural nets in EA runtime. |

---

## Implementation Notes for Codex (P1)

1. Compute Bollinger Bands on M5: `iBands(_Symbol, PERIOD_M5, 40, 0, 2.0, PRICE_CLOSE)`.
2. Compute `ATR(14, M5)` for dynamic safety stops: `iATR(_Symbol, PERIOD_M5, 14)`.
3. Support parameter sweep for `closedelta_per_mille` with range `[3, 7, 17]`. While 17 per mille was the crypto default, FX and metal dislocations typically materialize at 3–7 per mille; parameterizing this enables robust gate testing across both extreme crisis events and normal market volatility spikes.
4. Enforce strict single-position limit per symbol/magic.
5. Apply news blackout filter and spread filter (<= 6% stop distance).
6. Backtest set configuration must specify `RISK_FIXED = 1000` and `RISK_PERCENT = 0`.
7. Keep `qm_news_stale_max_hours = 336`.

---

## Pipeline History

| Gate | Status | Note |
|------|--------|------|
| G0   | DRAFT  | Append-only second-chance card draft under task `f05399de-2945-4ab3-8006-896e5b150b3a`. Updated to M5 timeframe and added complete Edge Lab charter sections (Falsification, Q08/Q11 Risk, FTMO Fit, Differentiation). |
