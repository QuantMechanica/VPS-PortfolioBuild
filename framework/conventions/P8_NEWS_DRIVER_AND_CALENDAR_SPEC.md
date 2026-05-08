# P8 News Driver and News Calendar Spec

Created: 2026-05-08
Issue: QUA-911
Owners: CTO + CEO
Scope: V5 pipeline P8 mode-selection and runtime news gating against MT5-native calendar seed data.

## 1. Purpose

Define the executable contract for:
- Offline P8 phase selection of news mode from sweep outputs.
- Runtime EA behavior for news blocking/pausing.
- News calendar data requirements and validation.

This spec binds `framework/scripts/p8_news_impact.py` outputs to EA runtime inputs and deployment packaging.

## 2. Hard-Rule Alignment

- Darwinex MT5 native data only. No external market API calls in P8 or runtime news filters.
- Symbols remain `.DWX` in research/backtest artifacts; suffix stripping is deploy-only.
- Friday Close remains independently enabled by default; news mode does not disable Friday Close.
- No ML scoring/classification in news driver logic.
- Claims must cite generated CSV/JSON artifacts.

## 3. Inputs

## 3.1 P8 Matrix CSV (required)

Minimum columns:
- `symbol`
- `mode`
- `pf`
- `sharpe`
- `drawdown_pct`
- `trades`
- `compliance_5ers`
- `compliance_ftmo`
- `compliance_news_only`
- `compliance_no_news`

`framework/scripts/p8_news_impact.py` normalizes mode aliases and filters to requested modes.

## 3.2 News Calendar Seed (required for runtime enforcement)

Canonical location:
- `seed_assets/news_calendar/`

Required fields per row:
- `event_id` unique identifier.
- `timestamp_utc` ISO-8601 UTC datetime.
- `currency` ISO currency code.
- `impact` one of `low|medium|high`.
- `event_name` non-empty text.

Optional fields:
- `country`, `source`, `revision_of_event_id`.

Validation contract:
- Reject rows with missing required fields.
- Reject rows with non-UTC timestamps.
- Reject duplicate `(timestamp_utc, currency, event_name)` unless explicit revision link exists.

## 4. Supported News Modes

Allowed normalized modes:
- `OFF`
- `PAUSE`
- `SKIP_DAY`
- `FTMO_PAUSE`
- `5ers_PAUSE`
- `no_news`
- `news_only`

Any non-normalized mode is ignored by selector and must fail runtime config validation.

## 5. Selection Logic (P8)

Per symbol:
- Eligible row: `pf >= 1.0` and `trades > 0`.
- Ranking key: `pf desc`, `sharpe desc`, `drawdown_pct asc`.
- Winner: top eligible row mode.
- No eligible row:
  - if `OFF` exists, recommend `OFF`.
  - else verdict `NO_ELIGIBLE_MODE` and manual review required.

Portfolio verdict:
- `MODE_SELECTED` only if all symbols have eligible winners.
- Else `NO_ELIGIBLE_MODE`.

## 6. Runtime EA Contract

EA must expose input enum compatible with normalized modes.

Behavioral contract:
- `OFF`: no news gating.
- `PAUSE`: block new entries around configured window; manage exits allowed.
- `SKIP_DAY`: no new entries for impacted symbol/day; manage exits allowed.
- `FTMO_PAUSE`: enforce FTMO-oriented pause window and impact threshold.
- `5ers_PAUSE`: enforce 5ers-oriented pause window and impact threshold.
- `no_news`: trade only when no relevant event is in active window.
- `news_only`: trade only inside configured event window; outside window block entries.

All runtime decisions must log:
- symbol
- mode
- event_id (if matched)
- decision (`allow_entry|block_entry|manage_only`)
- reason code
- timestamp UTC

## 7. Artifacts and Evidence

P8 selector output directory:
- `artifacts/<ea_id>/P8/`

Required outputs:
- `P8_result.json` (verdict + criterion + details)
- `P8_summary.csv` (symbol/mode decision matrix)

`P8_result.json` must include:
- `recommended_mode_by_symbol`
- compliance aggregate booleans
- flattened matrix rows with symbol attached

Any pass/fail statement in issue comments must cite exact artifact paths.

## 8. Failure Modes

Hard fail and stop phase when:
- Matrix CSV missing required columns.
- No rows remain after mode normalization/filtering.
- Recommended mode not in allowed normalized set.
- Calendar validation fails required-field/timestamp constraints.

Soft fail (manual review required):
- `NO_ELIGIBLE_MODE` for one or more symbols.

## 9. Acceptance Criteria for QUA-911

- Spec file exists at this path and is peer-readable.
- `framework/scripts/p8_news_impact.py` behavior matches Section 5.
- Pipeline documentation references this file as P8 normative contract.
- Evidence paths for at least one P8 run are included in issue close-out comment.
