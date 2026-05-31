# QM5_10603_mql5-mafn - Strategy Spec

**EA ID:** QM5_10603
**Slug:** mql5-mafn
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades the direction flip of a MovingAverage_FN-style low-pass moving average on the close of an H4 bar. A long signal occurs when the filtered average was falling and then turns upward; a short signal occurs when it was rising and then turns downward. If the opposite signal appears while a position is open, the current position is closed and the new direction may be opened on the same closed-bar evaluation. A fallback time stop closes any position after 16 completed H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H4 baseline; H6 optional P3 sweep | Timeframe used for the closed-bar signal. |
| `strategy_filter_period` | `44` | `4` and above | MovingAverage_FN low-pass period proxy matching source default `N44`. |
| `strategy_smooth_period` | `12` | `2` and above | Smoothing depth matching source default `XLength=12`. |
| `strategy_calc_bars` | `180` | At least filter + smooth + 3 | Closed-bar history window used for the signal calculation. |
| `strategy_atr_period` | `14` | `1` and above | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | `2.5` | `>0` | ATR multiplier for the catastrophic stop. |
| `strategy_max_hold_bars` | `16` | `1` and above | Fallback maximum holding time in completed H4 bars. |
| `strategy_max_spread_points` | `0` | `0` and above | Optional spread cap; `0` disables the cap. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - only strategy-specific inputs are listed here.

---

## 3. Symbol Universe

**Designed for:**
- `USDCHF.DWX` - source test symbol and a direct DWX FX major.
- `EURUSD.DWX` - liquid DWX FX major suitable for moving-average direction logic.
- `GBPUSD.DWX` - liquid DWX FX major suitable for moving-average direction logic.
- `XAUUSD.DWX` - DWX metal CFD included by the approved card as a portable CFD target.

**Explicitly NOT for:**
- Non-DWX symbols - the build and registries use DWX custom-symbol names only.
- Equity single names - the card targets FX majors and XAUUSD, not stock-specific behaviour.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 framework |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Up to 16 H4 bars by fallback time stop |
| Expected drawdown profile | Trend-following whipsaw risk in sideways regimes, bounded by ATR catastrophic stop |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/1317 and `artifacts/cards_approved/QM5_10603_mql5-mafn.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10603_mql5-mafn.md`

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
| v1 | 2026-05-31 | Initial build from card | 571eb1a2-1902-4631-b283-db881138d254 |
