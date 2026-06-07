# QM5_11076_tbo-breakout - Strategy Spec

**EA ID:** QM5_11076
**Slug:** tbo-breakout
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades a 50-bar TradeBreakOut range on the current H1 chart. A long entry occurs when the last closed bar's high breaks above the highest high of the prior 50 closed bars after the prior bar was not above its own prior 50-bar range. A short entry occurs when the last closed bar's low breaks below the lowest low of the prior 50 closed bars after the prior bar was not below its own prior 50-bar range. Long positions close on the opposite support breakout, short positions close on the opposite resistance breakout, and every trade has a catastrophic ATR(14) x 2.5 stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_breakout_lookback | 50 | >=1 | Number of previous closed bars used for the high/low breakout range. |
| strategy_atr_period | 14 | >=1 | ATR period used for the catastrophic stop. |
| strategy_atr_sl_mult | 2.5 | >0 | ATR multiple used to place the hard stop. |
| strategy_rr_take_profit | 0.0 | >=0 | Optional fixed R multiple take-profit; 0 disables TP for the P2 baseline. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed liquid DWX forex pair for H1 range breakout testing.
- GBPUSD.DWX - Card-listed liquid DWX forex pair for H1 range breakout testing.
- USDJPY.DWX - Card-listed liquid DWX forex pair for H1 range breakout testing.
- NDX.DWX - Card-listed liquid DWX index symbol for H1 range breakout testing.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker or custom-symbol evidence for P2.

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
| Trades / year / symbol | 80 |
| Typical hold time | Opposite H1 breakout exit; usually hours to days. |
| Expected drawdown profile | Whipsaw risk in range-bound periods, bounded by ATR hard stop. |
| Regime preference | breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub repository and MQL5 indicator source
**Pointer:** https://github.com/EarnForex/TradeBreakOut and https://www.earnforex.com/indicators/TradeBreakOut/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11076_tbo-breakout.md`

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
| v1 | 2026-06-07 | Initial build from card | d06deed2-7576-461c-a5d9-1de4f58a88bc |
