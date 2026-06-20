# QM5_9237_mql5-gm-band-cross - Strategy Spec

**EA ID:** QM5_9237
**Slug:** `mql5-gm-band-cross`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA calculates a geometric-mean midline from the last 20 closed H1 closes and builds an upper and lower band using two standard deviations around that midline. A long signal occurs when the prior closed bar was below the lower band and the most recent closed bar crosses back above the lower band. A short signal mirrors that rule at the upper band. Exits occur on a midline touch, a fresh close beyond the outer band against the position, or after 24 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_gm_period` | 20 | 2-500 | Number of closed bars used for the geometric mean and band standard deviation. |
| `strategy_band_deviation_mult` | 2.0 | >0 | Standard-deviation multiplier for the GM upper and lower bands. |
| `strategy_atr_period` | 14 | >0 | ATR period for stop placement and the minimum band-width filter. |
| `strategy_atr_sl_mult` | 1.6 | >0 | ATR multiple used for the initial stop loss. |
| `strategy_min_band_atr_mult` | 1.0 | >=0 | Minimum accepted band width as a multiple of ATR(14). |
| `strategy_midline_min_rr` | 0.8 | >=0 | Minimum reward-to-risk distance required before using the GM midline as TP. |
| `strategy_fallback_rr` | 1.8 | >0 | Take-profit R multiple when the GM midline is too close to entry. |
| `strategy_max_hold_bars` | 24 | >=0 | Failsafe maximum hold period in H1 bars. |
| `strategy_max_spread_atr_mult` | 0.25 | >=0 | Wide-spread no-trade guard; zero modeled spread never blocks trading. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; liquid FX major with H1 OHLC and ATR history in the DWX matrix.
- `GBPJPY.DWX` - card target; liquid FX cross with H1 OHLC and ATR history in the DWX matrix.
- `XAUUSD.DWX` - card target; gold CFD with H1 OHLC and ATR history in the DWX matrix.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX tester data contract.
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX` - not listed in this card's R3 PASS basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `65` |
| Typical hold time | Intraday to roughly 24 H1 bars |
| Expected drawdown profile | Mean-reversion band recrosses with ATR-defined downside per trade |
| Regime preference | Mean-revert / band-reversion after volatility stretch |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `MQL5 article`
**Pointer:** `https://www.mql5.com/en/articles/15135`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9237_mql5-gm-band-cross.md`

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
| v1 | 2026-06-20 | Initial build from card | ab6aeb64-633d-4efc-ac64-c88e17a1269e |
