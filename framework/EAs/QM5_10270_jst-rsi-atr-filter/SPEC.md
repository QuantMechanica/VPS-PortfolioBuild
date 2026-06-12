# QM5_10270_jst-rsi-atr-filter - Strategy Spec

**EA ID:** QM5_10270
**Slug:** jst-rsi-atr-filter
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (see `strategy-seeds/sources/1b906e79-c619-5a61-90db-ee19ac95a19f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades long-only mean-reversion pullbacks on the chart timeframe. On each newly closed bar it reads RSI(14), SMA(50), ATR(14), and the last close; if RSI is below 30 and the close is above the SMA, it opens a long market position on the new bar. The entry places a fixed stop at 1.5 times ATR below entry and a fixed take-profit at 2.0 times ATR above entry. Open longs are also closed when RSI(14) rises above 50, while the framework handles news blackout and Friday flattening.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | >= 1 | RSI lookback for entry and exit. |
| `strategy_rsi_oversold` | 30.0 | 0-100 | Long entry threshold; enter only when RSI is below this value. |
| `strategy_rsi_exit_level` | 50.0 | 0-100 | Discretionary exit threshold for open long positions. |
| `strategy_sma_period` | 50 | >= 1 | Trend filter; last close must be above this SMA. |
| `strategy_atr_period` | 14 | >= 1 | ATR lookback for stop, take-profit, and spread filter. |
| `strategy_atr_stop_mult` | 1.5 | > 0 | Stop distance in ATR multiples. |
| `strategy_atr_tp_mult` | 2.0 | > 0 | Take-profit distance in ATR multiples. |
| `strategy_min_atr_spread_mult` | 3.0 | > 0 | Blocks new trades when ATR is less than this multiple of spread. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - liquid DWX Nasdaq 100 index exposure named in the approved card.
- `WS30.DWX` - liquid DWX Dow 30 index exposure named in the approved card.
- `SP500.DWX` - approved S&P 500 custom symbol for backtest-only validation named in the card.
- `XAUUSD.DWX` - liquid DWX gold symbol named in the approved card.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts must use canonical `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 |
| Typical hold time | days |
| Expected drawdown profile | Mean-reversion pullbacks can cluster losses during persistent selloffs or high-spread volatility. |
| Regime preference | mean-revert with SMA trend filter |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository
**Pointer:** https://github.com/JSteveT/algorithmic-trading-strategies/blob/main/src/strategies.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10270_jst-rsi-atr-filter.md`

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
| v1 | 2026-06-12 | Initial build from card | f8abc52d-8eb5-4c19-90ca-f43d33d0f884 |
