# QM5_10900_carter-sma-stoch - Strategy Spec

**EA ID:** QM5_10900
**Slug:** carter-sma-stoch
**Source:** 6facee24-8a58-5bbf-88e9-38d44291db50
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades EURUSD on H1 after a fast SMA(3) crosses EMA(50). A long entry requires SMA(3) crossing above EMA(50) on the last closed bar and either Stochastic(50,60,30) crossing above its EMA(8) or MACD(65,75,35) crossing above its EMA(8). A short entry uses the same rules in the opposite direction. Every entry has a fixed 50-pip stop loss and fixed 100-pip take profit; there is no discretionary strategy exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_sma_period | 3 | 1+ | Fast SMA period for the primary cross. |
| strategy_ema_period | 50 | 1+ | Slow EMA period for the primary cross. |
| strategy_stoch_k_period | 50 | 1+ | Full Stochastic K period. |
| strategy_stoch_d_period | 60 | 1+ | Full Stochastic D period passed to the framework reader. |
| strategy_stoch_slowing | 30 | 1+ | Full Stochastic slowing period. |
| strategy_stoch_ema_period | 8 | 2+ | EMA period applied to the stochastic K line for confirmation. |
| strategy_macd_fast | 65 | 1+ | MACD fast EMA period. |
| strategy_macd_slow | 75 | greater than fast | MACD slow EMA period. |
| strategy_macd_signal | 35 | 1+ | MACD signal parameter used by the framework reader. |
| strategy_macd_ema_period | 8 | 2+ | EMA period applied to the MACD main line for confirmation. |
| strategy_stop_loss_pips | 50 | 1+ | Fixed stop loss distance from entry. |
| strategy_take_profit_pips | 100 | 1+ | Fixed take profit distance from entry. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - the card source symbol is EURUSD and R3 confirms EURUSD.DWX is available.

**Explicitly NOT for:**
- Other DWX symbols - the approved card does not authorize a portable multi-symbol basket.

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
| Trades / year / symbol | 35 |
| Typical hold time | hours to days, until 50-pip SL or 100-pip TP |
| Expected drawdown profile | fixed-risk trend-following drawdown from repeated failed crosses |
| Regime preference | trend and momentum-confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6facee24-8a58-5bbf-88e9-38d44291db50
**Source type:** book
**Pointer:** G:/My Drive/QuantMechanica/Ebook/PDF resources/20 Forex Trading Strategies - Thomas Carter.pdf, Strategy #1, page 7
**R1-R4 verdict (Q00):** all PASS / see artifacts/cards_approved/QM5_10900_carter-sma-stoch.md

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
| v1 | 2026-06-14 | Initial build from card | c836691e-bd7c-4c6d-9984-690304ab8f92 |
