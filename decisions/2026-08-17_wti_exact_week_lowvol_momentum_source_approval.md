# WTI Exact-Week Low-Volatility Momentum - Source Approval

Date: 2026-08-17

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, recovery of the
already reserved but unbuilt `QM5_21503` identity, one branch-only non-live
build, strict Q01 validation, and one paced non-live Q02 enqueue if CPU
capacity permits. Enqueue authority is not authority to dispatch a manual
tester or exceed the active factory resource ceiling.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, `RISK_FIXED` backtests, and
no live or portfolio-gate mutation.

## Candidate Identity

- reserved EA ID: `QM5_21503`
- reserved slug: `xti-weekly-tsmom-lowvol`
- normalized strategy ID: `ZHAO-ST-MOMREV-2026_XTI_S02`
- source ID: `28681f5d-aa78-584e-9698-750d1402e485`
- host and traded symbol: exact `XTIUSD.DWX`, D1, magic slot 0
- decision clock: first executable tick of a genuine broker Monday
- formation: exact completed prior Monday-through-Friday close return plus a
  low-tercile realized-volatility rank against forty earlier non-overlapping
  five-return blocks
- direction and lifecycle: follow the completed weekly return sign and flatten
  through the framework Friday-close path

Registry row `21503,xti-weekly-tsmom-lowvol` was reserved on 2026-08-13, but
there is no Strategy Card, EA directory, magic row, binary, setfile, or Q02
work item for that identity. This approval recovers that exact dormant
allocation; it does not reserve a second ID.

## Approved Source Basis

The bounded repository source packet
`strategy-seeds/sources/28681f5d-aa78-584e-9698-750d1402e485/source.md` and its
governed runtime research note at
`D:/QM/strategy_farm/artifacts/source_notes/28681f5d-aa78-584e-9698-750d1402e485.md`
were read completely before this decision.

The source of record is Shen Zhao, Yiyi Ding, Jianfeng Yu, and Wenjin Kang
(2026), "Momentum and Reversal on the Short-Term Horizon: Evidence from
Commodity Markets," SSRN working paper 6425598, posted 2026-03-16, DOI
`10.2139/ssrn.6425598`.

The durable packet records the exact access boundary: SSRN and ResearchGate
full-text endpoints were inaccessible, while metadata and the abstract/
methodology summary were cross-checked against the Lingnan College seminar
listing. No unavailable table, coefficient, return, parameter, or statistical
result is reconstructed. The usable claims are only that the residual
component of weekly commodity returns predicts the next week positively and
that the short-term momentum effect strengthens when volatility or
uncertainty is low.

The source uses investor-position information to decompose returns. QM has no
approved position or COT runtime feed. This candidate therefore tests a
disclosed native-price proxy: the sign of one exact completed broker week,
conditioned on the realized volatility of that same week ranking in the
lowest tercile of older non-overlapping price blocks. The source does not test
this proxy, a WTI-only CFD, exact Monday entry, Friday exit, the chosen rank
sample, fixed-dollar risk, an ATR stop, or the QM portfolio. No source return,
alpha, coefficient, significance, density, cost, drawdown, WTI-specific
efficacy, CFD equivalence, decorrelation, or portfolio result transfers.

The deterministic source reader previously classified direct generic
retrieval of the canonical SSRN URL as `DEFERRED:SOURCE_POLICY`. No proxy,
authentication, CAPTCHA, cookie, or access-control workaround is authorized
or attempted. The durable bounded packet is the complete evidence boundary.

## Locked Mechanic

At the first executable tick of a genuine broker Monday:

1. Support only the native same-day D1 label or the governed uniform `+1`
   calendar-day energy-label normalization. Apply one offset to every endpoint
   and never repair, shift, or substitute an individual bar.
2. Require the six immediately preceding completed normalized D1 bars, newest
   first, to be prior Friday, Thursday, Wednesday, Tuesday, Monday, and the
   preceding Friday at exact calendar offsets 3, 4, 5, 6, 7, and 10 days.
   A holiday-broken week consumes the Monday flat.
3. Persist the broker-Monday `yyyymmdd` attempt before history, signal, news,
   spread, quote, ATR, sizing, or order gates. Observe the entry path only
   within 180 minutes of the executable D1 opening boundary and never retry.
4. From those six closes compute five chronological log returns and
   `weekly_return = sum(r[0..4])`. Require positive finite endpoints and
   reconcile the sum to `log(PriorFridayClose / PrecedingFridayClose)` within
   `1e-10`.
5. Compute `current_rv = sqrt(sum(r[i]^2))`. From older completed D1 closes,
   compute forty immediately preceding, non-overlapping five-return block RVs
   with the identical formula. No current-week price and no return interval
   used by the signal week enters a baseline block.
6. Define the inclusive empirical rank as the count of baseline RV values less
   than or equal to `current_rv`. Admit only counts `0..13`, the fixed lower
   tercile of forty observations. Ties at the boundary fail closed.
7. BUY when the admitted `weekly_return` is positive and SELL when negative.
   Exact zero, failed reconciliation, invalid volatility, or a rank above 13
   consumes the week flat. Signal or volatility magnitude never scales risk.
8. Open at most one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `3.0 * ATR(20,D1)` broker hard stop, no target, and a 1,500-point
   spread ceiling.
9. Enable framework Friday close at broker hour 21. Close malformed exposure,
   exposure surviving into a later broker week, or exposure older than eight
   calendar days. Both news axes remain OFF; the framework kill switch and
   frozen hard stop remain authoritative.

The exact week, sign-only continuation, five-return RV transform,
non-overlapping forty-block baseline, inclusive lower-tercile rank, Monday
attempt, fixed risk, stop, spread, and Friday lifecycle are jointly
load-bearing. There is no magnitude threshold, rolling 20-D1 volatility
window, optimizer surface, external input, moving average, oscillator, volume
gate, curve signal, scale-in, grid, martingale, or pyramid.

## Reputable-Source Criteria

- R1 `PASS_WITH_ACCESS_AND_PROXY_RISK`: exactly one durable `source_id`, named
  authors, title, date, DOI and canonical URL, complete bounded accessible-
  material record, exact policy-deferred retrieval status, and explicit gaps.
- R2 `PASS`: weekday identity, completed endpoints, return and volatility
  formulas, non-overlapping baseline, fixed rank boundary, direction, attempt,
  entry grace, stop, spread, risk, and exit are deterministic before Q02.
- R3 `PASS_FOR_DISCLOSED_PROXY`: registered `XTIUSD.DWX` D1 close history and
  MT5 execution state supply every runtime input. No investor-position, COT,
  futures-chain, inventory, file, API, or analyst-calendar feed is required.
- R4 `PASS`: fixed calendar and native price arithmetic only; one position on
  one registered magic; no trained output, adaptive PnL fit, banned signal
  indicator, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The pre-card inventory contains 4,526 EA-registry rows, 622 root-card files,
575 approved-card files, and 3,630 EA directories. Exact identity review found
only the dormant `QM5_21503` reservation described above. It found no Card, EA
directory, magic row, source, setfile, binary, or pipeline work item for that
identity. Manual family review returned
`CLEAN_RESERVED_UNBUILT_WTI_EXACT_WEEK_LOW_TERCILE_MOMENTUM`:

- `QM5_13049_xti-1w-mom-vol` evaluates a rolling five-D1 move on any new D1
  bar, requires a fitted 1.25% magnitude threshold, ranks an overlapping
  20-D1 realized-volatility window against 120 observations at a 55th-
  percentile cap, and permits reversal/time exits. This candidate evaluates
  only an exact completed Monday-Friday week, has no return-magnitude
  threshold, ranks its five-return RV against forty non-overlapping blocks at
  a lower-tercile boundary, and owns the next exact week through Friday.
- `QM5_13101_xng-1w-mom-vol` uses the same rolling/magnitude family as 13049
  on natural gas. It is neither an exact-calendar WTI rule nor evidence for
  this carrier.
- `QM5_41020_wti-wclose-mom` follows only the prior week's Tuesday-Friday
  closing segment and exits Wednesday; it has no volatility state.
- `QM5_41022_wti-wdual-mom` requires sign agreement between two disjoint
  within-week return segments and has no volatility rank. This candidate uses
  the full exact-week return sign and can trade weeks whose segments disagree
  when total return is nonzero and volatility is low.
- `QM5_21521_wti-flow-switch` uses non-overlapping tick-volume tails to switch
  between continuation and reversal. This candidate reads no volume and never
  reverses the completed weekly sign.
- WTI calendar, event, inventory, roll, carry, range-breakout, longer-horizon
  trend, reversal, and relative-value families use different information
  objects, clocks, directions, or topology.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback on XNG in the certified book. This candidate is symmetric,
  exact-week, direct WTI continuation with no oscillator.

The carrier and exact signal topology differ from the certified book, but
that is not a correlation claim. Q09 alone may establish realized overlap.

## Kill And Safety Boundary

The frequency prior is approximately 10-18 completed positions per full
post-warm-up year, derived only from a lower-tercile weekly opportunity set.
Q02 must retire on zero trades, fewer than five completed positions per full
year, nonpositive governed economics, wrong weekday identity, current-bar
leakage, overlapping baseline blocks, wrong rank boundary, late or repeated
entry, direction different from the completed weekly sign, wrong Friday
lifecycle, invalid risk mode, or nondeterminism. No weak result may be rescued
by adding a magnitude threshold, widening the volatility rank, accepting a
holiday-shifted week, changing direction, or extending the hold.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission; and
correlation waivers. Q02 may be enqueued once if the exact-path tester count is
below the governed ceiling. If the ceiling is binding, stop before queue
mutation and record a non-live handoff.
