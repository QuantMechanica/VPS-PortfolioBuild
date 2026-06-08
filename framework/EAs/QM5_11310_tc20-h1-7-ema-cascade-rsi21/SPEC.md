# QM5_11310_tc20-h1-7-ema-cascade-rsi21 - Strategy Spec

**EA ID:** QM5_11310
**Slug:** `tc20-h1-7-ema-cascade-rsi21`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA trades the H1 close when five EMAs are in a full cascade and the EMA(3) crosses EMA(5). A long entry requires EMA(3) crossing above EMA(5), EMA(3) > EMA(5) > EMA(13) > EMA(21) > EMA(80), and RSI(21) above 50. A short entry mirrors that rule with the EMAs descending and RSI(21) below 50. Positions exit when EMA(3) moves back through EMA(5) against the position or RSI(21) crosses back through 50 against the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for EMA and RSI signal reads. |
| `strategy_ema_fast` | `3` | `1+` | Fast EMA used for cascade and trigger cross. |
| `strategy_ema_trigger` | `5` | `1+` | Trigger EMA crossed by EMA(3). |
| `strategy_ema_mid_fast` | `13` | `1+` | First middle EMA in the cascade. |
| `strategy_ema_mid_slow` | `21` | `1+` | Second middle EMA in the cascade. |
| `strategy_ema_trend` | `80` | `1+` | Slow trend EMA in the cascade. |
| `strategy_rsi_period` | `21` | `1+` | RSI period used for trend confirmation and exit. |
| `strategy_rsi_midline` | `50.0` | `0-100` | RSI level separating long and short trend confirmation. |
| `strategy_stop_pips` | `25` | `1+` | Fixed stop distance in pips from the market entry. |
| `strategy_spread_cap_pips` | `20` | `0+` | Maximum allowed spread in pips; `0` disables the strategy spread cap. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card primary instrument and liquid H1 major forex pair.
- `GBPUSD.DWX` - Card R3 P2 basket member with the same major-pair H1 behaviour class.
- `USDJPY.DWX` - Card R3 P2 basket member with available DWX H1 forex data.

**Explicitly NOT for:**
- `SP500.DWX` - Not part of the card's forex basket.
- `XAUUSD.DWX` - Metal volatility and pip economics are outside the card's stated instrument set.

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
| Trades / year / symbol | `80` |
| Typical hold time | Not specified in card; expected to be hours to days because exit waits for EMA(3)/EMA(5) reversal or RSI(21) midline loss. |
| Expected drawdown profile | Trend-following whipsaw drawdown during ranging H1 regimes. |
| Regime preference | Trend-following with EMA cascade alignment. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** book/PDF
**Pointer:** Thomas Carter, 20 Forex Trading Strategies (1 Hour Time Frame), Forex Trading Strategy #7, local PDF: `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\376863900-20-Forex-Trading-Strategies-Collection.pdf`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11310_tc20-h1-7-ema-cascade-rsi21.md`

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
| v1 | 2026-06-08 | Initial build from card | 74b99b3f-e844-4104-a78a-05802c048dbd |
