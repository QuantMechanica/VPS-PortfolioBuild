# QM5_20041_postclose-cont — Strategy Spec

**EA ID:** QM5_20041
**Slug:** `postclose-cont`
**Source:** CHIU-ET-AL-2024
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

Using a hash-pinned exchange and broker schedule, the EA freezes the first
executable midquote at the official cash open and the last executable midquote
at the official close. After exactly one complete post-close M15 observation
bar, it follows the normalized cash-session sign at the first quote of the next
M15 bar. The immutable hard stop is one Wilder ATR(14); there is no target, and
the trade exits at the earlier of 240 minutes or 15 minutes before the next
verified break/rollover, provided the whole interval is financing-safe and
remains on the same local trading day.

The paper establishes a return-continuity relationship in Taiwan index futures.
The European CFD routes, sign-only rule, delay, stop, friction gate, and holding
horizon are explicit QM interpretations rather than source backtest results.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_variant_id` | `POSTCLOSE_CONT_BASELINE` | locked | Approved variant identity. |
| `strategy_signal_tf` | `PERIOD_M15` | locked | Observation and entry timeframe. |
| `strategy_atr_period` | 14 | locked | Wilder ATR window frozen through the observation bar. |
| `strategy_atr_stop_mult` | 1.0 | locked | Immutable hard-stop distance in ATR units. |
| `strategy_hold_minutes` | 240 | locked | Maximum scheduled holding interval. |
| `strategy_safety_buffer_minutes` | 15 | locked | Exit lead before the next verified break/rollover. |
| `strategy_min_stop_to_friction` | 4.0 | locked | Minimum stop distance relative to modeled round-trip friction. |
| `strategy_max_cost_r` | 0.10 | locked | Maximum commission plus entry spread relative to initial risk. |
| `strategy_round_turn_commission_usd_per_lot` | 0.0 | governed value required | Per-symbol commission; zero fails closed. |
| `strategy_schedule_file` | `QM5_20041_exchange_financing_schedule.csv` | immutable file | Common-Files exchange, break, rollover, financing, and local-day schedule. |
| `strategy_schedule_sha256` | empty | SHA-256 | Required exact schedule-file hash. |
| `strategy_schedule_version` | empty | governed value required | Authoritative broker/exchange schedule version. |
| `strategy_calendar_valid_through` | `2025.12.31` | locked | Required schedule coverage. |
| `strategy_tzdb_version` | empty | governed value required | Pinned Xetra/LSE IANA timezone-data identity. |

## 3. Symbol Universe

**Designed for:**

- `GDAXI.DWX` — primary card route tied to the official Xetra cash session.
- `UK100.DWX` — card-authorized sibling tied to the official LSE cash session.

**Explicitly NOT for:**

- Other `.DWX` symbols — no other venue calendar and financing schedule is
  approved by this card.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none; cash anchors use synchronized executable ticks |
| Bar gating | one `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` edge consumes the sole post-close observation before entry gating |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 240 session opportunities before news, data, financing, and friction gates |
| Typical hold time | up to 240 minutes, shortened by the verified pre-break/rollover safety exit |
| Expected drawdown profile | approximately 12% card prior; GDAXI and UK100 form one correlated European index family |
| Regime preference | regular-to-after-hours directional continuation |
| Win rate target (qualitative) | unverified for the European CFD port; must remain positive after governed costs |

## 6. Source Citation

This card was mechanised from:

**Source ID:** CHIU-ET-AL-2024
**Source type:** peer-reviewed academic paper
**Pointer:** Chiu, Chang, Hsiao and Chiou (2024), *PLOS ONE* 19(3):e0299207,
DOI 10.1371/journal.pone.0299207; implementation card at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_20041_postclose-cont_card.md`.
**R1–R4 verdict (Q00):** all PASS per
`artifacts/cards_approved/QM5_20041_postclose-cont.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).
The approved baseline authorizes fixed-risk testing only; live sizing remains a
later governed promotion decision.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-22 | Initial build from card | 970c522b-abac-41eb-9096-4b0bba645ea8 |
