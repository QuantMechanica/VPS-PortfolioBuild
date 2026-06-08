# QM5_11286_at-macd-ema — Strategy Spec

**EA ID:** QM5_11286
**Slug:** `at-macd-ema`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA trades H1 completed-bar MACD pullback signals in the direction of a 200-period EMA trend filter. It opens long when the last closed bar is above EMA(200), MACD(12,26,9) crosses above its signal line, and the MACD line is still below zero. It opens short when the last closed bar is below EMA(200), MACD crosses below its signal line, and the MACD line is still above zero. The stop is the most recent confirmed 5-left/5-right swing point, falling back to 2.0 x ATR(14), and the target is 1.5R; an open position also closes when the opposite full entry condition appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | H1 intended | Completed-bar timeframe used for all strategy signals. |
| `strategy_ema_period` | `200` | 1-500 | EMA trend filter period. |
| `strategy_macd_fast` | `12` | 1-100 | Fast EMA period for MACD. |
| `strategy_macd_slow` | `26` | fast+1-200 | Slow EMA period for MACD. |
| `strategy_macd_signal` | `9` | 1-100 | MACD signal-line period. |
| `strategy_swing_left_right` | `5` | 1-20 | Number of bars on each side required to confirm a swing point. |
| `strategy_swing_scan_bars` | `80` | 12-300 | Maximum closed bars scanned to find the most recent confirmed swing point. |
| `strategy_atr_period` | `14` | 1-100 | ATR period for fallback stop placement. |
| `strategy_atr_fallback_mult` | `2.0` | 0.1-10.0 | ATR multiple used when no valid swing stop is available. |
| `strategy_reward_risk` | `1.5` | 0.1-10.0 | Take-profit distance as a multiple of initial risk. |
| `strategy_min_stop_points` | `10` | 1-10000 | Minimum stop distance in points required before an entry is sent. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — the source configuration uses EURUSD and H1 OHLC-derived indicators.
- `GBPUSD.DWX` — liquid FX major with the same H1 trend/MACD data requirements.
- `XAUUSD.DWX` — liquid metal symbol with H1 OHLC, EMA, MACD, ATR, and swing structure support.
- `GDAXI.DWX` — canonical DWX DAX symbol, used as the available port for the card's `GER40.DWX` target.
- `NDX.DWX` — liquid index symbol named directly in the card's initial test universe.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered German index equivalent.
- Symbols outside `dwx_symbol_matrix.csv` — the build registry only permits canonical DWX symbols with available data.

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
| Trades / year / symbol | `70` |
| Typical hold time | Hours to days, until 1.5R target, stop, Friday close, or opposite signal. |
| Expected drawdown profile | Trend-following losses cluster in sideways or choppy regimes. |
| Regime preference | Trend-following pullbacks with MACD momentum recovery. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** GitHub repository documentation
**Pointer:** `https://github.com/kieran-mackle/AutoTrader/blob/main/docs/source/tutorials/walkthrough.md`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11286_at-macd-ema.md`

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
| v1 | 2026-06-08 | Initial build from card | 147be7ac-43d2-44a3-8371-b407e278c2e6 |
