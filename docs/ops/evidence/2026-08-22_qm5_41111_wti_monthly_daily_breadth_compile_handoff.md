# QM5_41111 WTI Monthly Daily-Breadth Build And Compile Handoff

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41111_wti-mdaybreadth-mom`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; Q01 PENDING; Q02 NOT_ENQUEUED_Q01_STOP`

## New structural energy candidate

`QM5_41111` is a low-frequency, symmetric direct-WTI continuation candidate on exact
`XTIUSD.DWX` D1. At the first tradable normalized D1 bar of a new broker-calendar month,
it reconstructs the immediately completed month and its parent, each with 17 to 23 sessions.
The parent final close anchors the first newest-month daily return; every later observation is
the adjacent completed-session close return.

The EA buys only when strictly more than half of those newest-month returns are positive and
the parent-final-to-newest-final net return is also positive. It sells under the exact negative
mirror. Flat observations remain in the denominator. Ties, no strict majority, endpoint
equality, breadth/net disagreement, malformed or nonconsecutive month packages, late
attachment, and retries consume the month flat.

Each accepted position uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, one durable attempt per month, exact next-month
closure, and a forty-day stale repair. The approved card expects eight annual entries and sets
the Q02 trade-count floor at five.

Direct WTI supplies a physical-energy carrier absent from the certified XAU/SP500/NDX/XNG
book. This is a materially different candidate exposure, not a realized decorrelation claim;
unchanged Q09 alone owns the correlation verdict.

## Reputable source and non-duplicate boundary

Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`, supplies peer-reviewed monthly own-price
continuation lineage, one-month formation/holding evidence, and explicit WTI membership.
The governed parent record contains an end-to-end paper read and SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
Daily-sign breadth confirmation is a disclosed QM mechanization; no paper performance
transfers to this continuous-CFD build.

The pre-allocation duplicate check examined 4,605 registry identities, 1,279 cards, and 45
Strategy-Wiki nodes and returned `CLEAN` with no match. Manual review separates this edge
from:

- `QM5_41084_wti-wdaybreadth-mom`, whose weekly formation and one-week hold use only
  three to five sessions;
- `QM5_20244_wti-tsmom12m-breadth`, which votes across twelve monthly returns;
- `QM5_20187_wti-tsmom1m`, which uses an unconditional two-close monthly sign;
- `QM5_41105` through `QM5_41108`, whose monthly OHLC geometry ignores adjacent
  daily-return breadth;
- `QM5_20273_wti-monthly-signrun`, which requires a consecutive run instead of majority
  breadth; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only two-day XNG oscillator pullback.

The post-allocation check returned only the two expected exact self-hits for `QM5_41111`
(slug and strategy ID) and no foreign collision.

## Durable commit trail

- source approval and pre-allocation evidence: `12ce51468`;
- bounded source packet: `21d97081f`;
- deterministic EA-ID reservation: `733571b9d`;
- Q00-approved card and post-allocation receipt: `99432fd40`; and
- governed magic, resolver delta, EA, SPEC, reference suite, and fixed-risk preset:
  `9e4f9a01d`.

The governed allocator assigned slot-zero magic `411110000`. The MQ5 SHA-256 is
`9FACD1EAD3ADE302180B06304BCAF7C51C4F3F083E23055ACC56EB309374D096`.
The pre-compile setfile SHA-256 is
`E401C808EF3EA28EE74CB3FB90DF32BEE07D3E474B26E972F0D07A3943AB3F2C`;
its `build_hash` correctly remains `pending` until governed compilation. The approved
card and EA-local copy are byte-identical at SHA-256
`1F630027A6D3B85D159AB59FF1105109780C3CD9FD677D1005080DB4EC79DCDE`.

## Source-level validation

The target-only deterministic reference suite passed 13/13 checks. It covers strict long and
short directions; 17/20/23-session acceptance; 16/24-session rejection; ties and no-majority
states; flat observations retained in the denominator; breadth/net disagreement; endpoint
equality; malformed, nonconsecutive, duplicate-date, and current-month rejection; native and
uniformly shifted labels; entry grace; persistent attempts; year rollover; next-month exit;
stale repair; and the fixed-risk/card/setfile contract.

The following source-level gates passed:

- approved-card schema and prohibited-ML lint;
- G0 card lint;
- SPEC document validation;
- build prerequisites;
- V5 build guardrails;
- single-symbol scope validation; and
- governed targeted magic/resolver allocation.

The approved card and EA-local card are byte-identical. These checks do not claim a compile,
EX5, Q01 PASS, tester result, economics, certification, or decorrelation.

## Governed compile and Q02 blocker

The ad-hoc strict build-check preflight refused before compilation because live factory
`terminal64.exe` processes make include mirroring unsafe. Its failure class was
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry, process stop, mirror bypass, terminal
reservation, or terminal action occurred.

The mandated governed command created exactly one compile utility item,
`4f496575-3813-43d1-9df4-5c3a81d0e4ff`. It is pending with attempt count zero, no verdict,
no evidence path, and activation hold `COMPILE_EA_WORKER_ROLLOUT_PENDING`. The controlled
hold-release ceremony requires separate authorization and was not bypassed.

Therefore no EX5 or sealed build hash exists and Q01 is not PASS. The target-only Q02 sweep
preview selected zero rows, and read-only work-item verification shows exactly the one pending
compile item with no Q02 row. Applying `enqueue-backtest --phase Q02` before its EX5 and Q01
evidence would violate the governed phase order, so no unsafe apply was attempted.

## Capacity observation

Five fresh whole-host CPU samples at approximately four-second spacing were:

| Sample UTC | CPU |
|---|---:|
| `2026-08-22T11:56:27.3555936Z` | 76.41% |
| `2026-08-22T11:56:31.3793572Z` | 61.75% |
| `2026-08-22T11:56:35.3829653Z` | 74.42% |
| `2026-08-22T11:56:39.3862084Z` | 71.60% |
| `2026-08-22T11:56:43.3946296Z` | 82.53% |

Average CPU was 73.34 percent and maximum CPU was 82.53 percent, below the explicit 97
percent ceiling. Capacity did not block this handoff; the absent governed compile/Q01 verdict
did.

## Safe continuation

After a separately authorized fleet-worker rollout releases the exact compile hold, let the
canonical worker consume the bound source. Require strict compile PASS with zero errors and
warnings, a non-empty EX5, target build-check PASS, final setfile hash binding, and static Q01
evidence. Then repeat an immediate five-sample capacity check and enqueue exactly one
`XTIUSD.DWX` D1 Q02 row only if every sample remains below 97 percent and the queue dedup
gate is open.

No live/demo/shadow/stress/optimization preset, manual tester, backtest, terminal process
control, AutoTrading action, `T_Live` or deploy-manifest change, portfolio-gate mutation,
portfolio admission, correlation waiver, or live-use claim occurred. Unrelated dirty
worktree files were preserved.

Machine-readable evidence:
`artifacts/qm5_41111_compile_handoff_20260822T115643Z_board_advisor.json`.
