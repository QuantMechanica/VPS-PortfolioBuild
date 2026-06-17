# QM5_11037_atc-ma-limit — Strategy Spec

**EA ID:** QM5_11037
**Slug:** `atc-ma-limit`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (Boris Odintsov, MQL5 Articles 532)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Short-term moving-average trend-following with dynamically-refreshed pullback
limit-order entries. On each closed M5 bar the EA computes a fast SMA and a slow
SMA on close and the fast-MA slope over a lookback window. The trend is bullish
when fast > slow AND the fast-MA slope is positive, bearish when fast < slow AND
the slope is negative. While bullish and flat the EA places (and once per bar
refreshes) a BUY LIMIT at `Bid - limit_offset_atr * ATR` below market; while
bearish and flat it places a SELL LIMIT at `Ask + limit_offset_atr * ATR` above
market. The resting limit is re-priced each closed bar (old pending removed,
new one placed), auto-expires after `pending_expiry_bars`, and is cancelled when
the trend flips or disappears. A filled position carries a fixed stop at
`sl_atr_mult * ATR` from the limit price and a take-profit at `tp_rr ×` the stop
distance. The position is closed early if the MA trend turns to the opposite
direction. An optional ADX floor (default disabled) suppresses entries in flat
regimes.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ma_period` | 13 | 8-21 | Fast SMA period (close) |
| `strategy_slow_ma_period` | 55 | 34-89 | Slow SMA period (close) |
| `strategy_slope_lookback` | 5 | 3-8 | Bars back used to measure fast-MA slope |
| `strategy_atr_period` | 14 | 7-21 | ATR period (limit offset and stop) |
| `strategy_limit_offset_atr` | 0.25 | 0.15-0.40 | Pullback limit offset = mult × ATR |
| `strategy_sl_atr_mult` | 1.5 | 1.0-2.0 | Stop distance = mult × ATR from limit price |
| `strategy_tp_rr` | 2.0 | 1.5-2.5 | Take-profit = rr × stop distance |
| `strategy_pending_expiry_bars` | 6 | 3-20 | Cancel an unfilled pending after N bars |
| `strategy_adx_min` | 0.0 | 0 / 18-22 | Optional ADX floor (0 disables the filter) |
| `strategy_adx_period` | 14 | 7-21 | ADX period when the filter is enabled |
| `strategy_spread_pct_of_stop` | 15.0 | 5-30 | Skip if spread > this % of stop distance (fail-open) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid FX major; clean M5 MA trends and tight pullbacks.
- `GBPUSD.DWX` — liquid FX major with comparable intraday trend behaviour.
- `USDJPY.DWX` — liquid FX major; pip-scale handled via framework pip-factor.
- `XAUUSD.DWX` — gold metal; strong short-term trends suit MA + ATR-offset limits.

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500.DWX) — the M5 FX/metal calibration of MA periods and
  ATR offsets was not designed for index volatility scale.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~100 (card range 80-180)` |
| Typical hold time | `minutes to a few hours (M5 intraday)` |
| Expected drawdown profile | `bounded — fixed ATR stop, pending expiry, one position per magic` |
| Regime preference | `trend / trend-continuation pullback` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** `forum` (MQL5 Articles interview)
**Pointer:** `https://www.mql5.com/en/articles/532`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11037_atc-ma-limit.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
