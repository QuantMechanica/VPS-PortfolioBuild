# QM5_10911_grimes-complex-pb - Strategy Spec

**EA ID:** QM5_10911
**Slug:** `grimes-complex-pb`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (see `strategy-seeds/sources/fbfd7f6e-462a-55c8-9efa-9005a70c9f5c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H1 trend continuations after a complex pullback. A long requires a rising EMA(50), price above EMA(50), a recent thrust to a 20-bar high with range at least ATR(14), a first pullback of at least 0.8 ATR that remains above EMA(50), a failed first upside resumption, and then a close above the high of that failed resumption leg. Shorts mirror the same sequence below a falling EMA(50). Exits use a 1.5R target, a close through EMA(20) against the trade, or a 30-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_trend_period` | 50 | 2-200 | EMA period for trend direction and trend-integrity checks. |
| `strategy_ema_exit_period` | 20 | 2-100 | EMA period for the close-through discretionary exit. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for thrust, pullback, and stop-buffer measurements. |
| `strategy_thrust_lookback_bars` | 20 | 8-80 | Maximum bars back to search for the original thrust. |
| `strategy_thrust_prior_high_bars` | 20 | 2-80 | Prior-window length used to qualify a thrust high or low. |
| `strategy_thrust_range_atr_mult` | 1.00 | 0.1-5.0 | Minimum thrust range in ATR multiples. |
| `strategy_pullback_atr_mult` | 0.80 | 0.1-5.0 | First-pullback distance from the thrust extreme in ATR multiples. |
| `strategy_failure_window_bars` | 5 | 1-20 | Maximum bars after the first resumption trigger to confirm failure. |
| `strategy_min_thrust_to_entry_bars` | 8 | 3-40 | Minimum bars from original thrust to final entry. |
| `strategy_stop_buffer_atr_mult` | 0.20 | 0.0-2.0 | ATR buffer beyond the second-pullback swing for the stop. |
| `strategy_target_r_mult` | 1.50 | 0.1-10.0 | Fixed reward-to-risk target multiple. |
| `strategy_max_hold_bars` | 30 | 1-200 | Maximum H1 bars to hold before time exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-listed DWX FX major with H1 OHLC structure.
- `GBPUSD.DWX` — card-listed DWX FX major with H1 OHLC structure.
- `XAUUSD.DWX` — card-listed DWX gold symbol with H1 OHLC structure.
- `GDAXI.DWX` — DWX DAX custom symbol used as the available matrix equivalent for card-listed `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | up to 30 H1 bars |
| Expected drawdown profile | trend-continuation pullbacks with fixed 1.5R target and structural ATR-buffered stop |
| Regime preference | trend continuation after complex pullback |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** `blog`
**Pointer:** `Adam H. Grimes complex-consolidation article and Fundamental Trading Patterns supplemental reference`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10911_grimes-complex-pb.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | efc1db59-773f-42e7-8c98-2ababe576fcc |
