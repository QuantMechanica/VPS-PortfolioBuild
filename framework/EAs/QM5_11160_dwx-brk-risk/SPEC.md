# QM5_11160_dwx-brk-risk - Strategy Spec

**EA ID:** QM5_11160
**Slug:** `dwx-brk-risk`
**Source:** `0d015701-0978-5f79-85bc-045914b12692`
**Author of this spec:** Codex
**Last revised:** 2026-07-12

---

## 1. Strategy Logic

This symmetric H1 trend strategy buys when the last closed bar finishes above the highest high of the preceding 48 closed bars and sells when it finishes below the corresponding lowest low. The breakout bar must span at least 0.75 times ATR(14). The position enters at market on the next bar with a 1.5 ATR hard stop, tightened to the opposite edge of the breakout bar when that edge is closer, and a take-profit at 1.5 times initial risk. The stop moves to entry after a favourable move of 1R. A position also closes after 18 H1 bars or on a fresh opposite breakout. Entries are skipped during the first 15 minutes of the broker week or when spread exceeds 10% of the planned ATR stop.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_breakout_lookback` | 48 | 24, 48, 72, 96 | Prior closed bars used to form the price channel. |
| `strategy_atr_period` | 14 | fixed | ATR period used by the range filter and initial stop. |
| `strategy_brk_range_atr_mult` | 0.75 | fixed baseline | Minimum breakout-bar range as a multiple of ATR. |
| `strategy_atr_stop_mult` | 1.5 | 1.0-2.5 | Initial hard-stop distance as a multiple of ATR. |
| `strategy_tp_rr` | 1.5 | 1.0-2.0 | Take-profit distance as a multiple of initial risk. |
| `strategy_max_holding_bars` | 18 | 12-48 | Maximum closed H1 bars held before the time exit. |
| `strategy_be_trigger_rr` | 1.0 | fixed baseline | Favourable R multiple that moves the stop to entry. |
| `strategy_spread_pct_of_stop` | 10.0 | fixed baseline | Maximum spread as a percentage of the planned ATR stop. |
| `strategy_skip_minutes_after_open` | 15 | fixed baseline | Broker-week opening interval in which new entries are blocked. |

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major-FX breakout sleeve, registered at slot 0.
- `GBPUSD.DWX` - liquid major-FX breakout sleeve, registered at slot 1.
- `USDJPY.DWX` - liquid major-FX breakout sleeve with distinct quote dynamics, registered at slot 2.
- `GDAXI.DWX` - canonical Darwinex DAX symbol for the card's legacy `GER40.DWX` label, registered at slot 3.

**Explicitly NOT for:**
- Symbols without continuous, validated `.DWX` H1 history - the channel and ATR rules require a complete closed-bar window.
- Synthetic baskets or paired symbols - this is a single-symbol directional breakout, not a market-neutral construction.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 40-90; card baseline 55 |
| Typical hold time | several hours, capped at 18 H1 bars |
| Expected drawdown profile | clustered small losses in choppy ranges, offset by less frequent directional expansions |
| Regime preference | volatility-expansion breakout and persistent trends |
| Win rate target (qualitative) | low to medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0d015701-0978-5f79-85bc-045914b12692`
**Source type:** reputable broker/institution blog interview
**Pointer:** Darwinex Blog, "The Journey of an Automated Trading Expert", 2024-10-03, https://blog.darwinex.com/the-journey-of-an-automated-trading-expert; approved card copied at `docs/strategy_card.md`.
**R1-R4 verdict (Q00):** `APPROVED`; card frontmatter records R1-R4 as PASS.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-12 | Q02 infrastructure recovery | Added canonical spec/card/set metadata, cached closed-bar channel state, and corrected source-level magic-slot binding; the one-pass evidence records a stale-EX5 freshness failure for the next wake. |
