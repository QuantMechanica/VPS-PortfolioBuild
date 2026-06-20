# QM5_11510_carter-t-wma10-sma20-stoch-rsi-macd-m5 - Strategy Spec

**EA ID:** QM5_11510
**Slug:** `carter-t-wma10-sma20-stoch-rsi-macd-m5`
**Source:** `8794b680-f6f4-5142-b12c-e5e0057e7bcf` (see approved strategy card source record)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades M5 trend-following entries when a WMA(10) and SMA(20) crossover aligns with three momentum filters. A long setup requires WMA(10) above SMA(20), a bullish WMA/SMA cross within the last 3 closed bars, Stochastic(10,6,6) K above D and rising, RSI(28) above 50, and MACD(24,52,18) histogram above zero. A short setup uses the exact inverse conditions. Entries are market orders on the next bar with a fixed 10-pip stop and a 1:1 reward-to-risk take profit; there is no discretionary exit beyond SL, TP, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_wma_period` | 10 | >=1 | Weighted moving average period for the fast side of the crossover. |
| `strategy_sma_period` | 20 | >=1 | Simple moving average period for the slow side of the crossover. |
| `strategy_cross_lookback` | 3 | >=1 | Number of closed bars in which the WMA/SMA cross may have occurred. |
| `strategy_stoch_k` | 10 | >=1 | Stochastic K period. |
| `strategy_stoch_d` | 6 | >=1 | Stochastic D period. |
| `strategy_stoch_slowing` | 6 | >=1 | Stochastic slowing period. |
| `strategy_rsi_period` | 28 | >=1 | RSI period used for the midline trend filter. |
| `strategy_rsi_midline` | 50.0 | 0-100 | RSI threshold separating long and short momentum states. |
| `strategy_macd_fast` | 24 | >=1 | MACD fast EMA period. |
| `strategy_macd_slow` | 52 | > `strategy_macd_fast` | MACD slow EMA period. |
| `strategy_macd_signal` | 18 | >=1 | MACD signal EMA period. |
| `strategy_sl_pips` | 10 | >=1 | Fixed stop-loss distance in pips. |
| `strategy_rr` | 1.0 | >0 | Take-profit reward-to-risk multiple. |
| `strategy_spread_cap_pips` | 10 | >=1 | Maximum modeled spread in pips before new entries are blocked. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`; only strategy-specific inputs are listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX FX major with M5 data available.
- `GBPUSD.DWX` - card-listed DWX FX major with M5 data available.
- `AUDUSD.DWX` - card-listed DWX FX major with M5 data available.

**Explicitly NOT for:**
- Non-card symbols - the approved R3 universe names only EURUSD.DWX, GBPUSD.DWX, and AUDUSD.DWX for this strategy build.
- Non-DWX symbols - pipeline research and backtests must use canonical `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none; the card's M15 MACD note is implemented as MACD(24,52,18) on M5 per the approved QM note |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` from the V5 skeleton; generated setfiles use `M5` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 300 |
| Typical hold time | Not specified in card frontmatter; expected intraday M5 holds because SL and TP are both 10 pips. |
| Expected drawdown profile | Not specified in card frontmatter; fixed-risk M5 trend-following losses should cluster during choppy crossover regimes. |
| Regime preference | Trend-following / structural momentum. |
| Win rate target (qualitative) | Medium; TP and SL are symmetric at 1:1. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `8794b680-f6f4-5142-b12c-e5e0057e7bcf`
**Source type:** self-published book
**Pointer:** Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following Systems", System #5; local source record `sources/carter-thomas-20-forex-trend-following-systems`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11510_carter-t-wma10-sma20-stoch-rsi-macd-m5.md`

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
| v1 | 2026-06-20 | Initial build from card | a3393cda-9adf-4e19-92a4-882f5c3ce225 |
