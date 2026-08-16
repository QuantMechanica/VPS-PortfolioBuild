# QM5_41029 WTI Weekly Flow-Agreement Continuation G0 Authorization

Date: 2026-08-16

Decision: `APPROVED` for one branch-only V5 build, strict Q01 validation, one
locked `RISK_FIXED` backtest setfile, and one paced non-live Q02 enqueue. This
is not live, portfolio, or manual-tester authority.

## Identity

- EA: `QM5_41029_wti-flow-agree`
- strategy ID: `WILLIAMS-MOP-WTI-WFLOW-2026_S01`
- approved source: `WILLIAMS-MOP-WTI-WFLOW-2026`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41029_wti-flow-agree_card.md`
- host/slot 0: `XTIUSD.DWX`, D1, planned magic `410290000`
- risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

The atomic registry allocator assigned `QM5_41029` at commit `64373b395`.
No ID was inferred or appended by hand.

## Source And Hypothesis Review

The OWNER-authorized source decision is
`decisions/2026-08-16_wti_weekly_flow_agreement_source_approval.md` at commit
`ed9953241`. The bounded composite packet joins:

- Williams' OWNER-supplied Tier-A Pro-Go extraction, which defines separate
  close-to-open and open-to-close price-flow objects; and
- Moskowitz, Ooi, and Pedersen's peer-reviewed, complete-read JFE paper,
  which supplies own-return continuation lineage and WTI membership.

The approved hypothesis is narrower and different from either source. For an
exact completed WTI Monday-through-Friday week, sum the five close-to-open log
returns separately from the five open-to-close log returns. Trade the next
Monday only when both sums share the same strict sign, then flatten Friday.
The five-session aggregation, sign-agreement gate, exact calendar sequence,
continuous CFD, label normalization, attachment grace, fixed risk, hard stop,
spread cap, attempt ledger, and repair behavior are QM translations. No source
performance, significance, density, decorrelation, or portfolio result
transfers.

## G0 Gates

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: one OWNER-supplied Tier-A book
  extraction defines the two flow components and one complete-read
  peer-reviewed JFE paper supplies continuation lineage and WTI membership;
  the untested conjunction and source distance are disclosed.
- R2 `PASS`: exact prior-week sequence, close/open endpoints, strict
  component-sign agreement, persistent attempt, entry grace, risk, stop,
  spread, Friday close, and stale repair are deterministic and frozen.
- R3 `PASS`: registered `XTIUSD.DWX` D1 bars, measured energy-label offset,
  native ATR, quotes, spread, positions, deals, and terminal state supply all
  runtime inputs.
- R4 `PASS`: no trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Locked Execution Contract

1. Run only on exact `XTIUSD.DWX`, D1, EA ID 41029, magic slot 0.
2. Normalize current and historical D1 labels by only the governed same-day
   or uniform `+86400`-second energy convention. Require normalized current
   date to equal broker date.
3. On an exact current Monday, require the six immediately completed labels,
   newest first, to be Friday, Thursday, Wednesday, Tuesday, Monday, and the
   preceding Friday at offsets 3, 4, 5, 6, 7, and 10 calendar days. Never
   shift a holiday or substitute a nearest bar.
4. Admit only the first observed tick within 180 minutes of executable Monday
   D1 open. Persist the broker-Monday attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates. Never retry or backfill.
5. For the prior Monday-Friday sessions, calculate five completed
   `log(Open/PreviousClose)` values and five completed `log(Close/Open)`
   values. Sum each component independently. The current Monday price enters
   neither sum.
6. BUY only when both sums are strictly positive; SELL only when both are
   strictly negative. Equality, disagreement, or invalid arithmetic consumes
   the week flat. Magnitude cannot scale risk.
7. Use one fixed-risk position, a frozen `3.0*ATR(20,D1)` broker hard stop,
   no target, and a 1,500-point entry-spread ceiling.
8. Framework Friday close at broker hour 21 is the ordinary exit. A later
   broker-week boundary, eight elapsed calendar days, or malformed exposure
   is repair.

News temporal mode, compliance profile, and legacy mode are OFF. No flow
threshold, volatility gate, line crossover, weekday substitution, pending
order, retry, scale-in, target, trailing stop, break-even move, grid,
martingale, pyramid, or optimization is authorized.

## Non-Duplicate Review

The canonical pre-card checker scanned 4,516 registry rows and 612 root cards,
found no exact identity, and returned the expected fuzzy family hit
`QM5_41019_wti-wopen-mom`. Manual review returned
`CLEAN_WTI_WEEKLY_OVERNIGHT_SESSION_FLOW_AGREEMENT_AFTER_FAMILY_REVIEW`:

- `QM5_12784_progo-xti` trades fourteen-day flow-line crossings on any D1;
  this EA trades strict signs of two five-session log sums on Monday only.
- `QM5_41022_wti-wdual-mom` splits a close-to-close week into early and late
  temporal segments; this EA decomposes every prior-week session by
  close-to-open versus open-to-close information time.
- `QM5_41019` observes the current week and enters Wednesday; this EA observes
  a completed prior week and enters Monday.
- `QM5_13049` adds return-magnitude and volatility-rank filters; this EA has
  neither and instead requires flow-component agreement.
- `QM5_41028` is a monthly one-gap fade; this EA is weekly, uses ten completed
  component returns, and follows agreement.
- `QM5_12567` is a two-day oscillator pullback, not this structural flow rule.

## Validation And Kill Contract

Q01 must prove exact label/weekday acceptance and holiday rejection, completed
endpoint arithmetic, disagreement/equality flat states, no current-bar
leakage, persistent no-retry behavior, fixed-risk sizing, frozen stop, Friday
and stale exits, strict compile, card lint, setfile schema, magic resolution,
and static P1 validation.

Q02 must retire on zero trades, fewer than five completed positions per full
post-warm-up year, wrong week or endpoint identity, current-bar leakage,
entry on disagreement, late/repeated entry, wrong lifecycle, nondeterminism,
invalid risk mode, or nonpositive governed economics. Holiday exclusions,
source-to-carrier distance, CFD/futures basis, broker labels, WTI gaps, costs,
and later correlation are explicit risks. Q09 alone may establish realized
decorrelation.

## Safety Boundary

Authorized: card approval, one slot-0 magic row, one non-live V5 EA build, one
D1 backtest setfile, strict Q01 checks, and one paced Q02 enqueue.

Excluded: manual tester dispatch; live/demo/shadow/stress/optimization
setfiles; terminal reservation or process control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate edits; portfolio admission; and
correlation waivers. If the paced-fleet CPU ceiling is binding, stop before
any queue command and record the capacity handoff.
