# QM5_20043_tpo-va80-rot — Strategy Spec

**EA ID:** QM5_20043
**Slug:** `tpo-va80-rot`
**Source:** `FTMO-MARKETPROFILE-80-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

At the 10:30 New York M30 open, the EA trades only when the 09:30 opening print
was strictly outside the prior complete US cash session's 70% TPO value area and
both completed first-hour bars closed back inside it. It buys a below-value
re-entry or sells an above-value re-entry, places an immutable stop one minimum
tick beyond the first-hour extreme, and targets the opposite value-area edge.
The trade is skipped unless the target offers at least 1.5 times the stop
distance and governed costs are at most 0.10R; any survivor is closed at the
first tradable quote at or after 16:00 New York time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_variant_id` | `TPO_VA80_ROT_BASELINE` | fixed | Frozen card variant identity. |
| `strategy_signal_tf` | `PERIOD_M30` | fixed | Builds the profile and acceptance sequence from M30 bars. |
| `strategy_value_area_fraction` | `0.70` | fixed | Required fraction of prior-session TPO counts in value. |
| `strategy_min_reward_r` | `1.50` | fixed | Minimum target distance divided by stop distance; equality qualifies. |
| `strategy_max_cost_r` | `0.10` | fixed | Maximum governed round-turn commission plus current spread as a fraction of initial risk. |
| `strategy_round_turn_commission_usd_per_lot` | `0.0` | governed positive value | Per-symbol round-turn commission; zero fails closed because no value was supplied. |
| `strategy_cash_calendar_file` | `QM5_20043_us_cash_calendar.csv` | governed FILE_COMMON artifact | Provenance-locked US cash-session calendar. |
| `strategy_cash_calendar_sha256` | empty | exact 64-hex digest | Whole-file calendar identity; empty fails closed. |
| `strategy_calendar_valid_through` | `2025.12.31` | fixed | Required calendar coverage boundary from the card. |
| `strategy_tzdb_version` | empty | governed non-empty identity | Pinned IANA timezone database version; empty fails closed. |
| `strategy_expected_tick_feed_server` | empty | governed exact server identity | Binds synchronized real ticks to the approved feed; empty fails closed. |

---

## 3. Symbol Universe

**Designed for:**

- `NDX.DWX` — liquid US cash-index proxy named by the approved card.
- `WS30.DWX` — portable US cash-index proxy named by the approved card.
- `SP500.DWX` — canonical S&P 500 custom symbol named by the card; build and backtest only under the stated handoff boundary.

**Explicitly NOT for:**

- `SPX500.DWX`, `SPY.DWX`, and `ES.DWX` — unavailable aliases; only `SP500.DWX` is canonical.
- Non-US-session symbols — the edge is defined by the governed New York regular trading session.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | Single `QM_IsNewBar()` consumption in the skeleton; the closed-bar state is advanced once before the entry-only news gate. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 authoring-prior trades; unverified until DEV |
| Typical hold time | Intraday, from 10:30 ET entry to target/stop or no later than 16:00 ET (maximum about 5.5 hours) |
| Expected drawdown profile | Card prior 15%; correlated US-index instances form one auction-value risk family |
| Regime preference | Mean reversion after an outside-value cash open accepts back into prior-session value |
| Win rate target (qualitative) | Not specified; the source's “80%” label is explicitly not a probability prior |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `FTMO-MARKETPROFILE-80-2026`
**Source type:** web blog, quality tier D
**Pointer:** `https://ftmo.com/en/blog/market-profile-master-the-80-trading-strategy-hidden-magnets/`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_20043_tpo-va80-rot.md`

---

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
| v1 | 2026-07-22 | Initial build from card | d30d49fe-b535-4b03-972f-030b78d36e7a |
