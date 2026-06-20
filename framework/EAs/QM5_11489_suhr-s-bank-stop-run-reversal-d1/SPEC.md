# QM5_11489_suhr-s-bank-stop-run-reversal-d1 - Strategy Spec

**EA ID:** QM5_11489
**Slug:** suhr-s-bank-stop-run-reversal-d1
**Source:** 00fdf02a-7d9c-5521-8c30-99d986e908aa
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

At the start of each broker day, the EA records the previous D1 high and low as the manipulation levels. A short setup starts when a closed H1 bar trades at least 3 pips above the previous-day high; a later H1 bar must close back below that level, then remain within a 15-pip pullback window below the level before the EA sells at market. A long setup mirrors the rule below the previous-day low. Each trade uses a fixed 20-pip stop loss and a 3R take-profit, with no discretionary exit beyond fixed SL/TP and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_stop_run_break_pips | 3 | 0+ pips | Minimum penetration beyond the previous-day high or low required to mark a stop run. |
| strategy_pullback_window_pips | 15 | 1+ pips | Maximum pullback distance from the manipulation level allowed for entry. |
| strategy_stop_loss_pips | 20 | 1+ pips | Fixed stop-loss distance from market entry. |
| strategy_reward_rr | 3.0 | > 0 | Take-profit multiple of the stop distance. |
| strategy_spread_cap_pips | 20 | 1+ pips | Maximum spread allowed; zero modeled .DWX spread is allowed. |
| strategy_block_friday_entries | true | true/false | Blocks new entries on Friday. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid FX major with H1 and D1 DWX history.
- GBPUSD.DWX - card-listed liquid FX major with H1 and D1 DWX history.
- USDJPY.DWX - card-listed liquid FX major with H1 and D1 DWX history.
- AUDUSD.DWX - card-listed liquid FX major with H1 and D1 DWX history.

**Explicitly NOT for:**
- Non-FX index or commodity symbols - the card is a forex stop-run strategy and names FX pairs only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 previous-day high and low |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Not specified in card frontmatter |
| Expected drawdown profile | Not specified in card frontmatter |
| Regime preference | Not specified in card frontmatter; mechanically a reversal/liquidity-grab strategy |
| Win rate target (qualitative) | Not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 00fdf02a-7d9c-5521-8c30-99d986e908aa
**Source type:** TradingPub book chapter / compilation
**Pointer:** Sterling Suhr, "The Bank Trading Forex Strategy" in TradingPub "6 Simple Strategies for Trading Forex" (2014)
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11489_suhr-s-bank-stop-run-reversal-d1.md`

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
| v1 | 2026-06-20 | Initial build from card | aee985a7-c2ef-472c-9d00-46677df7e2c0 |
