# QM5_20045_london-box — Strategy Spec

**EA ID:** QM5_20045
**Slug:** london-box
**Source:** FF-MER071898-2010-LONBRK
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

At the first M15 bar after 06:00 UTC, the EA freezes the high and low of the
exact twelve complete bars from 03:00 through 05:45 UTC. If that box is no
wider than 40 logical pips and its UTC date is Monday through Friday, it places
equal-volume buy-stop and sell-stop orders one minimum tick beyond 27%
extensions of the box; the first fill cancels the opposite order. The UTC date
comes from broker-clock conversion and requires all twelve valid M15 bars; no
external trading-day ledger is used. The hard stop stays at the opposite box
boundary, the target is one box from the actual fill, unfilled orders expire
at 12:00 Europe/London, and any surviving position closes at 16:00
Europe/London.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_variant_id | LONDON_BOX_027_BASELINE | frozen | Card variant identity |
| strategy_timeframe | PERIOD_M15 | frozen | Box and entry timeframe |
| strategy_box_start_hour_utc | 3 | frozen | Inclusive fixed-UTC box start |
| strategy_box_end_hour_utc | 6 | frozen | Exclusive fixed-UTC box end |
| strategy_extension_fraction | 0.27 | frozen | Entry extension as a box fraction |
| strategy_max_box_pips | 40.0 | frozen | Maximum eligible box width |
| strategy_pip_size | 0.0001 | frozen | Logical pip in quote units |
| strategy_pending_expiry_hour_london | 12 | frozen | OCO expiry in Europe/London |
| strategy_flat_hour_london | 16 | frozen | Mandatory same-day flat time |
| strategy_max_cost_r | 0.10 | frozen | Maximum round-trip cost divided by initial risk |
| strategy_target_cost_multiple | 4.0 | frozen | Minimum target value relative to cost |
| strategy_round_turn_commission_account_per_lot | 0.0 | governed setfile value >0 | Round-turn account-currency commission per lot; zero fails closed |
| strategy_commission_source_id | empty | governed non-empty ID | Commission provenance identity |
| strategy_commission_source_sha256 | empty | 64 hex characters | Commission provenance digest |
| strategy_expected_tick_feed_server | empty | governed server identity | Expected real-tick feed route |
| strategy_tick_history_sha256 | empty | 64 hex characters | Per-symbol tick-history provenance digest |
| strategy_dataset_valid_through | 2025.12.31 | frozen | Required dataset coverage |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in framework/V5_FRAMEWORK_DESIGN.md and are not repeated
> here.

---

## 3. Symbol Universe

**Designed for:**

- GBPUSD.DWX — the source strategy is a liquid London-session sterling breakout.
- EURGBP.DWX — the approved card explicitly ports the same fixed-UTC box geometry to this liquid sterling cross.

**Explicitly NOT for:**

- Other .DWX instruments — their pip geometry and source-defined London-box transfer were not approved by this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 160 queue-ordering prior (untested) |
| Trade frequency | About 3.1 trades per week per symbol before validation |
| Typical hold time | Intraday; no later than the 16:00 Europe/London forced exit |
| Expected drawdown profile | Approximately 14% card prior; unverified until DEV/OOS |
| Regime preference | Volatility-expansion breakout |
| Win rate target (qualitative) | Unverified; the source claim is not an accepted prior |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** FF-MER071898-2010-LONBRK  
**Source type:** forum  
**Pointer:** ForexFactory thread 230640, first post and author clarifications; rendered card at D:/QM/strategy_farm/artifacts/cards_approved/QM5_20045_london-box_card.md  
**R1–R4 verdict (Q00):** all PASS per artifacts/cards_approved/QM5_20045_london-box.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by QM_FrameworkInit (EA_INPUT_RISK_MODE_MISMATCH).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-22 | Initial build from card | 52536807-e3b8-40ef-9e68-1b41e79623ba |
| v2 | 2026-07-22 | FTMO density prototype | Replaced the unprovisioned trading-day ledger with broker-clock UTC weekday and valid-bar eligibility. |
