# QM5_10859_tv-ema-rslaik - Strategy Spec

**EA ID:** QM5_10859
**Slug:** `tv-ema-rslaik`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA opens long positions when the current chart timeframe closes with EMA(21) above EMA(89), the closed-bar price above EMA(21), RSI(14) between 55 and 75, and ATR(14) above its 20-bar average. Entries are sent on the next candle after the qualifying closed bar. Each trade receives an ATR-based stop at 2.5 ATR and a target at 4.0 ATR, and the EA defensively closes an open position if EMA(21) crosses below EMA(89).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 21 | 1+ | Fast EMA trend period. |
| `strategy_ema_slow_period` | 89 | 1+ | Slow EMA trend period. |
| `strategy_rsi_period` | 14 | 1+ | RSI lookback period. |
| `strategy_rsi_min` | 55.0 | 0-100 | Lower inclusive RSI momentum bound. |
| `strategy_rsi_max` | 75.0 | 0-100 | Upper inclusive RSI momentum bound. |
| `strategy_atr_period` | 14 | 1+ | ATR lookback for volatility, stop, and target. |
| `strategy_atr_sma_period` | 20 | 1+ | ATR average lookback for volatility expansion filter. |
| `strategy_atr_stop_mult` | 2.5 | 0+ | Stop distance in ATR multiples. |
| `strategy_atr_target_mult` | 4.0 | 0+ | Target distance in ATR multiples. |
| `strategy_max_spread_frac` | 0.10 | 0+ | Maximum spread as a fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair with daily and H4 DWX history for EMA, RSI, and ATR signals.
- `GBPUSD.DWX` - major FX pair included in the card's portable basket.
- `XAUUSD.DWX` - metal CFD included in the card's portable basket.
- `NDX.DWX` - liquid index CFD included in the card's portable basket.
- `GDAXI.DWX` - DAX custom symbol used as the matrix-valid port for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - the broker/custom-symbol matrix cannot support backtests for unregistered symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none; H4 is a declared setfile variant using the current chart timeframe |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `5` |
| Typical hold time | days |
| Expected drawdown profile | Low-cadence trend-following with risk concentrated in range-bound periods. |
| Regime preference | trend / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/Igq6XlXA/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10859_tv-ema-rslaik.md`

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
| v1 | 2026-06-06 | Initial build from card | db6dca9c-a973-40f4-a075-7ada468cc988 |
