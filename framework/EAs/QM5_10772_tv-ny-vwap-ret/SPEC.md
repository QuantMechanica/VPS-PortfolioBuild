# QM5_10772_tv-ny-vwap-ret - Strategy Spec

**EA ID:** QM5_10772
**Slug:** `tv-ny-vwap-ret`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades New York session continuation after price retests session VWAP, the premarket range, or a fast EMA while price remains on the trend side of a higher-timeframe EMA. Session VWAP is advanced once per closed bar from typical price and tick volume, and premarket high/low reset each trading day. The default baseline uses VWAP retests only; the entry-model input can freeze premarket breakout, EMA retest, or combined mode for later tests. Positions exit when a closed candle body crosses the exit EMA against the trade or when the New York window ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_htf_tf` | `PERIOD_H1` | MT5 timeframe enum | Higher timeframe used for trend EMA. |
| `strategy_htf_ema_period` | `100` | `50-200` | Higher-timeframe EMA period. |
| `strategy_exit_ema_period` | `20` | `9-34` | EMA used for aggressive-body exit. |
| `strategy_fast_ema_period` | `20` | `9-34` | Fast EMA used by entry model 3. |
| `strategy_entry_model` | `1` | `1-4` | `1` VWAP retest, `2` premarket breakout, `3` EMA retest, `4` combined. |
| `strategy_premarket_breakout_mode` | `0` | `0-1` | `0` close beyond premarket range, `1` retest of boundary. |
| `strategy_atr_period` | `14` | `14` | ATR period for stop buffer and regime checks. |
| `strategy_atr_stop_buffer` | `0.50` | `0.25-1.0` | ATR buffer beyond VWAP, premarket boundary, or EMA retest swing. |
| `strategy_vwap_retest_atr` | `0.20` | `0.0-1.0` | ATR tolerance for VWAP or EMA retest touch. |
| `strategy_min_range_atr` | `0.25` | `0.0-2.0` | Blocks compressed bars relative to ATR. |
| `strategy_min_vwap_slope_points` | `0.0` | `0.0+` | Minimum VWAP slope in points; zero is the low-threshold baseline. |
| `strategy_exit_body_atr` | `0.20` | `0.0-2.0` | Minimum candle body size for exit EMA cross. |
| `strategy_cooldown_bars` | `5` | `0-10` | Closed-bar cooldown after strategy exit. |
| `strategy_max_spread_points` | `80` | `0+` | Spread ceiling for the no-trade filter. |
| `strategy_premarket_start_hour` | `12` | `0-23` | Broker-time premarket start hour. |
| `strategy_premarket_start_minute` | `0` | `0-59` | Broker-time premarket start minute. |
| `strategy_ny_start_hour` | `16` | `0-23` | Broker-time NY regular-session start hour. |
| `strategy_ny_start_minute` | `30` | `0-59` | Broker-time NY regular-session start minute. |
| `strategy_ny_end_hour` | `21` | `0-23` | Broker-time NY flat/end hour. |
| `strategy_ny_end_minute` | `0` | `0-59` | Broker-time NY flat/end minute. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - matrix-valid liquid FX major from the card R3 basket.
- `GBPUSD.DWX` - matrix-valid liquid FX major from the card R3 basket.
- `USDJPY.DWX` - matrix-valid liquid FX major from the card R3 basket.
- `XAUUSD.DWX` - matrix-valid gold symbol; normalizes card token `XAUUSD`.
- `GDAXI.DWX` - matrix-valid DAX proxy; normalizes card token `GER40.DWX`.
- `NDX.DWX` - matrix-valid US large-cap index from the card R3 basket.
- `WS30.DWX` - matrix-valid US large-cap index from the card R3 basket.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - broker/custom-symbol data availability is not verified.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` and `M15` |
| Multi-timeframe refs | Higher-timeframe EMA on `strategy_htf_tf`, default `PERIOD_H1` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | Intraday; positions are flat by the configured New York end time. |
| Expected drawdown profile | Fixed-risk intraday continuation with ATR-buffered structural stops. |
| Regime preference | Trend continuation, VWAP retest, and opening-range expansion. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/zV6RrYm5-NY-Session-Trend-Retest-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10772_tv-ny-vwap-ret.md`

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
| v1 | 2026-05-31 | Initial build from card | 597e7d5e-2619-482d-94cc-e22c03c59407 |
