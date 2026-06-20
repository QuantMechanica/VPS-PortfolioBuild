# QM5_11558_carter-t-m5-psar-macd64128-ema100 - Strategy Spec

**EA ID:** QM5_11558
**Slug:** carter-t-m5-psar-macd64128-ema100
**Source:** 42530cb3-0265-534a-89cc-150f80733ff5 (see `sources/carter-thomas-20-forex-strategies-5min`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades the M5 Carter System #19 alignment rule. It opens long when the last closed candle closes above EMA(100), PSAR(0.01, 0.1) is below that candle's low, and MACD main(64,128,9) is above zero. It opens short when the last closed candle closes below EMA(100), PSAR is above that candle's high, and MACD main is below zero. Each entry sets a fixed 9-pip take profit and a stop equal to 3 pips plus the closed-bar close-to-PSAR distance, capped at 15 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 100 | 1+ | EMA trend-filter period on M5. |
| `strategy_sar_step` | 0.01 | >0 | Parabolic SAR acceleration step. |
| `strategy_sar_max` | 0.10 | >0 | Parabolic SAR acceleration maximum. |
| `strategy_macd_fast` | 64 | 1+ | MACD fast EMA period. |
| `strategy_macd_slow` | 128 | > fast | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 1+ | MACD signal period. |
| `strategy_sl_buffer_pips` | 3 | 1+ | Pip buffer added beyond the PSAR stop distance. |
| `strategy_sl_cap_pips` | 15 | 1+ | Maximum stop distance in pips for P2. |
| `strategy_tp_pips` | 9 | 1+ | Fixed take-profit distance in pips. |
| `strategy_spread_cap_pips` | 5 | 1+ | Maximum live modeled spread before entry is blocked. |
| `strategy_no_friday_entry` | true | true/false | Blocks new entries on Friday broker time. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed M5 FX major with DWX data.
- GBPUSD.DWX - card-listed M5 FX major with DWX data.
- AUDUSD.DWX - card-listed M5 FX major with DWX data.

**Explicitly NOT for:**
- Indices, metals, energy, and unavailable FX symbols - the approved card names only the three DWX FX majors above.

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
| Trades / year / symbol | 200 |
| Typical hold time | Intraday; tight 9-pip TP and capped 15-pip SL imply minutes to hours. |
| Expected drawdown profile | Frequent small losses during non-trending or whipsaw regimes. |
| Regime preference | M5 trend/momentum alignment. |
| Win rate target (qualitative) | Medium to high due to fixed small TP and tight PSAR-based stop. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 42530cb3-0265-534a-89cc-150f80733ff5
**Source type:** book
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11558_carter-t-m5-psar-macd64128-ema100.md`

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
| v1 | 2026-06-20 | Initial build from card | 3b0b88fa-99b6-4758-a32c-ffcb21abdca6 |
