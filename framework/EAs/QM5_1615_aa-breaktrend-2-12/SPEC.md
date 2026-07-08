# QM5_1615_aa-breaktrend-2-12 - Strategy Spec

**EA ID:** QM5_1615
**Slug:** `aa-breaktrend-2-12`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

---

## 1. Strategy Logic

The EA rebalances once per calendar month using D1 data as a proxy for the card's completed monthly bars, because `.DWX` MN1 tester history is unavailable. It compares the last completed D1 close with closes about two months and 12 months earlier. If both momentum signs are negative it targets short; if both are positive, or if only the fast or slow leg is positive in the card's Correction/Rebound map, it targets long. It closes or reverses at the next monthly rebalance when the target changes, and uses a 3.0 x ATR(20,D1) initial stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_months` | 2 | 1-6 | Fast momentum lookback in calendar-month units. |
| `strategy_slow_months` | 12 | 6-18 | Slow momentum lookback in calendar-month units. |
| `strategy_trading_days_per_month` | 21 | 15-23 | D1 bars used to approximate one month in `.DWX` tests. |
| `strategy_min_completed_months` | 15 | 13-24 | Minimum completed monthly history proxy before signals are valid. |
| `strategy_atr_period_d1` | 20 | 5-100 | D1 ATR period for the initial stop. |
| `strategy_atr_sl_mult` | 3.0 | 0.5-10.0 | ATR multiplier for the initial stop. |
| `strategy_spread_median_days` | 20 | 5-60 | D1 spread lookback for the median-spread entry filter. |
| `strategy_spread_median_mult` | 2.5 | 1.0-10.0 | Maximum current spread as a multiple of the median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 proxy named by the card; backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 index proxy from the card's US index basket.
- `WS30.DWX` - Dow 30 index proxy from the card's US index basket.
- `GDAXI.DWX` - DAX index proxy from the card's global index basket.
- `XAUUSD.DWX` - Gold proxy named by the card.
- `XTIUSD.DWX` - Matrix-valid WTI crude proxy substituted for unavailable `USOIL.DWX`.
- `EURUSD.DWX` - Major FX pair named by the card and useful for instrument diversity.
- `GBPUSD.DWX` - Major FX pair named by the card and useful for instrument diversity.
- `USDJPY.DWX` - Major FX pair named by the card and useful for instrument diversity.

**Explicitly NOT for:**
- `USOIL.DWX` - The card names this symbol, but it is absent from `dwx_symbol_matrix.csv`; `XTIUSD.DWX` is the registered DWX equivalent.
- `SPX500.DWX` - Not the canonical custom S&P 500 symbol; the valid matrix symbol is `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `PERIOD_D1` ATR and D1 closed-price momentum proxy for MN1 logic |
| Bar gating | `QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0)` for monthly rebalance plus framework `QM_IsNewBar()` for entries |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` from card frontmatter |
| Typical hold time | Weeks to months, until the next monthly target change or SL |
| Expected drawdown profile | Trend-following drawdowns during choppy reversals; controlled by initial ATR stop |
| Regime preference | Trend and time-series momentum regimes |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** `blog`
**Pointer:** Larry Swedroe, "Breaking Bad Momentum Trends", Alpha Architect, 2024-03-15, https://alphaarchitect.com/momentum-trends/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1615_aa-breaktrend-2-12.md`

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
| v1 | 2026-07-08 | Initial build from card | 2881f157-5a9f-4d20-87c2-ef2023b2c9bf |
