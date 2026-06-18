# QM5_1098_unger-sp500-pivot-trend - Strategy Spec

**EA ID:** QM5_1098
**Slug:** unger-sp500-pivot-trend
**Source:** eb97a148-0af9-5b9c-878c-25fb5dfa34f9 (see `sources/unger-robbins-cup`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA calculates the previous New York cash-session floor pivots from the M30 bars: `P = (high + low + close) / 3`, `R1 = 2 * P - low`, and `S1 = 2 * P - high`. At 10:30 New York time it buys if the latest closed M30 bar closes above R1 and sells if it closes below S1. It takes no trade when the close is between S1 and R1, and it only evaluates one entry decision per symbol per day. Open trades exit at the U.S. cash-session close or when the opposite pivot condition appears after entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_hhmm_ny` | 1030 | 0000-2359 | New York time for the single daily entry check. |
| `strategy_cash_open_hhmm_ny` | 930 | 0000-2359 | Start of the New York cash-session window used for pivots and trading. |
| `strategy_cash_close_hhmm_ny` | 1600 | 0000-2359 | End of the New York cash-session window and time-exit point. |
| `strategy_atr_period` | 14 | 1-200 | ATR period on M30 for the initial stop. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiple for the initial stop distance. |
| `strategy_use_rr_tp` | false | true/false | Enables the optional P3 2R target; disabled for P2 baseline. |
| `strategy_rr_tp` | 2.0 | 0.1-10.0 | Reward-risk multiple used only when `strategy_use_rr_tp` is true. |
| `strategy_median_spread_points` | 0.0 | 0.0+ | Median spread input for the card's 2x spread guard; 0 disables the guard in `.DWX` backtests. |
| `strategy_pivot_scan_bars` | 160 | 20-500 | Bounded M30 history scan used to find the prior cash session. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - primary S&P 500 replication symbol from the card; valid for backtest-only validation.
- `NDX.DWX` - live-routable U.S. large-cap technology index port listed in the card R3 basket.
- `WS30.DWX` - live-routable U.S. large-cap industrial index port listed in the card R3 basket.

**Explicitly NOT for:**
- `SPX500.DWX` - not present in the DWX symbol matrix; SP500.DWX is the canonical S&P 500 custom symbol.
- `SPY.DWX` - not present in the DWX symbol matrix.
- `ES.DWX` - not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | Intraday; entry near 10:30 New York and exit by cash close |
| Expected drawdown profile | Breakout/trend-following losses controlled by ATR stop |
| Regime preference | Trend / pivot breakout |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** eb97a148-0af9-5b9c-878c-25fb5dfa34f9
**Source type:** article / book lineage
**Pointer:** Unger Academy S&P 500 trend-following portfolio lesson and `sources/unger-robbins-cup`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1098_unger-sp500-pivot-trend.md`

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
| v1 | 2026-06-18 | Initial build from card | d086e338-2643-4bcb-a273-71de15df3dde |
