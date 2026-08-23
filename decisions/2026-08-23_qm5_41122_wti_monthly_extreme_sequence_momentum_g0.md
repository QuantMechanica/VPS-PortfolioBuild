# QM5_41122 WTI Completed-Month Extreme-Sequence Momentum - G0 Decision

Date: 2026-08-23

Decision: `APPROVED`

Card:
`strategy-seeds/cards/approved/QM5_41122_wti-mextreme-sequence-mom_card.md`

Source approval:
`decisions/2026-08-23_wti_monthly_extreme_sequence_momentum_source_approval.md`

Source packet:
`strategy-seeds/sources/MOP-WTI-MEXTREME-SEQUENCE-MOM-2026/source.md`

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`, requiring one new, reputable-source, structural
low-frequency commodity edge, a `RISK_FIXED` backtest setfile, one Q02
enqueue, no live action, and no portfolio-gate or T_Live-manifest mutation.

## Identity and allocation

- EA ID: `41122`
- slug: `wti-mextreme-sequence-mom`
- strategy ID: `MOP-WTI-MEXTREME-SEQUENCE-MOM-2026_S01`
- source ID: `MOP-WTI-MEXTREME-SEQUENCE-MOM-2026`
- host: exact `XTIUSD.DWX`, D1, slot 0
- planned magic: `411220000`

The governed allocator reserved `41122` in
`framework/registry/ea_id_registry.csv` at commit `1d5d4a383`. Magic
allocation must follow the governed directory-first sequence before
implementation and compile; this decision does not bypass that gate.

## G0 findings

### R1 - Reputable track-record basis

`PASS_WITH_EXTREME_SEQUENCE_TRANSLATION_RISK`.

The bounded source carries Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje
Pedersen (2012), *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, a complete published-paper read, durable PDF
hash, and explicit WTI membership. The paper directly tests a monthly
own-return-sign/next-month-hold commodity specification.

The paper does not test unique monthly high/low sessions, their chronological
order, or agreement with the first-open-to-last-close sign. It does not test a
continuous WTI CFD, fixed-dollar ATR risk, or this portfolio. Those are
explicit pre-result QM translations. No source return, alpha, density, risk,
cost, CFD equivalence, or portfolio-correlation result transfers.

### R2 - Mechanical completeness

`PASS`.

The card locks exact symbol and D1 period; first-new-month timing; a
17-to-23-session immediately completed calendar month; strict timestamps and
OHLC geometry; unique aggregate high and low sessions; their chronological
order; agreeing completed-month body sign; ambiguity and disagreement flat;
consumed monthly attempt; fixed cash risk; a frozen ATR stop; spread cap; no
target; later-month exit; and a forty-day stale repair. There is no
optimization surface or fallback signal.

### R3 - Runtime data availability

`PASS_WITH_CALENDAR_LABEL_AND_CFD_BASIS_RISK`.

Registered native `XTIUSD.DWX` D1 history, MT5 symbol metadata, quotes, ATR,
positions, deals, broker time, and persistent terminal state supply every
runtime input. No futures chain or external dataset is required. Q02 owns
history sufficiency, holiday attrition, density, costs, fills, financing, and
continuous-CFD basis risk.

### R4 - Prohibited-mechanic ban

`PASS`.

The mechanic uses completed timestamps and OHLC, equality and integer index
comparisons, ATR risk distance, quotes, positions, deal history, and terminal
global state. It contains no trained or adaptive output, prohibited signal,
external runtime feed, grid, martingale, pyramid, scale-in, or result-driven
parameter change.

## Non-duplicate finding

The pre-allocation fail-closed checker scanned 4,621 registry identities,
1,290 cards, and 45 Strategy Wiki nodes and returned `CLEAN`:
`artifacts/qm5_wti_mextreme_sequence_mom_preallocation_dedup_20260823.json`.

After reservation, the same checker scanned 4,622 registry identities and
found only the expected exact slug and strategy-ID self-hits for reserved
`QM5_41122`:
`artifacts/qm5_41122_wti_mextreme_sequence_mom_postallocation_dedup_20260823.json`.

Manual review separates the weekly extreme-sequence carrier (`QM5_41098`),
monthly close-location and body-magnitude carriers (`QM5_41105`, `QM5_41106`),
parent-month range comparisons (`QM5_41107`, `QM5_41108`), daily-sign/block
aggregators (`QM5_41111`, `QM5_41114`, `QM5_41115`, `QM5_41117`), pure
one-month return-sign momentum, and the certified XNG oscillator pullback.
This card requires the exact completed calendar month's unique high/low
session order and matching body sign. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_EXTREME_SEQUENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Approved execution contract

1. One exact `XTIUSD.DWX` D1 carrier on governed slot 0.
2. One decision attempt on the first tradable D1 bar of each new broker month,
   within 180 minutes of the raw bar open.
3. Exactly the immediately completed calendar month, with 17 through 23
   unique D1 timestamps, valid OHLC, strict order, and an adjacent older bar
   proving the package is complete.
4. `O` is the chronological first open, `C` the final close, `H` the aggregate
   high, and `L` the aggregate low. Require one unique session for `H` and one
   unique session for `L`; repeated or same-session extremes remain flat.
5. Unique low-before-high plus `C>O` buys WTI. Unique high-before-low plus
   `C<O` sells WTI. Equality, order/body disagreement, and malformed states
   consume the month flat.
6. Persist the broker `yyyymm` attempt before all fallible gates. Rejection,
   restart, stop-out, or invalid data cannot retry the month.
7. Open at most one position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `3.5*ATR(20,D1)` hard stop, no target, no signal-strength sizing,
   and a 1,500-point entry-spread ceiling.
8. Close at the first later broker month or after forty calendar days. Do not
   retry, add, trail, partial-close, grid, martingale, pyramid, or use an
   external runtime feed.
9. Both news axes and Friday close are OFF. Framework kill switch and
   lifecycle repair remain authoritative.

## Falsification boundary

Expected cadence is approximately six to ten positions per full post-warm-up
year as a pre-result ordering prior. Q02 retires at zero positions, below five
completed positions in any full scored year, nonpositive governed economics,
or any month-label, history, geometry, uniqueness, order, body-agreement,
side, attempt, risk, lifecycle, or determinism defect.

A weak result may not be rescued by accepting repeated or same-session
extremes, dropping body agreement, reversing the side, changing the calendar
month or hold, or adding magnitude, body-share, wick, close-location,
range-rank, volatility, volume, season, event, inventory, moving-average,
oscillator, external, or prior-result state. Any such change requires a new
OWNER-approved identity.

WTI is an energy carrier absent from the certified XAU/SP500/NDX/XNG book.
That structural difference does not establish profitability, low
correlation, or portfolio admission. Q09 alone may establish the realized
portfolio result.

## Approval scope and safety

`g0_status: APPROVED` and `execution_contract_status: APPROVED` authorize the
card-aligned branch-only EA source, governed magic row, strict compile/Q01,
one `RISK_FIXED` backtest setfile, deterministic reference tests, and one
paced Q02 enqueue if the fresh resource ceiling permits.

This decision does not authorize a manual tester run, demo/shadow/live/stress/
optimization preset, AutoTrading, `T_Live`, deploy or T_Live manifest,
portfolio-gate mutation, portfolio admission, decorrelation claim,
correlation waiver, or live use.
