# QM5_10846_tv-growth-bo - Strategy Spec

**EA ID:** QM5_10846
**Slug:** `tv-growth-bo`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

Long only on D1 or H4. A trade opens when the last closed bar is near EMA(20), near the 252-bar high, closes above the prior 10-bar high, has tick volume at least 1.5 times the prior 20-bar average, passes the EMA trend filter, and has bullish StochRSI below 80. The emergency stop is 2.5 * ATR(14) below entry, and the primary discretionary exit closes the long when the last closed bar crosses below EMA(50).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema_period` | 20 | >0 | Fast EMA used for proximity and trend filter. |
| `strategy_slow_ema_period` | 50 | > fast EMA | Slow EMA used for trend filter and primary exit. |
| `strategy_breakout_lookback` | 10 | >0 | Prior-bar high window that the close must break. |
| `strategy_high_lookback_bars` | 252 | > breakout lookback | 52-week equivalent high window on D1/H4 bars. |
| `strategy_fast_ema_proximity` | 0.02 | >0 | Maximum absolute close-to-EMA(20) distance as a fraction of EMA. |
| `strategy_high_proximity` | 0.05 | >0 | Maximum distance below the lookback high. |
| `strategy_rvol_lookback` | 20 | >0 | Prior closed bars used for tick-volume average. |
| `strategy_rvol_threshold` | 1.5 | >0 | Required relative volume multiple. |
| `strategy_rsi_period` | 14 | >0 | RSI period used inside StochRSI. |
| `strategy_stoch_rsi_period` | 14 | >1 | RSI min/max window for StochRSI. |
| `strategy_stoch_k_smooth` | 3 | >0 | StochRSI K smoothing length. |
| `strategy_stoch_d_smooth` | 3 | >0 | StochRSI D smoothing length. |
| `strategy_stoch_overbought` | 80.0 | >0 | Upper cap for bullish StochRSI entries. |
| `strategy_atr_period` | 14 | >0 | ATR period for emergency stop and spread filter. |
| `strategy_atr_sl_mult` | 2.5 | >0 | ATR multiple for emergency stop. |
| `strategy_max_spread_stop_frac` | 0.15 | >0 | Maximum spread as a fraction of emergency stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 proxy for growth-stock breakout behavior.
- `WS30.DWX` - Dow 30 portable US large-cap index exposure.
- `GDAXI.DWX` - DAX equivalent available in the DWX matrix; used for card-stated GER40 exposure.
- `SP500.DWX` - S&P 500 custom symbol; valid for backtest-only build registration.
- `XAUUSD.DWX` - Portable liquid non-index instrument from the card basket.

**Explicitly NOT for:**
- `GER40.DWX` - Card-stated name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the available DAX symbol.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Not canonical DWX symbols for the S&P 500.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Expected trade frequency | not specified in card frontmatter |
| Typical hold time | not specified in card frontmatter; expected multi-day trend holds from EMA50 exit |
| Expected drawdown profile | Momentum breakout with risk during false breakouts and poor tick-volume portability. |
| Regime preference | breakout / momentum / volume-confirmed trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/cIaYJiab-Growth-Breakout-Strategy-v3-EMA-RVOL-Stoch-RSI/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10846_tv-growth-bo.md`

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
| v1 | 2026-06-06 | Initial build from card | 9c0289d0-5e29-4873-98f9-a3dfee8289b4 |
