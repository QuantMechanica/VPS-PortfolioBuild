# QM5_1122_unger-crude-donchian160 - Strategy Spec

**EA ID:** QM5_1122
**Slug:** `unger-crude-donchian160`
**Source:** `eb97a148-0af9-5b9c-878c-25fb5dfa34f9` (see `sources/unger-robbins-cup`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades XTIUSD.DWX on M5 using a 160-bar Donchian breakout. On each closed bar, it computes the highest high and lowest low of the prior 160 completed bars, excluding the just-closed breakout bar. It opens long when the last closed price is above the prior channel high and opens short when the last closed price is below the prior channel low. It exits on an opposite channel break, on the hard ATR stop, on the framework Friday close, or after a 10-session time cap.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_donchian_period` | 160 | 2+ | Number of completed M5 bars used for the Donchian high/low channel. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for the initial hard stop. |
| `strategy_atr_sl_mult` | 3.0 | >0 | ATR multiple for the initial stop distance. |
| `strategy_trailing_enabled` | false | true/false | Enables the optional ATR trailing stop; disabled for the first build per card. |
| `strategy_trailing_atr_mult` | 2.5 | >0 | ATR multiple used if the optional trailing stop is enabled. |
| `strategy_max_sessions` | 10 | 0+ | Maximum holding time in trading-session days before flattening; 0 disables this cap. |
| `strategy_session_start_hour` | 1 | 0-24 | Broker-time start hour for the XTIUSD active session assumption. |
| `strategy_session_start_minute` | 0 | 0-59 | Broker-time start minute for the XTIUSD active session assumption. |
| `strategy_session_end_hour` | 24 | 0-24 | Broker-time end hour for the XTIUSD active session assumption. |
| `strategy_session_end_minute` | 0 | 0-59 | Broker-time end minute for the XTIUSD active session assumption. |
| `strategy_session_skip_minutes` | 30 | 0+ | Skips the first and last minutes of the configured active session. |
| `strategy_max_spread_points` | 0.0 | 0+ | Optional spread cap; 0 disables the cap and never fails closed on zero `.DWX` spread. |
| `strategy_d1_vol_gate_enabled` | true | true/false | Requires D1 ATR to be above the configured historical percentile. |
| `strategy_d1_atr_period` | 14 | 1+ | D1 ATR period used by the volatility gate. |
| `strategy_d1_atr_lookback` | 120 | 20+ | Number of D1 ATR samples used for percentile ranking. |
| `strategy_d1_atr_min_percentile` | 25.0 | 0-100 | Minimum D1 ATR percentile required for new entries. |
| `strategy_allow_same_bar_reversal` | false | true/false | Allows opening the opposite direction on the same bar as an opposite-channel exit. |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - Crude-oil CFD/custom symbol explicitly named by the card and present in the DWX commodity matrix.

**Explicitly NOT for:**
- `XNGUSD.DWX` - Energy commodity but natural gas has a different volatility and seasonality profile.
- `XAUUSD.DWX` - Commodity symbol but the card is specifically crude-oil Donchian breakout logic.
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX` - Equity-index symbols outside the card's crude-oil universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `PERIOD_D1` ATR percentile volatility gate |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `500` |
| Typical hold time | Intraday to multi-day, capped at 10 trading sessions |
| Expected drawdown profile | Trend-following whipsaw risk during range-bound crude markets |
| Regime preference | Channel breakout / volatility expansion / trend following |
| Win rate target (qualitative) | Medium-low win rate with larger trend captures |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `eb97a148-0af9-5b9c-878c-25fb5dfa34f9`
**Source type:** article and book
**Pointer:** Unger Academy article "Trading Systems: $35,000 Gained in 2 Years on Crude Oil" and `sources/unger-robbins-cup`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1122_unger-crude-donchian160.md`

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
| v1 | 2026-06-23 | Initial build from card | 3ec7c436-5d21-4c52-b551-1470f02924ff |
