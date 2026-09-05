# QM5_41348 — XAU/XAG Monthly Redescending-Hampel Reversion

**EA ID:** QM5_41348
**Slug:** `xauxag-mhampel-rv`
**Strategy ID:** `AI-CODEX-XAUXAG-MHAMPEL-RV-20260905_S01`
**Author of this spec:** Codex
**Last revised:** 2026-09-05

The source card of record is `docs/strategy_card.md`; the approved repository
card is
`strategy-seeds/cards/approved/QM5_41348_xauxag-mhampel-rv_card.md`.

## 1. Strategy Logic

On the first synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 bar of each genuine
broker month, the EA reconstructs exactly thirteen consecutive synchronized
completed month-end observations of the gold-minus-silver log ratio. It forms
twelve adjacent chronological ratio returns and estimates their robust center
with an exact 32-step redescending Hampel M-location.

The estimator uses the even median as its initial location, an even raw MAD,
the frozen scale `1.4826 * MAD`, and the piecewise Hampel weights with
`a=2`, `b=4`, and `c=8`. A positive robust center sells XAU and buys XAG; a
negative center buys XAU and sells XAG. Both legs target opposed, approximately
equal notionals, so the trade is a relative-value package rather than an
outright metal-direction position.

The package exits at the next broker month or after forty elapsed calendar
days. Wrong-state repair closes any orphaned or same-side package. Per-leg
broker hard stops remain active throughout the holding period.

## 2. Parameters

| Parameter | Locked Q02 value | Meaning |
|---|---:|---|
| `strategy_monthend_points` | 13 | Consecutive synchronized completed month-end ratios |
| `strategy_ratio_returns` | 12 | Adjacent chronological log-ratio returns |
| `strategy_hampel_a` | 2.0 | Full-weight boundary |
| `strategy_hampel_b` | 4.0 | First redescending boundary |
| `strategy_hampel_c` | 8.0 | Zero-weight boundary |
| `strategy_hampel_steps` | 32 | Exact location-update count |
| `strategy_atr_period_d1` | 20 | D1 ATR period for each hard stop |
| `strategy_atr_sl_mult` | 3.5 | Frozen per-leg ATR stop multiple |
| `strategy_max_hold_days` | 40 | Calendar-day stale-package exit |
| `strategy_entry_grace_minutes` | 180 | First synchronized monthly-bar entry grace |
| `strategy_endpoint_stale_days` | 10 | Maximum accepted month-end endpoint age |
| `strategy_history_bars` | 1200 | Bounded D1 reconstruction history |
| `RISK_FIXED` | 1000 | Aggregate basket risk budget for backtests |
| `RISK_PERCENT` | 0 | Disabled in all backtest setfiles |

All Q02 strategy, risk, news, Friday, stress, symbol, timeframe, and magic
values are fail-closed locked by `OnInit` validation.

## 3. Symbol Universe

- Logical basket: `QM5_41348_XAU_XAG_HAMPEL_RV_D1`.
- Host leg: `XAUUSD.DWX`, slot 0, magic `413480000`.
- Second leg: `XAGUSD.DWX`, slot 1, magic `413480001`.
- Required package state: exactly one XAU position and one oppositely directed
  XAG position, with target notionals within the frozen 20% integrity bound.

## 4. Timeframe

- Host timeframe: D1.
- Signal cadence: once per genuine broker month on the first synchronized host
  and second-leg D1 bar.
- History cadence: synchronized completed broker-month endpoints only.
- Multi-timeframe references: none.

## 5. Expected Behaviour

- Frequency: at most one entry attempt per broker month, with no retry after a
  consumed month; Q02 must establish whether at least five completed logical
  packages occur in every full post-warm-up year.
- Holding period: one broker month at most, additionally capped at 40 calendar
  days.
- Exposure: opposed equal-target-notional XAU/XAG legs; the estimator fades
  persistent relative monthly ratio-return location rather than forecasting
  either metal outright.
- No-trade conditions: incomplete synchronization, stale endpoints, zero MAD,
  a final location within `1e-12` of zero, identity/risk/configuration failure,
  or a failed atomic two-leg open.
- News avoidance, Friday close, and stress mode are disabled for the locked Q02
  baseline.

## 6. Source Citation

- Schweikert, K. (2020), peer-reviewed evidence on the long-run gold-silver
  relationship. Local evidence packet:
  `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`.
- CME Group educational material on the gold/silver ratio as a relative-value
  spread. Local evidence packet:
  `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`.
- Hampel robust redescending M-estimation lineage and the repository's frozen
  mechanical implementation criteria. Local evidence packet:
  `strategy-seeds/sources/KELOHARJU-HAMPEL-MASS-WTI-SAMECAL-HAMPEL5-2026/source.md`.

The exact source hashes and OWNER source-approval record are frozen in the
approved Strategy Card and
`decisions/2026-09-05_xauxag_monthly_hampel_reversion_source_approval.md`.

## 7. Risk Model

| Scope | Risk mode | Value |
|---|---|---:|
| Q02 backtest package | RISK_FIXED | 1000 aggregate |
| Each leg | Equal target notional | 50% of package target |
| Each leg hard stop | ATR(20), D1 | 3.5 ATR |
| Live | Not authorized | — |

All three backtest setfiles require `RISK_FIXED=1000` and `RISK_PERCENT=0`.
The logical basket setfile is the only Q02 enqueue target; component setfiles
exist solely for deterministic basket plumbing. Q09 alone may establish
realized portfolio correlation.

This build authorizes non-live Q01 compilation and one paced logical-basket
Q02 handoff only. It does not authorize a manual backtest, optimization,
portfolio gate/admission change, deploy/live manifest change, `T_Live` access,
AutoTrading change, or live operation.
