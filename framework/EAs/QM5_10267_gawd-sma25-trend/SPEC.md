# QM5_10267_gawd-sma25-trend - Strategy Spec

**EA ID:** QM5_10267
**Slug:** gawd-sma25-trend
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (see `sources/github-gawd-backtest-indicator-strategies`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades a long-only daily trend filter. It opens a long position when the last closed D1 close is above the 25-period simple moving average of D1 close. It closes the long position when the last closed D1 close falls below the same SMA. New entries are skipped when ATR(14) is less than three times the current spread, and every entry uses a catastrophic stop at 3.0 times ATR(14) from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_D1` | MT5 timeframe enum | Base timeframe for the close, SMA, and ATR reads. |
| `strategy_sma_period` | `25` | `2+` | Simple moving average period for long entry and exit. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the catastrophic stop and spread filter. |
| `strategy_atr_sl_mult` | `3.0` | `> 0` | ATR multiple used to place the initial stop loss. |
| `strategy_min_atr_spread_mult` | `3.0` | `>= 0` | Minimum ATR relative to spread required before opening a new trade. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - DWX Nasdaq 100 index proxy for daily trend-following exposure.
- `WS30.DWX` - DWX Dow 30 index proxy for daily trend-following exposure.
- `SP500.DWX` - DWX S&P 500 custom symbol; valid for backtest per the card's SP500 caveat.
- `XAUUSD.DWX` - DWX gold symbol for daily trend-following exposure.

**Explicitly NOT for:**
- Non-DWX symbols - registry and pipeline runs require canonical `.DWX` names.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (skeleton default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `14` |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | ATR-capped daily trend-following losses |
| Regime preference | trend-following |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1b906e79-c619-5a61-90db-ee19ac95a19f`
**Source type:** GitHub repository
**Pointer:** `https://github.com/gawd-coder/Backtest-Indicator-Strategies/blob/master/Simple.py`, class `Conventional_MA`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10267_gawd-sma25-trend.md`

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
| v1 | 2026-06-12 | Initial build from card | cce7dfe5-c978-4a3b-b1b5-fa9987abd7e3 |
