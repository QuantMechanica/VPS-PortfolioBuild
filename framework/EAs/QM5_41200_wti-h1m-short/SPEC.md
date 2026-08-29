# QM5_41200_wti-h1m-short - Strategy Spec

Status: `G0 APPROVED; IMPLEMENTED; Q01 VALIDATION PENDING`

## Identity

**EA ID:** QM5_41200

- EA ID: `QM5_41200`
- slug: `wti-h1m-short`
- strategy ID: `BOROWSKI-WTI-H1M-2026_S01`
- source ID: `BOROWSKI-WTI-H1M-2026`
- source packet:
  `strategy-seeds/sources/BOROWSKI-WTI-H1M-2026/source.md`
- source approval:
  `decisions/2026-08-29_wti_first_half_month_short_source_approval.md`
- lifecycle amendment:
  `decisions/2026-08-29_wti_first_half_month_short_source_approval_amendment_1.md`
- approved card:
  `strategy-seeds/cards/approved/QM5_41200_wti-h1m-short_card.md`
- G0 decision:
  `decisions/2026-08-29_qm5_41200_wti_first_half_month_short_g0.md`
- host/traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- deterministic magic: `412000000`

## 1. Strategy Logic

At the first genuine normalized D1 broker-month boundary, sell one
`XTIUSD.DWX` position. Accept only the native bar date or one uniform
`+1`-calendar-day energy-label offset, require the normalized opening session
to be day 5 or earlier, and require attachment within 180 minutes of its open.

Persist the broker `yyyymm` attempt before spread, quote, ATR, sizing, margin,
news, or submission gates. A failure consumes the month. Close on the first
later normalized D1 bar dated day 16 or later; a close failure retries every
tick. The signal has no price, trend, return, inventory, event, curve, volume,
or external-data input.

## 2. Parameters

| Input | Locked value | Role |
|---|---:|---|
| `strategy_exit_calendar_day` | 16 | first ordinary exit day |
| `strategy_entry_latest_day` | 5 | latest admissible opening session |
| `strategy_boundary_attach_max_minutes` | 180 | boundary attachment ceiling |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 2.75 | frozen hard-stop distance |
| `strategy_max_hold_days` | 20 | survivor repair |
| `strategy_max_spread_points` | 2500 | entry cost ceiling |

Q02 has one baseline and no optimization surface.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`.
- Symbol slot: `0`; deterministic magic: `412000000`.
- One direct WTI leg only; no hedge, companion, conversion, or external feed.

## 4. Timeframe

Execution and structural clock are D1. Entry is at most once per broker month.
The ordinary holding interval begins at the normalized opening session and
ends at the first subsequent D1 session whose normalized calendar day is at
least 16.

## 5. Expected Behaviour

The pre-result cadence prior is roughly ten to twelve completed positions per
full year. An invalid label convention, late attach, risk failure, cost gate,
or rejected submission may consume a month flat. Q02 retires below five
completed positions in any full scored year. Q09 alone may establish realized
correlation with the current book.

### Duplicate Boundary

Canonical preallocation dedup scanned 4,699 EA identities, 1,345 cards, and
45 Strategy Wiki nodes. The expected source-family neighbors were manually
resolved:

- `QM5_20021_wti-h2m-short` owns the complementary day-16-to-next-month
  interval;
- `QM5_20028_wti-dom1-long` buys one actual day-1 session; and
- `QM5_20027_wti-dom26-short` shorts one later session.

This identity sells the complete first half from the first genuine opening
session through the first later session day 16 or beyond. Receipt:
`artifacts/qm5_wti_h1m_short_preallocation_dedup_20260829.json`.

## 6. Source Citation

Borowski (2016), “Analysis of Selected Seasonality Effects in Markets of
Future Contracts with the Following Underlying Instruments: Crude Oil, Brent
Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle, Live Cattle, Lean Hogs
and Lumber,” *Journal of Management and Financial Sciences*, issue 26,
27-44, supplies the negative WTI days-1-through-15 return sign and half-month
partition. The governed translation is
`strategy-seeds/sources/BOROWSKI-WTI-H1M-2026/source.md`.

The reported half-to-half difference is nonsignificant. No source economics,
cost, density, futures/CFD equivalence, or portfolio result transfers.

## 7. Risk Model

The sole backtest preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A valid short receives one frozen
`2.75*ATR(20,D1)` hard stop and no target. Both news axes, legacy news, and
framework Friday close are OFF.

The EA owns at most one position. It closes malformed, duplicate, non-SELL,
missing-stop, cross-month survivor, ordinary day-16, or 20-day stale exposure.
No scale-in, grid, martingale, hedge, pyramid, trail, break-even, partial exit,
target, or reversal is authorized.

## Framework Alignment

| Card rule | Implementation |
|---|---|
| exact host, identity, fixed risk, news/Friday modes, locked inputs | `Strategy_NoTradeFilter` |
| uniform label normalization and genuine month boundary | decision-clock helpers |
| durable consumed month and history recovery | attempt helpers and `Strategy_PrepareDecisionSignal` |
| SELL side, spread, quote, completed ATR, frozen stop | `Strategy_EntrySignal` |
| malformed, day-16, later-month, and stale repair | `Strategy_ManageOpenPosition` and lifecycle helper |
| no discretionary signal exit | `Strategy_ExitSignal` returns false |
| native order, sizing, kill switch, and telemetry | V5 framework wiring |

## Validation Contract

Q01 must pass the independent calendar/lifecycle fixtures, approved-card
schema lint, registry/resolver checks, symbol scope, spec validation, strict
compile with zero errors and warnings, setfile validation, and static build
checks. Q02 alone may measure density and economics; Q09 alone may establish
realized portfolio correlation.

Zero trades, fewer than five completed positions in any full scored year,
nonpositive governed economics, label or boundary drift, attachment after the
ceiling, wrong side, retry, missing stop, Friday truncation, late exit,
nondeterminism, or fixed-risk drift retires rather than tunes this identity.

## Safety Boundary

This is a non-live branch build. It creates no live/demo/shadow/stress preset,
deployment manifest, execution-contract registry row, portfolio-gate change,
portfolio admission, or promotion entitlement. Agents never toggle
AutoTrading.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-29 | G0-approved WTI first-half-of-month structural short build |
