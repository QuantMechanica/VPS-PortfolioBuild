# QM5_12792_gold-asian-drift - Strategy Spec

**EA ID:** QM5_12792
**Slug:** gold-asian-drift
**Source:** gold-asian-drift-inhouse-2026-06-29
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

This EA trades XAUUSD Asian-session continuation. At the configured broker-time decision bar, it measures the closed-bar move from the Asian session open to the decision point and compares the absolute move with ATR(14). If the move is at least `strategy_drift_min_atr` ATR, it enters in the drift direction, places a hard ATR stop, sets an RR take-profit, and exits any remaining position when the Asian session ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_start_hour_broker` | 0 | 0-23 | Broker-time hour for Asian session start. |
| `strategy_session_start_minute_broker` | 0 | 0-59 | Broker-time minute for Asian session start. |
| `strategy_entry_hour_broker` | 2 | 0-23 | Broker-time hour of the once-per-session drift decision bar. |
| `strategy_entry_minute_broker` | 0 | 0-59 | Broker-time minute of the once-per-session drift decision bar. |
| `strategy_session_end_hour_broker` | 8 | 0-23 | Broker-time hour when open positions are force-flat. |
| `strategy_session_end_minute_broker` | 0 | 0-59 | Broker-time minute when open positions are force-flat. |
| `strategy_atr_period` | 14 | >=1 | ATR period on the chart timeframe. |
| `strategy_drift_min_atr` | 0.20 | >0 | Minimum session-open drift in ATR units required to enter. |
| `strategy_atr_sl_mult` | 1.50 | >0 | ATR multiple for the hard stop loss. |
| `strategy_take_rr` | 1.75 | >0 | Take-profit as an R multiple of the stop distance. |
| `strategy_max_spread_points` | 250 | >=0 | Maximum modeled spread in points for new entries; zero spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - The card's R3 PASS row names XAUUSD.DWX M15/M30 history and the strategy is gold-specific.

**Explicitly NOT for:**
- `XAGUSD.DWX` - The card mentions silver only as optional partial read-across; it is not listed in R3 PASS for this build.
- Non-metal FX, index, and energy symbols - The edge is defined as gold Asian-session physical-demand drift, not a generic cross-asset rule.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` and `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | From the 02:00 broker decision bar until TP, SL, or 08:00 broker session exit. |
| Expected drawdown profile | About 10% expected DD from the card frontmatter. |
| Regime preference | Intraday momentum / Asian-session drift continuation; expected PF 1.35 from the card frontmatter. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** gold-asian-drift-inhouse-2026-06-29
**Source type:** in-house research / OWNER-directed build
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12792_gold-asian-drift.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12792_gold-asian-drift.md`

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
| v1 | 2026-06-30 | Initial build from card | 9c2efff5-0fc2-4f45-9b76-dc5d45cbf2e4 |
