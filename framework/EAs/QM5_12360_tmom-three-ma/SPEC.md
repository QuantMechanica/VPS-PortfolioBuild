# QM5_12360_tmom-three-ma - Strategy Spec

**EA ID:** QM5_12360
**Slug:** `tmom-three-ma`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates one completed D1 bar at a time after an 80-bar warmup. It goes long when the 5-period moving average is above the 20-period moving average and the 20-period moving average is above the 50-period moving average. It goes short when the same three averages are stacked in the opposite order. A long closes when the bullish stack no longer holds, and a short closes when the bearish stack no longer holds. The baseline uses SMA values; the EMA and ATR-separation controls are disabled defaults for later parameter testing.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_short_ma` | 5 | 3-8 | Fast moving-average period from the card baseline and P3 grid. |
| `strategy_medium_ma` | 20 | 13-30 | Middle moving-average period from the card baseline and P3 grid. |
| `strategy_long_ma` | 50 | 50-100 | Slow moving-average period from the card baseline and P3 grid. |
| `strategy_use_ema` | false | false/true | Uses SMA by default; true enables the card's EMA P3 variant. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for the protective hard stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.5-5.0 | Stop distance as a multiple of ATR(14). |
| `strategy_warmup_bars` | 80 | 50-200 | Minimum D1 history gate before signals can trade. |
| `strategy_min_sep_atr_mult` | 0.0 | 0.0-0.20 | Optional P3 MA-separation gate; 0.0 disables it for P2 baseline. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with D1 close-derived trend data.
- `GBPUSD.DWX` - FX major with D1 close-derived trend data.
- `USDJPY.DWX` - FX major with D1 close-derived trend data.
- `XAUUSD.DWX` - liquid metal CFD with D1 close-derived trend data.
- `GDAXI.DWX` - matrix-valid DAX custom symbol used for the card's `GER40.DWX` DAX target.
- `NDX.DWX` - liquid US index CFD with D1 close-derived trend data.
- `WS30.DWX` - liquid US index CFD with D1 close-derived trend data.

**Explicitly NOT for:**
- Non-`.DWX` symbols - build and backtest artifacts must use canonical DWX custom symbols.
- `GER40.DWX` - named by the card but absent from `dwx_symbol_matrix.csv`; `GDAXI.DWX` is used instead.

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
| Trades / year / symbol | `16` |
| Typical hold time | Multi-day trend holds; the card does not specify an exact hold-time value. |
| Expected drawdown profile | Delayed exits after sharp reversals are the main risk. |
| Regime preference | Trend-following / MA-ribbon. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** `GitHub repository`
**Pointer:** `ThewindMom/151-trading-strategies, src/strategies/stocks/three_ma.py, https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/stocks/three_ma.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12360_tmom-three-ma.md`

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
| v1 | 2026-06-11 | Initial build from card | 013d9909-03dc-4de9-a33a-871e91f94a89 |
