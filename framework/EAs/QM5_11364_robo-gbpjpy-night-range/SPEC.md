# QM5_11364_robo-gbpjpy-night-range — Strategy Spec

**EA ID:** QM5_11364
**Slug:** `robo-gbpjpy-night-range`
**Source:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`
**Author of this spec:** Codex
**Last revised:** 2026-07-31

---

## 1. Strategy Logic

On GBPJPY M15, the EA measures the broker-time range from 22:00 through
06:59. At 07:00 it skips Monday and any range wider than 70 pips, then places a
buy stop 5 pips above the range and a sell stop 5 pips below it. The first
filled leg cancels its sibling; unfilled orders expire after four hours.

The stop is the opposite side of the range plus the same 5-pip buffer, capped
at 50 pips from entry. The take-profit is one Asian-range width from entry,
clipped to 20–60 pips. Any surviving position closes at 17:00 broker time.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_session_start_hour` | 22 | card fixed | Broker hour at which Asian-range measurement begins. |
| `strategy_session_end_hour` | 7 | card fixed | Broker hour at which measurement ends and orders are placed. |
| `strategy_close_hour` | 17 | card fixed | Broker hour for the end-of-London forced close. |
| `strategy_buffer_pips` | 5 | 3 / 5 / 10 | Distance beyond each range edge for entries and natural stops. |
| `strategy_range_cap_pips` | 70 | 50 / 70 / 100 | Skip the setup when the measured range exceeds this value. |
| `strategy_tp_multiplier` | 1.0 | 0.75 / 1.0 / 1.5 | Multiplier applied to the measured range for take-profit distance. |
| `strategy_tp_min_pips` | 20 | card fixed | Minimum take-profit distance. |
| `strategy_tp_max_pips` | 60 | card fixed | Maximum take-profit distance. |
| `strategy_sl_cap_pips` | 50 | card fixed | Maximum P2 stop distance from entry. |
| `strategy_cancel_hours` | 4 | 3 / 4 / 6 | Lifetime of the unfilled pending bracket. |
| `strategy_spread_cap_pips` | 30 | card fixed | Blocks a new bracket only when positive modeled spread is wider. |
| `strategy_skip_monday` | true | card fixed | Suppresses the Monday 07:00 setup. |
| `strategy_news_window_minutes` | 120 | card fixed | Suppresses the setup for high-impact GBP/JPY news within this distance of 07:00. |

Framework inputs, including `RISK_PERCENT`, `RISK_FIXED`,
`PORTFOLIO_WEIGHT`, news modes, stress seed and Friday close, are documented in
`framework/V5_FRAMEWORK_DESIGN.md`.

## 3. Symbol Universe

**Designed for:**

- `GBPJPY.DWX` — the card is explicitly calibrated to GBPJPY's Asian-session
  consolidation and London-session volatility signature.

**Explicitly NOT for:**

- All other `.DWX` symbols — the card declares a GBPJPY-only baseline and does
  not authorize portability.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |
| Session clock | broker time, 22:00–07:00 measurement and 17:00 close |

## 5. Expected Behaviour

The card frontmatter supplies the annual trade count and expected drawdown but
does not define separate frequency, hold-time or regime keys. Those missing
items are stated below from the mechanical schedule rather than invented as
new performance claims.

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 140 |
| Expected trade frequency | approximately 2.7 trades per week, derived from 140 per year |
| Typical hold time | intraday; no position may remain after 17:00, so at most about 10 hours |
| Expected drawdown profile | approximately 18% (`expected_dd_pct` in card frontmatter) |
| Regime preference | Asian compression followed by London volatility expansion / breakout |
| Win rate target (qualitative) | not specified by the approved card |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`  
**Source type:** institutional PDF  
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\### Forex to read\RoboForex - Forex trading strategies.pdf`  
**Lineage:** R1 lineage recorded and R2–R4 PASS per
`artifacts/cards_approved/QM5_11364_robo-gbpjpy-night-range.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). This card's declared full-live value is 0.5%.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-31 | Initial build from card | ff7f7553-54d5-4418-aed2-0ad3adce5727 |
