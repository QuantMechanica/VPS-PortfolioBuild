# QM5_10229_tv-donchian-base - Strategy Spec

**EA ID:** QM5_10229
**Slug:** tv-donchian-base
**Source:** 30591366-874b-5bee-b47c-da2fca20b728
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA calculates a Donchian channel from the previous closed bars. It opens a long when the last closed bar closes above the previous Donchian highest high, and it opens a short when the last closed bar closes below the previous Donchian lowest low. The Donchian baseline is the average of that highest high and lowest low. Long positions close when the last closed bar closes below the baseline; short positions close when the last closed bar closes above the baseline. The emergency stop is 2 ATR by default, with an optional fixed stop input for later parameter sweeps.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_CURRENT | PERIOD_CURRENT, H4, D1 | Timeframe used for Donchian signal calculations. |
| strategy_donchian_lookback | 20 | 2-200 | Number of prior bars used for the Donchian highest high and lowest low. |
| strategy_atr_period | 14 | 1-200 | ATR period used for the emergency stop. |
| strategy_atr_sl_mult | 2.0 | 0.1-10.0 | ATR multiple for the emergency stop when fixed stop is disabled. |
| strategy_fixed_stop_pips | 0 | 0-10000 | Optional fixed stop in pips; 0 uses ATR stop. |
| strategy_allow_shorts | true | true/false | Enables the card's long/short mode; false makes the EA long-only. |
| strategy_max_spread_points | 0 | 0-100000 | Optional strategy spread ceiling; 0 leaves spread control to the framework. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - trend-capable gold CFD named in the card.
- GDAXI.DWX - available DWX DAX custom symbol used for the card's GER40/DAX leg.
- NDX.DWX - trend-capable Nasdaq 100 CFD named in the card.
- GBPJPY.DWX - trend-capable FX cross named in the card.
- EURJPY.DWX - trend-capable FX cross named in the card.

**Explicitly NOT for:**
- GER40.DWX - card label was ported to GDAXI.DWX because the matrix exposes GDAXI.DWX as the DAX custom symbol.
- Any symbol outside the five registered rows - no implicit universe expansion at runtime.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | H4 setfiles generated as the card's higher-cadence port; no cross-timeframe confirmation reads |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Not specified in card frontmatter; baseline-cross exits imply multi-bar trend holds. |
| Expected drawdown profile | Fixed-risk breakout drawdowns bounded by the framework risk model and emergency SL. |
| Regime preference | Trend-following breakout / volatility expansion. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView script
**Pointer:** https://www.tradingview.com/script/KA6ZtxT8-Donchian-Channel-Strategy-Idea/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10229_tv-donchian-base.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-10 | Initial build from card | b5807b4a-09ec-48ba-9042-3b961e86c508 |
