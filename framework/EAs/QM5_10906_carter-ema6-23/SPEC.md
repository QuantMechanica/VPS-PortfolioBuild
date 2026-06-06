# QM5_10906_carter-ema6-23 - Strategy Spec

**EA ID:** QM5_10906
**Slug:** `carter-ema6-23`
**Source:** `6facee24-8a58-5bbf-88e9-38d44291db50` (see `strategy-seeds/sources/6facee24-8a58-5bbf-88e9-38d44291db50/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades EURUSD on H1 after the last closed bar confirms an EMA(6) and EMA(23) crossover. A long entry requires EMA(6) crossing above EMA(23), MACD(30,60,30) above zero or crossing upward through zero, Stochastic(5,3,3) K crossing above D, and the entry price no farther than 0.5 ATR(14) from EMA(6). Shorts use the inverse rules. Exits are the fixed 25 pip stop, fixed 55 pip take profit, framework Friday close, or an EMA(6)/EMA(23) reverse cross.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema` | 6 | >1 and less than `strategy_slow_ema` | Fast EMA period for crossover and proximity check. |
| `strategy_slow_ema` | 23 | >`strategy_fast_ema` | Slow EMA period for crossover. |
| `strategy_macd_fast` | 30 | >1 and less than `strategy_macd_slow` | MACD fast EMA period. |
| `strategy_macd_slow` | 60 | >`strategy_macd_fast` | MACD slow EMA period. |
| `strategy_macd_signal` | 30 | >1 | MACD signal period used by MT5 MACD calculation. |
| `strategy_stoch_k` | 5 | >1 | Stochastic K period. |
| `strategy_stoch_d` | 3 | >1 | Stochastic D period. |
| `strategy_stoch_slowing` | 3 | >1 | Stochastic slowing period. |
| `strategy_atr_period` | 14 | >1 | ATR period for entry distance from EMA(6). |
| `strategy_entry_atr_mult` | 0.5 | >0 | Maximum entry distance from EMA(6), measured in ATR. |
| `strategy_stop_loss_pips` | 25 | >0 | Fixed stop loss in pips. |
| `strategy_take_profit_pips` | 55 | >0 | Fixed take profit in pips. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 says EURUSD is available as EURUSD.DWX and the source strategy is EURUSD H1.

**Explicitly NOT for:**
- Non-EURUSD `.DWX` symbols - the card does not authorize cross-symbol expansion.

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
| Trades / year / symbol | `35` |
| Typical hold time | Not specified in card frontmatter; bounded by 25 pip SL, 55 pip TP, reverse EMA cross, or Friday close. |
| Expected drawdown profile | Fixed-risk trend-following crossover with moderate trade count. |
| Regime preference | Trend-following / moving-average crossover. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6facee24-8a58-5bbf-88e9-38d44291db50`
**Source type:** `book`
**Pointer:** `G:/My Drive/QuantMechanica/Ebook/PDF resources/20 Forex Trading Strategies - Thomas Carter.pdf`, Thomas Carter, Strategy #3, page 9
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10906_carter-ema6-23.md`

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
| v1 | 2026-06-06 | Initial build from card | 16beaf30-ed42-45f5-aa20-915f9a94dba7 |
