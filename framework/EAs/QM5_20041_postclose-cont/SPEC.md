# QM5_20041_postclose-cont — Strategy Spec

**EA ID:** QM5_20041
**Slug:** `postclose-cont`
**Source:** CHIU-ET-AL-2024
**Author of this spec:** Codex
**Last revised:** 2026-07-22

---

## 1. Strategy Logic

The EA resolves venue-local cash sessions from separately governed calendars.
`GDAXI.DWX` uses the existing Xetra calendar and Europe/Berlin conversion;
`UK100.DWX` uses the manifest-bound LSE calendar with an 08:00 London open,
16:30 normal close, and 12:30 scheduled early close. Each local boundary is
converted local time → UTC → broker time before tick anchors are sampled. Full
closes, dates outside 2018-2025 coverage, missing files, hash mismatches, and
ambiguous clock conversions fail closed for new entries.

At the official close, the EA freezes the first executable midquote at or after
the official open and the last executable midquote at or before the official
close. After exactly one complete post-close M15 observation bar, it follows
the tick-normalized cash-session sign at the first tradable quote of the next
M15 bar. The immutable hard stop is one Wilder ATR(14); there is no target, and
the currently implemented clock exit is 240 minutes later on the same broker
date. The framework news gate and Friday guard remain active.

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
| `strategy_cash_open_hour_broker` / `strategy_cash_open_minute_broker` | 10:00 | legacy serialization only | Ignored by both routes; retained so existing setfiles remain readable. |
| `strategy_cash_close_hour_broker` / `strategy_cash_close_minute_broker` | 18:30 | legacy serialization only | Ignored by both routes; official venue-local closes come from Xetra/LSE calendars. |
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
| Trades / year / symbol | approximately 240 session opportunities before calendar, news, and valid-tick eligibility; unvalidated prior only |
| Typical hold time | at most the currently bound 240-minute clock exit unless stopped or flattened by framework safety controls |
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

## 8. Calendar Contracts and Remaining Safety Gaps

- The Xetra/GDAXI route remains on its existing independently hash-bound
  calendar and Europe/Berlin → UTC → broker conversion.
- The UK100 route loads
  `QM5_LSE_cash_session_exceptions_20180101_20251231.csv` from MT5 Common Files.
  The shared London loader first verifies the bundle manifest and then the LSE
  runtime file against SHA-256
  `166a391fbb59a49d42a363ff347286139725853cd9f70d30d8cd71a404dd7d8d`.
- An unlisted LSE weekday inside coverage is 08:00-16:30 London. An
  `EARLY_CLOSE` row is 08:00-12:30; a `FULL_CLOSE` row has no cash anchors.
  Weekends and dates outside 2018-01-01 through 2025-12-31 do not resolve to a
  tradable cash session.
- The loader validates London wall-clock labels against both possible UTC
  offsets and rejects ambiguity/nonexistence. A separately versioned IANA
  timezone artifact is still not bundled and remains a provenance gap.
- Authoritative Darwinex symbol-session, daily-break, rollover, and financing
  metadata are still unavailable. Runtime logs
  `STRATEGY_SETUP_COVERAGE_GAP`; no fabricated constant or static
  completeness flag was added as a gate. Therefore the card's required pre-rollover
  safety exit and financing-boundary proof are not yet implemented, and the EA
  remains card-incomplete despite the repaired exchange calendars.
- No build or backtest evidence is attached to this revision. The source paper
  is not evidence that either European CFD route is profitable.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-22 | Initial build from card | 970c522b-abac-41eb-9096-4b0bba645ea8 |
| v2 | 2026-07-22 | Density gate removal | Replaced the unprovisioned schedule/financing/cost gates with fixed broker-clock session eligibility and tester-applied venue costs. |
| v3 | 2026-07-22 | Venue-calendar repair | Preserved the completed Xetra/GDAXI route and replaced UK100's fixed broker-hour fallback with the manifest-bound LSE calendar, including early/full closes and London-local → UTC → broker conversion. |
