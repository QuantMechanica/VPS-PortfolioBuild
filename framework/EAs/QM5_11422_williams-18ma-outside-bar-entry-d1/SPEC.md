# QM5_11422_williams-18ma-outside-bar-entry-d1 - Strategy Spec

**EA ID:** QM5_11422
**Slug:** williams-18ma-outside-bar-entry-d1
**Source:** bb9e26af-ebd1-5a26-b1a8-cc4d78835f03 (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades D1 stop-order breakouts from a two-bar Williams moving-average setup. A long setup requires the last two closed daily lows to sit above the 18-period SMA and neither of those bars to be an inside bar; the EA places a buy stop one pip above the higher high of the two setup bars. A short setup mirrors the rule with both highs below the SMA and a sell stop one pip below the lower low. Stop loss is one pip beyond the opposite extreme of the two setup bars, capped at 80 pips, and the P2 default target is fixed at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma_period` | 18 | 2-200 | SMA period used for the Williams regime filter. |
| `strategy_atr_period` | 14 | 2-100 | ATR reference period retained from the card citation for future TP comparison. |
| `strategy_tp_r_multiple` | 2.0 | 0.5-10.0 | Fixed reward-to-risk multiple used for the P2 default target. |
| `strategy_entry_offset_pips` | 1.0 | 0.1-20.0 | Pip offset added beyond the setup high or low for stop-entry placement. |
| `strategy_max_stop_pips` | 80.0 | 1.0-500.0 | Maximum permitted initial stop distance in pips. |
| `strategy_spread_cap_pips` | 25.0 | 0.1-100.0 | Maximum allowed bid/ask spread in pips. |
| `strategy_pending_expiry_days` | 7 | 1-30 | Pending stop-order expiry in calendar days. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with D1 DWX history.
- `GBPUSD.DWX` - card-listed major FX pair aligned with Williams-tested GBP exposure.
- `USDJPY.DWX` - card-listed major FX pair aligned with Williams-tested JPY exposure.
- `AUDUSD.DWX` - card-listed liquid FX major for D1 trend breakout testing.
- `USDCAD.DWX` - card-listed liquid FX major for D1 trend breakout testing.

**Explicitly NOT for:**
- `SP500.DWX` - index exposure is outside the card's D1 FX target universe.
- `XAUUSD.DWX` - metals are mentioned as source-era examples but are not in the card's target instrument list.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 |
| Typical hold time | days, bounded by the SL/TP bracket and Friday-close framework guard |
| Expected drawdown profile | trend-breakout losses cluster during sideways or inside-bar-heavy regimes |
| Regime preference | trend-following breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** bb9e26af-ebd1-5a26-b1a8-cc4d78835f03
**Source type:** book / workshop PDF
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\Inner Circle Workshop Trading Method. (Larry Williams) (Z-Library).pdf`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11422_williams-18ma-outside-bar-entry-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | a50207a8-baea-454e-95fb-f759bf024682 |
