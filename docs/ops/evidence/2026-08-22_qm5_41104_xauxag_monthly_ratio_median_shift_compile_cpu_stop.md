# QM5_41104 XAU/XAG Monthly Ratio-Median Shift Build / CPU Stop

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41104_xauxag-mmedian-shift-rv`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; Q01 PENDING; Q02 NOT_ENQUEUED_CPU_CEILING`

## New Commodity Sleeve Candidate

`QM5_41104` is a low-frequency logical XAU/XAG relative-value basket. On the
first exact synchronized D1 boundary of a new broker month it builds
`log(XAU close)-log(XAG close)` for every synchronized session in each of the
two immediately completed consecutive calendar months. It computes one
ordinary sample median independently for each month and fades every strict
median displacement: a higher newest median sells XAU and buys XAG; a lower
newest median buys XAU and sells XAG. Equal medians, 16 or 24 sessions,
asynchronous or invalid closes, nonconsecutive months, incomplete parent
history, late attachment, and retry states consume the month flat.

The two legs are one package. They target equal absolute USD notionals within
20 percent after downward lot rounding, share one `RISK_FIXED=1000` budget,
use frozen `3.5*ATR(20,D1)` hard stops, have no target, and close on the first
observed next-month boundary with a forty-day stale repair guard.

This is not the already-built monthly range-migration rule in `QM5_41103`.
The new EA ignores extrema and uses only the two ordinary sample medians; it
can signal when monthly ranges overlap or their endpoints move in mixed
directions. `QM5_41103` ignores medians and requires strict same-direction
migration of both endpoints. The new rule also has no rolling median/MAD
score, z-score, threshold, fresh-cross state, return-winner ranking, or
single-symbol metal exposure. Equal notionals do not prove market neutrality
or decorrelation; Q09 alone may make a realized portfolio-correlation finding.

## Source And Non-Duplicate Boundary

Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`, supplies peer-reviewed state-dependent
gold/silver relationship lineage. CME Group's *Gold & Silver Ratio Spread*
supplies the intermarket carrier definition. Neither source tests this exact
completed-month median fade, continuous CFDs, package risk, or economics;
those are disclosed pre-result QM choices.

The pre-allocation checker scanned the deterministic registry, repository
cards, and Strategy Wiki and returned `CLEAN`. The post-allocation receipt has
only the expected new `QM5_41104` self-hits. The approved card records the
manual family boundaries and G0 verdict.

## Durable Commit Trail

- source approval and pre-allocation dedup: `65f571311`;
- bounded source extraction: `ceebb96ea`;
- deterministic EA-ID reservation: `54c2d3df6`;
- G0-approved card and post-allocation dedup: `c30adda07`;
- governed basket magics `411040000` and `411040001`: `409634d5b`; and
- EA, local card, SPEC, basket manifest, reference suite, and sole logical D1
  fixed-risk preset: `668e29837`.

The source MQ5 SHA-256 is
`24A1E033DED53492CA6DBF03E08F263988FFE58C329D0F11481A8AA30D434F94`.
The unbound logical setfile SHA-256 is
`E5D131E74D3DB67E896BC91408916E762D8506F34F0CB02163716F7840386C7A`;
its `build_hash` correctly remains `pending` until governed compilation.

## Source-Level Validation

The independent reference suite passed 14/14 tests. It covers both
contrarian directions; exact odd/even medians; equality flat despite unequal
ranges; signals with mixed endpoints; 17/23-session acceptance and 16/24
rejection; exact synchronization and timestamp order; invalid closes and zero
dispersion; current-month leakage; consecutive month identity and visible
older boundary; the 180-minute clock; one-shot attempt persistence; year
rollover; joint risk/notional sizing; lifecycle contracts; and static build
identity markers.

The V5 build guardrails, SPEC validator, basket symbol-scope validator, card
schema/prohibited-ML lint, and G0 lint all passed. The approved and EA-local
card copies are byte-identical at SHA-256
`7C6FC5CE605312F1CC235F82091A2DFACE748245665D266CB11A709352715EAF`.
These checks do not claim a compile, EX5, build-check PASS, Q01 PASS, tester
result, economics, certification, neutrality, or decorrelation.

## Governed Compile Blocker

The repository build guard refused before execution because live factory
terminal processes make ad-hoc include mirroring unsafe. Its detail was
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry, process stop, or bypass was
attempted. Because the guard runs before the remaining build-check stages,
there is no build-check verdict.

The mandated governed command created exactly one compile utility item,
`0960f13d-a245-410a-97c3-7b6e3411041f`. It is pending, verdict-free, and held
under `COMPILE_EA_WORKER_ROLLOUT_PENDING`. That hold is released only through
the separately authorized reviewed fleet-restart ceremony and was not
bypassed. Therefore there is no EX5, sealed build hash, build-check PASS, or
Q01 PASS yet.

## Binding Capacity Stop

Read-only `farmctl mt5-slots` at `2026-08-22T03:39:21Z` reported six active
governed terminals (`T1`, `T10`, `T2`, `T3`, `T4`, and `T6`), with zero
duplicate workers and zero orphaned processes. The separate `T_Live` and FTMO
processes were only reported by inventory; neither was accessed or controlled.

Five whole-host CPU samples at approximately five-second spacing were:

| Sample UTC | CPU |
|---|---:|
| `2026-08-22T03:39:41.875Z` | 71% |
| `2026-08-22T03:39:46.932Z` | 99% |
| `2026-08-22T03:39:51.955Z` | 54% |
| `2026-08-22T03:39:56.975Z` | 93% |
| `2026-08-22T03:40:01.999Z` | 99% |

Average CPU was 83.2 percent and maximum CPU was 99 percent. Two samples
crossed the explicit 97 percent hard ceiling. Per the mission stop condition,
no Q02 preview/apply, dispatcher tick, tester run, smoke run, or backtest was
started. Q02 is additionally blocked by the absent governed compile/Q01 PASS.
Read-only work-item verification shows exactly one `QM5_41104` row: the held
compile utility item, with no Q02 row.

## Safe Handoff

After a separately authorized fleet restart releases the compile hold, let
the governed worker consume the bound MQ5. Require strict compile PASS with
zero errors/warnings, a non-empty EX5, targeted build-check PASS, final
setfile hash binding, and static Q01 artifact PASS. Then repeat an immediate
capacity sample and enqueue exactly one logical-basket D1 Q02 row only if all
ceilings and dedup gates remain open.

No live/demo/shadow/stress/optimization preset, manual tester, terminal
reservation or control, AutoTrading action, `T_Live` or deploy-manifest
change, portfolio-gate mutation, portfolio admission, neutrality claim,
decorrelation claim, or correlation waiver occurred.

Machine-readable evidence:
`artifacts/qm5_41104_compile_handoff_20260822T034002Z_board_advisor.json`.
