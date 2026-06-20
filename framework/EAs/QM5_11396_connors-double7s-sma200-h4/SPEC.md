# QM5_11396_connors-double7s-sma200-h4 - Strategy Spec

**EA ID:** QM5_11396
**Slug:** connors-double7s-sma200-h4
**Source:** ea4596d1-24e0-5e43-9106-66fd575a5370
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades the Connors Double 7's pullback rule on H4 forex data. A long entry is opened on the next bar after the last closed bar is above SMA(200) and is the lowest close of the last 7 closed bars. A short entry is opened on the next bar after the last closed bar is below SMA(200) and is the highest close of the last 7 closed bars. Long positions exit when the last closed bar is the highest close of the last 7 closed bars; short positions exit when it is the lowest close of the last 7 closed bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 200 | 50-300 | SMA close period for the trend filter. |
| `strategy_extreme_lookback` | 7 | 5-10 | Number of closed bars used for the Double 7 low/high close extreme. |
| `strategy_atr_period` | 14 | 5-30 | ATR period used for protective stop distance. |
| `strategy_sl_atr_mult` | 2.0 | 0.5-5.0 | Stop distance multiplier applied to ATR. |
| `strategy_sl_max_pips` | 50 | 10-200 | Maximum protective stop distance in pips. |
| `strategy_spread_cap_pips` | 20 | 1-50 | Maximum positive modeled spread in pips before entries are blocked. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with H4 DWX data.
- `GBPUSD.DWX` - card-listed major FX pair with H4 DWX data.
- `USDJPY.DWX` - card-listed major FX pair with H4 DWX data.
- `AUDUSD.DWX` - card-listed major FX pair with H4 DWX data.

**Explicitly NOT for:**
- Non-FX index, metal, and energy symbols - this card is a Forex H4 adaptation of the original Connors index rule.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | several H4 bars |
| Expected drawdown profile | mean-reversion pullback losses controlled by ATR stop capped at 50 pips |
| Regime preference | mean-revert pullbacks inside SMA(200) trend state |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ea4596d1-24e0-5e43-9106-66fd575a5370
**Source type:** book
**Pointer:** Larry Connors and Cesar Alvarez, Short Term Trading Strategies That Work (2009), local PDF at `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\100324184-Short-Term-Trading-Strategies-That-Work-by-Larry-Connors-and-Cesar-Alvarez.pdf`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11396_connors-double7s-sma200-h4.md`

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
| v1 | 2026-06-20 | Initial build from card | 2fd4f862-4bbb-4fee-90ea-e3ee4228f2d2 |
