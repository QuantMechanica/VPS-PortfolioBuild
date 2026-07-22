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
distance; any survivor is closed at the first tradable quote at or after 16:00
New York time. Session eligibility is bound to the provenance-locked NYSE Group
US cash-equity exception calendar for 2018-01-01 through 2025-12-31. Full
closures and 13:00 ET early closes are ineligible, and dates outside calendar
coverage fail closed. The prior profile uses the immediately preceding normal
session; missing or misaligned bars on that session fail closed instead of
falling back to an older normal day. Each raw M30 low and high is quantized with
`MathRound(price / SYMBOL_TRADE_TICK_SIZE)` onto the symbol's declared tick
grid before TPO rows are built; sub-tick precision in the real-tick feed is not
itself a missing-bar defect. Tester Groups applies venue commission to fills,
while the EA retains an optional native spread-points guard.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_variant_id` | `TPO_VA80_ROT_BASELINE` | fixed | Frozen card variant identity. |
| `strategy_signal_tf` | `PERIOD_M30` | fixed | Builds the profile and acceptance sequence from M30 bars. |
| `strategy_value_area_fraction` | `0.70` | fixed | Required fraction of prior-session TPO counts in value. |
| `strategy_min_reward_r` | `1.50` | fixed | Minimum target distance divided by stop distance; equality qualifies. |
| `strategy_cash_open_hour_new_york` / `strategy_cash_open_minute_new_york` | `09:30` | fixed | Regular-session open converted through the broker clock. |
| `strategy_cash_close_hour_new_york` / `strategy_cash_close_minute_new_york` | `16:00` | fixed | Regular-session close converted through the broker clock. |
| `strategy_max_spread_points` | `0` | non-negative | Optional native spread guard; zero disables it. |
| `strategy_cash_calendar_file` | `QM5_NYSE_US_cash_session_exceptions_20180101_20251231.csv` | fixed | Canonical runtime basename provisioned to MT5 `Common\\Files`. |
| `strategy_cash_calendar_sha256` | `c2e87e2f…fd11` | fixed | Whole-file SHA-256 binding for the canonical runtime calendar. |

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
| v2 | 2026-07-22 | Density gate removal | Replaced the unprovisioned cash-calendar/feed/cost gates with fixed broker-clock session eligibility and tester-applied venue costs. |
| v3 | 2026-07-22 | Governed cash-calendar repair | Bound session eligibility to the shared ICE/NYSE-provenance calendar, excluded full/early closures, enforced coverage fail-closed, and removed older-normal-day profile fallback. |
| v4 | 2026-07-22 | Declared tick-grid quantization | Kept nearest-tick `MathRound` quantization while removing the invalid requirement that raw real-tick-derived M30 extrema already equal the declared tick grid exactly. All 13-bar, timestamp, OHLC, calendar, and prior-normal-session fail-closed gates remain unchanged. |
