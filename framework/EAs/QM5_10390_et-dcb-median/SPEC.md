# QM5_10390_et-dcb-median - Strategy Spec

**EA ID:** QM5_10390
**Slug:** `et-dcb-median`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA runs on completed D1 bars. It computes the highest close and lowest close over the last 55 completed daily bars, then defines the channel median as `(highest close + lowest close) / 2`. If flat, it enters long on the next bar when the latest completed close is at or above the channel high, or enters short when the latest completed close is at or below the channel low. A long exits when the latest completed close is at or below the median; a short exits when the latest completed close is at or above the median.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_channel_bars` | 55 | 20-100 | Completed D1 closes used for the Donchian close channel. |
| `strategy_atr_period` | 20 | 10-50 | ATR lookback used for the protective stop and channel-width filter. |
| `strategy_atr_sl_mult` | 2.5 | 2.0-2.5 | ATR multiple for the V5 protective stop. |
| `strategy_min_width_atr` | 1.5 | 0.5-3.0 | Minimum channel width as a multiple of ATR(20). |
| `strategy_min_stop_spreads` | 4 | 1-10 | Minimum protective stop distance measured in current spreads. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - only strategy-specific inputs are listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair suitable for daily breakout testing.
- `GBPUSD.DWX` - liquid major FX pair suitable for daily breakout testing.
- `XAUUSD.DWX` - liquid metal CFD with trend-following behavior suitable for daily breakout testing.
- `NDX.DWX` - major US equity index CFD suitable for daily breakout testing.
- `WS30.DWX` - major US equity index CFD suitable for daily breakout testing.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no sanctioned DWX data target exists for build registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework entry gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `18` |
| Typical hold time | days to weeks |
| Expected drawdown profile | Long-horizon trend follower with late-exit reversal risk. |
| Regime preference | breakout / trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/what-is-the-simplest-trading-strategy.286840/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10390_et-dcb-median.md`

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
| v1 | 2026-05-25 | Initial build from card | 60c180c1-6b47-4029-9517-1756356a48b9 |
