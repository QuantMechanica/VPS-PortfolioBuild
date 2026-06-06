# QM5_10956_ftmo-vwap-pb - Strategy Spec

**EA ID:** QM5_10956
**Slug:** ftmo-vwap-pb
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades M15 VWAP pullbacks during the configured London/New York broker-time session. A large expansion candle must close outside the same-side VWAP deviation band, then price has 12 M15 bars to pull back to central VWAP and reject it. Long entries require a VWAP touch/cross and bullish close back above VWAP; short entries mirror the rule below VWAP. TP is placed at the same-side VWAP deviation band, session end forces exit, and ATR trailing starts only after price reaches +1.5R before TP.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_timeframe | PERIOD_M15 | PERIOD_M15 | Signal timeframe required by the card. |
| strategy_atr_period | 14 | 2-100 | ATR period for expansion filter, stops, and trailing. |
| strategy_band_atr_mult | 1.0 | 0.1-5.0 | ATR width used for the VWAP deviation bands because the card does not specify a formula. |
| strategy_setup_expiry_bars | 12 | 1-96 | Bars after expansion before the pullback setup expires. |
| strategy_min_body_atr_mult | 0.80 | 0.1-5.0 | Minimum expansion candle body as a multiple of ATR. |
| strategy_slope_bars | 6 | 1-48 | Closed-bar VWAP slope lookback. |
| strategy_flat_slope_atr_mult | 0.10 | 0.0-2.0 | Skip entries when absolute VWAP slope is below this ATR multiple. |
| strategy_stop_atr_mult | 0.35 | 0.01-5.0 | ATR component of the stop distance beyond VWAP. |
| strategy_stop_band_mult | 0.15 | 0.01-2.0 | Deviation-band component of the stop distance beyond VWAP. |
| strategy_trail_trigger_r | 1.50 | 0.1-10.0 | Profit in R before ATR trailing can begin. |
| strategy_trail_atr_mult | 1.0 | 0.1-10.0 | ATR trailing stop multiplier. |
| strategy_session_start_hour | 7 | 0-23 | Broker-time session start for London/New York trading. |
| strategy_session_end_hour | 22 | 0-23 | Broker-time session end and time-exit boundary. |
| strategy_vwap_bootstrap_bars | 96 | 16-192 | Maximum M15 bars used inside the closed-bar VWAP cache refresh. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - primary liquid FX major from the card R3 basket.
- GBPUSD.DWX - liquid FX major from the card R3 basket.
- XAUUSD.DWX - gold instrument from the card R3 basket, suited to intraday VWAP pullbacks.
- NDX.DWX - liquid index instrument from the card R3 basket, suited to intraday expansion and pullback.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DarwinexZero testing.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_timeframe)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Intraday; minutes to the same session end |
| Expected drawdown profile | Pullback-continuation losses cluster during flat VWAP or failed expansion regimes |
| Regime preference | Intraday trend and volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** FTMO blog
**Pointer:** FTMO VWAP Pullback Strategy article; approved card path `artifacts/cards_approved/QM5_10956_ftmo-vwap-pb.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10956_ftmo-vwap-pb.md`

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
| v1 | 2026-06-06 | Initial build from card | 19c92c53-6957-40c4-8738-2ee63e9fa3a9 |
