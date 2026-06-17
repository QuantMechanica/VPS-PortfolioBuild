# QM5_11068_ma-limit-pull — Strategy Spec

**EA ID:** QM5_11068
**Slug:** `ma-limit-pull`
**Source:** `429e4612-2e1d-57be-b12e-ff8b94d42117` (see `strategy-seeds/sources/429e4612-2e1d-57be-b12e-ff8b94d42117/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Short-term EMA trend-pullback EA entered with a dynamically-refreshed pending
limit order. On each closed M5 bar it reads the fast EMA(12) and slow EMA(36):
the trend is bullish when fast > slow AND the fast EMA has risen over the last
`slope_lookback` bars, bearish when the mirror holds. A regime gate requires
ADX(14) >= 18 and rejects explosive volatility (ATR(14)/ATR(96) must stay at or
below `max_vol_expansion`). While bullish and flat it places/refreshes a BUY
LIMIT at `Bid - pullback_atr * ATR(14)`; while bearish and flat a SELL LIMIT at
`Ask + pullback_atr * ATR(14)`. The pending order is re-priced once per closed
bar, auto-expires after `pending_expiry_bars`, and is cancelled when the trend
flips or dies. A filled position carries a hard SL = 1.2 * ATR and TP = 1.8 *
ATR measured from the limit price, and is closed early if the EMA trend reverses
against it.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ma_period` | 12 | 5-50 | Fast EMA period (close) |
| `strategy_slow_ma_period` | 36 | 20-200 | Slow EMA period (close) |
| `strategy_slope_lookback` | 3 | 1-20 | Bars over which fast-EMA slope is measured |
| `strategy_atr_period` | 14 | 5-50 | ATR period for offset / stop / target |
| `strategy_atr_long_period` | 96 | 30-300 | Long ATR baseline for vol-expansion gate |
| `strategy_pullback_atr` | 0.35 | 0.05-2.0 | Pullback limit offset = mult * ATR |
| `strategy_sl_atr_mult` | 1.2 | 0.3-5.0 | Stop distance = mult * ATR from limit price |
| `strategy_tp_atr_mult` | 1.8 | 0.5-8.0 | Target distance = mult * ATR from limit price |
| `strategy_pending_expiry_bars` | 12 | 1-100 | Cancel unfilled pending after N bars |
| `strategy_adx_min` | 18.0 | 0-50 | ADX trend-strength floor (0 disables) |
| `strategy_adx_period` | 14 | 5-50 | ADX period |
| `strategy_max_vol_expansion` | 2.0 | 0-10 | Skip if ATR/ATR_long exceeds this (0 disables) |
| `strategy_spread_pct_of_stop` | 15.0 | 1-100 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card primary and only symbol; deepest-liquidity FX major where
  the short-term MA-trend pullback edge from the ATC 2010 source was observed.

**Explicitly NOT for:**
- Index / metal CFDs — the card scopes EURUSD M5 only; the R3 PASS row names no
  portable basket, so P2 registers the single named symbol (1 terminal).

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
| Trades / year / symbol | `~220` |
| Typical hold time | `minutes to a few hours (M5 intraday)` |
| Expected drawdown profile | `moderate; bounded by 1.2*ATR hard stop per trade` |
| Regime preference | `trend (pullback continuation), vol-filtered` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `429e4612-2e1d-57be-b12e-ff8b94d42117`
**Source type:** `forum` (MQL5 Articles interview)
**Pointer:** `https://www.mql5.com/en/articles/532` (Boris Odintsov interview, ATC 2010)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11068_ma-limit-pull.md`

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
