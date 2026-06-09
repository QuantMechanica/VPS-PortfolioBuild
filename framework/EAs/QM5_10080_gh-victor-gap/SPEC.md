# QM5_10080_gh-victor-gap - Strategy Spec

**EA ID:** QM5_10080
**Slug:** gh-victor-gap
**Source:** 3b3ec48a-0755-5187-9331-afb36e174175 (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

On each new H1 bar, the EA compares the latest closed bar open with the prior closed bar close. It buys after a gap down of at least 1.0 percent when that gap bar closes bullish and above SMA(250), and it sells after a gap up of at least 1.0 percent when that gap bar closes bearish and below SMA(250). The initial stop and take profit are both placed 1.0 ATR(250) from entry, and the stop is trailed once per tick from the latest closed-bar close by the same ATR distance. There is no discretionary close beyond attached SL/TP, ATR trailing, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_gap_threshold_pct` | 1.0 | >0 | Minimum open-vs-prior-close gap percent required for entry. |
| `strategy_sma_period` | 250 | >1 | Close-price SMA period used as the trend-side filter. |
| `strategy_atr_period` | 250 | >1 | ATR period used for initial SL, TP, and trailing stop distance. |
| `strategy_atr_sl_mult` | 1.0 | >0 | ATR multiplier for initial stop and trailing stop. |
| `strategy_atr_tp_mult` | 1.0 | >0 | ATR multiplier for initial take profit. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol; the card names it directly as a gap-prone index baseline.
- `NDX.DWX` - Nasdaq 100 index; the card names it directly as a gap-prone index baseline.
- `WS30.DWX` - Dow 30 index; the card names it directly as a gap-prone index baseline.
- `XAUUSD.DWX` - Gold metal CFD; the card names it directly as a gap-prone metals baseline.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - build rules forbid unregistered DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | hours to days, controlled by 1.0 ATR TP and trailing SL |
| Expected drawdown profile | Mean-reversion gaps can cluster losses in sustained directional gap regimes. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3b3ec48a-0755-5187-9331-afb36e174175
**Source type:** GitHub source code
**Pointer:** https://github.com/victor-algo/channel/blob/main/LIVE%20BOT%20-%20Cr%C3%A9ation%20de%20trading%20bot%20from%20scratch/Gap%20Reversal/Expert/GapReversal.mq5
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10080_gh-victor-gap.md`

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
| v1 | 2026-06-09 | Initial build from card | c9e8cd34-2d5c-440d-9f8f-17c967ae07a3 |
