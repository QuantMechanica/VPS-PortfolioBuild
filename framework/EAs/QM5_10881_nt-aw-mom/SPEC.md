# QM5_10881_nt-aw-mom - Strategy Spec

**EA ID:** QM5_10881
**Slug:** nt-aw-mom
**Source:** 886c5c2e-a87b-5893-9dff-5833be8bc0a3
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades a monthly long-only momentum rotation across SP500.DWX, NDX.DWX, and WS30.DWX. On the first D1 trading bar of each month it ranks the basket by 21-day rate of change, then buys the chart symbol only when that symbol is the highest-ranked member, its ROC is positive, and its last closed D1 close is above its 200-day SMA. It exits on the next monthly rebalance when the chart symbol is no longer the top qualifying member or when the SMA trend gate fails. The initial stop is fixed at 2.5 times ATR(D1, 14) below the entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_momentum_lookback_d1_bars | 21 | 1+ | D1 lookback used for the monthly ROC ranking. |
| strategy_trend_sma_period | 200 | 1+ | D1 SMA period for the trend gate. |
| strategy_atr_period | 14 | 1+ | D1 ATR period used for the initial stop. |
| strategy_atr_sl_mult | 2.5 | >0 | ATR multiplier for the fixed initial stop. |
| strategy_min_history_d1_bars | 221 | 1+ | Minimum D1 history check before ranking a symbol. |
| strategy_max_spread_points | 0 | 0+ | Optional spread ceiling; 0 disables the spread filter. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 proxy named in the card and available as a DWX custom symbol for backtests.
- NDX.DWX - Nasdaq 100 proxy named in the card's portable US index basket.
- WS30.DWX - Dow 30 proxy named in the card's portable US index basket.

**Explicitly NOT for:**
- SPX500.DWX - not a canonical DWX symbol in the matrix.
- SPY.DWX - not available in the DWX matrix.
- ES.DWX - not available in the DWX matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Days to one month, until the next monthly rebalance or stop loss |
| Expected drawdown profile | Trend-following index proxy; drawdowns expected during broad index reversals and leadership whipsaws |
| Regime preference | Trend-following momentum |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 886c5c2e-a87b-5893-9dff-5833be8bc0a3
**Source type:** blog
**Pointer:** Austin Starks, NexusTrade, "I analyzed 140,000 backtests, then built an AI algotrading agent. It's CRUSHING the market", 2026-02-04, https://nexustrade.io/blog/i-analyzed-140000-backtests-then-built-an-ai-algotrading-agent-its-crushing-the-market-20260204
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10881_nt-aw-mom.md`

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
| v1 | 2026-06-14 | Initial build from card | fcd94b06-0b7d-426f-8cbd-f46aef4a4a28 |
