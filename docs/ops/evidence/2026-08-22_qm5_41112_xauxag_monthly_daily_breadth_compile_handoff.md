# QM5_41112 XAU/XAG monthly daily-breadth build and compile handoff

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41112_xauxag-mdaybreadth-rv`

Outcome: `SOURCE BUILD COMMITTED; COMPILE QUEUED_ACTIVATION_HELD; Q01 PENDING; Q02 NOT_ENQUEUED_Q01_STOP`

## New commodity relative-value candidate

QM5_41112 is a low-frequency, two-leg gold/silver relative-value candidate on
exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX` D1 closes. At the first
tradable D1 boundary of a broker-calendar month, it reconstructs the two
immediately preceding completed calendar months. Each must contain 17 through
23 exact synchronized close pairs.

The parent month's chronological final log ratio anchors every daily relative
return in the newest completed month. The EA sells XAU and buys XAG only when
a strict majority of all those relative returns is positive and the final
ratio displacement is positive. The negative mirror buys XAU and sells XAG.
Zero returns stay in the denominator and count toward neither sign; ties,
endpoint disagreement, invalid history, and current-month leakage consume the
month flat.

The attempt is durable before all fallible gates. Accepted opposite-side legs
target equal absolute USD notionals, share one aggregate `RISK_FIXED=1000`
budget, use frozen `3.5*ATR(20,D1)` hard stops, have no target, and close at
the next broker month with a forty-day stale repair. This carrier is
structurally distinct from outright XAU, index, and XNG direction, but the
construction does not establish realized neutrality or decorrelation. Q09
alone owns that later finding.

## Reputable source and non-duplicate boundary

The bounded source packet is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026/source.md`.
Its governed lineage is Schweikert (2018), *Journal of Banking & Finance* 88,
44-51, DOI `10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045, DOI
`10.1016/j.resourpol.2021.102045`; and CME Group's official *Gold & Silver
Ratio Spread* education. Those sources support testing a state-dependent
gold/silver relationship and the ratio carrier. The completed-month daily-
sign breadth, endpoint conjunction, contrarian direction, CFD mapping, risk,
and lifecycle are disclosed QM hypotheses; no source performance, hedge
ratio, neutrality, CFD equivalence, or correlation result transfers.

The canonical pre-allocation check covered 4,608 registry identities, 1,280
repository cards, and 45 Strategy-Wiki nodes and returned `CLEAN`. The
post-allocation scan found only QM5_41112's expected self identity. Manual
family review separates this rule from QM5_41085's five-session weekly
four-of-five breadth, QM5_20275's six-return fresh run, monthly ratio range,
location, and distribution rules, outright WTI monthly breadth, and the
certified single-symbol XNG oscillator pullback.

## Deterministic identity and commits

| Stage | Commit |
|---|---|
| source approval and pre-allocation receipt | `6b0270433` |
| bounded reputable-source extraction | `191e20d0f` |
| atomic EA-ID reservation | `f6ba77e4a` |
| approved G0 card and post-allocation receipt | `653923b2c` |
| governed two-slot magic allocation and resolver | `c48abb338` |
| EA source, SPEC, manifest, reference suite, and fixed-risk set | `28b41c2c3` |

Allocated execution identities:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | `XAUUSD.DWX` | `411120000` |
| 1 | `XAGUSD.DWX` | `411120001` |

## Source-level validation

- Card schema and prohibited-ML lint: PASS.
- G0 card lint: PASS.
- Build prerequisite guard: PASS for active EA 41112, the exact directory,
  and the magic registry.
- Independent reference suite: 12/12 PASS. It covers both directions,
  majority/net disagreement, equality-inclusive denominator, exact session
  bounds for both months, synchronization and chronology failures,
  nonconsecutive months, invalid/current-month observations, parent-final
  anchor orientation, year rollover, one-shot attempts, joint fixed-risk
  sizing, static source/set/manifest markers, and card-copy identity.
- Build guardrails: PASS with zero findings across the MQ5 and setfile.
- SPEC validator: PASS.
- Symbol-scope validator: `BASKET_OK`, exactly XAU and XAG.
- Approved and EA-local cards are byte-identical at SHA-256
  `FEB9BAE7E1C79D0A6F867AA952D4D4FB8FF48F108ED4942D4083C77AF1A0D987`.

Artifact SHA-256 bindings at handoff:

| Artifact | SHA-256 |
|---|---|
| bounded source | `5398CB1D466D62EEBAE913AC952F4AE536D3924B527E8EBF795CFDE7BC6B89DB` |
| approved/build card | `FEB9BAE7E1C79D0A6F867AA952D4D4FB8FF48F108ED4942D4083C77AF1A0D987` |
| MQ5 | `5C37B603666E602013C00AA0E6014C352980874C02870663E38637B12E6B1C5B` |
| SPEC | `304EE2437C3BBB484494AB6E4EFD956177867585DBD4318B03FBC3CF4A9C0563` |
| basket manifest | `C7F82CD1F2A63C77B2B4EFE2C9DBF9F3AC3AFF8FB3C47DA2BB20074F68553DCF` |
| reference suite | `FAA01251532D5B295D0EEBCCEA4BC23A6747314EC19F4F2BC9FD2455AFA8DC0E` |
| unbound fixed-risk set | `99E70E4A371098414C5D7DBCDB721139A3C0906D92B24D4CD3EC681E7A6E056B` |

## Governed compile and Q02 stop

The targeted strict build-check stopped before compilation with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because `terminal64.exe` processes were
alive. No retry, include-mirror bypass, or process stop occurred.

The mandated governed enqueue created exactly one compile utility item:

- work item: `eb39f64b-4a53-4971-bb78-907fd067a0d9`;
- created: `2026-08-22T13:01:24Z`;
- state: pending, attempt 0, unclaimed, verdict-free;
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- compile evidence, EX5 hash, build-check result, and setfile binding: absent.

The hold may be released only through the separately authorized governed
compile-worker rollout ceremony. It was not released, bypassed, or edited by
this mission. Consequently Q01 is not PASS. The exact non-applying Q02 sweep
for EA `QM5_41112` and logical symbol
`QM5_41112_XAU_XAG_MDAYBREADTH_RV_D1` selected zero rows. Its receipt is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json`, SHA-256
`B86B243BF7BF19A07C0009C852F7A60C59E07D6936D462252AC315FEAA22DD7F`.
There is no Q02 work item; applying one without a strict compile, EX5, final
set binding, and Q01 PASS would violate the governed artifact gates.

## Capacity observation

Read-only `farmctl mt5-slots` at `2026-08-22T13:02:11Z` reported only T2
running governed tester work, ten resident terminal workers, zero duplicate
workers, and zero orphaned tester processes. T_Live and FTMO were inventory-
only observations and were neither accessed nor controlled.

Five whole-host CPU samples at four-second spacing were:

| UTC | CPU |
|---|---:|
| `2026-08-22T13:02:40.765Z` | 59.28% |
| `2026-08-22T13:02:44.767Z` | 65.04% |
| `2026-08-22T13:02:48.768Z` | 67.19% |
| `2026-08-22T13:02:52.768Z` | 71.95% |
| `2026-08-22T13:02:56.768Z` | 62.80% |

Average CPU was 65.25 percent and maximum CPU was 71.95 percent, below the
97-percent ceiling. Capacity was not the binding stop; absent governed
compile/Q01 evidence was.

## Safe continuation and safety boundary

After a separately authorized rollout releases the exact source-fresh compile
item, let a resident worker perform the strict build. Require zero errors and
warnings, target build-check PASS, a non-empty EX5, final set binding, and P1
artifact validation. Then take a fresh capacity sample and enqueue exactly one
logical-basket Q02 row if every gate remains open.

No manual tester, smoke, dispatcher tick, terminal reservation, worker or
terminal restart, AutoTrading action, live/demo/shadow/stress/optimization
preset, `T_Live` or deploy-manifest change, portfolio-gate mutation,
portfolio admission, decorrelation claim, or correlation waiver occurred.

Machine-readable companion:
`artifacts/qm5_41112_compile_q02_handoff_20260822T130439Z_board_advisor.json`.
