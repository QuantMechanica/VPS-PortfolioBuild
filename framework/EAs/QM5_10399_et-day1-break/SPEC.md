# QM5_10399_et-day1-break - Strategy Spec

**EA ID:** QM5_10399
**Slug:** `et-day1-break`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA runs on M15 by default. It records the high and low of the first completed trading-day bar, allows one trade for that day, and enters long when a later closed bar closes above that high or short when a later closed bar closes below that low. The take profit is one first-bar range beyond the breakout side, while the stop is placed at the opposite side of the first-bar range plus one current spread. Any still-open position is closed near the end of the broker session.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_bars` | 1 | 1-3 | Number of opening bars used to define the day range. |
| `strategy_atr_period` | 20 | 1+ | ATR period used for the maximum range filter. |
| `strategy_max_range_atr` | 1.5 | >0 | Maximum allowed opening range as a multiple of ATR. |
| `strategy_min_range_spreads` | 4.0 | >0 | Minimum allowed opening range as a multiple of current spread. |
| `strategy_session_close_hour` | 23 | 0-23 | Broker hour for forced session-flat exit. |
| `strategy_session_close_minute` | 45 | 0-59 | Broker minute for forced session-flat exit. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol; fits the card's US large-cap index breakout basket.
- `NDX.DWX` - Nasdaq 100 index exposure; fits the same liquid US index breakout logic.
- `WS30.DWX` - Dow 30 index exposure; fits the same liquid US index breakout logic.
- `GDAXI.DWX` - DAX custom symbol used as the available DWX port for card-stated `GER40.DWX`.
- `EURUSD.DWX` - Liquid FX major; the card states the rules use only OHLC session bars.
- `XAUUSD.DWX` - Liquid metal symbol; the card states the rules use only OHLC session bars.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is registered instead.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not canonical DWX custom symbols for S&P 500 in this framework.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | intraday, flat by broker-session close |
| Expected drawdown profile | bounded one-trade-per-day breakout losses from opposite-range stops |
| Regime preference | volatility-expansion breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/easy-language-software.116592/page-2`, post attributed to PitchBlack / Paul Menzing, 2008-02-04
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10399_et-day1-break.md`

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
| v1 | 2026-05-25 | Initial build from card | 34d13163-d2d5-471d-9e93-2f0012bb8384 |
