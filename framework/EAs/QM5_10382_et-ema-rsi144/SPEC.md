# QM5_10382_et-ema-rsi144 - Strategy Spec

**EA ID:** QM5_10382
**Slug:** et-ema-rsi144
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see Elite Trader source URL in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades H1 EMA crossovers on the approved DWX FX/metals basket. A long setup requires EMA(144) crossing above EMA(169), EMA(144) remaining above EMA(169), and RSI(14) having reached 35 or lower within the prior five trading days; it then places a buy stop one tick above EMA(144). A short setup mirrors the rule with EMA(144) crossing below EMA(169), RSI(14) having reached 65 or higher within the prior five trading days, and a sell stop one tick below EMA(144). Exits are the broker SL/TP or a full close when EMA(144) crosses back through EMA(169) before the target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_ema_period | 144 | 1+ | Fast EMA period. |
| strategy_slow_ema_period | 169 | 1+ | Slow EMA period. |
| strategy_rsi_period | 14 | 1+ | RSI period for recent extreme filter. |
| strategy_rsi_oversold | 35.0 | 0-100 | Long setup requires RSI at or below this threshold within lookback. |
| strategy_rsi_overbought | 65.0 | 0-100 | Short setup requires RSI at or above this threshold within lookback. |
| strategy_rsi_lookback_days | 5 | 1+ | Number of H1 trading days searched for the RSI extreme. |
| strategy_stop_pips | 20 | 1+ | Fixed FX protective stop in pips. |
| strategy_target_pips | 100 | 1+ | Baseline full-position profit target in pips. |
| strategy_nonfx_atr_period | 20 | 1+ | ATR period used for non-FX stop port. |
| strategy_nonfx_atr_mult | 1.0 | >0 | ATR multiple used for non-FX stop port. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - original source pair and directly available DWX FX symbol.
- GBPUSD.DWX - directly available liquid DWX FX symbol in the card's R3 basket.
- USDJPY.DWX - directly available liquid DWX FX symbol in the card's R3 basket.
- XAUUSD.DWX - directly available DWX metals symbol in the card's R3 basket, using the card's ATR stop port for non-FX symbols.

**Explicitly NOT for:**
- SP500.DWX - not part of the approved card's R3 basket.

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
| Typical hold time | hours to several days |
| Expected drawdown profile | Low-to-medium cadence FX swing strategy with whipsaw risk around EMA crosses. |
| Regime preference | trend pullback / swing continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/heres-my-strategy-rsi-and-ema-crossover-need-help.72399/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10382_et-ema-rsi144.md`

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
| v1 | 2026-06-13 | Initial build from card | 089b2eb3-2114-468f-b056-04081f8c4119 |
