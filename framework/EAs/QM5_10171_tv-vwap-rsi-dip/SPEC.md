# QM5_10171_tv-vwap-rsi-dip - Strategy Spec

**EA ID:** QM5_10171
**Slug:** `tv-vwap-rsi-dip`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This is a long-only H1 dip strategy for index CFD ports of SPY/QQQ. It enters when EMA(50) is above EMA(200), the last completed candle closes above its same-day session VWAP, that candle is bullish, and RSI(3) has traded below 10 at least once during the last 10 completed candles. Entry occurs only on the first closed bar where the full filter stack is true and there is no open position for this magic. The EA exits when RSI(3) crosses down through 90, or by the protective stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | H1 baseline | Timeframe used for EMA, VWAP, candle, RSI, and ATR logic |
| `strategy_ema_fast` | `50` | 1-500 | Fast EMA period for the bullish trend filter |
| `strategy_ema_slow` | `200` | 2-1000 | Slow EMA period for the bullish trend filter |
| `strategy_rsi_period` | `3` | 1-50 | RSI period for dip and exit checks |
| `strategy_rsi_dip_lookback` | `10` | 1-50 | Completed-bar lookback for at least one RSI dip below threshold |
| `strategy_rsi_dip_level` | `10.0` | 0-100 | RSI dip threshold required before entry |
| `strategy_rsi_exit_level` | `90.0` | 0-100 | RSI cross-down level for strategy exit |
| `strategy_atr_period` | `14` | 1-100 | ATR period for the ATR-side protective stop |
| `strategy_atr_stop_mult` | `2.5` | 0.1-10.0 | ATR multiplier for the protective stop |
| `strategy_percent_stop` | `5.0` | 0.1-20.0 | Percent stop distance; EA uses the tighter of this and ATR stop |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol port for the card's SPY source market.
- `NDX.DWX` - Nasdaq 100 index CFD port for the card's QQQ source market.

**Explicitly NOT for:**
- Symbols outside `SP500.DWX` and `NDX.DWX` - not named in the card's R3 portable basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | hours to days, until RSI(3) crosses down through 90 or stop is hit |
| Expected drawdown profile | fixed-risk drawdowns bounded by $1,000 risk per trade in backtest |
| Regime preference | mean-reversion dip inside bullish EMA/VWAP regime |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** TradingView script `VWAP and RSI strategy`, author `eemani123`, https://www.tradingview.com/script/oDnkONvx-VWAP-and-RSI-strategy/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10171_tv-vwap-rsi-dip.md`

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
| v1 | 2026-06-09 | Initial build from card | 8eea4280-89ad-4833-afe6-037d05748e88 |
