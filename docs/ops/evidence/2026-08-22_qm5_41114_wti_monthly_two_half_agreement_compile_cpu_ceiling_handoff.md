# QM5_41114 WTI monthly two-half agreement build and CPU-ceiling handoff

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41114_wti-mhalfagree-mom`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; CPU CEILING HIT; Q01 PENDING; Q02 NOT ENQUEUED`

## New commodity/energy candidate

QM5_41114 is a low-frequency direct-WTI structural continuation candidate on
exact `XTIUSD.DWX` D1 closes. On the first tradable broker-month bar, it
reconstructs the two immediately preceding consecutive completed months. Each
must contain 17 through 23 unique sessions under one uniform energy-label
convention.

Let `P` be the parent month's chronological final close, let the newest
month's chronological closes be `C[0]...C[n-1]`, and set `k=floor(n/2)`.
The two exhaustive cumulative legs are `log(C[k-1]/P)` and
`log(C[n-1]/C[k-1])`. Both positive triggers BUY; both negative triggers
SELL. Equality, sign disagreement, malformed chronology, an invalid split,
or current-month leakage consumes the month flat. The trade holds until the
first later normalized broker month, with a forty-calendar-day stale repair.

This supplies direct physical-energy exposure outside the certified
XAU/SP500/NDX/XNG book and differs from certified QM5_12567's long-only,
two-day XNG RSI2 pullback. Carrier and mechanic difference do not establish
profitability or decorrelation. Q09 alone owns that later finding.

## Reputable source and non-duplicate boundary

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-MHALFAGREE-MOM-2026/source.md`. Its governed
lineage is Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial
Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The
peer-reviewed paper supplies monthly own-price continuation and explicit WTI
carrier lineage. The chronological two-half state, CFD mapping, fixed-dollar
risk, performance, and correlation are disclosed QM hypotheses; no source
result transfers.

The canonical pre-allocation check scanned 4,610 registry identities, 1,282
repository cards, and 45 Strategy-Wiki nodes. It found no exact or fuzzy
candidate match. The post-allocation scan found only the allocated
QM5_41114 slug and strategy-ID self-hits.

Manual family review separates this mechanic from:

- QM5_41021's full-month plus nested final-five rule and five-session hold;
- QM5_41023's fixed opening/final-five segments and five-session hold;
- QM5_41111's individual daily-sign majority plus endpoint agreement;
- QM5_20187's unconditional nonzero one-month endpoint signal;
- QM5_41064's adjacent complete-month sign-flip rule;
- QM5_41105 through QM5_41108's monthly OHLC geometry; and
- certified QM5_12567's XNG RSI2 pullback.

## Deterministic identity and commits

| Stage | Commit |
|---|---|
| source approval and clean pre-allocation receipt | `3e3264609c1711c9ae80e5ee5261901bfc25fb24` |
| bounded reputable-source extraction | `d0383641df801b30d89984a072d3a07bf0bf0a5a` |
| atomic EA-ID reservation | `97e2d2ddd89f77b0600c367d143c101d8c234d2a` |
| approved G0 card and post-allocation receipt | `b9b4f0fb01dc0c8cca1927d3f71312078dc0d8b5` |
| governed magic allocation and resolver | `a1375e697ca0c3537c5c63ea720ebe501a032eb0` |
| EA source, SPEC, reference suite, and fixed-risk set | `160da264f83d61e904467a69b5d7fbc7c1a37d1c` |

The exact execution identity is slot 0, `XTIUSD.DWX`, magic `411140000`, D1.

## Source-level validation

- Card schema/prohibited-method lint: PASS.
- G0 card lint and governed approval: PASS.
- Build prerequisite guard: PASS for active EA 41114, its exact directory,
  and one active magic row.
- Independent reference suite: 13/13 PASS. Coverage includes both directions,
  equality and half-sign disagreement, 17/20/23-session acceptance,
  16/24-session rejection, odd floor splits, duplicate and invalid session
  labels, month adjacency and year rollover, current-month leakage, durable
  one-shot attempts, lifecycle, static MQ5 markers, fixed-risk set values, and
  local-card identity.
- SPEC validator: PASS.
- Symbol-scope validator: `SINGLE_SYMBOL_OK`, zero violations.
- Approved and EA-local cards are byte-identical at SHA-256
  `29D4E16B1B14DA0C34CB209D853D75E6DF225D39799A1FA7FDEBCB50358AE86A`.

The sole backtest set is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; both news axes and Friday close are OFF. It remains
deliberately unbound with `build_hash=pending` until strict compile/Q01.

## Governed compile and Q02 stop

The targeted strict compile stopped before compilation with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because `terminal64.exe` processes were
alive. No retry, include-mirror bypass, process stop, or terminal control
occurred.

The mandated governed enqueue created exactly one compile utility item:

- work item: `3e958389-60d9-4709-afb2-efdd2efe3965`;
- created: `2026-08-22T15:09:36Z`;
- state: pending, unclaimed, attempt count zero, verdict-free;
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- compile evidence, EX5, build-check result, and final set binding: absent.

Consequently Q01 is not PASS. No Q02 preview, backtest, dispatcher tick, or
queue mutation occurred after the capacity check.

## CPU ceiling stop

Five whole-host CPU samples at four-second spacing were:

| Sample | CPU |
|---:|---:|
| 1 | 99.78% |
| 2 | 77.12% |
| 3 | 64.24% |
| 4 | 84.01% |
| 5 | 89.92% |

Average CPU was 83.01 percent and maximum CPU was 99.78 percent. The maximum
crossed the explicit 97-percent backtest ceiling, so the OWNER instruction
required an immediate stop before Q02 queue mutation. Both capacity and the
missing Q01 artifacts are binding blockers.

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
`artifacts/qm5_41114_compile_q02_handoff_20260822T151029Z_board_advisor.json`.
