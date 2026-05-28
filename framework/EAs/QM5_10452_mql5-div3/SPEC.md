# QM5_10452_mql5-div3 — Strategy Spec

**EA ID:** QM5_10452
**Slug:** `mql5-div3`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA scans a fixed recent closed-bar window for two confirmed price swing lows or highs. It buys when price makes a lower low while at least two of RSI, MACD main, and Stochastic K make higher lows, and the last close is above EMA50. It sells when price makes a higher high while at least two of those oscillators make lower highs, and the last close is below EMA50. The stop is placed beyond the confirming divergence swing with a 0.25 ATR(14) buffer, and the baseline target is a fixed points distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bars_to_check` | 80 | 10-300 | Recent closed-bar window scanned for swing pairs. |
| `strategy_min_bars_distance` | 3 | 1-20 | Bars required on each side of a confirmed swing. |
| `strategy_min_confirmations` | 2 | 1-3 | Number of oscillators that must confirm divergence. |
| `strategy_rsi_period` | 14 | 2-100 | RSI period used for divergence confirmation. |
| `strategy_macd_fast` | 12 | 2-100 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 3-200 | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 2-100 | MACD signal period. |
| `strategy_stoch_k` | 5 | 2-100 | Stochastic K period. |
| `strategy_stoch_d` | 3 | 1-50 | Stochastic D period. |
| `strategy_stoch_slowing` | 3 | 1-50 | Stochastic slowing period. |
| `strategy_ema_period` | 50 | 5-300 | EMA trend filter period. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the swing-stop buffer. |
| `strategy_atr_stop_buffer` | 0.25 | 0.0-5.0 | ATR multiple added beyond the divergence swing for the stop. |
| `strategy_take_profit_points` | 1000 | 1-100000 | Fixed target distance in symbol points. |
| `strategy_max_spread_points` | 80 | 0-10000 | Spread guard in symbol points; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-listed major FX pair with standard OHLC and oscillator data.
- `GBPUSD.DWX` — card-listed major FX pair with standard OHLC and oscillator data.
- `USDJPY.DWX` — card-listed major FX pair with standard OHLC and oscillator data.
- `XAUUSD.DWX` — card-listed liquid metal with standard OHLC and oscillator data.
- `GDAXI.DWX` — verified DWX DAX 40 equivalent for the card's `DAX.DWX` robustness target.
- `NDX.DWX` — card-listed liquid index robustness target.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — build-time registration is restricted to verified DWX symbols.

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
| Trades / year / symbol | `35` |
| Typical hold time | hours to days |
| Expected drawdown profile | Mean-reversion drawdowns cluster during persistent one-way trends. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/62742`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10452_mql5-div3.md`

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
| v1 | 2026-05-28 | Initial build from card | 46620c0a-8db7-4398-973d-1a1f183c0cdc |
