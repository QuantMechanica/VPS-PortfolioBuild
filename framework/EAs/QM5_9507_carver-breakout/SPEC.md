# QM5_9507_carver-breakout - Strategy Spec

**EA ID:** QM5_9507
**Slug:** `carver-breakout`
**Source:** `1a059d6d-84fa-5d0c-94c5-86dd0481637c`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

---

## 1. Strategy Logic

This EA trades a daily Donchian breakout rule from Robert Carver's breakout forecast. On each new D1 bar it compares the prior D1 close with the previous 80-day high and low, entering long after an upside breakout and short after a downside breakout. Open positions exit when the prior close crosses the opposite 40-day Donchian channel, with an initial 4.0 x ATR(25) hard stop and a 40-day channel stop trail after 1.5R profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_breakout_lookback_d1` | 80 | 40-160 | Donchian channel lookback for entry breakouts. |
| `strategy_exit_lookback_d1` | 40 | 20-120 | Donchian channel lookback for exits and trailing stop. |
| `strategy_atr_period` | 25 | 10-60 | D1 ATR period for the catastrophic stop and volatility filter. |
| `strategy_atr_sl_mult` | 4.0 | 1.0-8.0 | Initial stop distance in ATR multiples. |
| `strategy_atr_median_bars` | 252 | 60-512 | D1 ATR sample used for the median-volatility filter. |
| `strategy_min_atr_median_mult` | 0.40 | 0.0-2.0 | Minimum current ATR as a fraction of median ATR. |
| `strategy_spread_days` | 60 | 0-128 | D1 spread sample used for the median spread filter. |
| `strategy_spread_mult` | 2.0 | 0.0-5.0 | Maximum current spread as a multiple of median spread. |
| `strategy_trail_after_r` | 1.5 | 0.0-5.0 | Profit threshold before the 40-day channel stop can trail. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - G10 FX pair named in the card and suitable for D1 breakout testing.
- `GBPUSD.DWX` - G10 FX pair named in the card and suitable for D1 breakout testing.
- `USDJPY.DWX` - G10 FX pair named in the card and suitable for D1 breakout testing.
- `AUDUSD.DWX` - G10 FX pair named in the card and suitable for D1 breakout testing.
- `XAUUSD.DWX` - liquid metal CFD named in the card's portable universe.
- `NDX.DWX` - liquid index CFD named in the card's portable universe.
- `GDAXI.DWX` - liquid index CFD named in the card's portable universe.
- `UK100.DWX` - liquid index CFD named in the card's portable universe.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the EA relies only on approved `.DWX` OHLC and spread data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `18` |
| Typical hold time | days to weeks |
| Expected drawdown profile | Trend-following drawdowns during range-bound regimes; ATR stop limits single-trade loss. |
| Regime preference | volatility-expansion / breakout |
| Win rate target (qualitative) | low to medium, with larger winners expected to carry expectancy |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1a059d6d-84fa-5d0c-94c5-86dd0481637c`
**Source type:** `book`
**Pointer:** Robert Carver, "Leveraged Trading", Harriman House, 2019, chapter 8 breakout rule; companion spreadsheet linked from `https://www.systematicmoney.org/leveraged-trading-resources`
**R1-R4 verdict (Q00):** all PASS; see `artifacts/cards_approved/QM5_9507_carver-breakout.md`

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
| v1 | 2026-07-02 | Initial build from card | build task `a92614e1-7895-452e-8b9b-c55329bff3bb` |
