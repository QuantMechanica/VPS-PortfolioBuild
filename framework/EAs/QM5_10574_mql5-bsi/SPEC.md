# QM5_10574_mql5-bsi - Strategy Spec

**EA ID:** QM5_10574
**Slug:** `mql5-bsi`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

This EA computes the Bounce Strength Indicator histogram on the chart timeframe. It enters long when the latest closed histogram color changes to bullish and enters short when the latest closed histogram color changes to bearish. It holds one position per symbol and magic number, exits on an opposite color change, and uses an ATR(14) 2.0x hard stop with a 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bsi_range_period` | 20 | 2-200 | BSI range lookback used for high, low, and tick-volume normalization. |
| `strategy_bsi_slowing` | 3 | 1-50 | BSI slowing window. |
| `strategy_bsi_avg_period` | 3 | 1-50 | Average window applied to the BSI histogram value. |
| `strategy_atr_period` | 14 | 1-200 | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiple used to place the hard stop. |
| `strategy_rr_target` | 1.5 | 0.1-10.0 | Reward-to-risk multiple used for the target. |
| `strategy_min_hist_abs` | 0.0 | 0.0-100.0 | Optional minimum absolute BSI value; zero disables this filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary source test market and liquid DWX FX major.
- `GBPUSD.DWX` - liquid DWX FX major suitable for closed-bar histogram logic.
- `EURJPY.DWX` - liquid DWX FX cross suitable for the same price/volume histogram rule.
- `XAUUSD.DWX` - DWX metal included by the card's portable P2 basket.

**Explicitly NOT for:**
- `SPX500.DWX` - not a canonical available DWX symbol.
- `SPY.DWX` - not a canonical available DWX symbol.
- `ES.DWX` - not a canonical available DWX symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H8` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `24` |
| Typical hold time | `H8 closed-bar cadence; likely hours to days` |
| Expected drawdown profile | `ATR-defined single-position trend/reversal exposure` |
| Regime preference | `closed-bar histogram color changes` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/14813`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10574_mql5-bsi.md`

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
| v1 | 2026-05-29 | Initial build from card | 9d821a37-53ae-4153-9b91-f168a21047fb |
