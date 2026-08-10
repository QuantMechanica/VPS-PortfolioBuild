# QM5_10648_tv-velox-mtf — Strategy Spec

**EA ID:** QM5_10648
**Slug:** `tv-velox-mtf`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Trend-following, both directions. Long when EMA(6) > EMA(21) AND the 3-bar
slope of EMA(6), expressed as an angle via `atan(slope / (0.15*ATR14))`, is
at least 80 degrees, AND the just-closed candle is a Marubozu (body >= 60% of
range), AND ADX(14) > 20, AND the two most recent confirmed price fractals
show higher-high + higher-low structure. Short is the mirror image. Stop =
1.5x ATR(14) beyond the signal candle's opposite extreme (skip if that
distance exceeds 4x ATR); target = 7.0R; time exit after 48 bars; early exit
if EMA(6) crosses back through EMA(21).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 6 | fixed | fast EMA period |
| `strategy_ema_slow` | 21 | fixed | slow EMA period |
| `strategy_atr_period` | 14 | fixed | ATR period |
| `strategy_slope_lookback_bars` | 3 | fixed | bars back for EMA slope |
| `strategy_angle_deg_threshold` | 80.0 | fixed | card: "at least 80 degrees" |
| `strategy_angle_norm_atr_mult` | 0.15 | design choice | ATR-normalization denominator for the dimensionless slope→angle proxy (card gives no chart-scale reference; documented interior design choice) |
| `strategy_marubozu_body_ratio` | 0.60 | fixed | card: "at least 60%" body/range |
| `strategy_adx_period` | 14 | fixed | ADX period |
| `strategy_adx_threshold` | 20.0 | fixed | card: "ADX(14) > 20" |
| `strategy_pivot_lookback_bars` | 60 | fixed | confirmed-fractal scan window |
| `strategy_sl_atr_mult` | 1.5 | fixed | stop beyond signal-candle extreme |
| `strategy_sl_atr_cap_mult` | 4.0 | fixed | skip entry if stop distance exceeds this |
| `strategy_tp_r_mult` | 7.0 | fixed | card: "7.0R" |
| `strategy_time_exit_bars` | 48 | fixed | card: "close after 48 bars" |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — card primary symbol.
- `GDAXI.DWX` — card lists GER40.DWX; GER40.DWX is not in `dwx_symbol_matrix.csv`, ported to the canonical DAX Custom Symbol GDAXI.DWX.
- `NDX.DWX` — card primary symbol.
- `GBPJPY.DWX` — card primary symbol.

**Explicitly NOT for:**
- `GER40.DWX` — not a valid Custom Symbol name in the matrix; see GDAXI.DWX above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~6-15 |
| Typical hold time | up to 48 M30 bars (~1 day) |
| Expected drawdown profile | infrequent losses capped near 1.5-4x ATR risk, large 7R winners rare |
| Regime preference | trend |
| Win rate target (qualitative) | low-medium (high R:R trend-following) |

---

## 6. Source Citation

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** forum (TradingView script listing)
**Pointer:** https://www.tradingview.com/script/9Z79EWiW-Velox-MTF-Visual-Enhanced-Marubozu-Filter/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10648_tv-velox-mtf.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-10 | Initial build from card | agent_router task 5f1f643e |
