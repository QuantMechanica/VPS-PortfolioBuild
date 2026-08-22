# QM5_41115 WTI monthly three-block vote build and CPU-ceiling handoff

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41115_wti-mthirdvote-mom`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; CPU CEILING HIT; Q01 PENDING; Q02 NOT ENQUEUED`

## New commodity/energy candidate

QM5_41115 is a low-frequency direct-WTI structural continuation candidate on
exact `XTIUSD.DWX` D1 closes. On the first tradable normalized broker-month
bar, it reconstructs the immediately completed month and its consecutive
parent. Both require 17 through 23 unique sessions under one uniform raw or
plus-one-day energy-label convention.

Let `P` be the parent month's chronological final close and let the newest
month's closes be `C[0]...C[n-1]`. With `a=floor(n/3)` and `b=floor(2n/3)`,
the exhaustive chronological blocks are `log(C[a-1]/P)`,
`log(C[b-1]/C[a-1])`, and `log(C[n-1]/C[b-1])`. At least two strictly
positive signs trigger BUY; at least two strictly negative signs trigger
SELL. Zero casts no vote, return magnitude is ignored, and the full-month
endpoint sign is deliberately not an extra gate. The position holds until the
first later normalized broker month, with a forty-calendar-day stale repair.

This supplies direct physical-energy carrier exposure outside the certified
XAU/SP500/NDX/XNG book and differs from certified QM5_12567's long-only,
two-day XNG RSI2 pullback. Carrier and mechanic difference do not establish
profitability or decorrelation. Q09 alone owns that later finding.

## Reputable source and non-duplicate boundary

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-MTHIRDVOTE-MOM-2026/source.md`. Its governed
lineage is Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial
Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The
peer-reviewed paper supplies monthly own-price continuation and explicit WTI
carrier lineage. The chronological three-block vote, CFD mapping, fixed-dollar
risk, performance, and correlation are disclosed QM hypotheses; no source
result transfers.

The canonical pre-allocation check scanned 4,611 registry identities, 1,283
repository cards, and 45 Strategy-Wiki nodes, finding no exact or fuzzy match.
The post-allocation scan found only the newly allocated QM5_41115 registry
slug and strategy-ID self-hits.

Manual family review separates this mechanic from full-month endpoint signals,
two-half unanimity, daily-sign breadth voting, adjacent-month sign flips,
monthly OHLC geometry, and certified QM5_12567's XNG RSI2 pullback.

## Deterministic identity and commits

| Stage | Commit |
|---|---|
| source approval and clean pre-allocation receipt | `e3b7b5d156d1cc46d637119a18f9686fa9e3d2d2` |
| bounded reputable-source extraction | `ff371aadaa83596396116413f6b7d6a29a7544f6` |
| atomic EA-ID reservation | `9f2517a777b04b064114c58f17ab7fef496b1b08` |
| approved G0 card and post-allocation receipt | `7f476ea0b16d1f8ae75f8fd80718df41ac26bce4` |
| governed magic allocation and resolver | `a2dfeab7dbb3036858ad19e71fe6076790261934` |
| EA source, SPEC, reference suite, and fixed-risk set | `8f8f7f830a4204a91085266349cb1bd88364ffcd` |

The exact execution identity is slot 0, `XTIUSD.DWX`, magic `411150000`, D1.

## Source-level validation

- Card schema and prohibited-method lint: PASS.
- Build prerequisite guard: PASS for active EA 41115, its exact directory,
  and one active magic row.
- Independent reference suite: 13/13 PASS. Coverage includes BUY and SELL;
  every two-of-three permutation; endpoint-opposed majorities; zero votes;
  all 17/20/23-session boundaries and exhaustive splits; 16/24 rejection;
  malformed, duplicate, nonconsecutive, and current-month data; raw and
  plus-one labels; late attempts; lifecycle; static MQ5 markers; the fixed-risk
  set; and approved/local card identity.
- SPEC validator: PASS.
- Symbol-scope validator: `SINGLE_SYMBOL_OK`, zero violations.
- Approved and EA-local cards are byte-identical at SHA-256
  `55F51A934BD5F386BD511D0B45615E107AC466C488461C9BBC4DA2F259CCE3A9`.

The sole backtest set is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; both news axes and Friday close are OFF. It remains
deliberately unbound with `build_hash=pending` until strict compile/Q01.

## Governed compile and Q02 stop

Active `terminal64.exe` and `metatester64.exe` processes were observed before
the compile boundary. No ad-hoc compile, process stop, terminal restart,
include-mirror bypass, or terminal control was attempted.

Exactly one governed compile utility item was created:

- work item: `87cd0c24-273d-4e11-b7ef-408c8dbccc3f`;
- created: `2026-08-22T16:27:36Z`;
- state: pending, unclaimed, attempt count zero, verdict-free;
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- compile evidence, EX5, build-check result, and final set binding: absent.

Consequently Q01 is not PASS. No Q02 preview, backtest, dispatcher tick, or
Q02 queue mutation occurred.

## CPU ceiling stop

Five whole-host CPU samples at four-second spacing were all `100.0%`.
Average and maximum CPU were therefore both 100 percent. The maximum crossed
the explicit 97-percent backtest ceiling, so the OWNER instruction required
an immediate stop before Q02 queue mutation. Both capacity and the missing
Q01 artifacts are binding blockers.

## Safe continuation and safety boundary

After a separately authorized rollout releases the exact source-fresh compile
item, a resident worker may perform the strict build. Require zero errors and
warnings, target build-check PASS, a non-empty EX5, final set binding, and Q01
artifact validation. Then take a fresh capacity sample and enqueue exactly one
Q02 row only if every gate remains open and no sample reaches the ceiling.

No manual tester, smoke, dispatcher tick, terminal reservation, worker or
terminal restart, AutoTrading action, live/demo/shadow/stress/optimization
preset, `T_Live` or deploy-manifest change, portfolio-gate mutation,
portfolio admission, decorrelation claim, or correlation waiver occurred.

Machine-readable companion:
`artifacts/qm5_41115_compile_q02_handoff_20260822T162814Z_board_advisor.json`.
