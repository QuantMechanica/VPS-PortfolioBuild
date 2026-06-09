# QM5_10075_gh-santi-pa2 — Strategy Spec

**EA ID:** QM5_10075
**Slug:** `gh-santi-pa2`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades a two-bar price-action reversal on the D1 chart. If the last closed candle is bearish and closes below the prior candle low, it places a one-bar buy stop at that candle high. If the last closed candle is bullish and closes above the prior candle high, it places a one-bar sell stop at that candle low. Open positions close when profitable after at least one bar in the market, or after 10 bars if no profitable exit has occurred; an ATR protective stop is attached for V5 baseline safety.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_max_hold_bars` | 10 | 1-100 | Maximum bars to hold if the profitable exit has not occurred. |
| `strategy_atr_period` | 14 | 1-200 | ATR period used only for the protective baseline stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiple for the protective baseline stop. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-listed major FX symbol with DWX OHLC data.
- `GBPUSD.DWX` — card-listed major FX symbol with DWX OHLC data.
- `XAUUSD.DWX` — card-listed gold symbol with DWX OHLC data.
- `GDAXI.DWX` — DAX DWX matrix symbol used for the card's GER40 DAX exposure.

**Explicitly NOT for:**
- Symbols outside the four registered rows above — not registered for this EA's magic slots.

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
| Trades / year / symbol | 40 |
| Expected trade frequency | low daily cadence |
| Typical hold time | 1-10 D1 bars |
| Expected drawdown profile | bounded by the V5 fixed-risk baseline stop and time exit |
| Regime preference | reversal after short-term price extension |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub source code
**Pointer:** `santiago-cruzlopez/MQL5`, `1_Expert_Advisors_EA/018_Price_Action_EA.mq5`
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_10075_gh-santi-pa2.md`

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
| v1 | 2026-06-09 | Initial build from card | e5ae380a-6cd5-49b0-9037-7ccc0880bc1a |
