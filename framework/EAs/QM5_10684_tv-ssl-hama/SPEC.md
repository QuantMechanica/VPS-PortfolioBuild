# QM5_10684_tv-ssl-hama - Strategy Spec

**EA ID:** QM5_10684
**Slug:** `tv-ssl-hama`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source citation)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

This EA trades when SSL Channel direction and Hama candle direction agree on the last closed bar. A long entry requires SSL uptrend, Hama uptrend, close above the Hama line, and no ATR compression; a short entry requires the inverse. Stop loss is placed beyond the Hama line with a 0.1 ATR buffer, take profit is a configurable fixed risk-to-reward target, and open positions are closed early if price returns to the Hama line before TP.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ssl_period` | 10 | 1-200 | SMA period for SSL high/low channel state. |
| `strategy_ssl_state_lookback` | 8 | 1-50 | Closed bars searched when the newest SSL bar is inside the channel. |
| `strategy_hama_ema_period` | 20 | 1-200 | EMA transform period for Hama open and close candles. |
| `strategy_hama_line_period` | 34 | 1-300 | EMA period for the Hama line. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for consolidation and stop buffer. |
| `strategy_atr_average_lookback` | 20 | 1-200 | ATR samples used for the consolidation baseline. |
| `strategy_consolidation_atr_ratio` | 0.80 | 0.10-2.00 | Blocks entries when current ATR is below this ratio of average ATR. |
| `strategy_stop_buffer_atr` | 0.10 | 0.00-2.00 | ATR buffer added beyond the Hama line for SL placement. |
| `strategy_rr` | 2.00 | 0.10-10.00 | Fixed take-profit multiple of initial risk. |
| `strategy_max_spread_points` | 0 | 0-10000 | Optional spread gate; 0 disables the gate. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major named in the card R3 basket.
- `GBPUSD.DWX` - liquid FX major named in the card R3 basket.
- `USDJPY.DWX` - liquid FX major named in the card R3 basket.
- `XAUUSD.DWX` - canonical DWX gold symbol for the card's `XAUUSD` target.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; DAX exposure is registered as `GDAXI.DWX`.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - broker/custom-symbol data is not available for build registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` and `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | short intraday scalping holds |
| Expected drawdown profile | many small trend-continuation losses controlled by Hama-line stop distance |
| Regime preference | trend-following with low-volatility consolidation filtered out |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/D817LSt0/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10684_tv-ssl-hama.md`

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
| v1 | 2026-05-31 | Initial build from card | 163fb994-75ce-45d0-9816-a4c79dca0a52 |
