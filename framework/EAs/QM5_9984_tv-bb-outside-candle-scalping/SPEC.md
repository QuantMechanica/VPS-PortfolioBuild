# QM5_9984_tv-bb-outside-candle-scalping - Strategy Spec

**EA ID:** QM5_9984
**Slug:** `tv-bb-outside-candle-scalping`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `sources/tradingview-popular-pine-scripts`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades M5 volatility-expansion candles that open and close fully outside a 20-period, 2.0-deviation Bollinger Band. A long signal occurs when the just-closed candle has both open and close above the upper band, optionally with close above EMA200; a short signal mirrors this below the lower band and optionally below EMA200. The initial stop is placed beyond the signal candle's opposite extreme by 1.0 ATR(14). Open positions attempt 33% partial exits at EMA8, EMA12, and final closure at EMA26 when those EMA levels are on the profitable side of entry; any residual position exits if a closed candle crosses back through the Bollinger middle band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | 2+ | Bollinger Band SMA length. |
| `strategy_bb_deviation` | 2.0 | >0 | Bollinger Band standard-deviation multiplier. |
| `strategy_ema_tp1_period` | 8 | 1+ | First EMA tier for 33% partial close. |
| `strategy_ema_tp2_period` | 12 | 1+ | Second EMA tier for 33% partial close. |
| `strategy_ema_tp3_period` | 26 | 1+ | Third EMA tier for final position close. |
| `strategy_use_ema200_filter` | true | true/false | Enables the optional EMA200 directional-bias filter. |
| `strategy_trend_ema_period` | 200 | 1+ | EMA period for the trend filter. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for initial stop distance. |
| `strategy_atr_sl_mult` | 1.0 | >0 | ATR multiplier added beyond the signal candle extreme for SL. |
| `strategy_spread_atr_mult` | 0.6 | >=0 | Blocks entry only when non-zero modeled spread exceeds this fraction of ATR. |
| `strategy_skip_first_session_bar` | true | true/false | Skips the first M5 broker-session bar to avoid stale overnight conditions. |
| `strategy_session_start_hour_broker` | 0 | 0-23 | Broker-time session start hour used by the first-bar skip. |
| `strategy_session_start_min_broker` | 0 | 0-59 | Broker-time session start minute used by the first-bar skip. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major named in the approved card target universe.
- `GBPUSD.DWX` - FX major named in the approved card target universe.
- `USDJPY.DWX` - FX major named in the approved card target universe.
- `XAUUSD.DWX` - liquid metal CFD named in the approved card target universe.
- `NDX.DWX` - live-routable US large-cap index CFD named in the card.
- `WS30.DWX` - live-routable US large-cap index CFD named in the card.
- `SP500.DWX` - supplementary S&P 500 backtest custom symbol named in the card; live promotion requires separate routable validation.

**Explicitly NOT for:**
- Non-DWX symbols and unavailable S&P variants such as `SPX500.DWX`, `SPY.DWX`, or `ES.DWX` - not canonical symbols in `dwx_symbol_matrix.csv`.
- Untested sector ETF or small-cap substitutions - the approved card does not name them for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | Intraday scalping holds, usually minutes to a few M5 bars when EMA tiers or middle-band exits fire. |
| Expected drawdown profile | Frequent small losses bounded by signal-candle extreme plus ATR stop. |
| Regime preference | Volatility-expansion breakout with optional trend bias. |
| Win rate target (qualitative) | Medium; edge comes from high cadence and staged exits, not a high single-trade payoff. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView popular Pine script
**Pointer:** `https://www.tradingview.com/script/CmHXgNGT-Bollinger-Band-Scalping/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9984_tv-bb-outside-candle-scalping.md`

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
| v1 | 2026-06-20 | Initial build from card | 125abeb0-f876-4a47-9252-6646746ea6fd |
