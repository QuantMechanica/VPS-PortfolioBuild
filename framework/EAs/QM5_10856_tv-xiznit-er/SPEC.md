# QM5_10856_tv-xiznit-er - Strategy Spec

**EA ID:** QM5_10856
**Slug:** tv-xiznit-er
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView Xiznit Advanced Scalper card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades a short-timeframe Efficiency Ratio regime transition after a full non-trending reset. A long entry requires ER to transition from neutral to uptrend, price and both EMAs to close above session VWAP, fast EMA to be above slow EMA, both EMAs to slope upward, the signal candle body to clear a minimum ATR-based size, and the close to break the prior-bar high. A short entry mirrors those rules below VWAP and below the prior-bar low. Open trades use fixed ATR stop and target distances, close when ER is no longer aligned with the trade direction, and flatten at the broker-time equivalent of the card's 15:58 CST cutoff.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ma_period` | 9 | 1+ | Fast EMA used for Full Filter alignment. |
| `strategy_slow_ma_period` | 21 | greater than fast MA | Slow EMA used for Full Filter alignment. |
| `strategy_er_length` | 20 | 2+ | Efficiency Ratio lookback length. |
| `strategy_er_trend_threshold` | 0.35 | greater than 0 | Minimum ER value that classifies a bar as trending. |
| `strategy_atr_period` | 14 | 1+ | ATR period for stop, target, spread guard, and body threshold. |
| `strategy_atr_stop_mult` | 1.0 | greater than 0 | Stop distance as a multiple of ATR(14). |
| `strategy_atr_target_mult` | 1.0 | greater than 0 | Take-profit distance as a multiple of ATR(14). |
| `strategy_min_body_atr_frac` | 0.05 | 0+ | Minimum signal candle body as a fraction of ATR. |
| `strategy_max_spread_stop_frac` | 0.15 | greater than 0 | Entry spread guard as a fraction of ATR stop distance. |
| `strategy_min_session_bars` | 20 | 1+ | Minimum broker-day bars required before session VWAP signals are valid. |
| `strategy_ny_open_hour_broker` | 16 | 0-23 | Broker hour corresponding to NY session open. |
| `strategy_ny_open_minute` | 30 | 0-59 | Broker minute corresponding to NY session open. |
| `strategy_open_block_minutes` | 20 | 0-1439 | Minutes blocked after NY session open. |
| `strategy_lunch_start_hour` | 20 | 0-23 | Broker hour for CST lunch-hour block start. |
| `strategy_lunch_end_hour` | 21 | 0-23 | Broker hour for CST lunch-hour block end. |
| `strategy_flat_hour_broker` | 23 | 0-23 | Broker hour for EOD flatten. |
| `strategy_flat_minute_broker` | 58 | 0-59 | Broker minute for EOD flatten. |

Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Card-stated Nasdaq index target ported from MNQ-style exposure.
- `WS30.DWX` - Card-stated US index basket member with liquid DWX intraday data.
- `GDAXI.DWX` - Canonical DWX DAX symbol used for the card's `GER40.DWX` target.
- `XAUUSD.DWX` - Card-stated metal CFD target ported from MGC-style exposure.
- `XAGUSD.DWX` - Card-stated silver CFD target ported from SIL-style exposure.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SP500.DWX` - Mentioned only as a possible later test path, not in the card's Primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M2, M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday scalps, usually minutes to same-session. |
| Expected drawdown profile | High-cadence scalper vulnerable to choppy VWAP and ER threshold noise. |
| Regime preference | ER-classified trend continuation with VWAP and EMA alignment. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/qP7M4QtD-Xiznit-Advanced-Scalper/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10856_tv-xiznit-er.md`

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
| v1 | 2026-06-06 | Initial build from card | 69a6b57e-316a-4590-8134-b8e7d0feffac |
