# QM5_10940_grimes-nested-pb — Strategy Spec

**EA ID:** QM5_10940
**Slug:** `grimes-nested-pb`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (see `strategy-seeds/sources/fbfd7f6e-462a-55c8-9efa-9005a70c9f5c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H4 breakouts that occur after a D1 pullback turns back in the direction of the D1 trend. A long setup requires D1 close above EMA(50), D1 EMA(20) above EMA(50), a 12-bar D1 retracement of 25%-55% of the preceding impulse window without D1 closes below EMA(50), then an H4 pause of 3-8 bars whose range is no more than 1.25 * ATR(20) and whose closes stay above H4 EMA(20). It enters long after an H4 close above the pause high; shorts mirror the same rules. Exits are the 2.0R target, stop moved to breakeven at 1.0R, H4 close back through EMA(20), or a 20 H4-bar time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_d1_fast_ema` | 20 | 5-100 | Fast EMA for D1 trend turn and H4 pause close filter. |
| `strategy_d1_slow_ema` | 50 | 20-200 | Slow D1 EMA trend boundary. |
| `strategy_d1_pullback_bars` | 12 | 3-30 | Number of D1 bars used to measure the pullback. |
| `strategy_d1_impulse_bars` | 24 | 3-80 | Preceding D1 window used as the fixed impulse-leg proxy. |
| `strategy_pullback_min_fraction` | 0.25 | 0.05-0.95 | Minimum retracement fraction of the impulse range. |
| `strategy_pullback_max_fraction` | 0.55 | 0.05-0.95 | Maximum retracement fraction of the impulse range. |
| `strategy_h4_atr_period` | 20 | 5-100 | ATR period for pause range, stop, and D1 volatility percentile. |
| `strategy_h4_pause_min_bars` | 3 | 3-8 | Minimum H4 pause length. |
| `strategy_h4_pause_max_bars` | 8 | 3-8 | Maximum H4 pause length. |
| `strategy_pause_range_atr_mult` | 1.25 | 0.25-5.00 | Maximum pause range as a multiple of H4 ATR(20). |
| `strategy_stop_atr_mult` | 0.35 | 0.05-2.00 | Stop offset beyond the pause extreme as a multiple of H4 ATR(20). |
| `strategy_max_stop_atr_mult` | 2.5 | 0.50-8.00 | Maximum allowed stop distance as a multiple of H4 ATR(20). |
| `strategy_target_r` | 2.0 | 0.50-5.00 | Target distance in R. |
| `strategy_breakeven_trigger_r` | 1.0 | 0.25-3.00 | Profit in R required before moving stop to breakeven. |
| `strategy_time_exit_bars` | 20 | 1-100 | Maximum holding period in H4 bars. |
| `strategy_d1_atr_percentile_lookback` | 120 | 20-300 | D1 ATR sample count for the low-volatility filter. |
| `strategy_d1_atr_min_percentile` | 20.0 | 0.0-100.0 | Skip entries when current D1 ATR is below this percentile. |
| `strategy_spread_stop_max_fraction` | 0.08 | 0.00-0.50 | Maximum spread as a fraction of setup stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-listed major FX symbol with D1/H4 DWX history.
- `GBPUSD.DWX` — card-listed major FX symbol with D1/H4 DWX history.
- `USDJPY.DWX` — card-listed major FX symbol with D1/H4 DWX history.
- `XAUUSD.DWX` — card-listed metal symbol with D1/H4 DWX history.
- `GDAXI.DWX` — available DWX DAX proxy for the card's unavailable `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `framework/registry/dwx_symbol_matrix.csv`; registered as `GDAXI.DWX` instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1 EMA(20), D1 EMA(50), D1 ATR(20), D1 pullback/impulse OHLC; H4 EMA(20), H4 ATR(20)` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `24` |
| Typical hold time | `Up to 20 H4 bars` |
| Expected drawdown profile | `Moderate trend-continuation drawdown during failed pullback breakouts` |
| Regime preference | `trend-continuation / breakout` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** `blog`
**Pointer:** `https://www.adamhgrimes.com/nested-pullback/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10940_grimes-nested-pb.md`

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
| v1 | 2026-06-06 | Initial build from card | 6584bd47-a2f0-4280-9072-55b51de25508 |
