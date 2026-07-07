# QM5_1423_wyckoff-sign-of-weakness-phase-d-h4 - Strategy Spec

**EA ID:** QM5_1423
**Slug:** `wyckoff-sign-of-weakness-phase-d-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

This EA sells the first Wyckoff sign-of-weakness breakdown after a distribution range and a recent failed UTAD on H4. It first requires a 200-bar horizontal range, an 80-bar pre-range uptrend slope, a recent failed upthrust above the range, and then a wide bearish H4 bar that breaks and closes below the range lower band without any earlier decisive close below the range since the UTAD. Entry is a market sell on the next H4 bar, with the stop above the UTAD high plus ATR buffer and the take profit one range amplitude below entry. It closes half the position halfway to target, moves the stop to entry, hard-exits on an H4 close above the UTAD reference band, and time-stops after 40 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | >=1 | H4/D1 ATR lookback used by ATR-scaled gates. |
| `strategy_range_lookback_bars` | 200 | >=80 | H4 lookback for distribution range detection. |
| `strategy_pivot_min_lookback_bars` | 80 | 10-200 | Minimum age for selected range pivots. |
| `strategy_range_duration_min_bars` | 60 | >=1 | Minimum H4 bars between oldest and newest selected range pivots. |
| `strategy_range_min_atr` | 4.0 | >0 | Minimum range amplitude in ATR units. |
| `strategy_range_max_atr` | 12.0 | >min | Maximum range amplitude in ATR units. |
| `strategy_range_containment_pct` | 0.85 | 0-1 | Minimum share of closes contained inside ATR-padded range. |
| `strategy_range_containment_atr` | 0.5 | >=0 | ATR padding around range for containment. |
| `strategy_prerange_slope_bars` | 80 | >=2 | H4 bars before range start used for uptrend slope. |
| `strategy_prerange_slope_atr_per_bar` | 0.10 | >=0 | Minimum pre-range slope in ATR per bar. |
| `strategy_utad_recent_bars` | 30 | >=2 | Maximum age of the failed UTAD. |
| `strategy_utad_break_atr` | 0.5 | >=0 | UTAD high and failure-exit close threshold above range upper. |
| `strategy_sow_low_break_atr` | 0.5 | >=0 | Required low break below range lower for the SOW bar. |
| `strategy_sow_first_break_atr` | 0.3 | >=0 | Prior-close threshold used by the first-break gate. |
| `strategy_sow_wide_spread_atr` | 1.5 | >0 | Minimum SOW bar range in ATR units. |
| `strategy_sow_close_near_low_pct` | 0.30 | 0-1 | Maximum close location inside the SOW bar range. |
| `strategy_volume_filter_enabled` | true | true/false | Enables reliable-symbol tick-volume confirmation. |
| `strategy_volume_mean_bars` | 20 | >=1 | Prior H4 bars used for mean tick volume. |
| `strategy_volume_mult` | 1.30 | >=0 | Current SOW bar volume multiple required versus mean. |
| `strategy_measured_move_mult` | 1.0 | >0 | Take-profit projection as range amplitude multiple. |
| `strategy_partial_move_pct` | 0.50 | 0-1 | Fraction of TP distance that triggers half close and break-even stop. |
| `strategy_sl_utad_atr_buffer` | 0.40 | >=0 | ATR buffer above UTAD high for initial stop. |
| `strategy_sl_max_atr` | 4.0 | >0 | Maximum initial stop distance from entry in ATR units. |
| `strategy_time_stop_h4_bars` | 40 | >=1 | Maximum holding time in H4 bars. |
| `strategy_reuse_guard_h4_bars` | 60 | >=0 | Bars to block re-entry after a detected SOW pattern or invalidation. |
| `strategy_sequence_guard_enabled` | true | true/false | Enables same-narrative guard against recent QM5_1419 LPSY shorts. |
| `strategy_sequence_guard_h4_bars` | 80 | >=0 | Lookback window for same-narrative guard. |
| `strategy_spread_max_atr` | 0.20 | >=0 | Maximum positive modeled spread as H4 ATR fraction. |
| `strategy_macro_sma_period` | 200 | >=2 | D1 SMA period for macro-bias filter. |
| `strategy_macro_slope_bars` | 20 | >=1 | D1 bars used for SMA slope. |
| `strategy_macro_slope_atr_per_bar` | 0.05 | >=0 | Maximum bullish D1 SMA slope allowed for shorts. |
| `strategy_news_pause_h4_bars` | 2 | >=0 | Extra entry-only high-impact news pause in H4 bars before and after events. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - USD major FX pair included by the card's FX majors basket.
- `GBPUSD.DWX` - USD major FX pair included by the card's FX majors basket.
- `USDJPY.DWX` - USD major FX pair included by the card's FX majors basket.
- `USDCHF.DWX` - USD major FX pair included by the card's FX majors basket.
- `USDCAD.DWX` - USD major FX pair included by the card's FX majors basket.
- `AUDUSD.DWX` - USD major FX pair included by the card's FX majors basket.
- `NZDUSD.DWX` - USD major FX pair included by the card's FX majors basket.
- `XAUUSD.DWX` - card-listed gold CFD with H4 OHLC and tick volume.
- `XTIUSD.DWX` - card-listed oil CFD with H4 OHLC and tick volume.
- `NDX.DWX` - card-listed US index CFD with H4 OHLC and tick volume.
- `WS30.DWX` - card-listed US index CFD with H4 OHLC and tick volume.

**Explicitly NOT for:**
- Cross-pair FX symbols outside the R3 basket - card names FX majors, not a full cross-pair universe.
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtest registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1 SMA(200)` and `D1 ATR(14)` macro-bias filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Up to `40` H4 bars by time stop. |
| Expected drawdown profile | Reversal-pattern drawdown concentrated around failed distributions and strong bullish continuations. |
| Regime preference | Distribution-to-markdown reversal after a prior uptrend. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum / book / course`
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1423_wyckoff-sign-of-weakness-phase-d-h4.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1423_wyckoff-sign-of-weakness-phase-d-h4.md`

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
| v1 | 2026-07-07 | Initial build from card | c506d1dc-71dd-4971-92c4-de6298c91a77 |
