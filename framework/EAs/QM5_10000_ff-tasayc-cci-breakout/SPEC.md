# QM5_10000_ff-tasayc-cci-breakout - Strategy Spec

**EA ID:** QM5_10000
**Slug:** `ff-tasayc-cci-breakout`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

---

## 1. Strategy Logic

This EA trades the ForexFactory TASAYC CCI breakout rule on H1 closed bars. It records the prior completed CCI(20) excursion beyond +100 or -100 after the oscillator returns inside the zone, then enters only when a later excursion breaks that stored prior extreme. Stops use the signal candle extreme plus a small ATR buffer, take profit is 2R, the stop moves to breakeven after 1R, and an early exit fires if CCI crosses back through zero before breakeven.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cci_period` | 20 | 2+ | CCI lookback used for the excursion memory and breakout trigger. |
| `strategy_cci_threshold` | 100.0 | 50.0+ | Positive and negative CCI zone threshold. |
| `strategy_atr_period` | 14 | 2+ | ATR period used for the stop buffer and signal-candle range filter. |
| `strategy_atr_sl_buffer` | 0.10 | 0.0+ | ATR fraction added beyond the signal candle high or low for the hard stop. |
| `strategy_max_range_atr` | 2.50 | 0.1+ | Maximum signal-candle range as a multiple of ATR. |
| `strategy_tp_r_multiple` | 2.0 | 0.1+ | Take-profit distance in initial-risk multiples. |
| `strategy_time_stop_bars` | 36 | 1+ | Maximum hold time in H1 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair with H1 DWX history and source-family portability.
- `GBPUSD.DWX` - major FX pair with H1 DWX history and source-family portability.
- `USDJPY.DWX` - major FX pair with H1 DWX history and source-family portability.
- `XAUUSD.DWX` - liquid DWX metal included by the approved card as a momentum-breakout test market.

**Explicitly NOT for:**
- Non-DWX broker symbols - the Q02 tester uses only local `.DWX` history.
- Monthly-only or external-macro symbols - the strategy is H1 oscillator breakout logic.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35-70 |
| Typical hold time | Several hours to 36 H1 bars |
| Expected drawdown profile | Momentum-breakout drawdown clusters during choppy oscillator whipsaw regimes. |
| Regime preference | H1 momentum breakout after a completed CCI excursion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** ForexFactory TASAYC System / CCI channel breakout rules, https://www.forexfactory.com/thread/325369-tasayc-system
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10000_ff-tasayc-cci-breakout.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-27 | Q02 INFRA repair | Added missing SPEC, full P2 setfile basket, and documented card-required single-bar OHLC reads. |
