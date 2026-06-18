# QM5_12375_tmom-masset-trend - Strategy Spec

**EA ID:** QM5_12375
**Slug:** `tmom-masset-trend`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA checks the last completed D1 bar. It enters long when the closed price is above the 200-day SMA and the last 20 daily returns have positive annualized realized volatility. It exits the long position when the last completed D1 close is at or below the 200-day SMA. The strategy has no short side and uses a 2.0 x ATR(14) hard stop from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_trend_lookback` | 200 | 100-200 | SMA lookback used for long/flat trend state. |
| `strategy_vol_lookback` | 20 | 10-40 | Daily return lookback used for realized-volatility gating. |
| `strategy_vol_target` | 0.10 | 0.05-0.15 | Source volatility-target value retained as a strategy input. |
| `strategy_atr_period` | 14 | 14 | ATR period for the protective hard stop. |
| `strategy_atr_sl_mult` | 2.0 | 1.5-2.5 | ATR multiplier for the protective hard stop. |
| `strategy_min_warmup_bars` | 230 | 230+ | Minimum closed D1 bars before signal evaluation. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with D1 close data for trend-following.
- `GBPUSD.DWX` - liquid FX major with D1 close data for trend-following.
- `USDJPY.DWX` - liquid FX major with D1 close data for trend-following.
- `XAUUSD.DWX` - liquid metal CFD with D1 close data for trend-following.
- `GDAXI.DWX` - available DWX DAX proxy for the card's `GER40.DWX` target.
- `NDX.DWX` - liquid US index CFD with D1 close data for trend-following.
- `WS30.DWX` - liquid US index CFD with D1 close data for trend-following.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SP500.DWX` - card lists it as optional backtest-only, not part of the primary P2 basket.

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
| Trades / year / symbol | 8 |
| Typical hold time | weeks to months |
| Expected drawdown profile | Slow trend-following drawdowns around late exits after reversals. |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** `public GitHub source file`
**Pointer:** `https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/etfs/multi_asset_trend.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12375_tmom-masset-trend.md`

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
| v1 | 2026-06-18 | Initial build from card | caac300b-b67d-4251-93bf-2a1905132c9e |
