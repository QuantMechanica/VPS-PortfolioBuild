# QM5_10680_tv-liq-engulf - Strategy Spec

**EA ID:** QM5_10680
**Slug:** `tv-liq-engulf`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA looks for a closed candle that sweeps a recent local low or high, then confirms reversal with an engulfing candle. A long signal requires the signal candle to sweep the prior lookback low, close bullish, and close above the previous bearish candle high. A short signal requires the signal candle to sweep the prior lookback high, close bearish, and close below the previous bullish candle low. Positions use fixed SL/TP, close after the max hold window, and close early when an opposite qualified liquidity plus engulfing signal appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_liquidity_lookback` | 20 | 1-200 | Closed bars used to define the prior upper and lower liquidity lines. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for stop buffer, stop cap, TP distance, and engulfing range filter. |
| `strategy_stop_buffer_atr` | 0.2 | 0.0-5.0 | ATR buffer placed beyond the signal candle extreme for the initial SL. |
| `strategy_max_stop_atr_mult` | 2.5 | 0.1-10.0 | Maximum allowed SL distance in ATR units. |
| `strategy_tp_atr_mult` | 2.0 | 0.1-10.0 | Predefined TP distance in ATR units. |
| `strategy_max_engulf_range_atr_mult` | 2.0 | 0.1-10.0 | Skips engulfing candles whose range exceeds this ATR multiple. |
| `strategy_session_start_hour` | 15 | 0-23 | Broker-hour start of the London/New York overlap entry window. |
| `strategy_session_start_min` | 0 | 0-59 | Broker-minute start of the London/New York overlap entry window. |
| `strategy_session_end_hour` | 19 | 0-23 | Broker-hour end of the London/New York overlap entry window. |
| `strategy_session_end_min` | 0 | 0-59 | Broker-minute end of the London/New York overlap entry window. |
| `strategy_max_hold_bars` | 48 | 1-500 | Time exit after this many base-timeframe bars. |
| `strategy_allow_longs` | true | true/false | Enables bullish sweep plus engulfing entries. |
| `strategy_allow_shorts` | true | true/false | Enables bearish sweep plus engulfing entries. |
| `strategy_max_spread_points` | 0 | 0-100000 | Optional spread ceiling; 0 disables the spread filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX symbol with full DWX matrix support.
- `GBPUSD.DWX` - card-listed liquid FX symbol with full DWX matrix support.
- `USDJPY.DWX` - card-listed liquid FX symbol with full DWX matrix support.
- `XAUUSD.DWX` - canonical DWX form of card-listed `XAUUSD` metal exposure.
- `GDAXI.DWX` - matrix-valid DAX custom symbol used for card-listed `GER40.DWX`.

**Explicitly NOT for:**
- Non-DWX broker symbols - the build and P2 registry use DWX custom symbols only.
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday, capped at 48 M15 bars (about 12 hours) |
| Expected drawdown profile | Mean-reversion reversals with fixed SL/TP and one active position per symbol/magic |
| Regime preference | Mean-revert liquidity sweep rejection |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy script`
**Pointer:** `https://www.tradingview.com/script/xnV1EEYr-Liquidity-Engulfment-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10680_tv-liq-engulf.md`

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
| v1 | 2026-05-31 | Initial build from card | 0d56c52a-3535-44ff-94b3-276ab09df527 |
