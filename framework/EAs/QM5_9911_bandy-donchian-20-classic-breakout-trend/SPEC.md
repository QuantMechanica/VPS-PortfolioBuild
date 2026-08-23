# QM5_9911_bandy-donchian-20-classic-breakout-trend - Strategy Spec

**EA ID:** QM5_9911
**Slug:** `bandy-donchian-20-classic-breakout-trend`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Author of this spec:** Gemini
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

This EA implements the classic Donchian-20 high/low breakout trend-following strategy with Howard Bandy's 200-period SMA regime filter and ATR catastrophic risk overlay on daily (D1) bars.

- **Entry**: On closed daily bars (D1), the EA computes `donchian_high = HHV(high, 20)` and `donchian_low = LLV(low, 20)` over the 20 completed bars prior to the signal bar (shifts 2..21) to prevent look-ahead bias, as well as the regime filter `regime = SMA(close, 200)` on the signal bar (shift 1).
  - Long signal: `close[1] > donchian_high` AND `close[1] > regime`
  - Short signal: `close[1] < donchian_low` AND `close[1] < regime`
  - Entries are executed at the open of the next bar. One position per magic number is maintained (long and short are mutually exclusive).
- **Exit**:
  - Long exit: `close[1] < LLV(low, 10)` over the 10 completed bars prior to the signal bar (shifts 2..11) - Turtle-style 10-bar trailing low exit.
  - Short exit: `close[1] > HHV(high, 10)` over the 10 completed bars prior to the signal bar (shifts 2..11) - Turtle-style 10-bar trailing high exit.
  - Hard time stop: Closes after `strategy_time_stop_bars` (default 60) trading days.
- **Stop Loss**: A catastrophic backstop stop loss is placed at entry at `2.5 * ATR(14)` distance from fill.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_lookback` | 20 | 10-60 | Donchian channel entry lookback in completed D1 bars. |
| `strategy_exit_lookback` | 10 | 5-20 | Turtle-style Donchian channel exit lookback in completed D1 bars. |
| `strategy_regime_sma_period` | 200 | 50-300 | SMA period used for trend regime confirmation. |
| `strategy_atr_period` | 14 | 5-30 | ATR period used for the catastrophic stop loss distance. |
| `strategy_atr_stop_mult` | 2.5 | 1.0-5.0 | Multiplier of ATR for catastrophic stop loss. |
| `strategy_time_stop_bars` | 60 | 20-120 | Maximum holding time in D1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `NZDUSD.DWX`
- `XAUUSD.DWX`
- `NDX.DWX`, `WS30.DWX`, `SP500.DWX`, `GDAXI.DWX`, `UK100.DWX`

**Explicitly NOT for:**
- Non-DWX broker symbols without local historical data.
- Intraday-only or high-frequency environments (strategy operates strictly on closed D1 bars).

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
| Trades / year / symbol | ~14 |
| Typical hold time | 10 to 60 trading days |
| Expected drawdown profile | Drawdowns occur during choppy sideways / range-bound market regimes. |
| Regime preference | Persistent multi-week trending regimes. |
| Win rate target (qualitative) | Low to medium (~35-45%) with high payoff ratio (> 2.0). |

---

## 6. Source Citation

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** Book
**Pointer:** Howard B. Bandy, *Quantitative Technical Analysis: An Integrated Approach to Trading System Development and Trade Management*, Blue Owl Press, 2015, ISBN 9780979183850.
**R1-R4 verdict (Q00):** PASS per `artifacts/cards_approved/QM5_9911_bandy-donchian-20-classic-breakout-trend.md`

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
