# QM5_1089_aa-raa-robust-pairs - Strategy Spec

**EA ID:** QM5_1089
**Slug:** `aa-raa-robust-pairs`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA evaluates each registered symbol at the monthly cadence. It computes 12-month total return versus the configured cash return and compares the latest closed monthly close with its 12-month simple moving average. A long position is allowed when either half of the robust allocation is active; the position is closed when both the time-series momentum half and moving-average half are inactive.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_months` | 12 | 12-24 | Monthly lookback for total return and moving average. |
| `strategy_cash_12m_return` | 0.0 | -0.20-0.20 | Cash or T-bill hurdle used for 12-month excess return. |
| `strategy_atr_period` | 20 | 5-100 | ATR period used for the default protective stop. |
| `strategy_atr_sl_mult` | 4.0 | 1.0-10.0 | ATR multiplier for the initial stop loss. |
| `strategy_take_profit_rr` | 0.0 | 0.0-10.0 | Optional reward-to-risk take profit; 0 disables TP. |
| `strategy_max_spread_points` | 5000 | 0-100000 | Maximum spread in points; 0 disables this strategy spread check. |
| `strategy_min_monthly_bars` | 14 | 13-240 | Minimum monthly bars required before signals are valid. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 equity leg from the card's R3 mapping; backtest-only custom symbol.
- `GDAXI.DWX` - DAX equity leg from the card's R3 mapping.
- `XAUUSD.DWX` - Gold crisis or real-asset leg from the card's R3 mapping.
- `XTIUSD.DWX` - Crude oil real-asset leg from the card's R3 mapping.
- `EURUSD.DWX` - FX pair leg from the card's R3 mapping.
- `USDJPY.DWX` - FX pair leg from the card's R3 mapping.
- `NDX.DWX` - Live-tradable US index substitute named in the card's R3 mapping.
- `WS30.DWX` - Live-tradable US index substitute named in the card's R3 mapping.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - they are not valid DWX build targets.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` execution with monthly signal references |
| Multi-timeframe refs | `PERIOD_MN1` for 12-month total return and 12-month SMA; current chart ATR for stop sizing |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` |
| Typical hold time | Multi-month trend holds, checked monthly |
| Expected drawdown profile | Trend-following drawdowns during choppy or sideways regimes |
| Regime preference | Cross-asset trend-following and tactical allocation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** `blog`
**Pointer:** `https://alphaarchitect.com/asset-allocation-horserace-robust-asset-allocation-raa-vs-dual-momentum/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1089_aa-raa-robust-pairs.md`

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
| v1 | 2026-05-25 | Initial build from card | b346c27d-1664-4047-90c6-0fded2a87e66 |
