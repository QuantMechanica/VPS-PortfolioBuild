# QM5_10096_gh-ema-pullstop - Strategy Spec

**EA ID:** QM5_10096
**Slug:** gh-ema-pullstop
**Source:** 3b3ec48a-0755-5187-9331-afb36e174175
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades long-only H1 EMA pullbacks. On each closed bar it requires EMA 8 to be above EMA 21, with the previous candle close below EMA 21 and below or equal to EMA 8. If there is no open position or pending buy-stop order for this magic number, it places a buy stop at the highest close of the previous five closed candles, adjusted upward when needed to satisfy the broker minimum stop distance. The order uses a fixed point stop below the previous close and a fixed point take-profit above the entry; stale pending orders are submitted with a 10-bar expiration.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_ema_period | 8 | > 0 | Fast EMA used for the uptrend condition. |
| strategy_slow_ema_period | 21 | > 0 | Slow EMA used for the uptrend and pullback condition. |
| strategy_breakout_lookback | 5 | > 0 | Number of closed candles used for the highest-close buy-stop level. |
| strategy_sl_buffer_points | 3 | > 0 | Fixed point buffer subtracted from the previous candle close for stop-loss. |
| strategy_tp_points | 100 | > 0 | Fixed point distance added to the buy-stop entry for take-profit. |
| strategy_pending_expiry_bars | 10 | > 0 | Number of chart bars used for the unfilled pending buy-stop expiration. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-targeted forex pair with DWX custom data available.
- XAUUSD.DWX - card-targeted gold CFD with DWX custom data available.
- GDAXI.DWX - matrix-supported DAX CFD used as the available DWX equivalent for the card's GER40.DWX target.

**Explicitly NOT for:**
- GER40.DWX - card-stated name is not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is registered instead.

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
| Trades / year / symbol | 100 |
| Typical hold time | Not specified in card frontmatter; intraday to multi-day until SL, TP, stale pending cleanup, or Friday close. |
| Expected drawdown profile | Fixed-risk trend-pullback pending breakout exposure; drawdown expected during non-trending or failed-breakout regimes. |
| Regime preference | Trend-following pullback with pending breakout confirmation. |
| Win rate target (qualitative) | Not specified in card; medium target implied by fixed SL/TP breakout profile. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3b3ec48a-0755-5187-9331-afb36e174175
**Source type:** GitHub repository
**Pointer:** https://github.com/umairkj/mql5-expert-advisor-auto-trading-bot/blob/master/Experts/auto-trading-bot.mq5
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10096_gh-ema-pullstop.md`

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
| v1 | 2026-06-11 | Initial build from card | 54f6f1da-ddd2-4f68-9790-842b3bac8130 |
