# QM5_10785_tv-momo-200 - Strategy Spec

**EA ID:** QM5_10785
**Slug:** tv-momo-200
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView source pointer below)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

This EA trades a momentum breakout through the long-term 200-period simple moving average. A long entry requires the last closed bar to cross above SMA(200), MACD(12,26,9) to be above zero, and smoothed StochRSI %K to be above 80. A short entry requires the last closed bar to cross below SMA(200), MACD to be below zero, and StochRSI %K to be below 20. Stops use the most recent confirmed swing low or high with an ATR buffer; targets use the most recent swing in the trade direction and fall back to a fixed R multiple when no valid swing target exists.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 200 | 100-200 | Long-term SMA used for breakout cross. |
| `strategy_macd_fast` | 12 | 8-12 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 21-26 | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 5-9 | MACD signal period. |
| `strategy_rsi_period` | 14 | 7-21 | RSI period used inside StochRSI. |
| `strategy_stoch_rsi_period` | 14 | 7-21 | Lookback for StochRSI min/max normalization. |
| `strategy_stoch_k_smooth` | 3 | 1-5 | Smoothing samples for StochRSI %K. |
| `strategy_stoch_long_level` | 80.0 | 70.0-80.0 | Long momentum threshold. |
| `strategy_stoch_short_level` | 20.0 | 20.0-30.0 | Short momentum threshold. |
| `strategy_swing_lookback` | 10 | 5-20 | Bars searched for confirmed swing stop/target anchors. |
| `strategy_swing_confirm` | 2 | 1-3 | Bars on each side required to confirm a swing. |
| `strategy_atr_period` | 14 | 7-21 | ATR period for the stop buffer. |
| `strategy_atr_buffer_mult` | 0.25 | 0.0-1.0 | ATR multiple added beyond the swing stop anchor. |
| `strategy_fallback_rr` | 2.0 | 1.5-2.0 | R multiple used when no valid swing target is available. |
| `strategy_max_bars_in_trade` | 96 | 24-192 | Time exit after this many chart bars. |
| `strategy_max_spread_atr` | 0.20 | 0.0-0.50 | No-trade spread ceiling as a fraction of ATR. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - this table lists only strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with DWX history and sufficient liquidity for SMA/MACD/StochRSI tests.
- `GBPUSD.DWX` - card-listed FX major with DWX history and sufficient liquidity for momentum breakout tests.
- `USDJPY.DWX` - card-listed FX major with DWX history and sufficient liquidity for momentum breakout tests.
- `XAUUSD.DWX` - canonical DWX gold symbol for the card's `XAUUSD` target.
- `GDAXI.DWX` - matrix-listed DAX custom symbol used for the card's unavailable `GER40.DWX` name.
- `NDX.DWX` - card-listed Nasdaq 100 index symbol.
- `WS30.DWX` - card-listed Dow 30 index symbol.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `XAUUSD` - not a DWX matrix symbol without the `.DWX` suffix; mapped to `XAUUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

The card also lists `M30` and `H1` as parameter-test timeframes, so Q02 setfiles are generated for `M15`, `M30`, and `H1`.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | intraday to several days, bounded by `strategy_max_bars_in_trade` |
| Expected drawdown profile | whipsaw risk around the 200 SMA, especially in sideways regimes |
| Regime preference | momentum breakout / trend transition |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/gYkIvFGi-Momentum-Breakout-200SMA-MACD-StochRSI/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10785_tv-momo-200.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-05 | Initial build from card | 2017e44c-d8c2-4f0b-8a26-91f5ed91f8a3 |
