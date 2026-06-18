# QM5_10905_carter-sma3-ema50 - Strategy Spec

**EA ID:** QM5_10905
**Slug:** `carter-sma3-ema50`
**Source:** `6facee24-8a58-5bbf-88e9-38d44291db50` (see `strategy-seeds/sources/6facee24-8a58-5bbf-88e9-38d44291db50/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades the H1 Carter SMA3/EMA50 trend-cross rule. A long setup requires SMA(3) to cross above EMA(50) on the last closed bar, with either Stochastic %K(50,60,30) crossing above its EMA(8) or MACD main(65,75,35) crossing above its EMA(8) on the same closed bar. A short setup is the inverse cross. Entries are market orders on the next framework new-bar pass, with a fixed 50-pip stop, fixed 100-pip target, and a fallback close after 72 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_fast_period` | 3 | >=1 | Fast SMA period used for the trend cross. |
| `strategy_ema_slow_period` | 50 | >=1 | Slow EMA period used for the trend cross. |
| `strategy_stoch_k_period` | 50 | >=1 | Full Stochastic %K period. |
| `strategy_stoch_d_period` | 60 | >=1 | Full Stochastic %D period. |
| `strategy_stoch_slowing` | 30 | >=1 | Full Stochastic slowing value. |
| `strategy_macd_fast` | 65 | >=1 | MACD fast EMA period. |
| `strategy_macd_slow` | 75 | >=1 | MACD slow EMA period. |
| `strategy_macd_signal` | 35 | >=1 | MACD signal period for the MT5 MACD buffer. |
| `strategy_osc_ema_period` | 8 | >=1 | EMA period applied to the Stochastic and MACD confirmation values. |
| `strategy_stop_loss_pips` | 50 | >=1 | Fixed stop loss in pips. |
| `strategy_take_profit_pips` | 100 | >=1 | Fixed take profit in pips. |
| `strategy_max_hold_bars` | 72 | >=0 | Maximum H1 holding period before fallback exit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - the source symbol named by the card and verified in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- Non-EURUSD symbols - the card says the logic is portable to other DWX forex symbols but does not list a concrete P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | Up to `72` H1 bars per card exit rule. |
| Expected drawdown profile | Fixed 50-pip stop and 100-pip target; drawdown profile not otherwise specified by the card frontmatter. |
| Regime preference | Trend-following moving-average crossover. |
| Win rate target (qualitative) | Not specified by the card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6facee24-8a58-5bbf-88e9-38d44291db50`
**Source type:** `book`
**Pointer:** `G:/My Drive/QuantMechanica/Ebook/PDF resources/20 Forex Trading Strategies - Thomas Carter.pdf`, Thomas Carter, *20 Forex Trading Strategies (1 Hour Time Frame)*, Strategy #1, page 7.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10905_carter-sma3-ema50.md`

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
| v1 | 2026-06-18 | Initial build from card | 3308f96a-248d-467d-a307-55651898dc86 |
