# QM5_1229_carver-statevol - Strategy Spec

**EA ID:** QM5_1229
**Slug:** carver-statevol
**Source:** 2a380bee-1ec4-50d1-a348-b10fac642c7a (see `sources/rob-carver-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

On each closed D1 bar, the EA computes 25-day standard deviation of daily percentage returns, divides it by a long-run average of that volatility, ranks the current normalized volatility against prior normalized values, and maps the percentile to a forecast from -20 to +20 with 10-day EMA smoothing. It opens long when the smoothed forecast is above +5 and short when it is below -5. Long positions close when the cached closed-bar forecast falls to 0 or lower; short positions close when it rises to 0 or higher. Every entry uses an emergency stop at 2.5 times ATR(20) on D1.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_vol_lookback` | 25 | 2+ | Daily percentage-return standard deviation lookback. |
| `strategy_long_vol_baseline` | 2500 | 1+ | Preferred long-run average window for daily volatility. |
| `strategy_smooth_period` | 10 | 1+ | EMA smoothing period applied to raw forecast. |
| `strategy_entry_threshold` | 5.0 | 0-20 | Forecast threshold for long and short entries. |
| `strategy_exit_threshold` | 0.0 | 0-20 | Forecast level that triggers strategy exit. |
| `strategy_min_prior_bars` | 500 | 20+ | Minimum D1 history for smoke and percentile calculations. |
| `strategy_atr_period` | 20 | 1+ | ATR period used for the emergency stop. |
| `strategy_atr_sl_mult` | 2.5 | 0+ | ATR multiple used for the emergency stop distance. |
| `strategy_spread_lookback` | 20 | 0+ | D1 spread lookback for the 2x median spread entry cap. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `AUDCHF.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `AUDJPY.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `AUDNZD.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `AUDUSD.DWX` - DWX forex major with D1 OHLC history suitable for return-volatility ranking.
- `CADCHF.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `CADJPY.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `CHFJPY.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `EURAUD.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `EURCAD.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `EURCHF.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `EURGBP.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `EURJPY.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `EURNZD.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `EURUSD.DWX` - DWX forex major with D1 OHLC history suitable for return-volatility ranking.
- `GBPAUD.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `GBPCAD.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `GBPCHF.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `GBPJPY.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `GBPNZD.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `GBPUSD.DWX` - DWX forex major with D1 OHLC history suitable for return-volatility ranking.
- `NZDCAD.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `NZDCHF.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `NZDJPY.DWX` - DWX forex pair with D1 OHLC history suitable for return-volatility ranking.
- `NZDUSD.DWX` - DWX forex major with D1 OHLC history suitable for return-volatility ranking.
- `USDCAD.DWX` - DWX forex major with D1 OHLC history suitable for return-volatility ranking.
- `USDCHF.DWX` - DWX forex major with D1 OHLC history suitable for return-volatility ranking.
- `USDJPY.DWX` - DWX forex major with D1 OHLC history suitable for return-volatility ranking.
- `SP500.DWX` - DWX S&P 500 custom index with D1 OHLC history for backtest-only index exposure.
- `NDX.DWX` - DWX Nasdaq 100 index with D1 OHLC history suitable for return-volatility ranking.
- `WS30.DWX` - DWX Dow 30 index with D1 OHLC history suitable for return-volatility ranking.
- `GDAXI.DWX` - DWX DAX index with D1 OHLC history suitable for return-volatility ranking.
- `UK100.DWX` - DWX FTSE 100 index with D1 OHLC history suitable for return-volatility ranking.
- `XAUUSD.DWX` - DWX gold symbol explicitly included by the card.
- `XTIUSD.DWX` - DWX crude oil symbol explicitly included by the card.

**Explicitly NOT for:**
- `XAGUSD.DWX` - not included in the card's named commodity pair.
- `XNGUSD.DWX` - not included in the card's named commodity pair.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default skeleton gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 10 |
| Typical hold time | Not stated in frontmatter; D1 factor holds until forecast crosses zero. |
| Expected drawdown profile | Volatility-expansion factor with ATR emergency stops. |
| Regime preference | Volatility regime / volatility expansion. |
| Win rate target (qualitative) | Not stated in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 2a380bee-1ec4-50d1-a348-b10fac642c7a
**Source type:** blog
**Pointer:** https://qoppac.blogspot.com/2023/10/the-state-of-vol.html
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1229_carver-statevol.md`

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
| v1 | 2026-06-18 | Initial build from card | 0fe12180-f3b0-4f53-8fa8-5f646af594aa |
