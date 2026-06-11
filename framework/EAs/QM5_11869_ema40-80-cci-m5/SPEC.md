# QM5_11869_ema40-80-cci-m5 - Strategy Spec

**EA ID:** QM5_11869
**Slug:** ema40-80-cci-m5
**Source:** 7eb3773b-4c7d-5f72-9c2a-99773154821f (see local PDF archive)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades on M5 closed bars. It goes long when EMA(40) is above EMA(80) and CCI(21) crosses from below zero to above zero on the newly closed bar. It goes short when EMA(40) is below EMA(80) and CCI(21) crosses from above zero to below zero. Positions use market entry with a fixed 12-pip stop loss and fixed 12-pip take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_fast_period | 40 | >=1 | Fast EMA period for the trend filter |
| strategy_ema_slow_period | 80 | >=1 | Slow EMA period for the trend filter |
| strategy_cci_period | 21 | >=1 | CCI period for the zero-line cross trigger |
| strategy_sl_pips | 12 | >=1 | Fixed stop loss in pips |
| strategy_tp_pips | 12 | >=1 | Fixed take profit in pips |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed low-spread major forex pair.
- GBPUSD.DWX - card-listed major forex pair.
- USDJPY.DWX - card-listed major forex pair.
- AUDUSD.DWX - card-listed major forex pair.

**Explicitly NOT for:**
- Non-forex symbols - the card specifies forex majors only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 60 |
| Expected trade frequency | monthly or more often on M5 majors |
| Typical hold time | minutes to hours |
| Expected drawdown profile | tight fixed-pip losses, sensitive to spread costs |
| Regime preference | intraday trend-following momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 7eb3773b-4c7d-5f72-9c2a-99773154821f
**Source type:** book / local PDF archive
**Pointer:** Thomas Carter, 20 Forex Trading Strategies (5 Minute Time Frame), 2014. URL: local PDF archive
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11869_ema40-80-cci-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | 890961dc-2b51-4a8f-89c0-d08f1f280a18 |
