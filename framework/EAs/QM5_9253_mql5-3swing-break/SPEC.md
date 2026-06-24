# QM5_9253_mql5-3swing-break - Strategy Spec

**EA ID:** QM5_9253
**Slug:** `mql5-3swing-break`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see approved card artifact)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA scans closed H1 bars for swing highs and swing lows using a fixed five-bar left/right strength. It builds descending resistance from lower swing highs and ascending support from higher swing lows, then keeps the best three-contact line by touch count, deviation, and recency. A long opens when the latest closed bar breaks above a validated descending resistance line; a short opens when it breaks below a validated ascending support line. Initial stop is the most recent opposite swing plus or minus 0.5 ATR(14), take profit is 2.0R, and strategy exits occur on a quick close back inside the broken line, an opposite breakout, or after 72 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_swing_strength` | 5 | 1+ | Bars required on each side of a swing high or low. |
| `strategy_lookback_bars` | 180 | 20+ | Closed H1 bars scanned for swings and trendline candidates. |
| `strategy_max_swings` | 32 | 3-64 | Maximum swing highs and lows retained for candidate scoring. |
| `strategy_breakout_buffer_pips` | 2 | 1+ | Price buffer beyond the slanted line required for breakout confirmation. |
| `strategy_line_deviation_pips` | 4 | 1+ | Fixed minimum allowed third-touch deviation in pips. |
| `strategy_line_deviation_atr_mult` | 0.15 | 0.01+ | ATR-scaled allowed third-touch deviation. |
| `strategy_min_contacts` | 3 | 3+ | Minimum swing contacts for a validated support or resistance line. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for stop buffer and line-deviation scaling. |
| `strategy_stop_atr_mult` | 0.5 | 0.01+ | ATR multiplier added beyond the most recent swing stop point. |
| `strategy_take_profit_rr` | 2.0 | 0.1+ | Reward-to-risk multiple for the initial take profit. |
| `strategy_time_exit_bars` | 72 | 1+ | Maximum position hold in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with continuous H1 OHLC history for swing-line breakouts.
- `GBPJPY.DWX` - card-listed FX cross with sufficient H1 volatility for structural breakouts.
- `GDAXI.DWX` - DWX matrix DAX custom symbol used for the card's `GER40.DWX` intent.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; the registered DAX equivalent is `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants and unrelated to this card.

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
| Trades / year / symbol | 45 |
| Typical hold time | Up to 72 H1 bars |
| Expected drawdown profile | Breakout losses cluster during failed or choppy trendline breaks. |
| Regime preference | breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Christian Benjamin, "Price Action Analysis Toolkit Development (Part 61): Structural Slanted Trendline Breakouts with 3-Swing Validation", MQL5 Articles, 2026-02-17, https://www.mql5.com/en/articles/21277
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9253_mql5-3swing-break.md`

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
| v1 | 2026-06-25 | Initial build from card | 0dc099ec-63c8-4a3e-9725-0270eeecf9fb |
