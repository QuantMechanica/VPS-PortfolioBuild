# QM5_10204_tv-ema-wma-2tpbe - Strategy Spec

**EA ID:** QM5_10204
**Slug:** `tv-ema-wma-2tpbe`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades an EMA/WMA crossover on the current tester timeframe, intended for the card's M30/H1 baseline. It opens long when EMA(20) crosses above WMA(50), and opens short when EMA(20) crosses below WMA(50). FX symbols use a 20-pip initial stop and 40-pip final target; non-FX symbols use ATR(14) with 1.0R initial stop and 2.0R final target. When price reaches +1.0R, the stop is moved to break-even while the full position remains open toward TP2.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_CURRENT` | `PERIOD_CURRENT`, `PERIOD_M30`, `PERIOD_H1` | Timeframe used for EMA/WMA and ATR calculations. |
| `strategy_ema_period` | `20` | `1+` | EMA period for the fast crossover leg. |
| `strategy_wma_period` | `50` | `1+` | WMA period for the slow crossover leg. |
| `strategy_fx_stop_pips` | `20` | `1+` | FX initial stop distance and TP1 break-even trigger in pips. |
| `strategy_fx_tp2_pips` | `40` | `2+` and greater than stop pips | FX final take-profit distance in pips. |
| `strategy_atr_period` | `14` | `1+` | ATR period for non-FX bracket conversion. |
| `strategy_nonfx_stop_atr_mult` | `1.0` | `> 0` | Non-FX initial stop distance in ATR multiples. |
| `strategy_nonfx_tp2_atr_mult` | `2.0` | greater than stop multiple | Non-FX final take-profit distance in ATR multiples. |
| `strategy_max_spread_stop_fraction` | `0.15` | `0.0+` | Blocks new entries when spread is above this fraction of initial stop distance. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed FX symbol; pip stop and target apply directly.
- `GBPUSD.DWX` - Card-listed FX symbol; pip stop and target apply directly.
- `USDJPY.DWX` - Card-listed FX symbol; pip stop and target apply directly.
- `XAUUSD.DWX` - Card-listed metal; ATR stop and target conversion applies.
- `GDAXI.DWX` - Matrix-available DAX custom symbol used for the card's `GER40.DWX` exposure.

**Explicitly NOT for:**
- Symbols outside the active magic-number rows for this EA - no implicit runtime universe expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` and `H1` |
| Multi-timeframe refs | none; `strategy_signal_tf` defaults to the tester chart timeframe |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Expected trade frequency | High cadence for a moving-average crossover baseline on M30/H1 bars |
| Typical hold time | Intraday to multi-session, bounded by SL/TP, break-even, and Friday close |
| Regime preference | Trend-following continuation after EMA/WMA crossover |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** `https://www.tradingview.com/script/tGTV8MkY-Two-Take-Profits-and-Two-Stop-Loss/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10204_tv-ema-wma-2tpbe.md`

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
| v1 | 2026-06-09 | Initial build from card | 5adf9833-8b3c-4035-bd4e-b810210ab293 |
