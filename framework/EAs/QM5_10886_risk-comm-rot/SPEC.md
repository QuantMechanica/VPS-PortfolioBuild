# QM5_10886_risk-comm-rot - Strategy Spec

**EA ID:** QM5_10886
**Slug:** risk-comm-rot
**Source:** 8ef51a3a-ad3e-53af-90b6-e0fb4c8f5b38 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA evaluates the commodity basket once on the first tradable D1 bar of each calendar month. For each commodity it computes the 6-month daily return, the latest close percentile inside a 252-day window, and 63-day realised volatility. A symbol is eligible for a long entry when it passes either the positive momentum rule or the low-percentile mean-reversion rule, unless it is in the high-volatility bucket. Held positions are closed after a monthly rebalance when the symbol no longer qualifies.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_momentum_lookback_d1 | 126 | 63-189 | D1 bars used as the 6-month return proxy. |
| strategy_percentile_bars | 252 | 252+ | D1 bars used for the 12-month percentile rank. |
| strategy_realized_vol_days | 63 | 21-126 | D1 log-return window for realised volatility. |
| strategy_meanrev_percentile | 25.0 | 20.0-30.0 | Percentile rank threshold for mean-reversion candidates. |
| strategy_high_vol_percentile | 75.0 | 70.0-80.0 | Universe volatility percentile above which candidates are excluded. |
| strategy_max_selected | 4 | 2-4 | Maximum number of basket commodities selected at rebalance. |
| strategy_atr_period_d1 | 20 | 5-60 | D1 ATR period for the initial stop. |
| strategy_atr_sl_mult | 2.5 | 0.5-8.0 | ATR multiple for the initial stop. |
| strategy_spread_max_points | 0.0 | 0+ | Optional maximum current spread in points; zero disables the spread cap. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - gold commodity proxy from the approved R3 basket.
- XAGUSD.DWX - silver commodity proxy from the approved R3 basket.
- XTIUSD.DWX - crude oil commodity proxy from the approved R3 basket.
- XNGUSD.DWX - natural gas commodity proxy from the approved R3 basket.

**Explicitly NOT for:**
- Non-commodity index or forex symbols - the card is a commodity basket rotation strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none — monthly mean-reversion confirmation uses a D1 proxy (21-bar close compare); MN1 is NOT read (0 bars in tester for DWX symbols) |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | Weeks to one month, until the next monthly rebalance or ATR stop |
| Expected drawdown profile | Commodity proxy gaps and high-volatility trends can create sharp stop-outs |
| Regime preference | Commodity momentum with secondary mean-reversion after low percentile ranks |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8ef51a3a-ad3e-53af-90b6-e0fb4c8f5b38
**Source type:** article
**Pointer:** Nick Sawyer, "JP Morgan adds manager to quantitative strategy", Risk.net, 2007-04-26, https://www.risk.net/derivatives/structured-products/1505797/jp-morgan-adds-manager-quantitative-strategy
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10886_risk-comm-rot.md`

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
| v1 | 2026-06-06 | Initial build from card | 55f9b751-c08d-4793-85e4-3ea8ce5c27a8 |
