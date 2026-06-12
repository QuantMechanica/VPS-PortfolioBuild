# QM5_10268_gawd-sma25-100-cross - Strategy Spec

**EA ID:** QM5_10268
**Slug:** `gawd-sma25-100-cross`
**Source:** `1b906e79-c619-5a61-90db-ee19ac95a19f` (see `strategy-seeds/sources/1b906e79-c619-5a61-90db-ee19ac95a19f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA is long when the fast simple moving average is above the slow simple moving average on the last closed D1 bar. A new long entry is allowed only when SMA25 is above SMA100 and the SMA100 value is not lower than it was 10 bars earlier. The position is closed when SMA25 falls below SMA100, with a catastrophic stop placed 3.5 ATR(14) below entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_sma_period` | 25 | `1+` and less than slow SMA | Fast SMA period used for entry and exit. |
| `strategy_slow_sma_period` | 100 | Greater than fast SMA | Slow SMA period used for entry, exit, and slope filter. |
| `strategy_slow_slope_bars` | 10 | `1+` | Bars used to require nonnegative SMA100 slope before a new long entry. |
| `strategy_atr_period` | 14 | `1+` | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | 3.5 | `> 0` | ATR multiple used to place the initial stop loss. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - liquid Nasdaq 100 index proxy suited to daily trend following.
- `WS30.DWX` - liquid Dow 30 index proxy suited to daily trend following.
- `SP500.DWX` - S&P 500 custom symbol suited to backtest-only daily trend following.
- `XAUUSD.DWX` - liquid gold instrument suited to daily SMA trend following.

**Explicitly NOT for:**
- Unlisted `.DWX` symbols - not specified by the approved card for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `8` |
| Typical hold time | Not specified in card frontmatter |
| Expected drawdown profile | Not specified in card frontmatter |
| Regime preference | Trend-following |
| Win rate target (qualitative) | Not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1b906e79-c619-5a61-90db-ee19ac95a19f`
**Source type:** GitHub repository
**Pointer:** `https://github.com/gawd-coder/Backtest-Indicator-Strategies/blob/master/Simple.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10268_gawd-sma25-100-cross.md`

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
| v1 | 2026-06-12 | Initial build from card | a52b71ce-7b22-40d2-9fff-f22ee578ad9c |
