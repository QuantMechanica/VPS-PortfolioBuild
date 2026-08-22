# QM5_1425_classical-triple-bottom-reversal-h4 — Strategy Spec

**EA ID:** QM5_1425
**Slug:** `classical-triple-bottom-reversal-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** auto-generated ex-post by gen_spec_md.py
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/QM5_1425_classical-triple-bottom-reversal-h4.md`. See that card's body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_1425_classical-triple-bottom-reversal-h4.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tf` | PERIOD_H4 | (see source) | (see strategy logic) |
| `strategy_atr_period` | 14 | (see source) | (see strategy logic) |
| `strategy_fractal_wing_bars` | 1 | (see source) | (see strategy logic) |
| `strategy_lookback_min_bars` | 60 | (see source) | (see strategy logic) |
| `strategy_lookback_max_bars` | 200 | (see source) | (see strategy logic) |
| `strategy_trough_spacing_min_bars` | 25 | (see source) | (see strategy logic) |
| `strategy_trough_spacing_max_bars` | 120 | (see source) | (see strategy logic) |
| `strategy_trough_depth_atr` | 0.50 | (see source) | (see strategy logic) |
| `strategy_trough_equal_atr` | 0.50 | (see source) | (see strategy logic) |
| `strategy_peak_amplitude_min_atr` | 1.50 | (see source) | (see strategy logic) |
| `strategy_peak_equal_atr` | 0.40 | (see source) | (see strategy logic) |
| `strategy_neckline_slope_max_atr` | 0.05 | (see source) | (see strategy logic) |
| `strategy_downtrend_lookback_bars` | 40 | (see source) | (see strategy logic) |
| `strategy_downtrend_slope_max_atr` | -0.10 | (see source) | (see strategy logic) |
| `strategy_prior_break_filter_atr` | 0.30 | (see source) | (see strategy logic) |
| `strategy_breakout_buffer_atr` | 0.40 | (see source) | (see strategy logic) |
| `strategy_breakout_recency_bars` | 12 | (see source) | (see strategy logic) |
| `strategy_tp1_close_fraction` | 0.50 | (see source) | (see strategy logic) |
| `strategy_tp1_ratio` | 0.50 | (see source) | (see strategy logic) |
| `strategy_failure_exit_bars` | 8 | (see source) | (see strategy logic) |
| `strategy_failure_exit_buffer_atr` | 0.30 | (see source) | (see strategy logic) |
| `strategy_time_stop_bars` | 30 | (see source) | (see strategy logic) |
| `strategy_sl_buffer_atr` | 0.40 | (see source) | (see strategy logic) |
| `strategy_sl_cap_atr` | 4.00 | (see source) | (see strategy logic) |
| `strategy_macro_bias_enabled` | true | (see source) | (see strategy logic) |
| `strategy_macro_sma_period` | 50 | (see source) | (see strategy logic) |
| `strategy_reuse_guard_bars` | 40 | (see source) | (see strategy logic) |
| `strategy_spread_filter_enabled` | true | (see source) | (see strategy logic) |
| `strategy_spread_max_atr` | 0.20 | (see source) | (see strategy logic) |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA
- `GBPUSD.DWX` — registered in magic_numbers.csv for this EA
- `USDJPY.DWX` — registered in magic_numbers.csv for this EA
- `AUDUSD.DWX` — registered in magic_numbers.csv for this EA
- `USDCAD.DWX` — registered in magic_numbers.csv for this EA
- `USDCHF.DWX` — registered in magic_numbers.csv for this EA
- `NZDUSD.DWX` — registered in magic_numbers.csv for this EA
- `NDX.DWX` — registered in magic_numbers.csv for this EA
- `WS30.DWX` — registered in magic_numbers.csv for this EA
- `GDAXI.DWX` — registered in magic_numbers.csv for this EA
- `UK100.DWX` — registered in magic_numbers.csv for this EA
- `SP500.DWX` — registered in magic_numbers.csv for this EA
- `XAUUSD.DWX` — registered in magic_numbers.csv for this EA
- `XTIUSD.DWX` — registered in magic_numbers.csv for this EA

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | see `Strategy_*` hooks in the .mq5 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | unspecified |
| Cadence note | see card body |
| Typical hold time | see card body |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | per card thesis |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Pointer:** `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_1425_classical-triple-bottom-reversal-h4.md`

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
| v1 | 2026-08-22 | Initial spec (ex-post, generated by gen_spec_md.py) | post-PT15 remediation |
