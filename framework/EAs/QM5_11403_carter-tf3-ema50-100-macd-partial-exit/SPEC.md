# QM5_11403_carter-tf3-ema50-100-macd-partial-exit - Strategy Spec

**EA ID:** QM5_11403
**Slug:** `carter-tf3-ema50-100-macd-partial-exit`
**Source:** `29c77a02-59bd-52f7-bcb3-b3108d5f1e79` (see card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA trades an H4 trend-following rule from Thomas Carter Strategy #3. A long setup requires price above EMA50 and EMA100, price at least 10 pips above EMA50, and a MACD(12,26,9) main-line cross above the signal line within the last five bars. A short setup mirrors the rule below EMA50 and EMA100. The initial stop is the 5-bar structure low/high capped at 80 pips; at 2R the EA moves the stop to breakeven and closes 50%, then exits the remainder if price breaks back through EMA50 by 10 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 50 | `>0` | Fast EMA used for entry zone and trailing exit anchor. |
| `strategy_ema_slow_period` | 100 | `> strategy_ema_fast_period` | Slow EMA used to confirm the trend zone. |
| `strategy_macd_fast` | 12 | `>0` | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | `> strategy_macd_fast` | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | `>0` | MACD signal period. |
| `strategy_macd_cross_lookback` | 5 | `>0` bars | Number of recent bars in which the MACD cross may have occurred. |
| `strategy_break_pips` | 10 | `>0` pips | Required distance beyond EMA50 for entry and trailing exit. |
| `strategy_structure_lookback` | 5 | `>0` bars | Lookback for the initial structure stop. |
| `strategy_max_sl_pips` | 80 | `>0` pips | Maximum initial stop distance for P2. |
| `strategy_spread_cap_pips` | 20 | `>0` pips | Entry-blocking spread cap. Zero modeled spread is allowed. |
| `strategy_partial_rr` | 2.0 | `>0` | R multiple for the partial exit trigger. |
| `strategy_partial_fraction` | 0.50 | `0.0-1.0` | Fraction of current position volume to close at TP1. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed H4 DWX FX major.
- `GBPUSD.DWX` - Card-listed H4 DWX FX major.
- `USDJPY.DWX` - Card-listed H4 DWX FX major.
- `AUDUSD.DWX` - Card-listed H4 DWX FX major.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts must use the `.DWX` symbol names.
- Symbols outside the approved card list - the card specifies these four FX instruments only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Expected trade frequency | Card frontmatter does not provide `expected_trade_frequency`; approval notes describe H4 cadence around 40 trades/year/symbol. |
| Typical hold time | Not specified in card frontmatter; exits are mechanical via SL, 2R partial, and EMA50 trail. |
| Expected drawdown profile | Not specified in card frontmatter; P2 uses fixed $1,000 risk with an 80-pip initial SL cap. |
| Regime preference | Trend-following. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `29c77a02-59bd-52f7-bcb3-b3108d5f1e79`
**Source type:** `book`
**Pointer:** `Thomas Carter, 20 Trend Following Systems (2014), Strategy #3; local PDF C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\514732392-Forex-Trend-Following-Strategy.pdf`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11403_carter-tf3-ema50-100-macd-partial-exit.md`

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
| v1 | 2026-07-07 | Initial build from card | 9b29ebc5-7f55-4b70-9331-520a263e7c41 |
