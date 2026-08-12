# QM5_20068_pricebob-bounded-fixedr-intraday-ws30 — Strategy Spec

**EA ID:** QM5_20068
**Slug:** `pricebob-bounded-fixedr-intraday-ws30`
**Source:** `68eff294-e3b2-5010-82d8-e9dd5f4130e6`
**Author of this spec:** Codex
**Last revised:** 2026-07-31

---

## 1. Strategy Logic

On each closed M15 bar during the Dow cash session, the EA compares that bar's close with the high and low of the preceding six bars. It buys when the close is above that range or sells when the close is below it, provided the range is between 0.3 and 2.5 times D1 ATR(14), the spread is no more than 15% of the range, no position is already open, and the same direction has fewer than three session entries. The opposite range edge is the stop, the take-profit is fixed at 2R, and any unresolved position closes at the end of the New York cash session; no break-even or trailing logic is used.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_bars` | 6 | ≥2; P3-controlled | Number of completed M15 bars preceding the trigger bar that define the rolling high/low. |
| `strategy_max_entries_per_direction` | 3 | 2/3/4/5 per card | Hard maximum executed entries in each direction between consecutive New York cash-session opens. |
| `strategy_reward_risk` | 2.0 | fixed baseline | Take-profit distance as a multiple of the entry-to-stop distance. |
| `strategy_daily_atr_period` | 14 | fixed baseline | D1 ATR period used by the range-width sanity filter. |
| `strategy_min_range_atr` | 0.3 | fixed baseline | Minimum rolling-range width as a fraction of D1 ATR. |
| `strategy_max_range_atr` | 2.5 | fixed baseline | Maximum rolling-range width as a multiple of D1 ATR. |
| `strategy_max_spread_range_fraction` | 0.15 | fixed baseline | Maximum positive spread as a fraction of the rolling range; zero modeled spread remains valid. |
| `strategy_session_open_hour_ny` | 9 | fixed baseline | New York cash-session opening hour. |
| `strategy_session_open_minute_ny` | 30 | fixed baseline | New York cash-session opening minute. |
| `strategy_session_close_hour_ny` | 16 | fixed baseline | New York cash-session closing hour and time-stop boundary. |
| `strategy_session_close_minute_ny` | 0 | fixed baseline | New York cash-session closing minute. |

## 3. Symbol Universe

**Designed for:**

- `WS30.DWX` — the approved R3 instrument and a liquid, live-tradable Dow 30 CFD with a defined New York cash-session volatility window.

**Explicitly NOT for:**

- Other symbols — the approved card and its R3 PASS row authorize only `WS30.DWX`; no basket expansion was inferred.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `D1` ATR(14), closed shift 1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Expected trade frequency | Approximately one entry per trading session on average, with a hard cap of three entries per direction per session. |
| Typical hold time | Intraday only; at most the 6.5-hour New York cash session. |
| Expected drawdown profile | Approximately 18.0% per the approved-card frontmatter, with losses concentrated in false range breaks. |
| Regime preference | Cash-session breakout and volatility expansion. |
| Win rate target (qualitative) | Low to medium, paired with a fixed 2R payoff. |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `68eff294-e3b2-5010-82d8-e9dd5f4130e6`
**Source type:** forum
**Pointer:** Forex Factory, “The PriceBob Strategy,” `https://www.forexfactory.com/thread/1331012-the-pricebob-strategy`; approved card at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_20068_pricebob-bounded-fixedr-intraday-ws30.md`.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_20068_pricebob-bounded-fixedr-intraday-ws30.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-31 | Initial build from card | 7c6567cf-2628-428a-8aec-388b335c0b79 |
