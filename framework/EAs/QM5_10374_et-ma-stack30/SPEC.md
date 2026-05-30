# QM5_10374_et-ma-stack30 - Strategy Spec

**EA ID:** QM5_10374
**Slug:** et-ma-stack30
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA evaluates completed H1 bars. A long setup starts when SMA(60) is above SMA(90) and SMA(90) is above SMA(150); a short setup starts when the same averages are stacked downward. On the first stacked bar it stores the prior 30-bar high and low, then enters long after a completed bar breaks above the stored high or short after a completed bar breaks below the stored low. Long positions exit when the completed close falls below SMA(90) or below the stored low; short positions exit when the completed close rises above SMA(90) or above the stored high.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_sma_period` | 60 | 1-500 | Fast SMA in the stack condition. |
| `strategy_mid_sma_period` | 90 | 2-500 | Middle SMA used for stack order and strategy exit. |
| `strategy_slow_sma_period` | 150 | 3-500 | Slow SMA in the stack condition and warmup floor. |
| `strategy_breakout_lookback` | 30 | 1-250 | Bars used for the stored breakout high and low. |
| `strategy_atr_period` | 20 | 1-250 | ATR period used for maximum stop-distance filtering. |
| `strategy_max_stop_atr` | 2.5 | 0.1-10.0 | Skip setup when stop distance is above this multiple of ATR. |
| `strategy_min_stop_spreads` | 4.0 | 1.0-20.0 | Skip setup when stop distance is below this multiple of current spread. |
| `strategy_timeframe` | PERIOD_H1 | M30-H4 | Timeframe used for SMA stack, breakout, ATR, and exits. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card target FX major; present in the DWX matrix.
- `GBPUSD.DWX` - Card target FX major; present in the DWX matrix.
- `XAUUSD.DWX` - Card target metal; present in the DWX matrix.
- `GDAXI.DWX` - DWX matrix equivalent for the card's GER40/DAX exposure.
- `SP500.DWX` - Card target S&P 500 exposure; valid backtest-only custom symbol.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available to the broker/test matrix.
- `GER40.DWX` - card-stated alias is not in the matrix; `GDAXI.DWX` is registered instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Typical hold time | hours to days |
| Expected drawdown profile | Whipsaw drawdowns when stacked averages flatten after mature trends. |
| Regime preference | trend-following breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/easylanguage-code-problem.312743/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10374_et-ma-stack30.md`

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
| v1 | 2026-05-25 | Initial build from card | ffe6e92e-43f2-407c-b305-de001392f417 |
