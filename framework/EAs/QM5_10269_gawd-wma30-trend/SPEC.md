# QM5_10269_gawd-wma30-trend - Strategy Spec

**EA ID:** QM5_10269
**Slug:** gawd-wma30-trend
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f (see `strategy-seeds/sources/1b906e79-c619-5a61-90db-ee19ac95a19f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades a long-only D1 WMA trend rule. On each new closed bar, it compares the last closed close to WMA(30) of close and opens a long position when the close is above WMA(30). The position is closed when the last closed close falls below WMA(30). A catastrophic stop is placed at 3.0 * ATR(14) from the entry, and new entries, but not exits, are blocked unless ATR(14) is greater than three times the current spread.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_D1` | MT5 timeframe enum | Timeframe used for WMA and ATR reads. |
| `strategy_wma_period` | `30` | `> 1` | Weighted moving average period for entry and exit comparison. |
| `strategy_atr_period` | `14` | `> 0` | ATR period for catastrophic stop and volatility filter. |
| `strategy_atr_sl_mult` | `3.0` | `> 0.0` | ATR multiple used for initial stop distance. |
| `strategy_min_atr_spread_mult` | `3.0` | `>= 0.0` | Minimum ATR-to-spread multiple required before a new entry. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Card-listed DWX large-cap index target.
- `WS30.DWX` - Card-listed DWX large-cap index target.
- `SP500.DWX` - Card-listed S&P 500 custom symbol, valid for backtest with live-route caveat handled downstream.
- `XAUUSD.DWX` - Card-listed DWX metals target for the generic trend rule.

**Explicitly NOT for:**
- None specified by the approved card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `16` |
| Typical hold time | Not specified in card frontmatter |
| Expected drawdown profile | Not specified in card frontmatter |
| Regime preference | Trend-following |
| Win rate target (qualitative) | Not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository
**Pointer:** https://github.com/gawd-coder/Backtest-Indicator-Strategies/blob/master/Simple.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10269_gawd-wma30-trend.md`

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
| v1 | 2026-06-12 | Initial build from card | 03aacf37-aba8-47d7-9c8b-8b3bf9e3326e |
