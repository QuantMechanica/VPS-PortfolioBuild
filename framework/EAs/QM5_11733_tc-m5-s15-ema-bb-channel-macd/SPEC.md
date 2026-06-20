# QM5_11733_tc-m5-s15-ema-bb-channel-macd - Strategy Spec

**EA ID:** QM5_11733
**Slug:** tc-m5-s15-ema-bb-channel-macd
**Source:** 40a4454c-64ff-5015-8538-9f7b32abc0e9
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades an M5 EMA channel breakout with MACD confirmation. EMA(50) of bar highs is the upper channel and EMA(50) of bar lows is the lower channel. A long entry is placed on the next bar when EMA(15) close is above the upper channel and the MACD histogram is positive; a short entry is placed when EMA(15) close is below the lower channel and the MACD histogram is negative. Stop loss and take profit are both set at 2 times ATR(14), and there is no discretionary strategy exit beyond SL/TP and framework exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_timeframe | PERIOD_M5 | M1-MN1 | Timeframe used for all strategy indicator reads. |
| strategy_ema_fast_period | 15 | > 0 | EMA period applied to close for breakout confirmation. |
| strategy_channel_period | 50 | > 0 | EMA period applied to highs and lows for the channel. |
| strategy_macd_fast | 15 | > 0 | MACD fast EMA period. |
| strategy_macd_slow | 70 | > strategy_macd_fast | MACD slow EMA period. |
| strategy_macd_signal | 24 | > 0 | MACD signal period used for histogram calculation. |
| strategy_atr_period | 14 | > 0 | ATR period for stop and target distances. |
| strategy_sl_atr_mult | 2.0 | > 0 | Stop distance multiplier of ATR(14). |
| strategy_tp_atr_mult | 2.0 | > 0 | Take-profit distance multiplier of ATR(14). |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed major FX pair with DWX M5 data.
- GBPUSD.DWX - Card-listed major FX pair with DWX M5 data.
- USDJPY.DWX - Card-listed major FX pair with DWX M5 data.
- AUDUSD.DWX - Card-listed major FX pair with DWX M5 data.

**Explicitly NOT for:**
- Non-FX index symbols - The approved card targets only EURUSD, GBPUSD, USDJPY, and AUDUSD.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | Not specified in card frontmatter; M5 intraday SL/TP strategy implies short intraday holds. |
| Expected drawdown profile | Not specified in card frontmatter. |
| Regime preference | EMA-channel trend breakout with MACD momentum confirmation. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 40a4454c-64ff-5015-8538-9f7b32abc0e9
**Source type:** book
**Pointer:** local vault source `sources/tc-20-forex-strategies-m5-367145560`; all R1-R4 PASS per `artifacts/cards_approved/QM5_11733_tc-m5-s15-ema-bb-channel-macd.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11733_tc-m5-s15-ema-bb-channel-macd.md`

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
| v1 | 2026-06-20 | Initial build from card | f4b97049-54f8-49c4-8011-ad8045565f89 |
