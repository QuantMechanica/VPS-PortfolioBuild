# WTI Weekly Flow-Agreement Continuation - Source Approval

Date: 2026-08-16

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. This decision does not authorize a manual
tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, `RISK_FIXED` backtests, and
no live or portfolio-gate mutation.

## Candidate Identity

- proposed slug: `wti-flow-agree`
- proposed strategy ID: `WILLIAMS-MOP-WTI-WFLOW-2026_S01`
- proposed source ID: `WILLIAMS-MOP-WTI-WFLOW-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, symmetric long/short
- decision clock: the first genuine normalized Monday D1 session after one
  exact completed Monday-through-Friday week
- price state: separate sums of the completed week's close-to-open and
  open-to-close log returns
- lifecycle: enter only when both flow sums have the same strict sign and
  flatten through the framework Friday-close rule

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following bounded repository sources were read completely before this
decision:

1. Larry R. Williams (1999), *Long-Term Secrets to Short-Term Trading*, Wiley
   Trading. The OWNER-supplied Tier-A packet at
   `strategy-seeds/sources/SRC03/source.md` and its bounded page-18 extraction
   at `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` define Pro-Go's two
   price-flow objects: prior close to current open and current open to current
   close. Williams smooths those objects over fourteen days and discusses
   their crossings and divergences.
2. Tobias J. Moskowitz, Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
   Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. The complete-paper packet at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md` documents own-return-sign
   continuation, commodity-futures coverage, and explicit WTI membership.

Neither source tests the proposed conjunction. Williams does not prescribe a
five-session component sum, strict component-sign agreement, a Monday clock,
WTI, or a Friday exit. Moskowitz, Ooi, and Pedersen do not decompose weekly
returns into overnight/session components. The exact Darwinex carrier,
calendar sequence, normalized broker labels, 180-minute attachment boundary,
fixed cash risk, ATR stop, spread cap, attempt ledger, and weekly lifecycle are
transparent QM falsification choices. No source return, coefficient,
significance, trade density, cost, drawdown, CFD equivalence, decorrelation,
or portfolio result transfers.

## Locked Mechanic

On the first observed tick of an exact normalized Monday `XTIUSD.DWX` D1 bar:

1. Repair or close malformed, duplicated, wrong-side, stale, or
   out-of-lifecycle owned exposure before applying entry-only gates.
2. Normalize current and historical D1 labels only by the governed native
   same-day or uniform `+1` calendar-day energy convention. Require the
   normalized current date to equal the broker date.
3. Require exactly the newest sequence
   `prior-Friday, prior-Thursday, prior-Wednesday, prior-Tuesday,
   prior-Monday, preceding-Friday` behind the current Monday, with strict
   timestamp order and the expected one- or three-calendar-day gaps. Holidays
   are not shifted, substituted, or backfilled.
4. Require the first observed tick within 180 minutes of the executable
   Monday D1 open. Persist the current broker-week attempt before history,
   signal, news, spread, quote, ATR, sizing, or order gates. Never retry or
   backfill the week.
5. Across the five completed prior-week sessions, compute
   `overnight_flow = sum(log(Open[d] / PriorClose[d]))` and
   `session_flow = sum(log(Close[d] / Open[d]))`. All inputs are fixed
   completed-bar endpoints. The current Monday price enters neither sum.
6. BUY only when both sums are strictly positive. SELL only when both sums
   are strictly negative. Disagreement, exact zero, or invalid arithmetic
   consumes the week flat. Signal magnitude never scales risk.
7. Open at most one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.0 * ATR(20,D1)` hard stop, a 1,500-point
   spread ceiling, and no target.
8. Framework Friday close at broker hour 21 is the ordinary exit. Close stale
   exposure on the first later broker-week boundary or after eight calendar
   days. Both news axes remain OFF.

The two return decompositions, exact prior-week sequence, strict agreement,
Monday clock, no-shift/no-late-entry/no-retry rules, fixed risk, hard stop, and
Friday lifecycle are load-bearing. No threshold, volatility gate, line
crossover, weekday substitution, target, or longer hold is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_COMPOSITE_TRANSLATION_RISK`: one OWNER-supplied Tier-A
  practitioner book extraction defines the two price-flow components, and one
  peer-reviewed complete-read JFE paper supplies own-return continuation and
  WTI membership. The untested conjunction and source-to-implementation
  distance are explicit.
- R2 `PASS`: normalized exact-week identity, fixed completed endpoints,
  component sums, strict sign agreement, attempt state, entry timing, risk,
  stop, spread, and Friday exit are deterministic and locked.
- R3 `PASS`: registered `XTIUSD.DWX` D1 OHLC and MT5 execution state supply
  every runtime input. Its direct-carrier session offset is measured in
  `framework/registry/session_offset_minutes.csv`.
- R4 `PASS`: native calendar, OHLC, logarithm, ATR risk plumbing, quote,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,516 EA-registry rows and 612 root
cards. It found no exact identity and one expected fuzzy neighbor,
`QM5_41019_wti-wopen-mom`. Manual semantic review fixes the family boundaries:

- `QM5_12784_progo-xti` forms fourteen-day signed-value averages of the two
  Williams flows and trades line crossings on any new D1 bar with an
  opposite-cross/time exit. This candidate forms separate five-session log
  sums for one exact completed calendar week, requires their signs to agree,
  decides only on the next Monday, and exits Friday.
- `QM5_41022_wti-wdual-mom` divides a prior week's close-to-close path into
  disjoint Friday-to-Tuesday and Tuesday-to-Friday temporal segments. This
  candidate instead decomposes every prior-week session by information time:
  close-to-open versus open-to-close.
- `QM5_41019_wti-wopen-mom` observes the current week's Friday-to-Tuesday
  close path, enters Wednesday, and exits Friday. This candidate uses a fully
  completed prior week, a two-component agreement state, and a Monday entry.
- `QM5_13049_xti-1w-mom-vol` uses a thresholded five-D1 close return and a
  realized-volatility percentile gate on any weekly attempt. This candidate
  has no magnitude or volatility filter and requires component agreement.
- `QM5_41028_wti-mgap-fade` fades only the prior-month-final-close to
  current-month-first-open gap for one D1 interval. This candidate follows
  agreement across ten completed prior-week component observations.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon oscillator pullback across
  multiple commodity carriers, not a fixed-clock WTI flow-decomposition rule.

Verdict: `CLEAN_WTI_WEEKLY_OVERNIGHT_SESSION_FLOW_AGREEMENT_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately fifteen to thirty completed positions per
full post-warm-up year after exact-week and sign-agreement gates. Q02 must
retire on zero trades, below five completed positions per year, wrong weekday
sequence, current-bar leakage, incorrect flow endpoints, entry on component
disagreement, late or repeated entry, wrong lifecycle, nondeterminism,
invalid risk mode, or nonpositive governed economics. Holiday exclusions,
source-to-carrier distance, continuous-futures/CFD roll and basis,
broker-label mapping, WTI gaps, spreads, financing, and later book correlation
are first-order risks. Q09 alone may establish realized correlation with the
certified book.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
