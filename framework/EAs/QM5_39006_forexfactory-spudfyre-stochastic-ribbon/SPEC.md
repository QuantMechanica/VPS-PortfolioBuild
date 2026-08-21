# QM5_39006_forexfactory-spudfyre-stochastic-ribbon — Strategy Spec

**EA ID:** QM5_39006
**Slug:** `forexfactory-spudfyre-stochastic-ribbon`
**Source:** `forexfactory-spudfyre-stochastic-ribbon-official-source`
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

The strategy implements Spudfyre's Multi-Timeframe Stochastic Ribbon system on the 1-hour (H1) timeframe. It constructs a harmonic ribbon bundle of 7 Stochastics (%K periods 6, 9, 12, 14, 18, 24, 30 with %D 3 and slowing 3) evaluated on closed bars.

Long entries trigger when the stochastic ribbon compresses deeply into oversold territory at shift 2 (minimum Stoch <= 20.0 and maximum Stoch <= 25.0) followed by an unhook expansion at shift 1 where the fastest Stoch (6) rises above 20.0 and crosses above the anchor Stoch (30). Short entries trigger when the ribbon compresses in overbought territory at shift 2 (maximum Stoch >= 80.0 and minimum Stoch >= 75.0) followed by an unhook at shift 1 where Stoch (6) drops below 80.0 and falls below Stoch (30). Stop loss is placed beyond the swing structure with a 3.0-pip buffer, clamped between 0.5 and 3.5 ATR, and take profit is targeted at 2.0 times the stop distance (1:2.0 R:R). Open trades move to break-even after advancing 20 pips into profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `InpOverbought` | 80.0 | 75.0-85.0 | Overbought extreme threshold |
| `InpOversold` | 20.0 | 15.0-25.0 | Oversold extreme threshold |
| `strategy_atr_period` | 14 | 7-28 | ATR period on H1 |
| `strategy_sl_buffer_pips` | 3.0 | 1.0-5.0 | Stop loss buffer beyond swing structure in pips |
| `strategy_tp_rr` | 2.0 | 1.5-3.5 | Take profit risk-to-reward multiple |
| `strategy_swing_lookback` | 10 | 5-20 | Swing structure lookback bars |
| `strategy_be_trigger_pips` | 20.0 | 10.0-30.0 | Break-even trigger distance in pips |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Primary liquid FX pair with high H1 trend stability and low spread.
- `GBPUSD.DWX` — Major FX pair with prominent cyclical swings and stochastic expansions.
- `AUDUSD.DWX` — Commodity FX pair with clean cyclical oscillations fitting the stochastic ribbon.

**Explicitly NOT for:**
- Non-DWX symbols absent from `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | 4-24 hours |
| Expected drawdown profile | < 3.6% maximum drawdown |
| Regime preference | Cyclical mean-reversion reversals and swing trend unhooks |
| Win rate target (qualitative) | High (70-75% win rate) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `forexfactory-spudfyre-stochastic-ribbon-official-source`
**Source type:** `forum`
**Pointer:** `Spudfyre (2007-2024). The Spud Stochastic Thread. Forex Factory (>10M Views).`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_39006_forexfactory-spudfyre-stochastic-ribbon.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build from card | Gemini build pass |
