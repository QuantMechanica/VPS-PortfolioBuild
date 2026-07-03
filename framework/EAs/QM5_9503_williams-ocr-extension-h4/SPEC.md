# QM5_9503_williams-ocr-extension-h4 - Strategy Spec

**EA ID:** QM5_9503
**Slug:** `williams-ocr-extension-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-03

---

## 1. Strategy Logic

The EA trades Larry Williams open-close-range continuation bars on H4. A setup
bar must have a body at least 85 percent of its range, a range of at least
`1.50 * ATR(14)` versus the prior bar's ATR, and a close on the same side of
SMA(50) as the bar direction. The next closed H4 bar must extend through the
setup bar's high or low by `0.10 * ATR(14)` and close beyond the setup close in
the same direction. The EA then enters at market on the next H4 bar.

Long stops sit below the setup low by `0.30 * ATR(14)` and shorts mirror above
the setup high. The profit target projects `1.50 * setup_bar_range` from the
extension bar close. A position closes through server-side SL/TP or by time
stop after 12 completed H4 bars plus the following close tick.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | `> 0` | ATR period for setup range, extension buffer, spread, and stop buffer. |
| `strategy_sma_period` | 50 | `> 0` | SMA trend gate period on H4 close. |
| `strategy_ocr_ratio_min` | 0.85 | `0 < value <= 1` | Minimum absolute body divided by full bar range for the setup bar. |
| `strategy_range_atr_mult` | 1.50 | `> 0` | Minimum setup range as a multiple of prior ATR. |
| `strategy_extension_atr_mult` | 0.10 | `>= 0` | Required next-bar break beyond the setup extreme. |
| `strategy_sl_atr_buffer` | 0.30 | `>= 0` | ATR buffer beyond setup structure for the fixed stop. |
| `strategy_tp_range_mult` | 1.50 | `> 0` | Projection multiple of setup range for the take profit. |
| `strategy_spread_atr_mult` | 0.20 | `> 0` | Maximum entry spread as a multiple of ATR; zero modeled spread is allowed. |
| `strategy_time_stop_h4_bars` | 12 | `> 0` | Maximum holding period in H4 bars before strategy close. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major, registered slot 0.
- `GBPUSD.DWX` - FX major, registered slot 1.
- `USDJPY.DWX` - FX major, registered slot 2.
- `AUDUSD.DWX` - FX major, registered slot 3.
- `USDCAD.DWX` - FX major, registered slot 4.
- `USDCHF.DWX` - FX major, registered slot 5.
- `NZDUSD.DWX` - FX major, registered slot 6.
- `XAUUSD.DWX` - metal CFD, registered slot 7.
- `XTIUSD.DWX` - energy CFD, registered slot 8.
- `GDAXI.DWX` - index CFD, registered slot 9.
- `NDX.DWX` - index CFD, registered slot 10.
- `WS30.DWX` - index CFD, registered slot 11.
- `UK100.DWX` - index CFD, registered slot 12.

**Explicitly NOT for:**
- `FRA40.DWX` - present in the approved card but absent from the local DWX symbol matrix.
- `JP225.DWX` - present in the approved card but absent from the local DWX symbol matrix.
- Any other symbol - runtime guard rejects symbols without a registered slot.

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
| Trades / year / symbol | 22 |
| Typical hold time | Several H4 bars, capped after 12 completed H4 bars |
| Expected drawdown profile | Fixed-risk trend-continuation profile bounded by RISK_FIXED and framework kill-switch gates |
| Regime preference | Volatility-expansion breakout continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum and book lineage
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9503_williams-ocr-extension-h4.md`
**R1-R4 verdict (Q00):** all PASS; see `artifacts/cards_approved/QM5_9503_williams-ocr-extension-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3% to 0.5% |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-03 | Initial build from approved card | Build task `c1521674-35a1-4248-a152-fbe9ca89d852` |
