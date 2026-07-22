# QM5_20044_gap-hilo-fade — Strategy Spec

**EA ID:** QM5_20044
**Slug:** `gap-hilo-fade`
**Source:** `SANCHES-COSTA-2008-GAPHILO`
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

The EA measures the 09:30 New York cash open against the prior normal session's
16:00 close and arms only when that gap is between 0.25 and 1.25 times the
session-anchored Wilder ATR(20). It fades the gap at the next M30 open after the
first opposite HiLo(10) close that is within 0.10 ATR(14) of the running session
extreme, using the signal-bar extreme plus 0.25 ATR as an immutable stop and the
prior cash close as target. The trade must satisfy the frozen stop-distance,
1.25R target, governed-cost, and broker-volume gates, and any survivor is closed
at the first tradable quote at or after 15:55 New York time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_variant_id` | `GAP_HILO_FADE_BASELINE` | fixed | Frozen card variant identity. |
| `strategy_signal_tf` | `PERIOD_M30` | fixed | Session-aligned signal and execution timeframe. |
| `strategy_d1_atr_period` | `20` | fixed | Wilder period for session-anchored daily true range. |
| `strategy_gap_atr_min` | `0.25` | fixed | Inclusive minimum absolute gap divided by D1 ATR. |
| `strategy_gap_atr_max` | `1.25` | fixed | Inclusive maximum absolute gap divided by D1 ATR. |
| `strategy_hilo_period` | `10` | fixed | Prior completed cash M30 highs/lows averaged before each candidate. |
| `strategy_m30_atr_period` | `14` | fixed | Wilder ATR frozen through the qualifying signal bar. |
| `strategy_extreme_atr_tolerance` | `0.10` | fixed | Maximum signal close distance from the running session extreme. |
| `strategy_stop_atr_offset` | `0.25` | fixed | ATR offset beyond the signal-bar high or low. |
| `strategy_stop_atr_min` | `0.75` | fixed | Inclusive minimum fill-to-stop distance in ATR units. |
| `strategy_stop_atr_max` | `1.50` | fixed | Inclusive maximum fill-to-stop distance in ATR units. |
| `strategy_min_reward_r` | `1.25` | fixed | Minimum favorable target distance divided by stop distance. |
| `strategy_max_cost_r` | `0.10` | fixed | Maximum governed commission plus current spread as initial-risk fraction. |
| `strategy_round_turn_commission_usd_per_lot` | `0.0` | governed positive value | Per-symbol round-turn commission; zero fails closed. |
| `strategy_cash_calendar_file` | `QM5_20044_us_cash_calendar.csv` | governed FILE_COMMON artifact | Provenance-locked US cash-session calendar. |
| `strategy_cash_calendar_sha256` | empty | exact 64-hex digest | Whole-file calendar identity; empty fails closed. |
| `strategy_calendar_valid_through` | `2025.12.31` | fixed | Required calendar coverage boundary. |
| `strategy_tzdb_version` | empty | governed non-empty identity | Pinned IANA timezone database identity; empty fails closed. |
| `strategy_expected_tick_feed_server` | empty | governed exact server identity | Binds real ticks to the approved feed; empty fails closed. |

---

## 3. Symbol Universe

**Designed for:**

- `SP500.DWX` — canonical S&P 500 custom symbol requested by the card; build and backtest under the stated handoff boundary.
- `WS30.DWX` — portable US cash-index CFD requested by the card.

**Explicitly NOT for:**

- Broker-midnight D1 constructions — the gap and daily ATR are anchored only to complete 09:30–16:00 New York cash sessions.
- Non-US-session symbols — the transfer thesis depends on the governed US cash open and close.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | Custom session-anchored D1 OHLC and Wilder ATR(20), derived from completed cash-session M30 bars |
| Bar gating | Single `QM_IsNewBar()` consumption; candidate state advances before the entry-only news gate. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 85 queue-ordering-prior trades; unverified until DEV |
| Typical hold time | Intraday; next-bar entry no later than 12:30 ET and mandatory close by 15:55 ET |
| Expected drawdown profile | Card prior 15%; both symbols form one correlated gap-fade family |
| Regime preference | Mean reversion after a bounded prior-close-to-cash-open gap and opposite HiLo confirmation |
| Win rate target (qualitative) | Not specified; source performance claims are explicitly unverified |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `SANCHES-COSTA-2008-GAPHILO`
**Source type:** strategy-document mirror, quality tier C
**Pointer:** `https://pt.scribd.com/doc/164360203/Estrategia-Gap-HiLo-Indice-V1-0`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_20044_gap-hilo-fade.md`

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
| v1 | 2026-07-22 | Initial build from card | 0e4d6565-17ef-4321-8608-ed6396819e13 |
