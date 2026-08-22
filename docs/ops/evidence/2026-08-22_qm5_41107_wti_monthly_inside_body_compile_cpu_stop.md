# QM5_41107 WTI Monthly Inside-Body Build / CPU Stop

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41107_wti-minside-body-mom`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; Q01 PENDING; Q02 NOT_ENQUEUED_CPU_CEILING`

## New Structural Energy Candidate

`QM5_41107` is a low-frequency, symmetric direct-WTI continuation candidate
on exact `XTIUSD.DWX` D1. On the first tradable normalized bar of a new broker
month, it aggregates the two immediately completed consecutive 17-to-23-
session calendar months. It buys when the newest full range is strictly
inside its parent range and the newest month closes above its own first open;
it sells under the same strict containment condition when the newest month
closes below its own first open. Equal range endpoints, equal open/close,
non-inside geometry, 16 or 24 sessions, malformed or nonadjacent history, late
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
read and durable PDF hash. Completed-month OHLC aggregation, strict parent-
range containment, and the contained-month body state are disclosed QM
translations; no paper or sibling performance transfers to this continuous-
CFD build.

The pre-allocation checker examined 4,596 registry identities, 1,275 cards,
and 45 Strategy-Wiki nodes. It found no exact identity and only expected
inside/body-family siblings. Manual review separates:

- `QM5_41091_wti-winside-body-mom`, whose two three-to-five-session weeks,
  weekly turnover, and one-week hold differ from two 17-to-23-session calendar
  months and a next-month lifecycle;
- `QM5_41102_wti-mrange-migrate-mom`, which requires same-direction range-
  endpoint migration and excludes opens and closes;
- `QM5_41106_wti-mbody-dominance-mom`, which reads one month, has no parent
  geometry, and requires a strict majority body share;
- `QM5_20187_wti-tsmom1m`, which follows every nonzero two-close monthly
  return without strict range containment; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only two-day XNG oscillator
  pullback rather than symmetric monthly WTI continuation.

After allocation, the checker returned only the new `QM5_41107` registry
self-hits and no foreign collision.

## Durable Commit Trail

- source approval and pre-allocation evidence: `dca99885d`;
- bounded source packet: `1bf582724`;
- deterministic EA-ID reservation: `5746329a5`;
- Q00-approved card and post-allocation receipt: `8e62b338a`;
- governed slot-zero magic `411070000` and resolver: `3abcbecf5`;
- EA source, SPEC, reference suite, and sole D1 fixed-risk preset:
  `eeabd9f39`; and
- byte-identical local approved-card copy: `1fd04ed38`.

The MQ5 SHA-256 is
`1125FFC0A52E53B9AB0197FFF04CE80307BC6E19A9E184E7736710AA917C382E`.
The unbound pre-compile setfile SHA-256 is
`332092F233FC767F24C27879B08366D0E0AD96E76F08439DC3CEF0BC9658AF38`;
its `build_hash` remains `pending` until governed compilation. The approved
card and EA-local copy are byte-identical at SHA-256
`B2F0C1A6A2B23C482C7F643FA740857A470A44A2F3F13DCA126F02FE78BACF16`.

## Source-Level Validation

The target-only deterministic reference suite passed 11/11 checks. It covers
strict long and short directions; 17/20/23-session acceptance; 16/24-session
rejection; containment equality, non-inside, and inside-doji flat states;
chronological first-open/final-close side; malformed, zero-range,
nonconsecutive, duplicate-date, and current-month rejection; native and
uniformly shifted energy labels; the 180-minute entry grace; persistent
attempts; year rollover; next-month exit; stale repair; and the static fixed-
risk contract.

The build prerequisite guard, V5 guardrails, SPEC validator, single-symbol
scope validator, card schema/prohibited-method lint, and G0 lint all passed.
The first build-prerequisite invocation used display-form `QM5_41107`; the
guard reads raw numeric CSV IDs, so its corrected `41107` invocation is the
recorded PASS. These source checks do not claim a compile, EX5, strict build-
check PASS, Q01 PASS, tester result, economics, certification, or
decorrelation.

## Governed Compile Blocker

The ad-hoc strict build wrapper refused before execution because live factory
terminal processes make include mirroring unsafe. Its failure class was
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry, process stop, include-mirror
bypass, or terminal action occurred.

The mandated governed command created exactly one compile utility item,
`44e72083-6aa3-4618-a3d4-9ec4d04c02db`. It is pending, verdict-free, and held
under `COMPILE_EA_WORKER_ROLLOUT_PENDING`. Therefore there is no EX5, sealed
build hash, build-check PASS, or Q01 PASS.

## Binding Capacity Stop

Read-only `farmctl mt5-slots` at `2026-08-22T06:53:56Z` reported five active
governed terminals (`T1`, `T2`, `T3`, `T4`, and `T6`), with zero duplicate
terminal workers and zero orphaned processes. Separate `T_Live` and FTMO
processes were reported only by inventory; neither was accessed or
controlled.

Five fresh whole-host CPU samples at approximately four-second spacing were:

| Sample UTC | CPU |
|---|---:|
| `2026-08-22T06:54:14.5954908Z` | 98.06% |
| `2026-08-22T06:54:18.6168146Z` | 99.90% |
| `2026-08-22T06:54:22.6505090Z` | 99.43% |
| `2026-08-22T06:54:26.6560244Z` | 96.39% |
| `2026-08-22T06:54:30.6769534Z` | 99.14% |

Average CPU was 98.58 percent and maximum CPU was 99.90 percent. Both exceed
the explicit 97 percent hard ceiling. Per the mission stop condition, no Q02
preview or apply, dispatcher tick, tester run, smoke run, or backtest was
started. Q02 is additionally blocked by the absent governed compile/Q01 PASS.
Read-only work-item verification shows exactly one `QM5_41107` row: the held
compile utility item, with no Q02 row.

## Safe Handoff

After a separately authorized fleet-worker release lets the governed compiler
consume the bound MQ5, require strict compile PASS with zero errors/warnings,
a non-empty EX5, targeted build-check PASS, final setfile hash binding, and
static Q01 artifact PASS. Then repeat an immediate five-sample capacity check
and enqueue exactly one `XTIUSD.DWX` D1 Q02 row only if average and maximum
remain below 97 percent and all dedup gates remain open.

No live/demo/shadow/stress/optimization preset, manual tester, terminal
reservation or control, AutoTrading action, `T_Live` or deploy-manifest
change, portfolio-gate mutation, portfolio admission, decorrelation claim, or
correlation waiver occurred.

Machine-readable evidence:
`artifacts/qm5_41107_compile_handoff_20260822T065430Z_board_advisor.json`.
