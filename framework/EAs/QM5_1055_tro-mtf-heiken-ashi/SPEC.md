# QM5_1055_tro-mtf-heiken-ashi - Strategy Spec

**EA ID:** QM5_1055
**Slug:** tro-mtf-heiken-ashi
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades on M15 closed bars when Heiken Ashi candle color aligns across H4, H1, and M15, and the M15 Heiken-Ashi-Smoothed confirmation candle has the same color. Long entries require all four readings bullish; short entries require all four readings bearish. The initial stop is placed at the most recent completed H1 Heiken Ashi low for longs or high for shorts, plus a point buffer. Open trades close when the M15 Heiken-Ashi-Smoothed candle flips against the position, with an optional H1 flip exit exposed as a P3 parameter.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_has_period | 6 | 1-100 | EMA pre-smoothing period for the Heiken-Ashi-Smoothed M15 confirmation. |
| strategy_ha_lookback_bars | 80 | 12-500 | Bounded warmup bars used for deterministic Heiken Ashi open recursion. |
| strategy_sl_buffer_points | 15 | 0-1000 | Extra point buffer beyond the H1 Heiken Ashi low/high stop anchor. |
| strategy_spread_cap_points | 20 | 0-1000 | Maximum allowed spread in points; zero disables the cap. |
| strategy_exit_on_h1_flip | false | true/false | Optional P3 exit variant: close if the H1 HA candle flips against the position. |
| strategy_use_session_filter | false | true/false | Optional P3 session gate for London through NY hours. |
| strategy_london_start_hour | 7 | 0-23 | Broker-hour session start when the optional session gate is enabled. |
| strategy_ny_end_hour | 21 | 0-23 | Broker-hour session end when the optional session gate is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 basket FX major with DWX live-tradable data.
- GBPUSD.DWX - card R3 basket FX major with DWX live-tradable data.
- USDJPY.DWX - card R3 basket JPY cross with DWX live-tradable data.
- AUDUSD.DWX - card R3 basket FX major with DWX live-tradable data.
- EURJPY.DWX - card R3 basket JPY cross with DWX live-tradable data.
- GBPJPY.DWX - card R3 basket JPY cross with DWX live-tradable data.

**Explicitly NOT for:**
- Non-FX index, metal, energy, or crypto symbols - not part of the approved R3 TRO FX basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | H4 closed HA candle, H1 closed HA candle, M15 closed HA candle, M15 closed HAS candle |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_M15) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 500 |
| Typical hold time | Intraday to multi-session trend holds |
| Expected drawdown profile | Trend-following whipsaw risk during mixed HA regimes |
| Regime preference | trend / multi-timeframe confluence |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** ForexFactory Trading Systems forum, TRO Heiken Ashi / TRO MTF thread cluster
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1055_tro-mtf-heiken-ashi.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-13 | Initial build from card | dd1bc996-d0c7-4e13-becf-368bebdc46af |
