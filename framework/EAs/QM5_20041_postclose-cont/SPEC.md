# QM5_20041_postclose-cont — Strategy Spec

**EA ID:** QM5_20041
**Slug:** `postclose-cont`
**Source:** CHIU-ET-AL-2024
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

Using fixed broker-clock session anchors, the EA freezes the first executable
midquote at the 10:00 cash open and the last executable midquote at the 18:30
close. After exactly one complete post-close M15 observation
bar, it follows the normalized cash-session sign at the first quote of the next
M15 bar. The immutable hard stop is one Wilder ATR(14); there is no target, and
the trade exits after 240 minutes on the same broker trading day. UTC-weekday
eligibility, the framework news gate, and the Friday guard provide blackout
protection.

The paper establishes a return-continuity relationship in Taiwan index futures.
The European CFD routes, sign-only rule, delay, stop, and holding
horizon are explicit QM interpretations rather than source backtest results.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_variant_id` | `POSTCLOSE_CONT_BASELINE` | locked | Approved variant identity. |
| `strategy_signal_tf` | `PERIOD_M15` | locked | Observation and entry timeframe. |
| `strategy_atr_period` | 14 | locked | Wilder ATR window frozen through the observation bar. |
| `strategy_atr_stop_mult` | 1.0 | locked | Immutable hard-stop distance in ATR units. |
| `strategy_hold_minutes` | 240 | locked | Maximum scheduled holding interval. |
| `strategy_cash_open_hour_broker` / `strategy_cash_open_minute_broker` | 10:00 | locked | Fixed European cash-session open in broker time. |
| `strategy_cash_close_hour_broker` / `strategy_cash_close_minute_broker` | 18:30 | locked | Fixed European cash-session close and observation anchor in broker time. |
| `strategy_max_spread_points` | 0 | non-negative | Optional native spread guard; zero disables it. |

## 3. Symbol Universe

**Designed for:**

- `GDAXI.DWX` — primary card route tied to the official Xetra cash session.
- `UK100.DWX` — card-authorized sibling tied to the official LSE cash session.

**Explicitly NOT for:**

- Other `.DWX` symbols — no other route is approved by this card.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none; cash anchors use synchronized executable ticks |
| Bar gating | one `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` edge consumes the sole post-close observation before entry gating |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 240 session opportunities before news and valid-tick eligibility |
| Typical hold time | 240 minutes unless stopped or flattened by framework safety controls |
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
| v2 | 2026-07-22 | Density gate removal | Replaced the unprovisioned schedule/financing/cost gates with fixed broker-clock session eligibility and tester-applied venue costs. |
