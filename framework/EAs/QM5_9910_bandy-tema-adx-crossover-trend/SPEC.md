# QM5_9910_bandy-tema-adx-crossover-trend - Strategy Spec

**EA ID:** QM5_9910
**Slug:** `bandy-tema-adx-crossover-trend`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Author of this spec:** Gemini
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

This EA implements Howard Bandy's Triple Exponential Moving Average (TEMA) crossover trend-following strategy with ADX confirmation gate and ATR Chandelier trailing exit on daily (D1) bars.

- **Entry**: On closed daily bars (D1), the EA computes fast TEMA (8), slow TEMA (21), and ADX (14).
  - Long signal: `tema_fast` crosses above `tema_slow` on the just-finished bar (`tema_fast[1] > tema_slow[1]` and `tema_fast[2] <= tema_slow[2]`) AND `adx[1] >= 20.0`.
  - Short signal: `tema_fast` crosses below `tema_slow` on the just-finished bar (`tema_fast[1] < tema_slow[1]` and `tema_fast[2] >= tema_slow[2]`) AND `adx[1] >= 20.0`.
  - Entries are executed at the open of the next bar. One position per magic number is maintained (long and short are mutually exclusive).
- **Exit**:
  - ATR Chandelier Trailing Stop: Primary trailing stop initialized at `2.0 * ATR(14)` from entry and trailed via `max(prev_stop, close - 2.0 * ATR)`.
  - Signal Exit: Long exits if `tema_fast` crosses below `tema_slow` (`tema_fast[1] < tema_slow[1]`); short exits if `tema_fast` crosses above `tema_slow` (`tema_fast[1] > tema_slow[1]`).
  - Hard time stop: Closes after `strategy_time_stop_bars` (default 60) trading days.
- **Stop Loss**: Initial stop set at `2.0 * ATR(14)` trail distance; catastrophic backstop at `5.0 * ATR(14)`.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tema_fast` | 8 | 3-20 | Fast TEMA lookback period. |
| `strategy_tema_slow` | 21 | 15-50 | Slow TEMA lookback period. |
| `strategy_adx_period` | 14 | 5-30 | ADX calculation period. |
| `strategy_adx_threshold` | 20.0 | 10.0-35.0 | Minimum ADX required for trend entry confirmation. |
| `strategy_atr_period` | 14 | 5-30 | ATR period used for Chandelier trail and stop calculation. |
| `strategy_trail_atr_mult` | 2.0 | 1.0-4.0 | Multiplier of ATR for Chandelier trailing stop. |
| `strategy_catastrophic_atr_mult` | 5.0 | 3.0-8.0 | Multiplier of ATR for catastrophic backstop. |
| `strategy_time_stop_bars` | 60 | 20-120 | Maximum holding time in D1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `NZDUSD.DWX`
- `XAUUSD.DWX`
- `NDX.DWX`, `WS30.DWX`, `SP500.DWX`, `GDAXI.DWX`, `UK100.DWX`

**Explicitly NOT for:**
- Non-DWX broker symbols without local historical data.
- Intraday-only or high-frequency environments.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~20 |
| Typical hold time | Several days to 60 trading days |
| Expected drawdown profile | Drawdowns occur during choppy non-trending periods where ADX whipsaws above/below threshold. |
| Regime preference | Sustained directional trends with ADX >= 20. |
| Win rate target (qualitative) | Medium (~40-50%) with positive skew. |

---

## 6. Source Citation

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** Book
**Pointer:** Howard B. Bandy, *Quantitative Technical Analysis: An Integrated Approach to Trading System Development and Trade Management*, Blue Owl Press, 2015, ISBN 9780979183850.
**R1-R4 verdict (Q00):** PASS per `artifacts/cards_approved/QM5_9910_bandy-tema-adx-crossover-trend.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by portfolio layer |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | Initial build | Complete spec and implementation from approved Bandy card. |
