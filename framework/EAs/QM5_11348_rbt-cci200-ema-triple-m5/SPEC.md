# QM5_11348_rbt-cci200-ema-triple-m5 - Strategy Spec

**EA ID:** QM5_11348
**Slug:** rbt-cci200-ema-triple-m5
**Source:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades the M5 close when CCI(200) and the EMA stack point in the same direction. It buys when CCI(200) is above zero and EMA10 is above EMA21 and EMA50; it sells when CCI(200) is below zero and EMA10 is below EMA21 and EMA50. Each trade uses a fixed 15 pip take-profit and a 12 pip stop capped at ATR(14) x 0.5. Open trades also close when EMA10 crosses EMA21 against the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_cci_period | 200 | >=2 | CCI lookback used as trend regime filter. |
| strategy_ema_fast | 10 | >=1 | Fast EMA used for direction and exit cross. |
| strategy_ema_mid | 21 | >=1 | Middle EMA used for entry alignment and exit cross. |
| strategy_ema_slow | 50 | >=1 | Slow EMA used for entry alignment. |
| strategy_stop_pips | 12.0 | >0 | Fixed stop distance before ATR cap. |
| strategy_tp_pips | 15.0 | >0 | Fixed take-profit distance. |
| strategy_atr_period | 14 | >=1 | ATR lookback for stop cap. |
| strategy_atr_stop_cap_mult | 0.5 | >0 | Maximum stop distance as ATR multiple. |
| strategy_spread_cap_pips | 3.0 | >0 | Maximum allowed spread in pips. |
| strategy_session_start_gmt | 13 | 0-23 | Start hour for the London plus NY session gate in GMT. |
| strategy_session_end_gmt | 22 | 0-23 | End hour for the London plus NY session gate in GMT. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid major FX pair with M5 DWX data.
- GBPUSD.DWX - card-listed liquid major FX pair with M5 DWX data.
- AUDUSD.DWX - card-listed liquid major FX pair with M5 DWX data.
- USDJPY.DWX - card-listed liquid major FX pair with M5 DWX data.

**Explicitly NOT for:**
- Non-FX index and commodity symbols - the card specifies only major FX pairs for this scalp.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 400 |
| Typical hold time | intraday M5 scalp, usually minutes to hours |
| Expected drawdown profile | frequent small fixed-risk losses during choppy EMA/CCI disagreement |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
**Source type:** local PDF archive
**Pointer:** C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11348_rbt-cci200-ema-triple-m5.md`

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
| v1 | 2026-06-08 | Initial build from card | 73851104-f833-4873-962c-74c4d947c1c1 |
