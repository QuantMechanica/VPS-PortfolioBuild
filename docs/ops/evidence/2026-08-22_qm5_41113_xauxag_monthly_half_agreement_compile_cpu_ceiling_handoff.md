# QM5_41113 XAU/XAG monthly half-agreement build and CPU-ceiling handoff

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41113_xauxag-mhalfagree-rv`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; CPU CEILING HIT; Q01 PENDING; Q02 NOT ENQUEUED`

## New commodity relative-value candidate

QM5_41113 is a low-frequency, two-leg gold/silver relative-value candidate on
exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 closes. At the first
tradable D1 boundary of a broker-calendar month, it reconstructs the two
immediately preceding completed calendar months. Each must contain 17 through
23 exact synchronized close pairs.

Let `P` be the parent month's final synchronized log ratio, let the newest
month's chronological ratios be `Q[0]...Q[n-1]`, and set `k=floor(n/2)`. The
first cumulative leg is `Q[k-1]-P`; the second is `Q[n-1]-Q[k-1]`. Both
positive triggers SELL XAU / BUY XAG; both negative triggers BUY XAU / SELL
XAG. Equality, sign disagreement, bad chronology, an invalid split,
asynchronous history, or current-month leakage consumes the month flat.

The attempt is durable before all fallible gates. Accepted opposite-side legs
target equal absolute USD notionals, share one aggregate `RISK_FIXED=1000`
budget, use frozen `3.5*ATR(20,D1)` hard stops, have no target, and close at the
next broker month with a forty-day stale repair. This is structurally distinct
from outright XAU, index, and XNG direction, but the construction does not
establish realized neutrality or decorrelation. Q09 alone owns that later
finding.

## Reputable source and non-duplicate boundary

The bounded source packet is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MHALFAGREE-RV-2026/source.md`.
Its governed lineage is Schweikert (2018), *Journal of Banking & Finance* 88,
44-51, DOI `10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; and CME
Group's official *Gold & Silver Ratio Spread* education. Those sources support
testing a state-dependent gold/silver relationship and the ratio carrier. The
two-half condition, contrarian direction, CFD mapping, risk, and lifecycle are
disclosed QM hypotheses; no source performance, hedge ratio, neutrality, CFD
equivalence, or correlation result transfers.

The canonical pre-allocation check covered 4,609 registry identities, 1,281
repository cards, and 45 Strategy-Wiki nodes. It found no exact collision and
one fuzzy family neighbor, QM5_41112. Manual review separates QM5_41112's
daily-sign majority plus endpoint rule from QM5_41113's two cumulative
chronological legs. A path can pass either and fail the other. The
post-allocation scan found only QM5_41113's expected self identity.

## Deterministic identity and commits

| Stage | Commit |
|---|---|
| source approval and pre-allocation receipt | `895531aef` |
| bounded reputable-source extraction | `8356c6bba` |
| atomic EA-ID reservation | `4d68e13a3` |
| approved G0 card and post-allocation receipt | `82896811b` |
| governed two-slot magic allocation and resolver | `cbc1c5070` |
| EA source, SPEC, manifest, reference suite, and fixed-risk set | `8bfede1e782b33c7d5d6aa9bb53a4f165ede3e88` |

Allocated execution identities:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | `XAUUSD.DWX` | `411130000` |
| 1 | `XAGUSD.DWX` | `411130001` |

## Source-level validation

- Card schema and prohibited-method lint: PASS.
- G0 card lint and governed approval: PASS.
- Build prerequisite guard: PASS for active EA 41113, exact directory, and two
  magic rows.
- Independent reference suite: 13/13 PASS. It covers both directions,
  half-sign disagreement, equality flat, even/odd floor splits, exact session
  bounds for both months, synchronization and chronology failures,
  nonconsecutive months, invalid/current-month observations, parent-final
  anchor orientation, year rollover, one-shot attempts, joint fixed-risk
  sizing, static source/set/manifest markers, and card-copy identity.
- SPEC validator: PASS.
- Symbol-scope validator: `BASKET_OK`, exactly XAU and XAG.
- Approved and EA-local cards are byte-identical at SHA-256
  `D335264A558E5A8C675D0E7723738CF03CF851311E8F0C983669320E5AF647A7`.
- Build guardrails and strict compile remain pending because their common
  entry point was factory-guard refused before either ran.

Artifact SHA-256 bindings at handoff:

| Artifact | SHA-256 |
|---|---|
| bounded source | `E255831AC46A4AA0E3AF22BA1FBBF86D9C4BF4CDA8DC47A19EE5ACB7424FBD44` |
| approved/build card | `D335264A558E5A8C675D0E7723738CF03CF851311E8F0C983669320E5AF647A7` |
| MQ5 | `FF830FBB5A81673C31F8D80D475A2304CA37FD06137AB8C725C4E729BDD42109` |
| SPEC | `D641AA1CD1A8B121071AE0B33BDD48CBB1AF2E611C601CC71C0A3BCCE5CA9012` |
| basket manifest | `35506CB451BB57EAE55BC207EEF8CFFFCE85FA94816A51C268538623DFAECBA7` |
| reference suite | `3AF4B0D0D870FF270E3E8B1ED8D1E8A9BA9B341C27188E00BCF38CB760EC3DB4` |
| unbound fixed-risk set | `D89BAD7E90F4C1895700C426933B1483D4A2076597CC9F0D32A6E64B1E72DF1E` |

## Governed compile and Q02 stop

The targeted strict compile and the non-compiling build-check entry point both
stopped before validation with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because
`terminal64.exe` processes were alive. No retry, include-mirror bypass,
process stop, or terminal control occurred.

The mandated governed enqueue created exactly one compile utility item:

- work item: `f29ebccb-c2ce-49dd-8031-6d24760b0ecc`;
- state: pending, unclaimed, verdict-free;
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- compile evidence, EX5, build-check result, and final setfile binding: absent.

The hold may be released only through the separately authorized governed
compile-worker rollout ceremony. It was not released, bypassed, or edited by
this mission. Consequently Q01 is not PASS. The exact non-applying Q02 sweep
for `QM5_41113` selected zero rows. Its receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`D94EB4A965726189759EBCD24B7C763F666614B9DF3A914EF7A723457202AC6E`.
There is no Q02 work item. Applying one without strict compile, EX5, final set
binding, and Q01 PASS would violate the governed artifact gates.

## CPU ceiling stop

Five whole-host CPU samples at four-second spacing were:

| Sample | CPU |
|---:|---:|
| 1 | 89.31% |
| 2 | 89.11% |
| 3 | 91.25% |
| 4 | 89.41% |
| 5 | 99.27% |

Average CPU was 91.67 percent and maximum CPU was 99.27 percent. The maximum
crossed the 97-percent backtest ceiling, so the OWNER instruction required an
immediate stop before Q02 queue mutation. Both CPU capacity and missing Q01
artifacts are binding blockers.

## Safe continuation and safety boundary

After a separately authorized rollout releases the exact source-fresh compile
item, let a resident worker perform the strict build. Require zero errors and
warnings, target build-check PASS, a non-empty EX5, final set binding, and Q01
artifact validation. Then take a fresh capacity sample and enqueue exactly one
logical-basket Q02 row only if every gate remains open and no sample reaches
the ceiling.

No manual tester, smoke, dispatcher tick, terminal reservation, worker or
terminal restart, AutoTrading action, live/demo/shadow/stress/optimization
preset, `T_Live` or deploy-manifest change, portfolio-gate mutation,
portfolio admission, decorrelation claim, or correlation waiver occurred.

Machine-readable companion:
`artifacts/qm5_41113_compile_q02_handoff_20260822T135256Z_board_advisor.json`.
