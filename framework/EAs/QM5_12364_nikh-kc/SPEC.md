# QM5_12364_nikh-kc - Strategy Spec

**EA ID:** QM5_12364
**Slug:** nikh-kc
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades a long-only daily Keltner Channel reversal. It computes a 20-period EMA of close as the channel middle and a 10-period ATR, then places the bands at middle plus or minus 2 ATR. It enters long when the prior completed D1 close is below the lower band and the latest completed D1 close is higher than that prior close. It exits when the prior completed D1 close is above the upper band and the latest completed D1 close is lower than that prior close; protection is a 2.0 * ATR(14) hard stop from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_keltner_lookback` | 20 | 20-30 | EMA lookback for the Keltner middle line. |
| `strategy_keltner_atr_period` | 10 | 10-14 | ATR lookback used for Keltner band width. |
| `strategy_band_multiplier` | 2.0 | 1.5-2.5 | Multiplier applied to ATR for upper and lower bands. |
| `strategy_stop_atr_period` | 14 | 14 | ATR period for the protective hard stop. |
| `strategy_stop_atr_mult` | 2.0 | 1.5-2.5 | Multiplier applied to ATR(14) for stop distance. |
| `strategy_warmup_bars` | 120 | 120+ | Minimum D1 history required before trading. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - D1 FX major data fits the card's DWX OHLC/ATR portability claim.
- `GBPUSD.DWX` - D1 FX major data fits the card's DWX OHLC/ATR portability claim.
- `USDJPY.DWX` - D1 FX major data fits the card's DWX OHLC/ATR portability claim.
- `XAUUSD.DWX` - D1 metals data fits the card's listed metals portability claim.
- `GDAXI.DWX` - matrix-verified DAX equivalent for card-listed `GER40.DWX`.
- `NDX.DWX` - matrix-verified US index CFD from the card basket.
- `WS30.DWX` - matrix-verified US index CFD from the card basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SP500.DWX` - card marks this as optional backtest-only, not part of the primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 14 |
| Typical hold time | Days to weeks |
| Expected drawdown profile | Vulnerable to persistent breakouts after lower-band entries. |
| Regime preference | Daily volatility-band mean reversion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** public GitHub repository
**Pointer:** https://github.com/Nikhil-Adithyan/Algorithmic-Trading-with-Python/blob/main/Volatility/Keltner_Channel.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12364_nikh-kc.md`

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
| v1 | 2026-06-11 | Initial build from card | 28479241-1beb-449f-a8f9-8a9cd6b8a9c0 |
