# QM5_10401_et-frama-band - Strategy Spec

**EA ID:** QM5_10401
**Slug:** et-frama-band
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA runs on H1 bars and computes price as the average of each bar's high and low. It builds an Ehlers-style FRAMA mean over an even period, measures standard deviation of that price around the FRAMA mean, and places upper and lower deviation bands. A long setup occurs when the last closed bar's low crosses back above the lower band; a short setup occurs when the last closed bar's high crosses back below the upper band. Entries use the card's stop-order wording at the crossed band level, with initial stop distance equal to 0.75 x ATR(20), target equal to 3 x the trail amount, and ATR trailing after entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_frama_period | 16 | even integer >= 4 | FRAMA and deviation lookback length. |
| strategy_num_devs_up | 2.0 | > 0 | Upper band standard-deviation multiplier. |
| strategy_num_devs_down | 2.0 | > 0 | Lower band standard-deviation multiplier. |
| strategy_atr_period | 20 | integer > 0 | ATR period for normalized trail amount. |
| strategy_trail_atr_mult | 0.75 | > 0 | Trail amount as a multiple of ATR. |
| strategy_target_trail_mult | 3.0 | > 0 | Profit target as a multiple of the trail amount. |
| strategy_min_band_spreads | 4.0 | > 0 | Skip entries when band width is less than this many current spreads. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid FX major with OHLC data.
- GBPJPY.DWX - card-listed liquid FX cross with OHLC data.
- XAUUSD.DWX - card-listed metal with OHLC data.
- GDAXI.DWX - verified local DAX custom symbol used as the DWX port for card target GER40.DWX.
- NDX.DWX - card-listed index CFD with OHLC data.

**Explicitly NOT for:**
- GER40.DWX - card-listed name is not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the verified DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Hours to days, bounded by fixed ATR target, ATR trail, and Friday close |
| Expected drawdown profile | Medium risk because entries fade re-entry at adaptive statistical bands |
| Regime preference | Mean-revert / adaptive-band reversal |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** ElectricSavant, Ehlers' Fractal Moving Average (FRAMA), Elite Trader, 2006-10-15, https://www.elitetrader.com/et/threads/ehlers-fractal-moving-average-frama.78790/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10401_et-frama-band.md`

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
| v1 | 2026-05-25 | Initial build from card | 304b0d9c-8280-4510-838c-72fa369c59e2 |
