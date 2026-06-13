# QM5_10598_mql5-figseries - Strategy Spec

**EA ID:** QM5_10598
**Slug:** mql5-figseries
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `sources/mql5-codebase-mt5-strategies`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

At the configured daily decision time, the EA calculates the FigurelliSeries histogram using 36 moving averages starting at period 6 and stepping by 6. The histogram is the count of moving averages below the close minus the count above the close. The card direction is inverse to the histogram: above zero opens short, below zero opens long. Open positions close at the configured stop time or after the completed-bar histogram crosses to the opposite side of zero.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_start_hour` | 8 | 0-23 | Broker-hour for the once-per-day entry decision. |
| `strategy_start_minute` | 0 | 0-59 | Broker-minute for the once-per-day entry decision. |
| `strategy_stop_hour` | 0 | -1-23 | Broker-hour for timed position close; -1 disables timed close. |
| `strategy_stop_minute` | 0 | 0-59 | Broker-minute for timed position close. |
| `strategy_fig_start_period` | 6 | 1-100 | First moving-average period in FigurelliSeries. |
| `strategy_fig_step` | 6 | 1-100 | Period increment between FigurelliSeries moving averages. |
| `strategy_fig_total` | 36 | 1-50 | Number of moving averages in FigurelliSeries. |
| `strategy_fig_ma_type` | MODE_EMA | MT5 MA methods | Moving-average method used by FigurelliSeries. |
| `strategy_fig_price` | PRICE_CLOSE | MT5 applied prices | Applied price for the FigurelliSeries moving averages. |
| `strategy_signal_shift` | 1 | 1-10 | Completed bar used for histogram signals. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiple for the catastrophic stop. |

---

## 3. Symbol Universe

**Designed for:**
- `USDCHF.DWX` - Source test used USDCHF M30, matching the card baseline.
- `EURUSD.DWX` - Card R3 lists DWX FX portability for major FX symbols.
- `GBPUSD.DWX` - Card R3 lists DWX FX portability for major FX symbols.
- `USDJPY.DWX` - Card R3 lists DWX FX portability for major FX symbols.

**Explicitly NOT for:**
- Non-DWX symbols - Build and backtest artifacts must use canonical `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | Intraday, from the 08:00 decision until timed close or opposite zero-cross. |
| Expected drawdown profile | Catastrophic-stop bounded, no take-profit baseline. |
| Regime preference | Timed oscillator mean-reversion / zero-cross behaviour. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/1641 and `artifacts/cards_approved/QM5_10598_mql5-figseries.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10598_mql5-figseries.md`

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
| v1 | 2026-06-13 | Initial build from card | 8306d0f3-a945-4b59-8df5-a88a4c9757f4 |
