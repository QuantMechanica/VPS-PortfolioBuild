# QM5_41135 XAU/XAG Completed-Month Daily-Return Interquartile-Mean Reversion - G0 Decision

Date: 2026-08-23

Decision: `APPROVED`

Card:
`strategy-seeds/cards/approved/QM5_41135_xauxag-mdaily-iqrmean-rv_card.md`

Source approval:
`decisions/2026-08-23_xauxag_monthly_daily_interquartile_mean_reversion_source_approval.md`

Source packet:
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MDAILY-IQRMEAN-RV-2026/source.md`

Authority: current explicit OWNER commodity/energy portfolio mission on branch
`agents/board-advisor`, requiring one new, reputable-source, structural low-
frequency commodity edge, a `RISK_FIXED` backtest setfile, one Q02 enqueue, no
live action, and no portfolio-gate or T_Live-manifest mutation.

## Identity And Allocation

- EA ID: `41135`
- slug: `xauxag-mdaily-iqrmean-rv`
- strategy ID:
  `SCHWEIKERT-CME-XAUXAG-MDAILY-IQRMEAN-RV-2026_S01`
- source ID: `SCHWEIKERT-CME-XAUXAG-MDAILY-IQRMEAN-RV-2026`
- host: `XAUUSD.DWX`, D1, slot 0, magic `411350000`
- companion: `XAGUSD.DWX`, D1, slot 1, magic `411350001`
- logical symbol: `QM5_41135_XAU_XAG_MDAILY_IQRMEAN_RV_D1`

The deterministic registry reserved `41135` at commit `c56a69aa0` before this
decision. Magic allocation must follow the governed directory-first sequence
before implementation and compile; this decision does not bypass that gate.

## G0 Findings

### R1 - Reputable Track-Record Basis

`PASS_WITH_WITHIN_MONTH_IQR_LOCATION_TRANSLATION_RISK`.

The bounded source preserves a peer-reviewed gold/silver relation paper with
DOI and official CME intermarket-spread research, with complete-read evidence
and durable hashes. The within-month central-band estimator and contrarian
direction are explicit pre-result QM translations. No performance, density,
cost, CFD-equivalence, hedge-ratio, neutrality, or correlation result
transfers.

### R2 - Mechanical Completeness

`PASS`.

The card locks exact symbols and D1 period; first-new-month timing; an exact
17-to-23-session immediately completed synchronized month; one adjacent older
boundary pair; chronological relative returns ending on every completed-month
session; endpoint identity; full ascending sort; `floor(n/4)` deletion from
both tails; exact retained indexes; central arithmetic mean; contrarian sides;
consumed monthly attempt; aggregate fixed risk; equal notionals; frozen ATR
stops; spread caps; atomic repair; first-later-month exit; and forty-day stale
closure. There is no optimization surface or fallback signal.

### R3 - Runtime Data Availability

`PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`.

Registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 history, MT5 symbol
metadata, quotes, spreads, ATR, position/deal state, broker time, and terminal-
global attempt state supply every input. No futures chain or external dataset
is required. Q02 owns history sufficiency, costs, fills, financing, density,
calendar overlap, gaps, and continuous-CFD basis.

### R4 - ML And Prohibited-Mechanic Ban

`PASS`.

The mechanic uses completed timestamps, prices, logarithms, addition, sorting,
integer division, comparisons, ATR risk distance, quotes, positions, deals,
and persistent terminal state. It contains no trained or adaptive output,
banned signal, external runtime feed, grid, martingale, pyramid, scale-in, or
result-driven parameter change.

## Non-Duplicate Finding

The pre-allocation fail-closed checker scanned 4,634 registry identities,
1,302 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`:
`artifacts/qm5_xauxag_mdaily_iqrmean_rv_preallocation_dedup_20260823.json`.

Manual review separates fitted ratio/OLS/MAD crossing systems; sign breadth
and fixed-block cards; ordered state transitions; L1 and L2 path quotients;
adjacent-return persistence; and certified XNG cumulative-RSI logic. The
nearest estimator analog, `QM5_41134_wti-mdaily-iqrmean-mom`, is an outright
WTI continuation leg; this card instead applies the central-band statistic to
synchronized XAU-minus-XAG returns, fades it, and owns an atomic equal-
notional package. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_INTERQUARTILE_MEAN_REVERSION_AFTER_FAMILY_REVIEW`.

## Approved Execution Contract

1. Exact `XAUUSD.DWX` host and `XAGUSD.DWX` companion, D1, EA `41135`, slots
   0/1, magics `411350000`/`411350001`.
2. One decision attempt on the first synchronized executable bar of each new
   broker month, within 180 minutes of the raw host D1 bar open.
3. Exactly the immediately completed calendar month, 17 through 23 unique
   synchronized close pairs, plus one adjacent older pair proving the left
   boundary.
4. Chronological relative log returns from the older pair into every month-
   session pair; verify endpoint identity, sort every return ascending, remove
   `floor(n/4)` from each tail, and average the exact retained band.
5. Positive central mean: SELL XAU and BUY XAG. Negative central mean: BUY XAU
   and SELL XAG. Zero, endpoint mismatch, invalid retained membership, and
   malformed states consume the month flat. The raw endpoint is diagnostic
   only.
6. One equal-target-notional opposite-leg package, aggregate
   `RISK_FIXED=1000`, no more than 20% realized notional mismatch, frozen
   `3.5*ATR(20,D1)` hard stops on both legs, no target or signal-strength
   sizing, and spread ceilings of 1,500 XAU / 500 XAG points.
7. Submit atomically with immediate cleanup after a second-leg failure;
   flatten orphaned, duplicated, same-side, stopless, wrong-magic, or
   notional-invalid exposure.
8. Close both legs at the first later broker-month tick, with a forty-day stale
   guard; no retry, add, rebalance, trail, partial close, grid, martingale, or
   pyramid.
9. Both news axes and Friday close OFF. Framework kill switch and ownership
   repair remain authoritative.

## Falsification Boundary

Every valid nonzero central mean can qualify, giving a design prior near twelve
packages per year. This is not market evidence. Q02 retires at zero packages,
below five completed packages in any full scored post-warm-up year,
nonpositive governed economics, or any synchronization, boundary,
orientation, endpoint, sort, trim, mean, side, attempt, risk, atomicity,
lifecycle, or determinism defect.

A weak result may not be rescued by changing the trim, direction, return
inclusion, session bounds, hold, risk, or carrier, or by adding endpoint
agreement, a fitted center or scale, sign count, calendar block, event,
seasonal, external, or prior-result state.

Opposite equal-notional legs are a market-neutral design, not a neutrality or
decorrelation finding. Unchanged Q09 alone owns the realized portfolio
decision.

## Approval Scope And Safety

`g0_status: APPROVED` and `execution_contract_status: APPROVED` authorize the
card-aligned branch-only EA source, governed magic rows, strict compile/Q01,
one logical `RISK_FIXED` backtest setfile, deterministic reference tests, and
one paced Q02 enqueue if the fresh resource ceiling permits.

This decision does not authorize a manual tester run, demo/shadow/live/stress/
optimization preset, AutoTrading, `T_Live`, deploy or T_Live manifest,
portfolio-gate mutation, portfolio admission, decorrelation claim,
correlation waiver, or live use. Q09 alone may establish realized portfolio
correlation.
