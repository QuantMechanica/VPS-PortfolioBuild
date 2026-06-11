# QM5_9518_mql5-l1-adx — Strategy Spec

**EA ID:** QM5_9518
**Slug:** `mql5-l1-adx`
**Source:** `a120af9a-fb72-526c-bb80-d1d098a617b5` (see `strategy-seeds/sources/a120af9a-fb72-526c-bb80-d1d098a617b5/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On every closed H1 bar, the EA reads the ADX, +DI, and -DI values. A long entry fires when +DI crosses above -DI (i.e., +DI was below or equal to -DI on the previous bar and is now above) and ADX exceeds the trend-strength threshold. A short entry fires on the symmetric crossover in the opposite direction. The catastrophic stop is set at ATR(14) × 2.0 from entry. The position is held until the opposite DI crossover occurs AND the L1 trend proxy (SMMA with period 20) confirms the reversal by showing a negative slope for longs or a positive slope for shorts.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_adx_period` | 14 | 7–28 | Period for ADX and DI calculation |
| `strategy_adx_trend_level` | 25.0 | 15.0–40.0 | Minimum ADX value required for a valid entry |
| `strategy_l1_period` | 20 | 10–50 | SMMA period used as L1 trend slope proxy at exit |
| `strategy_atr_period` | 14 | 7–28 | ATR period for catastrophic stop distance |
| `strategy_atr_sl_mult` | 2.0 | 1.0–4.0 | ATR multiplier for stop loss distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Card primary; liquid major FX with clear trend regimes on H1
- `GBPUSD.DWX` — Card primary; correlated major FX, ADX trends reliably on H1
- `USDJPY.DWX` — Card primary; major FX with distinct trend vs range cycles
- `GDAXI.DWX` — Card listed GER40.DWX (not in matrix); ported to GDAXI.DWX (DAX 40), directionally equivalent

**Explicitly NOT for:**
- `GER40.DWX` — not in DWX symbol matrix; replaced by GDAXI.DWX

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~40 |
| Typical hold time | hours to days |
| Expected drawdown profile | moderate; trend-following, losses cluster in ranging markets |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `a120af9a-fb72-526c-bb80-d1d098a617b5`
**Source type:** article
**Pointer:** MetaQuotes, "Applying L1 Trend Filtering in MetaTrader 5", MQL5 Articles, 2026-04-20
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9518_mql5-l1-adx.md`

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
| v1 | 2026-06-11 | Initial build from card | f40f0292-554d-4cb6-8794-8a36ecb7a374 |
