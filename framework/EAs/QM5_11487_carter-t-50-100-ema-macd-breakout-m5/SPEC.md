# QM5_11487_carter-t-50-100-ema-macd-breakout-m5 - Strategy Spec

**EA ID:** QM5_11487
**Slug:** carter-t-50-100-ema-macd-breakout-m5
**Source:** b3b11449-1e72-5140-917b-c35b6253f1e7 (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades M5 closes that break fully outside the 50 EMA and 100 EMA pair. A long entry requires the closed price to be above both EMAs, at least 10 pips above EMA50, and to have a MACD main-line zero cross from negative to positive within the last five closed bars. A short entry mirrors the rule below both EMAs with a MACD zero cross from positive to negative. The initial stop is the prior five-bar low for long trades or five-bar high for short trades, capped at 25 pips; the EA closes half at 2R, moves the stop to breakeven, and exits the remainder when price closes back through EMA50 by 10 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| strategy_ema_fast_period | 50 | 1-500 | Fast EMA used as the breakout reference. |
| strategy_ema_slow_period | 100 | 1-500 | Slow EMA used to confirm price is outside the EMA pair. |
| strategy_macd_fast | 12 | 1-100 | MACD fast EMA period. |
| strategy_macd_slow | 26 | 1-200 | MACD slow EMA period. |
| strategy_macd_signal | 9 | 1-100 | MACD signal period used by the framework reader. |
| strategy_macd_lookback | 5 | 1-20 | Closed bars to scan for a MACD main-line zero cross. |
| strategy_breakout_pips | 10 | 1-100 | Required pip buffer beyond EMA50 for entry and trailing exit. |
| strategy_sl_lookback_bars | 5 | 1-50 | Number of prior bars used for the structural stop. |
| strategy_sl_max_pips | 25 | 1-200 | Maximum allowed structural stop distance. Wider stops are skipped. |
| strategy_tp1_rr | 2.0 | 0.1-10.0 | Reward/risk multiple that triggers half close and breakeven. |
| strategy_spread_cap_pips | 15 | 0-100 | Maximum entry spread in pips; zero modeled spread is allowed. |
| strategy_no_friday_entry | true | true/false | Suppresses new Friday entries while leaving framework Friday close active. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - listed by the card as an M5 DWX FX target.
- GBPUSD.DWX - listed by the card as an M5 DWX FX target.
- USDJPY.DWX - listed by the card as an M5 DWX FX target.
- AUDUSD.DWX - listed by the card as an M5 DWX FX target.
- USDCAD.DWX - listed by the card as an M5 DWX FX target.

**Explicitly NOT for:**
- Index, metal, energy, and non-card FX symbols - not included in the card's R3 portable basket for this strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) in framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Not specified in frontmatter; expected intraday to multi-hour from M5 breakout and EMA50 trail mechanics. |
| Expected drawdown profile | Not specified in frontmatter; fixed-risk breakout system with 25-pip initial stop cap. |
| Regime preference | Breakout / trend-change. |
| Win rate target (qualitative) | Not specified in frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b3b11449-1e72-5140-917b-c35b6253f1e7
**Source type:** self-published strategy collection / blog
**Pointer:** Thomas Carter, 20 Forex Trading Strategies (5 Minute Time Frame), System #9; see `artifacts/cards_approved/QM5_11487_carter-t-50-100-ema-macd-breakout-m5.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11487_carter-t-50-100-ema-macd-breakout-m5.md`

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
| v1 | 2026-06-23 | Initial build from card | a4da8571-3d41-41ef-b035-f1aaa2f8f964 |
