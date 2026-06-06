# QM5_10884_risk-carry-3x3 - Strategy Spec

**EA ID:** QM5_10884
**Slug:** `risk-carry-3x3`
**Source:** `8ef51a3a-ad3e-53af-90b6-e0fb4c8f5b38` (see `sources/risk-net`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

On the first tradable D1 bar of each calendar month, the EA estimates currency carry from broker swap rates across the available USD-major DWX basket. It ranks USD, EUR, GBP, JPY, AUD, CAD, CHF, and NZD by average carry, then buys the current pair when its base currency is in the top three and its quote currency is in the bottom three, or sells when the quote currency is top-three and the base currency is bottom-three. New entries are skipped when ATR(20,D1) is above its trailing 252-day 90th percentile, and open positions are closed at monthly rebalance if the pair no longer maps to the selected high-versus-low basket.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | `20` | `1+` | ATR period for the emergency stop and volatility percentile filter. |
| `strategy_atr_sl_mult` | `2.5` | `>0` | Emergency stop distance as a multiple of ATR(20,D1). |
| `strategy_vol_lookback_days` | `252` | `20+` | D1 bars used for the ATR percentile warmup and volatility skip. |
| `strategy_vol_percentile_cap` | `0.90` | `0.0-1.0` | Skip new entries when current ATR percentile is above this cap. |
| `strategy_top_currencies` | `3` | `1-8` | Count of highest-carry currencies selected for the long side. |
| `strategy_bottom_currencies` | `3` | `1-8` | Count of lowest-carry currencies selected for the short side. |
| `strategy_rebalance_first_days` | `3` | `1-7` | Calendar-day window used to catch the first tradable D1 bar of the month. |
| `strategy_rebalance_hour_broker` | `0` | `0-23` | Earliest broker hour for monthly rebalance evaluation. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - USD-major pair in the approved R3 carry basket.
- `GBPUSD.DWX` - USD-major pair in the approved R3 carry basket.
- `USDJPY.DWX` - USD-major pair in the approved R3 carry basket.
- `AUDUSD.DWX` - USD-major pair in the approved R3 carry basket.
- `USDCAD.DWX` - USD-major pair in the approved R3 carry basket.
- `USDCHF.DWX` - USD-major pair in the approved R3 carry basket.
- `NZDUSD.DWX` - USD-major pair in the approved R3 carry basket.

**Explicitly NOT for:**
- Non-FX index or commodity `.DWX` symbols - the card is a broker-swap FX carry strategy.

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
| Trades / year / symbol | `10` |
| Typical hold time | Monthly rebalance hold, normally up to one calendar month unless the ATR stop is hit. |
| Expected drawdown profile | Carry can draw down sharply during high-volatility risk-off reversals; ATR percentile skip is intended to reduce new exposure in those regimes. |
| Regime preference | Currency carry risk premium, with high-volatility months avoided. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `8ef51a3a-ad3e-53af-90b6-e0fb4c8f5b38`
**Source type:** `article`
**Pointer:** `https://www.risk.net/foreign-exchange/1510703/profits-carry`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10884_risk-carry-3x3.md`

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
| v1 | 2026-06-06 | Initial build from card | 4ba62ed3-d6f6-42b0-bd4a-1d4a209104f6 |
