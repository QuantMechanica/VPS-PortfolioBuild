# QM5_1086_aa-dpm-tmom-ma - Strategy Spec

**EA ID:** QM5_1086
**Slug:** `aa-dpm-tmom-ma`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `sources/alpha-architect-blog`)
**Author of this spec:** Claude (Development)
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA runs natively on the MN1 chart so the framework new-bar gate fires once per monthly close — that gate is the monthly rebalance. On each rebalance it computes the 12-month total return minus a configurable cash proxy (TMOM) and compares the last monthly close with its 12-month simple moving average (MA). If both signals are positive it holds long at 100% of the strategy risk budget; if exactly one is positive it holds long at 50% of the risk budget; if neither is positive it goes to cash. The 50%/100% ladder is realised by scaling the framework risk weight (so a 50% state risks half of RISK_FIXED). The position is HELD across months while exposure is unchanged; the rebalance hook closes on a cash signal and closes-then-reopens on the same bar when the target exposure changes. A per-position D1-ATR stop is the catastrophic backstop (the source uses signal-based cash switching as the primary exit).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_months` | 12 | 1-60 | Monthly lookback used for total return and SMA length. |
| `strategy_cash_return_12m_pct` | 0.0 | -10.0-20.0 | 12-month cash return proxy subtracted from total return, in percent. |
| `strategy_atr_period` | 14 | 2-100 | D1 ATR period used for the per-position catastrophic stop. |
| `strategy_atr_sl_mult` | 3.0 | 0.5-20.0 | ATR multiple for the initial stop loss. |
| `strategy_max_spread_points` | 5000 | 0-100000 | Maximum allowed spread in points at monthly entry; 0 disables this guard. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol named in R3; backtest-only caveat applies at T6.
- `NDX.DWX` - Nasdaq 100 index CFD proxy for US large-cap risk exposure.
- `WS30.DWX` - Dow 30 index CFD proxy for US large-cap risk exposure.
- `GDAXI.DWX` - DAX index CFD proxy for international index trend exposure.
- `XAUUSD.DWX` - Gold CFD proxy named in R3 as a portable non-equity asset.
- `XTIUSD.DWX` - Oil CFD proxy named in R3 as a portable non-equity asset.
- `EURUSD.DWX` - Liquid FX major suitable for monthly time-series momentum.
- `GBPUSD.DWX` - Liquid FX major suitable for monthly time-series momentum.
- `USDJPY.DWX` - Liquid FX major suitable for monthly time-series momentum.
- `AUDUSD.DWX` - Liquid FX major suitable for monthly time-series momentum.
- `USDCAD.DWX` - Liquid FX major suitable for monthly time-series momentum.
- `USDCHF.DWX` - Liquid FX major suitable for monthly time-series momentum.
- `NZDUSD.DWX` - Liquid FX major suitable for monthly time-series momentum.

**Explicitly NOT for:**
- `SPX500.DWX` - not present in the DWX matrix; `SP500.DWX` is the canonical S&P 500 symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `MN1` |
| Multi-timeframe refs | `PERIOD_MN1` for monthly total return and 12-month SMA; `PERIOD_D1` for the ATR stop |
| Bar gating | Single `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` gate (PERIOD_CURRENT = MN1) = the monthly rebalance; no second QM_IsNewBar call (the tracker is consuming) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | About one month between rebalance events |
| Expected drawdown profile | Downside-protection profile that reduces or removes exposure when monthly trend signals weaken |
| Regime preference | Trend-following risk-on/risk-off |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** `blog`
**Pointer:** Wesley Gray, PhD, "Avoiding the Big Drawdown with Trend-Following Investment Strategies", Alpha Architect, 2015-08-13, https://alphaarchitect.com/avoiding-the-big-drawdown-with-trend-following-investment-strategies/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1086_aa-dpm-tmom-ma.md`

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
| v1 | 2026-06-06 | Initial build from card | (prior task) |
| v2 | 2026-06-06 | Rebuild-in-place (DL-069): MN1-native single new-bar gate (prior D1+MN1 dual gate / month-rollover detection produced 0 trades); exposure ladder via risk-weight scaling; rebalance close+reopen centralised in the new-bar-gated hook | 4c937a7c-3bc6-4f6a-b805-9757b0e85fcf |
