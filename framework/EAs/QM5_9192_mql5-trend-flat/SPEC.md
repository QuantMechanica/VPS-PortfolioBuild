# QM5_9192_mql5-trend-flat — Strategy Spec

**EA ID:** QM5_9192
**Slug:** `mql5-trend-flat`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each closed H1 bar the EA checks three layered conditions. First, a fast SMA(11) must cross above (for long) or below (for short) a slow SMA(25). Second, RSI(14) must be above 50 for longs or below 50 for shorts, confirming momentum direction. Third, both CCI(36) and CCI(55) must be positive (long) or negative (short), providing dual-period momentum confirmation. When all three conditions align, the EA enters at market. Stop loss is placed at the most recent confirmed pivot low (long) or pivot high (short), found by scanning back up to 50 bars. Take-profit is a fixed 500 points from entry. An open trade is also closed early if the full opposite signal fires.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ma_period` | 11 | 5–50 | Fast SMA period for cross signal |
| `strategy_slow_ma_period` | 25 | 10–100 | Slow SMA period for cross signal |
| `strategy_rsi_period` | 14 | 7–28 | RSI smoothing period |
| `strategy_rsi_buy_thresh` | 50.0 | 40–70 | RSI must be above this for long entry |
| `strategy_rsi_sell_thresh` | 50.0 | 30–60 | RSI must be below this for short entry |
| `strategy_cci_fast_period` | 36 | 14–72 | CCI fast period (source default) |
| `strategy_cci_slow_period` | 55 | 28–110 | CCI slow period (source default) |
| `strategy_tp_points` | 500 | 100–5000 | Fixed take-profit in SYMBOL_POINT units |
| `strategy_pivot_left` | 5 | 2–20 | Bars to the left of a pivot candidate |
| `strategy_pivot_right` | 5 | 2–20 | Bars to the right of a pivot candidate |
| `strategy_pivot_lookback` | 50 | 20–200 | Max bars to scan for pivot stop |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; H1 trends well; commission affordable vs pip TP
- `GBPUSD.DWX` — correlated major with good H1 volatility; same DWX data quality
- `GDAXI.DWX` — DAX 40 index; trending instrument with strong intraday momentum; card listed GER40 (same index, ported to canonical DWX name GDAXI)

**Explicitly NOT for:**
- `GER40.DWX` — not a valid DWX symbol; ported to GDAXI.DWX (documented in open_questions)

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
| Trades / year / symbol | ~24 (several per month, per card) |
| Typical hold time | Hours to days (SMA(11/25) cross or TP/SL) |
| Expected drawdown profile | Moderate; pivot stops vary by market structure |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Allan Munene Mutiiria, "Automating Trading Strategies in MQL5 (Part 10): Developing the Trend Flat Momentum Strategy", MQL5 Articles, 2025-02-27
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9192_mql5-trend-flat.md`

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
| v1 | 2026-06-10 | Initial build from card | 51b9eba0-63ba-4f7a-bf4b-44bc89edc481 |
