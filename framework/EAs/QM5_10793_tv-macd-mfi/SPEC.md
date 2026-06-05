# QM5_10793_tv-macd-mfi - Strategy Spec

**EA ID:** QM5_10793
**Slug:** `tv-macd-mfi`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades closed-bar MACD signal-line crosses on a fixed higher timeframe and requires tick-volume money flow to agree with the direction. A long opens when MACD crosses bullish and MFI is above the configured positive-flow threshold; a short opens when MACD crosses bearish and MFI is below the configured negative-flow threshold. Optional EMA, RSI-band, and ATR-percentile filters can block entries without changing the core MACD/MFI rule. Stops are ATR-normalized by default, trailing profit activates after the configured R multiple, and an opposite MACD cross closes the open position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_M15` | `PERIOD_M5`-`PERIOD_M30` tested | Fixed timeframe used for MACD, MFI, EMA, RSI, and ATR filters |
| `strategy_macd_fast` | `12` | `8`-`12` tested | Fast MACD EMA length |
| `strategy_macd_slow` | `26` | `21`-`26` tested | Slow MACD EMA length |
| `strategy_macd_signal` | `9` | `5`-`9` tested | MACD signal length |
| `strategy_mfi_period` | `14` | `14`-`21` tested | Tick-volume MFI lookback |
| `strategy_mfi_long_min` | `50.0` | `0`-`100` | Minimum MFI for long confirmation |
| `strategy_mfi_short_max` | `50.0` | `0`-`100` | Maximum MFI for short confirmation |
| `strategy_ema_filter_on` | `false` | `true/false` | Enables the optional trend-side EMA filter |
| `strategy_ema_period` | `200` | `20`-`300` | EMA length for optional direction filter |
| `strategy_rsi_filter_on` | `false` | `true/false` | Enables the optional RSI activity-band filter |
| `strategy_rsi_period` | `14` | `7`-`21` | RSI lookback for optional activity band |
| `strategy_rsi_lower` | `40.0` | `0`-`100` | Lower RSI activity-band boundary |
| `strategy_rsi_upper` | `70.0` | `0`-`100` | Upper RSI activity-band boundary |
| `strategy_atr_filter_on` | `false` | `true/false` | Enables the optional low-volatility ATR percentile filter |
| `strategy_atr_period` | `14` | `7`-`21` | ATR lookback used for stop and optional volatility filter |
| `strategy_atr_rank_bars` | `100` | `20`-`300` | ATR sample count for percentile threshold |
| `strategy_atr_min_pctile` | `20.0` | `0`-`100` | Minimum ATR percentile accepted when the filter is enabled |
| `strategy_stop_mode` | `0` | `0`-`1` | `0` uses ATR stop, `1` uses fixed-percent stop |
| `strategy_stop_atr_mult` | `1.5` | `1.0`-`2.0` tested | ATR stop multiplier |
| `strategy_stop_fixed_pct` | `0.5` | `0.1`-`5.0` | Fixed-percent stop distance for index-style axis |
| `strategy_trail_activate_r` | `1.0` | `1.0`-`2.0` tested | Profit multiple that activates trailing management |
| `strategy_trail_deviation_r` | `1.0` | `0.5`-`2.0` | Trailing stop distance measured from current price in initial-risk units |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with native DWX tick data and enough intraday movement for MACD/MFI scalping.
- `GBPUSD.DWX` - liquid FX major with native DWX tick data and higher intraday range.
- `USDJPY.DWX` - liquid FX major with native DWX tick data and distinct USD/JPY momentum profile.
- `XAUUSD.DWX` - metal CFD equivalent for the card's gold exposure, with DWX tick-volume proxy available.
- `GDAXI.DWX` - DAX 40 DWX matrix symbol used in place of the card's `GER40.DWX` label.
- `NDX.DWX` - Nasdaq 100 index CFD with liquid intraday momentum behavior.
- `WS30.DWX` - Dow 30 index CFD for US large-cap intraday momentum exposure.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `XAUUSD` - unsuffixed live-style symbol; backtest registry uses `XAUUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | Fixed signal timeframe input, default `M15`; tested axis includes `M5`, `M15`, `M30` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | Intraday scalps, usually minutes to hours |
| Expected drawdown profile | Higher-cadence momentum strategy with normal clustered losing streak risk around range-bound sessions |
| Regime preference | Momentum-confirmation and volatility-expansion intraday regimes |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10793_tv-macd-mfi.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10793_tv-macd-mfi.md`

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
| v1 | 2026-06-05 | Initial build from card | 7f6be844-32d6-43e5-a10f-c526ddb0b025 |
