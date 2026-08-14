# XNG Weekend-Hold — G0 Decision

Date: 2026-08-14

Decision: `APPROVED` for deterministic EA-ID allocation, one non-live V5
build, strict Q01 validation, and one paced Q02 handoff only.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
2026-08-14. The mission explicitly permits a second XNG sleeve when its logic
differs from `QM5_12567`, requires a structural low-frequency rule and
reputable sources, and authorizes a branch-only card/build/Q02 handoff while
forbidding live and portfolio-gate changes.

## Candidate

- Canonical slug: `xng-wkend-hold`.
- EA ID: `QM5_21519`.
- Strategy ID: `TGIF-XNG-WEEKEND-2017_S04`.
- Composite source ID: `TGIF-EIA-XNG-WKEND-2026`.
- Carrier/slot/magic: `XNGUSD.DWX`, H1, slot 0, `215190000`.
- Driver: the natural-gas Monday return effect measured in the peer-reviewed
  energy-weekend study, translated into an executable Friday 21:00 broker-time
  entry through Monday 21:00 broker-time hold.
- Lifecycle: one consumed Friday decision per broker week, frozen
  `3.5 * ATR(20,D1)` hard stop, Monday cutoff exit, and a 96-hour stale guard.

The deterministic allocator reserved `QM5_21519` after this durable
pre-allocation authorization record was written. The ID and intended slot-0
magic are fixed for the card, approved copy, registries, and build evidence.

## Approved source boundary

The complete governed parent packets were read before this decision:

1. Hoelscher, Mbanga, and Nelson (2017), "TGIF? The Weekend Effect in Energy
   Commodities," *Journal of Finance Issues* 16(1), 47-68, DOI
   `10.58886/jfi.v16i1.2264`. The repository packet records a complete
   22-page review and the natural-gas Monday coefficients across robust
   estimators and subperiods.
2. U.S. Energy Information Administration, "Factors affecting natural gas
   prices," for the official weather-sensitive heating and electric-power
   demand context.

The bounded composite packet is
`strategy-seeds/sources/TGIF-EIA-XNG-WKEND-2026/source.md`. A fresh
2026-08-14 deterministic generic-URL route returned
`DEFERRED:SOURCE_POLICY`; no proxy or access workaround was used. The
previous complete repository review remains the evidence boundary.

The paper uses EIA spot close-to-close returns and does not prescribe a
Darwinex CFD, an H1 execution clock, a broker-time cutoff, fixed-dollar risk,
an ATR stop, or transaction-cost assumptions. EIA documents price drivers,
not a trading return. No performance number transfers to this candidate.

## Locked rule

On each genuine new `XNGUSD.DWX` H1 bar:

1. Require the broker-calendar bar to start Friday at exactly 21:00 and the
   first executable tick to arrive within a five-minute attach grace.
2. Derive the current framework `PERIOD_W1` key and persist it as consumed
   before position, history, news, spread, quote, sizing, stop, or order
   checks. A rejection, restart, or stop-out cannot retry that week.
3. Require no owned exposure, a nonnegative spread no greater than 1,000
   points, an executable ask, and a positive completed D1 ATR(20).
4. Buy one `XNGUSD.DWX` position with aggregate `RISK_FIXED=1000`, a frozen
   `3.5 * ATR(20,D1)` broker hard stop, and no take-profit.
5. Disable the framework Friday flatten because holding the Friday-to-Monday
   window is load-bearing. Close on the first tick at or after Monday 21:00
   broker time, on the first later-week tick if that cutoff was missed, after
   96 elapsed hours, or immediately for malformed owned state.

Both news axes are OFF for Q02; the strategy does not read an event calendar.
No alternative weekday, cutoff, direction, seasonal filter, gap condition,
trend filter, target, retry, or signal-sized risk is authorized.

## Reputable-source criteria

- R1: PASS. One bounded composite lineage backed by a fully reviewed
  peer-reviewed energy-weekend paper and an official EIA structural source.
- R2: PASS. Carrier, H1 decision bar, direction, attempt state, risk, D1 stop,
  Monday exit, stale repair, and invalid-state behavior are fixed.
- R3: PASS. Registered native `XNGUSD.DWX` H1/D1 history, broker time, quote,
  spread, and position state supply every runtime input.
- R4: PASS. Deterministic calendar/OHLC/ATR arithmetic only; no trained output,
  external runtime feed, optimizer state, grid, martingale, scale-in, or
  pyramid.

## Non-duplicate decision

The canonical pre-allocation checker found no exact slug or strategy-ID
collision across 4,391 registry rows and 487 root cards. It surfaced one
expected source-family fuzzy neighbor, `QM5_20016_xti-xng-mon-rv`, which is a
two-leg Monday-session package entered after the weekend and cannot hold
either leg alone.

Manual mechanic review also separates the closest XNG cards:

- `QM5_12806_xng-rev-weekend` opens XNG after Monday begins and separately
  shorts Friday; it never holds a long position across the weekend.
- `QM5_12738_xng-weekend-gap` waits until a Monday gap and same-direction body
  are complete, then follows the realized gap.
- XNG weekday/trend cards enter after the relevant D1 boundary; storage,
  weather, seasonality, carry, and relative-value sleeves use different
  information objects or traded packages.
- `QM5_12567_cum-rsi2-commodity` is a long-only short-horizon cumulative-RSI
  pullback under a slow trend filter. This candidate has no oscillator,
  pullback, trend mean, or daily signal; its only alpha state is the
  pre-weekend calendar window.

The Friday pre-close entry, deliberate weekend hold, Monday matching-cutoff
exit, one-week attempt ledger, and XNG-only long carrier are jointly
load-bearing. Verdict:
`CLEAN_AUTHORIZED_XNG_PREWEEKEND_TO_MONDAY_HOLD_AFTER_FAMILY_REVIEW`.

## Density, kill, and safety boundary

The cadence prior is approximately 45-51 completed packages per full year
after holidays and execution gates; this is not test evidence. Retire below
five completed trades/year, on nonpositive governed economics, or at later
portfolio-correlation rejection. Fail on a Monday-open entry, Friday short,
gap-conditioned direction, same-week retry, premature Friday flatten,
Tuesday discretionary extension, missing stop, wrong risk mode, or
nondeterminism.

Q02 uses exactly one H1 backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This decision excludes a manual
backtest; live/demo/shadow/stress/optimization setfiles; `T_Live`;
AutoTrading; deploy or T_Live manifests; portfolio admission; portfolio-gate
changes; correlation waivers; and terminal start/stop/reap actions. If the
paced fleet's CPU ceiling is binding before enqueue, stop without enqueue.
