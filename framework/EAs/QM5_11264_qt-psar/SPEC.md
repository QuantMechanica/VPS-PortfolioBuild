# QM5_11264_qt-psar - Strategy Spec

**EA ID:** QM5_11264
**Slug:** `qt-psar`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `artifacts/cards_approved/QM5_11264_qt-psar.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA reconstructs Parabolic SAR on closed bars with initial AF 0.02, step AF 0.02, and max AF 0.20. It opens long when the latest closed bar has SAR below close and opens short when the latest closed bar has SAR above close; a fresh flat tester account is allowed to align with the current SAR state. Existing opposite positions are closed before the reversal entry is submitted. New entries are skipped when SAR is closer than 0.25 ATR(14) to close or when spread is more than 10% of that SAR distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_CURRENT` | H1, H4, D1 in P2/P3 tests | Timeframe used for PSAR and ATR signal reads. |
| `strategy_psar_initial_af` | `0.02` | 0.01-0.02 | Initial Parabolic SAR acceleration factor. |
| `strategy_psar_step_af` | `0.02` | 0.01-0.02 | Acceleration increment when a new extreme is made. |
| `strategy_psar_max_af` | `0.20` | 0.10-0.20 | Maximum Parabolic SAR acceleration factor. |
| `strategy_psar_warmup_bars` | `120` | 30-240 | Closed bars used to reconstruct SAR state. |
| `strategy_atr_period` | `14` | 7-30 | ATR period for hard stop and distance filter. |
| `strategy_atr_sl_mult` | `2.50` | 1.0-4.0 | ATR multiple for the initial hard stop. |
| `strategy_min_sar_distance_atr` | `0.25` | 0.0-0.50 | Minimum SAR-to-close distance as a fraction of ATR. |
| `strategy_max_spread_sar_pct` | `10.0` | 0.0-25.0 | Maximum spread as a percent of SAR-to-close distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid DWX forex major with H1/H4/D1 OHLC coverage.
- `GBPUSD.DWX` - liquid DWX forex major with H1/H4/D1 OHLC coverage.
- `XAUUSD.DWX` - liquid DWX metal CFD aligned with the source note that SAR parameters are used on commodities.
- `NDX.DWX` - liquid DWX index CFD for US index exposure.
- `GDAXI.DWX` - canonical DWX DAX symbol; used as the matrix-verified substitute for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; canonical available DAX symbol is `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | Until the next PSAR reversal; usually several H4 bars to multiple days. |
| Expected drawdown profile | Medium risk from whipsaw in sideways markets. |
| Regime preference | Trend-following / stop-and-reverse. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** GitHub repository script
**Pointer:** `https://github.com/je-suis-tm/quant-trading/blob/master/Parabolic%20SAR%20backtest.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11264_qt-psar.md`

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
| v1 | 2026-06-08 | Initial build from card | 5f9dcc7c-6b0b-4366-ae71-aabb4f94b9c0 |
