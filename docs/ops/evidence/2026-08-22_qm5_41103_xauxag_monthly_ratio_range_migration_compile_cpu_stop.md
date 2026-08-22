# QM5_41103 XAU/XAG Monthly Ratio-Range Migration Reversion Build / CPU Stop

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41103_xauxag-mrange-migrate-rv`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; Q01 PENDING; Q02 NOT_ENQUEUED_CPU_CEILING`

## New Commodity Sleeve Candidate

`QM5_41103` is a low-frequency logical XAU/XAG relative-value basket. On the
first exact synchronized D1 boundary of a new broker month it builds
`log(XAU close)-log(XAG close)` for every synchronized session in each of the
two immediately completed consecutive calendar months. It fades only strict
migration of both observed range endpoints: an upward migration sells XAU and
buys XAG; a downward migration buys XAU and sells XAG. Equality, mixed
movement, zero range, 16 or 24 sessions, asynchronous or invalid closes,
nonconsecutive months, incomplete parent history, late attachment, and retry
states consume the month flat.

The two legs are one package. They target equal absolute USD notionals within
20 percent after downward lot rounding, share one `RISK_FIXED=1000` budget,
use frozen `3.5*ATR(20,D1)` hard stops, have no target, and close on the first
observed next-month boundary with a forty-day stale repair guard.

This differs from rolling XAU/XAG z-score, OLS-residual, return-rank,
variance-ratio, weekly-close-extreme, and weekly path families. It also differs
from certified `QM5_12567`, a single-symbol long-only two-day XNG oscillator
pullback. Equal notionals do not establish neutrality or decorrelation; Q09
alone may make a realized portfolio-correlation finding.

## Source And Non-Duplicate Boundary

Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`, supplies peer-reviewed state-dependent
gold/silver relationship lineage. CME Group's *Gold & Silver Ratio Spread*
supplies the intermarket carrier definition. Neither source tests the exact
completed-month endpoint-migration fade, continuous CFDs, package risk, or
economics; those are disclosed pre-result QM choices.

The pre-allocation checker scanned 4,592 registry rows, 1,271 repository
cards, and 45 Strategy-Wiki nodes and returned `CLEAN`, with no exact or fuzzy
match. The post-allocation receipt contains only the expected new `QM5_41103`
self-hit. The approved card records the manual family boundaries and the
verdict
`CLEAN_XAUXAG_COMPLETED_MONTH_RATIO_RANGE_MIGRATION_REVERSION_AFTER_FAMILY_REVIEW`.

## Durable Commit Trail

- source approval and pre-allocation dedup: `d947ea184`;
- bounded source extraction: `0aeb42b12`;
- deterministic EA-ID reservation: `47b8e7401`;
- G0-approved card and post-allocation dedup: `37d5a8943`;
- governed basket magics `411030000` and `411030001`: `4dd3eb620`;
- EA, local card, SPEC, basket manifest, reference suite, and sole logical D1
  fixed-risk preset: `1508804df`; and
- SPEC whitespace normalization: `06943044e`.

The source MQ5 SHA-256 is
`283426F456A4BD50CF161AE1AF2EBC8D5909BD5A55A1E27382885FF1B316BCB9`.
The unbound logical setfile SHA-256 is
`2F702F08432966D8F660E81A052A3D76C5EBBF922486CD7F67B9B1095A10E6AB`;
its `build_hash` correctly remains `pending` until governed compilation.

## Source-Level Validation

The independent reference suite passed 12/12 tests. It covers both
contrarian directions; equality, inside, outside, and mixed states flat;
17/23-session acceptance and 16/24 rejection; exact synchronization and
timestamp order; invalid closes and zero ranges; current-month leakage;
consecutive month identity and visible older boundary; the 180-minute clock;
one-shot attempt persistence; year rollover; joint risk/notional sizing; and
next-month/stale lifecycle contracts.

The build prerequisite guard, V5 build guardrails, SPEC validator, basket
symbol-scope validator, card schema/prohibited-ML lint, and G0 lint all passed.
The approved and EA-local card copies are byte-identical at SHA-256
`D879C7159045CFE9E42F043E7192A9BAE56536EE9CAC14541C05531B76AC052B`.
These checks do not claim a compile, EX5, Q01 PASS, tester result, economics,
or certification.

## Governed Compile Blocker

The direct strict compile stopped safely before MetaEditor execution because
live factory terminal processes make ad-hoc include mirroring unsafe. The
reason class was `INCLUDE_MIRROR_REFUSED`, with detail
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry, process stop, or bypass was
attempted. The refusal summary is
`D:/QM/reports/compile/20260822_023838/summary.csv`, SHA-256
`E68F3EED3CCFE7759C1E1654C62F30E1F95B64095E2C702E41CE29CEF7AE41B2`.

The mandated governed command created compile utility item
`e1e75830-9671-4541-b7b8-bcc5aaa7b54d`. It is pending, verdict-free, and held
under `COMPILE_EA_WORKER_ROLLOUT_PENDING`. That hold is released only through
the separately authorized reviewed fleet-restart ceremony and was not
bypassed. Therefore there is no EX5, sealed build hash, build-check PASS, or
Q01 PASS yet.

## Binding Capacity Stop

Read-only `farmctl mt5-slots` at `2026-08-22T02:40:40Z` reported four active
governed terminals (`T1`, `T2`, `T3`, and `T5`), with zero duplicate workers
and zero orphaned processes. The separate `T_Live` and FTMO processes were
only reported by inventory; neither was accessed or controlled.

Five whole-host CPU samples at approximately four-second spacing were:

| Sample UTC | CPU |
|---|---:|
| `2026-08-22T02:42:21.146Z` | 99% |
| `2026-08-22T02:42:25.436Z` | 77% |
| `2026-08-22T02:42:29.704Z` | 87% |
| `2026-08-22T02:42:33.970Z` | 76% |
| `2026-08-22T02:42:38.236Z` | 71% |

Average CPU was 82 percent and maximum CPU was 99 percent. The first sample
crossed the explicit 97 percent hard ceiling. Per the mission stop condition,
no Q02 preview/apply, dispatcher tick, tester run, smoke run, or backtest was
started. Q02 is additionally blocked by the absent governed compile/Q01 PASS.
Read-only work-item verification shows exactly one `QM5_41103` row: the held
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
`artifacts/qm5_41103_compile_handoff_20260822T024238Z_board_advisor.json`.
