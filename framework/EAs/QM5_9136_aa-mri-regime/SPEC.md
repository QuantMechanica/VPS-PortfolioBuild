# QM5_9136_aa-mri-regime - Strategy Spec

**EA ID:** QM5_9136
**Slug:** aa-mri-regime
**Source:** ede348b4-0fa7-5be1-baa8-09e9089b67b7 (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA evaluates one completed D1 bar at a time. It computes a 200-day SMA regime and an MRI value defined as the 252-day return minus the trailing mean of 252-day returns, divided by annualized 252-day daily-return volatility. In an up-market regime, it buys when MRI is below -0.50 and sells when MRI is above +0.50; in a down-market regime, the direction is inverted. It exits when MRI crosses zero, the close crosses the SMA200 regime boundary, or 21 completed D1 bars have elapsed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 200 | 50-300 | D1 SMA lookback for the regime switch. |
| `strategy_return_period` | 252 | 126-300 | D1 bars used for the MRI return and volatility window. |
| `strategy_trading_days_year` | 252 | 200-300 | Annualization convention for D1 volatility. |
| `strategy_mean_years` | 10 | 5-15 | Preferred trailing years for mean 252-day return estimation. |
| `strategy_fallback_years` | 5 | 3-10 | Fallback trailing years when 10 years are unavailable. |
| `strategy_min_history_bars` | 1260 | 1260-2520 | Minimum completed D1 bars required before entries. |
| `strategy_mri_threshold` | 0.50 | 0.10-2.00 | Absolute MRI entry threshold. |
| `strategy_atr_period` | 20 | 5-60 | D1 ATR period for the initial stop. |
| `strategy_atr_sl_mult` | 2.50 | 0.50-6.00 | ATR multiple for the initial stop. |
| `strategy_max_hold_d1_bars` | 21 | 1-63 | Completed D1 bars before time-stop exit. |
| `strategy_spread_lookback` | 20 | 5-60 | D1 bars used for the median spread filter. |
| `strategy_spread_median_mult` | 2.50 | 1.00-10.00 | Blocks entries only when live spread is wider than this multiple of median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol explicitly called out by the card.
- `NDX.DWX` - Nasdaq 100 index member of the card's portable market basket.
- `WS30.DWX` - Dow 30 index member of the card's portable market basket.
- `GDAXI.DWX` - DAX index member of the card's portable market basket.
- `XAUUSD.DWX` - Gold CFD included by the card's commodity/gold extension.
- `XTIUSD.DWX` - Matrix-verified WTI crude CFD port for the card's `USOIL.DWX` target.
- `EURUSD.DWX` - Major FX pair included by the card's FX extension.
- `GBPUSD.DWX` - Major FX pair included by the card's FX extension.
- `USDJPY.DWX` - Major FX pair included by the card's FX extension.

**Explicitly NOT for:**
- `USOIL.DWX` - not present in `dwx_symbol_matrix.csv`; use `XTIUSD.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not canonical DWX symbols for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entry; daily cache keyed by `QM_CalendarPeriodKey(PERIOD_D1)` for exit state |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Up to 21 completed D1 bars |
| Expected drawdown profile | Mean-reversion entries with ATR-bounded initial risk and multi-week time stops |
| Regime preference | State-dependent mean reversion under a 200-day momentum regime |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Source type:** blog
**Pointer:** https://alphaarchitect.com/timing-the-market-with-mean-reversion-indicators/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9136_aa-mri-regime.md`

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
| v1 | 2026-07-07 | Initial build from card | 4c2482f8-affc-4478-8a33-efe741c3bd13 |
