# QM5_11549_carter-t-m5-bb503234-rsi3-stoch633 - Strategy Spec

**EA ID:** QM5_11549
**Slug:** carter-t-m5-bb503234-rsi3-stoch633
**Source:** 42530cb3-0265-534a-89cc-150f80733ff5 (see `strategy-seeds/sources/42530cb3-0265-534a-89cc-150f80733ff5/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a Carter M5 mean-reversion setup after price stretches into a Bollinger Band extreme. A long setup requires the prior push bar to touch or penetrate the lower BB(50,2) band with RSI(3) below 20, followed by a closed confirmation bar back inside the lower BB(50,2) band with RSI(3) recovered to 20 or higher and Stochastic(6,3,3) K crossing above D while still below the lower Stochastic threshold. Shorts mirror the same logic at the upper BB(50,2) band with RSI above 80 and Stochastic crossing down from the upper threshold. The EA sets take profit at the BB(50,2) middle band and stop loss at the BB(50,4) outer band capped at 40 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 50 | 30-75 planned P3 sweep | Shared Bollinger Band center period. |
| `strategy_bb_entry_dev` | 2.0 | 2.0-3.0 planned P3 sweep | Bollinger deviation used as the touch/re-entry trigger band. |
| `strategy_bb_stop_dev` | 4.0 | fixed by card | Bollinger deviation used as the outer stop reference. |
| `strategy_rsi_period` | 3 | fixed by card | RSI period for the extreme and recovery filter. |
| `strategy_rsi_long_lo` | 20.0 | 15.0-25.0 planned P3 sweep | Long oversold threshold and recovery level. |
| `strategy_rsi_short_hi` | 80.0 | 75.0-85.0 mirror of long sweep | Short overbought threshold and recovery level. |
| `strategy_stoch_k` | 6 | fixed by card | Stochastic K period. |
| `strategy_stoch_d` | 3 | fixed by card | Stochastic D period. |
| `strategy_stoch_slow` | 3 | fixed by card | Stochastic slowing value. |
| `strategy_stoch_long_level` | 40.0 | fixed by card | Long Stochastic cross must occur while K remains in the lower zone. |
| `strategy_stoch_short_level` | 60.0 | fixed by card | Short Stochastic cross must occur while K remains in the upper zone. |
| `strategy_sl_cap_pips` | 40.0 | fixed by card for P2 | Maximum stop distance when the BB(50,4) stop is farther away. |
| `strategy_no_friday_entry` | true | true/false | Blocks new entries on Friday per card filter. |
| `strategy_spread_cap_pips` | 5.0 | fixed by card | Blocks only genuinely wide spreads above 5 pips; zero modeled DWX spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - the card's R3 PASS section explicitly states EURUSD.DWX M5 is available and testable.

**Explicitly NOT for:**
- Non-EURUSD `.DWX` symbols - the approved card names only EURUSD.DWX and does not declare a portable multi-symbol basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | Not explicit in card frontmatter; expected minutes to hours from M5 BB-middle mean-reversion TP. |
| Expected drawdown profile | Not explicit in card frontmatter; bounded single-position mean-reversion risk with BB(50,4) stop capped at 40 pips. |
| Regime preference | Mean-revert after short-term volatility stretch. |
| Win rate target (qualitative) | Medium-high, with smaller BB-middle targets and capped outer-band stops. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 42530cb3-0265-534a-89cc-150f80733ff5
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", self-published 2014, System #8.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11549_carter-t-m5-bb503234-rsi3-stoch633.md`

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
| v1 | 2026-06-20 | Initial build from card | 7e7eaa7e-2991-423b-a095-b8141531cc9e |
