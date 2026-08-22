# QM5_41108 WTI Monthly Range-Expansion Build / CPU Stop

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41108_wti-mrange-expansion-mom`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; Q01 PENDING; Q02 NOT_ENQUEUED_CPU_CEILING`

## New Structural Energy Candidate

`QM5_41108` is a low-frequency, symmetric direct-WTI continuation candidate
on exact `XTIUSD.DWX` D1. On the first tradable normalized bar of a new broker
month, it aggregates the two immediately completed consecutive 17-to-23-
session calendar months. It requires the newest completed monthly high-low
range to be strictly wider than the preceding completed monthly range, then
buys when the newest month closes above its own first open or sells when it
closes below that open. Equal or narrower ranges, monthly dojis, 16- or 24-
session packages, malformed or nonadjacent history, late attachment, and
retry states consume the month flat.

Each accepted position uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, one durable attempt per month, and a
normal next-month exit with a forty-day stale repair. Direct WTI adds a
physical-energy carrier and monthly expansion/continuation state unlike the
certified XAU/SP500/NDX/XNG book. That design difference is a candidate-
selection fact, not a realized decorrelation claim; Q09 owns the correlation
finding.

## Reputable Source And Non-Duplicate Boundary

Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`, supplies peer-reviewed monthly
own-price continuation lineage, one-month holding evidence, and explicit WTI
membership. The governed parent record contains an end-to-end 23-page paper
read and durable PDF hash. Completed-month OHLC aggregation and strict range-
expansion conditioning are disclosed QM translations; no paper or sibling
performance or correlation transfers to this continuous-CFD build.

The pre-allocation checker examined 4,597 registry identities, 1,276 cards,
and 45 Strategy-Wiki nodes. It found no exact identity and only expected
family-level fuzzy matches. Manual review separates:

- `QM5_41102_wti-mrange-migrate-mom`, which requires same-direction migration
  of both monthly endpoints, ignores monthly opens/closes, and can qualify
  when the newest range narrows;
- `QM5_41106_wti-mbody-dominance-mom`, which reads one month, has no parent-
  month comparison, and instead requires a strict majority body share;
- `QM5_41107_wti-minside-body-mom`, whose strict containment necessarily
  makes the newest range narrower and therefore has disjoint entry geometry;
- weekly WTI variants, whose three-to-five-session packages, weekly turnover,
  and one-week hold differ from this 17-to-23-session monthly lifecycle;
- `QM5_20187_wti-tsmom1m`, which follows an unconditional two-close monthly
  return without comparing two monthly range widths; and
- certified `QM5_12567_cum-rsi2-commodity`, a long-only two-day XNG oscillator
  pullback rather than symmetric monthly WTI continuation.

After deterministic allocation, the checker examined 4,598 registry
identities, 1,276 cards, and 45 Strategy-Wiki nodes. It returned only the new
`QM5_41108` self-hits and no foreign collision.

## Durable Commit Trail

- source approval and pre-allocation evidence: `de681718f`;
- bounded source packet: `a9a279cff`;
- deterministic EA-ID reservation: `2de3e2cc9`;
- Q00-approved card and post-allocation receipt: `9612dd539`;
- governed slot-zero magic `411080000`, resolver, and byte-identical local
  card: `0131fa6e2`; and
- EA source, SPEC, reference suite, and sole D1 fixed-risk backtest preset:
  `eead118b0`.

The MQ5 SHA-256 is
`315FBE4290C58FEFAEBBC50A90D498FCA1E61A015BCC00A3EAC9414C314CF7DB`.
The unbound pre-compile setfile SHA-256 is
`0277245A1FA38802801AA62F4A61A5795B46E993F7336A3F3EBFBE8F216B2E7B`;
its `build_hash` remains `pending` until governed compilation. The approved
card and EA-local copy are byte-identical at SHA-256
`8B6EEA055F1143E52C0B01442637E62839F0062DAA4B29F0052197D887850D25`.

## Source-Level Validation

The target-only deterministic reference suite passed 11/11 checks. It covers
strict long and short directions; 17/20/23-session acceptance; 16/24-session
rejection; range-width equality, narrower range, and expansion-doji flat
states; chronological first-open/final-close handling; malformed, zero-range,
nonconsecutive, duplicate-date, and current-month rejection; native and
uniformly shifted energy labels; the 180-minute entry grace; persistent
attempts; year rollover; next-month exit; stale repair; and the static fixed-
risk contract.

The build prerequisite guard, V5 guardrails, SPEC validator, single-symbol
scope validator, card schema/prohibited-method lint, G0 lint, and governed
targeted magic/resolver allocation guard all passed. The repository-wide
registry validator still reports unrelated pre-existing legacy debt; this
work neither repaired nor committed those rows. These source checks do not
claim a compile, EX5, strict build-check PASS, Q01 PASS, tester result,
economics, certification, or decorrelation.

## Governed Compile Blocker

The ad-hoc strict build wrapper refused before compilation because live
factory terminal processes make include mirroring unsafe. Its result was
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`, class `INCLUDE_MIRROR_REFUSED`; no
retry, process stop, include-mirror bypass, or terminal action occurred. The
receipt is at
`framework/build/compile/20260822_074946/QM5_41108_wti-mrange-expansion-mom.compile.log`.

The mandated governed command created exactly one compile utility item,
`34ec16fa-4c6a-4eea-9b8e-0e42c504d038`. It remains pending with attempt count
zero and no verdict under `COMPILE_EA_WORKER_ROLLOUT_PENDING`. Therefore there
is no EX5, sealed build hash, build-check PASS, or Q01 PASS.

## Binding Capacity Stop

Read-only `farmctl mt5-slots` at `2026-08-22T07:50:32Z` reported four active
governed terminals (`T1`, `T3`, `T4`, and `T8`), with zero duplicate terminal
workers and zero orphaned processes. Separate `T_Live` and FTMO processes
were inventory-only; neither was accessed or controlled.

Five fresh whole-host CPU samples at approximately five-second spacing were:

| Sample UTC | CPU |
|---|---:|
| `2026-08-22T07:50:39.6834848Z` | 97.76% |
| `2026-08-22T07:50:44.7113523Z` | 90.46% |
| `2026-08-22T07:50:49.7284623Z` | 99.42% |
| `2026-08-22T07:50:54.7317860Z` | 85.26% |
| `2026-08-22T07:50:59.7355777Z` | 92.38% |

Average CPU was 93.06 percent and maximum CPU was 99.42 percent. The maximum
exceeds the explicit 97 percent hard ceiling. Per the mission stop condition,
no Q02 preview or apply, dispatcher tick, tester run, smoke run, or backtest
was started. Q02 is independently blocked by the absent governed compile and
Q01 PASS. Read-only work-item verification shows exactly one `QM5_41108` row:
the held compile utility item, with no Q02 row.

## Safe Handoff

After a separately authorized fleet-worker release lets the governed compiler
consume the bound MQ5, require strict compile PASS with zero errors/warnings,
a non-empty EX5, targeted build-check PASS, final setfile hash binding, and
static Q01 artifact PASS. Then repeat an immediate five-sample capacity check
and enqueue exactly one `XTIUSD.DWX` D1 Q02 row only if every sample remains
below 97 percent and all dedup gates remain open.

No live/demo/shadow/stress/optimization preset, manual tester, terminal
reservation or control, AutoTrading action, `T_Live` or deploy-manifest
change, portfolio-gate mutation, portfolio admission, decorrelation claim, or
correlation waiver occurred. Unrelated dirty worktree files were preserved.

Machine-readable evidence:
`artifacts/qm5_41108_compile_handoff_20260822T075100Z_board_advisor.json`.
