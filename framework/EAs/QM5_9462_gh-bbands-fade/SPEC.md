# QM5_9462_gh-bbands-fade — Strategy Spec

**EA ID:** QM5_9462
**Slug:** `gh-bbands-fade`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA fades price moves beyond the outer Bollinger Bands on H1 bars. A long entry fires when the most-recently closed bar's close is below the lower Bollinger Band (period 20, 2-sigma deviation, applied to close). A short entry fires when the closed-bar close is above the upper Bollinger Band. The position is exited when the closed-bar close crosses back to the opposite outer band. Stop loss is set at ATR(14) × 2.0 from entry. Only one open position per symbol is allowed at any time; entry is skipped if a position for this magic already exists.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 5–100 | Bollinger Band lookback period |
| `strategy_bb_deviation` | 2.0 | 1.0–4.0 | Band width in standard deviations |
| `strategy_atr_period` | 14 | 5–50 | ATR lookback for stop-loss distance |
| `strategy_atr_sl_mult` | 2.0 | 0.5–5.0 | Multiplier applied to ATR for SL distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; mean-reversion characteristics on H1
- `GBPUSD.DWX` — liquid major FX pair; similar mean-reversion profile to EURUSD
- `XAUUSD.DWX` — gold; significant mean-reversion tendencies around volatility extremes
- `GDAXI.DWX` — DAX 40 index; card specified GER40, ported to canonical DWX symbol GDAXI.DWX

**Explicitly NOT for:**
- `GER40.DWX` — not in dwx_symbol_matrix.csv; replaced by GDAXI.DWX

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
| Trades / year / symbol | ~55 |
| Typical hold time | hours to a few days |
| Expected drawdown profile | moderate mean-reversion drawdowns; SL caps each at 2× ATR |
| Regime preference | mean-revert / volatility-band |
| Win rate target (qualitative) | medium (fade strategy, ~50%+) |

---

## 6. Source Citation

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub repository
**Pointer:** `https://github.com/pipbolt/experts/blob/master/experts/Bollinger-Bands-EA.mq5` (pipbolt.io)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9462_gh-bbands-fade.md`

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
| v1 | 2026-06-11 | Initial build from card | 2127f681-7ffc-4ce9-85c3-d762ad3760eb |
