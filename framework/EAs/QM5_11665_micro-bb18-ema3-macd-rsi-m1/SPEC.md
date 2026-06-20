# QM5_11665_micro-bb18-ema3-macd-rsi-m1 - Strategy Spec

**EA ID:** QM5_11665
**Slug:** micro-bb18-ema3-macd-rsi-m1
**Source:** c6118ff9-b7f0-5cb1-95cd-7cb0fff06f35 (see `sources/9-forex-systems-moneytec`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades an M1 scalping rule from the approved card. A long entry is opened when EMA(3) crosses above the BB(18, EMA) middle band, implemented as EMA(18), while MACD(12,26,9) histogram is positive and RSI(14) is above 50. A short entry is the mirror image: EMA(3) crosses below EMA(18), MACD histogram is negative, and RSI(14) is below 50. Exits are only the fixed take profit or stop loss; the stop is 10 pips or 2x M1 ATR if ATR is wider, and take profit is 7 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 3 | >= 2 | Fast EMA used as the crossing line. |
| `strategy_bb_mid_period` | 18 | >= 2 | BB(18, EMA) middle band, implemented as EMA(18). |
| `strategy_macd_fast` | 12 | >= 2 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | > fast | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | >= 2 | MACD signal EMA period. |
| `strategy_rsi_period` | 14 | >= 2 | RSI lookback period. |
| `strategy_rsi_mid` | 50.0 | 1.0-99.0 | RSI side threshold for long/short confirmation. |
| `strategy_sl_pips` | 10 | >= 1 | Fixed stop-loss floor in pips. |
| `strategy_tp_pips` | 7 | >= 1 | Fixed take-profit distance in pips. |
| `strategy_atr_period` | 14 | >= 2 | ATR period used to widen the stop if needed. |
| `strategy_sl_atr_mult` | 2.0 | > 0 | ATR multiplier for the widened stop. |
| `strategy_max_spread_pips` | 1.0 | >= 0 | Maximum positive modeled spread allowed before entry is blocked. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target FX major with DWX M1 data available.
- `GBPUSD.DWX` - card target FX major with DWX M1 data available.
- `USDJPY.DWX` - card target FX major with DWX M1 data available.
- `USDCHF.DWX` - card target FX major with DWX M1 data available.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 backtest and registry contract requires `.DWX` symbols.
- Indices, metals, energy symbols - the card target universe is the four listed FX pairs only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 800 |
| Typical hold time | minutes, bounded by 7 pip TP or 10 pip / 2x ATR stop |
| Expected drawdown profile | High-cadence M1 scalping with small per-trade brackets and sensitivity to spread. |
| Regime preference | Short-term momentum / scalping. |
| Win rate target (qualitative) | medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c6118ff9-b7f0-5cb1-95cd-7cb0fff06f35
**Source type:** forum compilation
**Pointer:** Anonymous (DayTradeForex.com), "Micro Trading the 1 Minute Charts System", in 9 Forex Systems (MoneyTec forum compilation), p. 12, about 2006.
**R1-R4 verdict (Q00):** all PASS per card frontmatter; see `artifacts/cards_approved/QM5_11665_micro-bb18-ema3-macd-rsi-m1.md`.

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
| v1 | 2026-06-20 | Initial build from card | 3c059329-c57f-4cb6-ab68-8bb4e5995d96 |
