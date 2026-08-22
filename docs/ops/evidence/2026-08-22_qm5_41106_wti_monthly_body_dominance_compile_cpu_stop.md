# QM5_41106 WTI Monthly Body-Dominance Build / CPU Stop

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41106_wti-mbody-dominance-mom`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; Q01 PENDING; Q02 NOT_ENQUEUED_CPU_CEILING`

## New Structural Energy Candidate

`QM5_41106` is a low-frequency, symmetric direct-WTI continuation candidate
on exact `XTIUSD.DWX` D1. On the first tradable normalized bar of a new broker
month, it aggregates the immediately completed 17-to-23-session calendar
month. It buys when that month's final close is above its first open and the
strict inequality `2*abs(close-open)>high-low` holds; it sells under the same
strict majority-body condition when the close is below the open. Threshold
equality, zero body, 16 or 24 sessions, malformed or nonadjacent history, late
attachment, and retry states consume the month flat.

Each accepted position uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, one durable attempt per month, and a
normal next-month exit with a forty-day stale repair. Direct WTI gives the
candidate physical-energy exposure absent from the certified XAU/SP500/NDX/
XNG book. Carrier and mechanic difference do not establish decorrelation;
Q09 alone owns that finding.

## Reputable Source And Non-Duplicate Boundary

Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`, supplies peer-reviewed monthly
own-price continuation lineage, one-month holding tests, and explicit WTI
membership. The governed parent record contains an end-to-end 23-page paper
read and durable PDF hash. Completed-month OHLC aggregation and the strict
majority-body state are disclosed QM translations; no paper or sibling
performance transfers to this continuous-CFD build.

The pre-allocation checker examined 4,595 registry identities, 1,274 cards,
and 45 Strategy-Wiki nodes. It found no exact identity and only the expected
weekly body-family siblings. Manual review separates:

- `QM5_41092_wti-wbody-dominance-mom`, whose three-to-five-session week,
  strict two-thirds threshold, weekly turnover, and one-week hold differ from
  one 17-to-23-session calendar month, a strict majority threshold, and a
  next-month lifecycle;
- `QM5_41094_xng-wbody-dominance-mom`, a weekly XNG carrier;
- `QM5_20187_wti-tsmom1m`, which uses two month-end closes and no first-open
  or body-share gate;
- `QM5_41105_wti-mclose-location-mom`, which uses consecutive final closes
  plus outer-quartile settlement rather than one month's real-body share; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only two-day XNG oscillator
  pullback rather than symmetric monthly WTI continuation.

After allocation, the checker returned only the new `QM5_41106` registry
self-hits and no foreign collision.

## Durable Commit Trail

- source approval and pre-allocation evidence: `e0eb12c16`;
- bounded source packet: `b1eedd804`;
- deterministic EA-ID reservation: `9fb6f1548`;
- Q00-approved card and post-allocation receipt: `813b6dea4`;
- governed slot-zero magic `411060000` and resolver: `fe8420a1e`; and
- EA source, local card, SPEC, reference suite, and sole D1 fixed-risk preset:
  `43ade5c04`.

The MQ5 SHA-256 is
`5AA7D4F6D1E4829CE39EB2E84D94C6E79484F2ADE644CF86080B6BCFD5425695`.
The unbound pre-compile setfile SHA-256 is
`99A0216B125B3B55195CE6E738F358B840037787A88A0B6A68DA0E0843481938`;
its `build_hash` remains `pending` until governed compilation. The approved
card and EA-local copy are byte-identical at SHA-256
`FC512212DEB734B2E0E61A7FAFD9EFC1C159372B53E31C83DB4DD6F5EBCA0C33`.

## Source-Level Validation

The target-only deterministic reference suite passed 11/11 checks. It covers
strict long and short directions; 17/20/23-session acceptance; 16/24-session
rejection; threshold equality, sub-threshold, and zero-body flat states;
malformed, zero-range, nonconsecutive, duplicate-date, and current-month
rejection; native and uniformly shifted energy labels; the 180-minute entry
grace; persistent attempts; year rollover; next-month exit; stale repair; and
the static fixed-risk contract.

The build prerequisite guard, V5 guardrails, SPEC validator, single-symbol
scope validator, card schema/prohibited-ML lint, and G0 lint all passed. These
checks do not claim a compile, EX5, strict build-check PASS, Q01 PASS, tester
result, economics, certification, or decorrelation.

## Governed Compile Blocker

The ad-hoc strict compiler refused before execution because live factory
terminal processes make include mirroring unsafe. Its failure class was
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry, process stop, include-mirror
bypass, or terminal action occurred.

The mandated governed command created exactly one compile utility item,
`1c5bbf58-399e-4f37-bb35-4f56118fbd76`. It is pending, verdict-free, and held
under `COMPILE_EA_WORKER_ROLLOUT_PENDING`. Therefore there is no EX5, sealed
build hash, build-check PASS, or Q01 PASS.

## Binding Capacity Stop

Read-only `farmctl mt5-slots` at `2026-08-22T05:37:32Z` reported five active
governed terminals (`T1`, `T10`, `T2`, `T3`, and `T5`), with zero duplicate
terminal workers and zero orphaned processes. The separate `T_Live` and FTMO
processes were reported only by inventory; neither was accessed or controlled.

Five whole-host CPU samples at approximately four-second spacing were:

| Sample UTC | CPU |
|---|---:|
| `2026-08-22T05:37:33.1957551Z` | 93% |
| `2026-08-22T05:37:38.2768231Z` | 96% |
| `2026-08-22T05:37:43.2977138Z` | 85% |
| `2026-08-22T05:37:48.3895589Z` | 97% |
| `2026-08-22T05:37:53.4070941Z` | 79% |

Average CPU was 90.0 percent and maximum CPU was 97 percent. The explicit
hard ceiling was reached. Per the mission stop condition, no Q02 preview or
apply, dispatcher tick, tester run, smoke run, or backtest was started. Q02 is
additionally blocked by the absent governed compile/Q01 PASS. Read-only work-
item verification shows exactly one `QM5_41106` row: the held compile utility
item, with no Q02 row.

## Safe Handoff

After a separately authorized fleet-worker release lets the governed compiler
consume the bound MQ5, require strict compile PASS with zero errors/warnings,
a non-empty EX5, targeted build-check PASS, final setfile hash binding, and
static Q01 artifact PASS. Then repeat an immediate capacity sample and enqueue
exactly one `XTIUSD.DWX` D1 Q02 row only if all ceilings and dedup gates remain
open.

No live/demo/shadow/stress/optimization preset, manual tester, terminal
reservation or control, AutoTrading action, `T_Live` or deploy-manifest
change, portfolio-gate mutation, portfolio admission, decorrelation claim, or
correlation waiver occurred.

Machine-readable evidence:
`artifacts/qm5_41106_compile_handoff_20260822T053753Z_board_advisor.json`.
