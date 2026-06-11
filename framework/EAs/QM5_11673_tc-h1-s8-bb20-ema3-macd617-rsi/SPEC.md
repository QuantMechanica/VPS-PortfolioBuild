# QM5_11673_tc-h1-s8-bb20-ema3-macd617-rsi - Strategy Spec

**EA ID:** QM5_11673
**Slug:** `tc-h1-s8-bb20-ema3-macd617-rsi`
**Source:** `6b5ab225-a2d3-54b1-ac8b-2b000a205468`
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades an H1 Bollinger middle-line cross using EMA(3) as the price proxy. A long signal occurs when EMA(3) crosses above the Bollinger Bands(20, 3) middle line on the last closed bar, with MACD(6,17,1) histogram above zero and RSI(14) above 50. A short signal mirrors the rule with EMA(3) crossing below the middle line, MACD histogram below zero, and RSI below 50. Entries are placed at the next bar open; stops use the card's 2x ATR(14) factory default, with a 50-pip broker target and a discretionary exit when price touches the opposite Bollinger band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 2+ | Bollinger Bands lookback period. |
| `strategy_bb_deviation` | 3.0 | >0 | Bollinger Bands deviation multiplier. |
| `strategy_ema_period` | 3 | 2+ | EMA period used as the crossing price proxy. |
| `strategy_macd_fast` | 6 | 1+ | MACD fast EMA period. |
| `strategy_macd_slow` | 17 | greater than fast | MACD slow EMA period. |
| `strategy_macd_signal` | 1 | 1+ | MACD signal period. |
| `strategy_rsi_period` | 14 | 2+ | RSI confirmation period. |
| `strategy_rsi_midline` | 50.0 | 0-100 | RSI long/short confirmation threshold. |
| `strategy_atr_period` | 14 | 1+ | ATR period for the factory-default stop. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR stop multiplier. |
| `strategy_take_profit_pips` | 50 | 1+ | Fixed broker take-profit distance in pips. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card target symbol with H1 DWX data available.
- `GBPUSD.DWX` - Card target symbol with H1 DWX data available.

**Explicitly NOT for:**
- Non-`.DWX` symbols - V5 research and backtest artifacts must use DWX suffixes.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - broker/custom-symbol data availability is not established.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Expected trade frequency | Not specified in approved card frontmatter |
| Typical hold time | Not specified in approved card frontmatter |
| Expected drawdown profile | Not specified in approved card frontmatter |
| Regime preference | BB middle-line cross momentum with MACD and RSI confirmation |
| Win rate target (qualitative) | Not specified in approved card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6b5ab225-a2d3-54b1-ac8b-2b000a205468`
**Source type:** book
**Pointer:** Thomas Carter, "Forex Trading Strategy #8", in: 20 Forex Trading Strategies Collection (H1), self-published 2014, pp. 18-19.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11673_tc-h1-s8-bb20-ema3-macd617-rsi.md`

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
| v1 | 2026-06-11 | Initial build from card | 3ccdd668-dded-4754-bf18-94ab2f290eb4 |
