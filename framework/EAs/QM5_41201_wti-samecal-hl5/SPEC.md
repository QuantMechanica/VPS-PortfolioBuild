# QM5_41201_wti-samecal-hl5 - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 VALIDATION PENDING`

## Identity

**EA ID:** QM5_41201

- EA ID: `QM5_41201`
- slug: `wti-samecal-hl5`
- strategy ID: `KELOHARJU-HL-WTI-SAMECAL5-2026_S01`
- source ID: `KELOHARJU-HL-WTI-SAMECAL5-2026`
- source packet:
  `strategy-seeds/sources/KELOHARJU-HL-WTI-SAMECAL5-2026/source.md`
- source approval:
  `decisions/2026-08-29_wti_same_calendar_hodges_lehmann5_source_approval.md`
- approved card:
  `strategy-seeds/cards/approved/QM5_41201_wti-samecal-hl5_card.md`
- G0 decision:
  `decisions/2026-08-29_qm5_41201_wti_same_calendar_hodges_lehmann5_g0.md`
- host/traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- deterministic magic: `412010000`

## 1. Strategy Logic

At the first genuine normalized D1 broker-month boundary in `(Y,M)`, load the
completed WTI return for calendar month `M` in every exact year `Y-1..Y-5`.
Create `(r[i]+r[j])/2` for all `i<=j`, require exactly fifteen finite values,
sort them, and follow the sign of zero-based index `7` until the next month.

Persist `yyyymm` before every fallible gate. A failure consumes the month.
No current-month price enters the signal, no missing historical year is
substituted, and no alternate estimator is a fallback.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_years` | 5 | exact historical years |
| `strategy_required_observations` | 5 | exact raw-return count |
| `strategy_required_pair_averages` | 15 | exact inclusive-pair count |
| `strategy_signal_epsilon` | 1e-12 | inclusive flat band |
| `strategy_history_bars_d1` | 3000 | bounded endpoint scan |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen stop distance |
| `strategy_max_hold_days` | 35 | survivor repair |
| `strategy_max_spread_points` | 1500 | entry cost ceiling |

Q02 has one baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`.
- Symbol slot: `0`; deterministic magic: `412010000`.
- One direct WTI leg only; no hedge, companion, conversion, or external feed.

## 4. Timeframe

Execution and structural clock are D1. Entry is at most once per broker month.
Formation uses five disjoint observations of the upcoming calendar month in
the exact prior five years. Ordinary exit is the next broker-month boundary.

## 5. Expected Behaviour

The pre-result cadence prior is roughly ten to twelve completed positions per
full post-warm-up year. An invalid label convention, missing year, risk
failure, cost gate, or rejected submission may consume a month flat. Q02
retires below five completed positions in any full scored year. Q09 alone may
establish realized correlation with the current book.

### Duplicate Boundary

Canonical preallocation dedup scanned 4,700 identities, 1,346 cards, and 45
Strategy Wiki nodes. Expected same-calendar fuzzy neighbors were manually
resolved. The raw mean, median, hit-rate, signed-rank, middle-three trim,
contiguous-return pseudomedian, and completed-month daily pseudomedian all use
different information or estimator functions. Fixed vectors in the approved
card prove opposite direction decisions. Receipt:
`artifacts/qm5_wti_samecal_hl5_preallocation_dedup_20260829.json`.

## 6. Source Citation

Keloharju, Linnainmaa, and Nyberg (2016), *Journal of Finance* 71(4),
1557-1590, supply the same-calendar return object, crude-oil membership, and
five-year floor. The governed Moskowitz, Ooi, and Pedersen (2012), *Journal
of Financial Economics* 104(2), 228-250, extraction supplies WTI own-return
lineage and inclusive-pair arithmetic. The exact conjunction is a transparent
QM translation; no source performance or decorrelation result transfers.

## 7. Risk Model

The sole backtest preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A valid position receives one frozen
`3.5*ATR(20,D1)` hard stop and no target. Both news axes, legacy news, and
framework Friday close are OFF.

The EA owns at most one position. It closes malformed, duplicate, wrong-side,
missing-stop, cross-month, or 35-day stale exposure. No scale-in, grid,
martingale, hedge, pyramid, trail, break-even, partial exit, target, or
reversal is authorized.

## Framework Alignment

| Card rule | Implementation |
|---|---|
| exact host, identity, fixed risk, news/Friday modes, locked inputs | `Strategy_NoTradeFilter` |
| uniform label normalization and genuine month boundary | decision-clock helpers |
| exact historical endpoints | completed-month helper |
| fifteen inclusive pairs and central index | signal helpers |
| durable consumed month and history recovery | attempt helpers and `Strategy_PrepareDecisionSignal` |
| strict sign, spread, quote, completed ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, later-month, and stale repair | `Strategy_ManageOpenPosition` and lifecycle helper |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| native order, sizing, kill switch, and telemetry | V5 framework wiring |

## Validation Contract

Q01 must pass independent calendar, exact-year, pair-enumeration, central-
index, fixed-vector, attempt, and lifecycle fixtures; approved-card schema
lint; registry/resolver checks; symbol scope; spec validation; strict compile
with zero errors and warnings; setfile validation; and static build checks.

Zero trades, fewer than five completed positions in any full scored year,
nonpositive governed economics, label or endpoint drift, missing year, wrong
pair count or side, retry, missing stop, late exit, nondeterminism, or fixed-
risk drift retires rather than tunes this identity.

## Safety Boundary

This is a non-live branch build. It creates no live/demo/shadow/stress preset,
deployment manifest, execution-contract registry row, portfolio-gate change,
portfolio admission, or promotion entitlement. Agents never toggle
AutoTrading.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-29 | G0-approved WTI same-calendar Hodges-Lehmann build |
