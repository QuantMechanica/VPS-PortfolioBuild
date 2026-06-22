# QM5_9235_mql5-am-price-cross - Strategy Spec

**EA ID:** QM5_9235
**Slug:** `mql5-am-price-cross`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades a closed-bar price cross against an arithmetic mean of closing prices. A long entry occurs when the prior closed bar was at or below AM(20) and the latest closed bar closes above AM(20); a short entry is the inverse. The signal is allowed only when the absolute AM(20) slope over three bars is greater than 0.05 times ATR(14). Exits occur when price closes back through AM(20) in the opposite direction, when the 2.0R take profit or 1.8 ATR stop is reached, or after 36 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_am_period` | 20 | 2-200 | Arithmetic mean period on closed H1 closes. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for the stop and slope threshold. |
| `strategy_atr_sl_mult` | 1.8 | 0.1-10.0 | ATR multiple for the initial stop distance. |
| `strategy_rr_take_profit` | 2.0 | 0.1-10.0 | Reward-to-risk multiple for the initial take profit. |
| `strategy_slope_lookback` | 3 | 1-20 | Number of closed bars used to measure AM slope. |
| `strategy_slope_atr_fraction` | 0.05 | 0.0-1.0 | Minimum AM slope as a fraction of ATR(14). |
| `strategy_max_hold_bars` | 36 | 1-240 | Failsafe maximum holding time in base timeframe bars. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid FX major with full DWX OHLC and ATR data.
- `GBPJPY.DWX` - Card-listed liquid FX cross with full DWX OHLC and ATR data.
- `XAUUSD.DWX` - Card-listed metals instrument with full DWX OHLC and ATR data.

**Explicitly NOT for:**
- Non-DWX symbols - Build and backtest artifacts must use the canonical `.DWX` symbols.
- Symbols outside the card target list - This build registers only the card's R3 PASS universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 95 |
| Typical hold time | H1 trades, capped at 36 bars by the failsafe time exit |
| Expected drawdown profile | Fixed-risk trend-following cross system with ATR-defined per-trade risk |
| Regime preference | Trend-following, supported by the AM slope filter |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 24): Moving Averages", 2024-06-26, https://www.mql5.com/en/articles/15135
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9235_mql5-am-price-cross.md`

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
| v1 | 2026-06-23 | Initial build from card | b2df21de-7d0a-4a8c-9c33-8d6953c0a6b5 |
