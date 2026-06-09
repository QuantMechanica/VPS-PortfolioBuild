# QM5_10162_tv-ema10-20-rsi-trail - Strategy Spec

**EA ID:** QM5_10162
**Slug:** `tv-ema10-20-rsi-trail`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades the M15 EMA10/EMA20 crossover only when both crossover averages are on the same side of EMA100. A long entry requires EMA10 crossing above EMA20, both above EMA100, and a bullish closed signal bar; a short entry requires the mirror image with a bearish closed signal bar. Positions exit when RSI crosses the configured overbought or oversold threshold, or when a position has been open for 24 M15 bars and is profitable. A fixed percent initial stop is placed at entry, with FX stops capped by ATR(14), and ATR trailing becomes active after favorable movement.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M15` | M1-D1 practical | Timeframe used for EMA, RSI, ATR, candle direction, and time-exit bar count. |
| `strategy_ema_fast` | `10` | 2-50 | Fast EMA used for crossover entry. |
| `strategy_ema_slow` | `20` | 3-100 | Slow EMA used for crossover entry. |
| `strategy_ema_trend` | `100` | 20-300 | Trend EMA that the fast and slow EMAs must both clear. |
| `strategy_rsi_period` | `14` | 2-50 | RSI period for signal exits. |
| `strategy_rsi_overbought` | `70.0` | 50-95 | Long exit threshold crossed upward by RSI. |
| `strategy_rsi_oversold` | `30.0` | 5-50 | Short exit threshold crossed downward by RSI. |
| `strategy_atr_period` | `14` | 2-100 | ATR period for FX stop cap and trailing stop. |
| `strategy_stop_percent` | `1.5` | 0.1-10.0 | Initial stop distance as percent of entry price. |
| `strategy_fx_atr_cap` | `1.0` | 0.1-10.0 | Maximum FX stop distance in ATR units when the percent stop is wider. |
| `strategy_trail_atr_mult` | `1.5` | 0.1-10.0 | ATR multiple used by the trailing stop. |
| `strategy_trail_offset_atr` | `1.0` | 0.1-10.0 | Favorable movement in ATR units required before trailing starts. |
| `strategy_time_exit_bars` | `24` | 1-500 | Profitable time exit after this many signal bars. |
| `strategy_max_spread_stop_fraction` | `0.20` | 0.01-1.00 | Blocks new entries when spread exceeds this fraction of initial stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only strategy-specific inputs are listed above.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with liquid M15 DWX data.
- `GBPUSD.DWX` - card-listed FX major with liquid M15 DWX data.
- `XAUUSD.DWX` - card-listed gold CFD target with liquid M15 DWX data.
- `GDAXI.DWX` - available DWX DAX custom symbol used for the card's `DAX.DWX` target.

**Explicitly NOT for:**
- `DAX.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Any symbol not registered for this EA in `magic_numbers.csv` - no implicit runtime expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `160` |
| Typical hold time | intraday, up to 24 M15 bars before profitable time exit |
| Expected drawdown profile | trend-following drawdowns during choppy EMA crossover regimes, bounded by framework fixed-risk sizing |
| Regime preference | trend-following / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView script`
**Pointer:** `https://www.tradingview.com/script/mgD7xBuw-3-EMA-RSI-with-Trail-Stop-Free990-LOW-TF/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10162_tv-ema10-20-rsi-trail.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-09 | Initial build from card | eaeedb9b-d97d-4b9d-a190-6a1c9729b167 |
