# QM5_9256_mql5-3swing-tl - Strategy Spec

**EA ID:** QM5_9256
**Slug:** `mql5-3swing-tl`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see approved card artifact)
**Author of this spec:** Gemini
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

The EA scans closed H1 bars for swing highs and swing lows using a 5-bar left/right strength. It constructs descending resistance lines from lower swing highs and ascending support lines from higher swing lows, validating lines with at least three touches within a 0.15 ATR tolerance. A long trade is triggered when the latest closed bar closes above a validated descending resistance line by at least the breakout buffer; a short trade is triggered when the latest closed bar closes below a validated ascending support line. Initial stop loss is set at the most recent opposite validated swing low/high with a 0.5 * ATR(14) buffer, and initial take profit is set at 2.2R. Exits occur on a close back inside the broken trendline, an opposite breakout, or after a maximum holding period of 72 H1 bars. A cooldown of 6 bars between entries is enforced.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_swing_strength` | 5 | 1+ | Bars required on each side of a swing high or low. |
| `strategy_lookback_bars` | 180 | 20+ | Closed H1 bars scanned for swings and trendline candidates. |
| `strategy_max_swings` | 32 | 3-64 | Maximum swing highs and lows retained for candidate scoring. |
| `strategy_breakout_buffer_pips` | 2 | 1+ | Price buffer beyond the slanted line required for breakout confirmation. |
| `strategy_line_deviation_pips` | 4 | 1+ | Fixed minimum allowed touch deviation in pips. |
| `strategy_line_deviation_atr_mult` | 0.15 | 0.01+ | ATR-scaled allowed touch deviation for line validation. |
| `strategy_min_contacts` | 3 | 3+ | Minimum swing contacts required for a validated line. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for stop buffer and deviation scaling. |
| `strategy_stop_atr_mult` | 0.5 | 0.01+ | ATR multiplier added beyond the most recent swing stop point. |
| `strategy_take_profit_rr` | 2.2 | 0.1+ | Reward-to-risk multiple for the initial take profit (2.2R). |
| `strategy_time_exit_bars` | 72 | 1+ | Maximum position hold in H1 bars. |
| `strategy_min_bars_between_entries` | 6 | 0+ | Cooldown bars required between entry signals. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with continuous H1 OHLC history for structural trendline breakouts.
- `XAUUSD.DWX` - Precious metal with pronounced structural swing formations.
- `GDAXI.DWX` - DWX matrix DAX custom symbol (mapped from card's GER40.DWX intent).

**Explicitly NOT for:**
- `GER40.DWX` - Unregistered symbol alias; GDAXI.DWX is canonical.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Up to 72 H1 bars |
| Expected drawdown profile | Losses cluster during choppy false breakouts. |
| Regime preference | Breakout / volatility expansion |
| Win rate target | Medium (35-45% at 2.2R) |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Christian Benjamin, "Price Action Analysis Toolkit Development (Part 61): Structural Slanted Trendline Breakouts with 3-Swing Validation", MQL5 Articles, 2026-02-17, https://www.mql5.com/en/articles/21277
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9256_mql5-3swing-tl.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-24 | Initial build from approved card | Gemini draft for task b454e005 |
