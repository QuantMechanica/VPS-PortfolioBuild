# QM5_34005_sokolov-cstrategy-donchian-atr-breakout — Strategy Spec

**EA ID:** QM5_34005
**Slug:** sokolov-cstrategy-donchian-atr-breakout
**Source:** sokolov-cstrategy-donchian-atr-breakout-official-source
**Author of this spec:** Gemini
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

The strategy implements Vasiliy Sokolov's Donchian channel breakout strategy with dynamic ATR volatility filtering and trailing stops on H4 closed bars.

Long entry triggers when the closed bar price exceeds the highest high of the preceding 20 H4 bars AND current ATR(14) is above its 20-period simple moving average baseline. Short entry triggers when the closed bar price drops below the lowest low of the preceding 20 H4 bars AND current ATR(14) is above its 20-period simple moving average. Initial stop loss is placed at 1.5× ATR(14), take profit at 2.0× SL distance (1:2.0 R:R), and open positions are managed with an ATR dynamic trailing stop.

---

## 2. Parameters

Table of strategy-specific parameters declared in the EA:

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_donchian_period` | 20 | 10-50 | Donchian Channel breakout lookback bars |
| `strategy_atr_period` | 14 | 7-28 | ATR volatility filter period |
| `strategy_atr_ma_period` | 20 | 10-50 | ATR SMA baseline period |
| `strategy_sl_atr_mult` | 1.5 | 0.5-3.0 | Initial SL distance in ATR multiples |
| `strategy_tp_rr_mult` | 2.0 | 1.0-4.0 | Take profit risk-to-reward multiplier |
| `strategy_spread_atr_period` | 14 | 7-28 | Spread filter ATR period |
| `strategy_spread_atr_mult` | 1.8 | 1.0-3.0 | Spread filter threshold in ATR multiples |

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for:

**Designed for:**
- `EURUSD.DWX` — Primary liquid FX major with robust trend-following characteristics
- `SP500.DWX` — US large-cap equity index with strong breakout momentum
- `XTIUSD.DWX` — Crude oil commodity with pronounced volatility expansions

**Explicitly NOT for:**
- `AUDCAD.DWX` — Illiquid cross with high spread friction

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H4)` |

---

## 5. Expected Behaviour

How this EA should behave in production:

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | 2-5 days |
| Expected drawdown profile | <15% total drawdown |
| Regime preference | breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** sokolov-cstrategy-donchian-atr-breakout-official-source
**Source type:** paper
**Pointer:** Sokolov, V. (2015). Universal Expert Advisor Architecture in MQL5. MQL5 Articles.
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_34005_sokolov-cstrategy-donchian-atr-breakout.md`

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
| v1 | 2026-08-17 | Initial build from card | a0f709cd-2c0b-40db-a01b-372c715beef9 |
