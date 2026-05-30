# QM5_10430_et-cum-rsi2 - Strategy Spec

**EA ID:** QM5_10430
**Slug:** `et-cum-rsi2`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

The EA trades a completed-bar D1 long-only pullback rule. It sums the last two completed RSI(2) values; if that cumulative RSI is below 10 and the last completed close is above SMA(200), it enters long on the next daily bar. It exits when cumulative RSI rises above 65 or when the last completed close falls below SMA(200). Each entry carries a catastrophic protective stop at 3.0 times ATR(20), with no profit target, trailing stop, break-even, or partial close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 2 | 2-4 | RSI period used in the cumulative RSI calculation. |
| `strategy_cum_rsi_days` | 2 | 2-4 | Number of completed daily RSI values to sum. |
| `strategy_entry_threshold` | 10.0 | 5-15 | Enter long when cumulative RSI is below this value. |
| `strategy_exit_threshold` | 65.0 | 55-75 | Exit long when cumulative RSI is above this value. |
| `strategy_sma_period` | 200 | 100-200 | SMA trend filter period. |
| `strategy_atr_period` | 20 | 20 | ATR period used for the emergency stop. |
| `strategy_atr_stop_mult` | 3.0 | 2.5-4.0, or 0 in parameter tests | ATR multiple used for the emergency stop. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - canonical S&P 500 custom-symbol port for the source's US equity exposure; backtest-only per symbol discipline.
- `NDX.DWX` - live-tradable US large-cap index CFD for portable US equity exposure.
- `WS30.DWX` - live-tradable US large-cap index CFD for portable US equity exposure.
- `GDAXI.DWX` - matrix-valid DAX CFD used for the card's `GER40.DWX` basket item.
- `EURUSD.DWX` - matrix-valid FX port included by the approved card's R3 basket.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated name is not present in the DWX symbol matrix; this build registers `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; `SP500.DWX` is the canonical custom symbol.

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
| Trades / year / symbol | `20` |
| Typical hold time | days, until RSI mean reversion or SMA trend failure |
| Expected drawdown profile | single-symbol pullback mean reversion may be weaker than the source stock-basket version |
| Regime preference | pullback mean-revert inside an uptrend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/larry-connors-cumulative-rsi-26-annual-return-now-with-sensitivity-analysis.379982/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10430_et-cum-rsi2.md`

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
| v1 | 2026-05-27 | Initial build from card | 3a78a245-20f2-40f3-81ee-dd58339284ba |
