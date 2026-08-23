# QM5_41120 XAU/XAG fixed-open residence reversion — source build and CPU-ceiling handoff

Date: 2026-08-23

Branch: `agents/board-advisor`

EA: `QM5_41120_xauxag-mopen-residence-rv`

Outcome: **APPROVED SOURCE BUILD COMMITTED; EXACT COMPILE ITEM RELEASED AND
PENDING; CPU CEILING HIT; Q01 PENDING; Q02 NOT ENQUEUED**

## Completed non-duplicate commodity edge

QM5_41120 is one low-frequency, opposite-leg gold/silver relative-value
package. At the first synchronized D1 boundary of a broker month, it rebuilds
the immediately completed 17-to-23-session month from timestamp-identical
`XAUUSD.DWX` and `XAGUSD.DWX` closes. For chronological log-ratio closes:

```text
s[i]     = log(XAU_close[i]) - log(XAG_close[i])
anchor   = s[0]
m        = n - 1
above    = count(s[i] > anchor, i=1..n-1)
below    = count(s[i] < anchor, i=1..n-1)
required = ceil(3*m/4) = (3*m+3)//4

above >= required and s[n-1] > anchor => SELL XAU / BUY XAG
below >= required and s[n-1] < anchor => BUY XAU / SELL XAG
otherwise                              => FLAT
```

The first close is excluded from the denominator. Later equalities count
toward neither side, and the final close must independently remain on the
qualifying side. The monthly attempt is persisted before history, signal,
news, spread, quote, ATR, sizing, and order gates, so a flat or failed month
cannot acquire a retry.

Accepted legs target equal absolute USD notionals, share one aggregate
`RISK_FIXED=1000` budget, use frozen `3.5*ATR(20,D1)` stops, have no target,
and normally exit at the next broker month. This is a market-neutral design,
not evidence of profitability, beta neutrality, or decorrelation. Q09 alone
owns the realized portfolio result.

## Reputable source and non-duplicate boundary

The approved card and source already existed but had never been built because
its first magic allocation stopped at an unrelated legacy resolver inventory
defect. The source lineage is Schweikert (2018), *Journal of Banking &
Finance* 88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`; supporting
fractional-cointegration research from Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045; and CME Group's official *Gold & Silver Ratio
Spread*.

Those records support a related but state-dependent intermetal carrier. They
do not test the completed-month fixed-open residence rule, the three-quarter
threshold, contrarian translation, continuous CFDs, fixed-dollar basket risk,
or the QM book. All those elements remain disclosed QM falsification choices.

The canonical pre-allocation checker returned `CLEAN` across 4,619 registry
identities, 1,288 cards, and 45 Strategy-Wiki nodes. Manual review separates
this rule from adjacent-return breadth (`QM5_41112`), prior-month range
residence (`QM5_41110`), final-close rank (`QM5_41119`), location estimators,
rolling fitted ratio systems, and certified single-symbol XNG RSI pullback
`QM5_12567`. The immutable first-close anchor, exhaustive strict later-close
counts, ceiling-three-quarter threshold, final-side confirmation, and monthly
contrarian package are jointly load-bearing.

## Identity, registry, and commits

| Stage | Commit |
|---|---|
| durable source approval | `a7d733f31` |
| bounded source extraction | `2bb49c71f` |
| EA-ID reservation | `bf8a336c4` |
| approved G0 card | `26d2e4c43` |
| magic allocation and resolver binding | `af0fb64fc` |
| EA source, SPEC, manifest, reference suite, card binding, and fixed-risk set | `1e2cc637a` |

Execution identities are slot 0 `XAUUSD.DWX` / magic `411200000` and slot 1
`XAGUSD.DWX` / magic `411200001`. The resolver generator initially reproduced
the earlier block on missing legacy directories for IDs 1001, 1015, and 1016.
Following the later behavior-preserving branch precedent, regeneration used
transient materialization of only those expected directory names, retained
all existing bindings, deleted zero retired rows, used no `--allow-dropped`,
added exactly the two 41120 rows, and removed the transient directories. The
resolver now has 17,822 rows and its embedded registry SHA-256 is
`7B821FD790B7432BC61B961E4E091AB22B36A9E2C427F4FE3F79E117750E9A38`.

## Source-level validation

- Approved-card schema, G0 status, and prohibited-ML lint: PASS.
- Approved and EA-local cards are byte-identical at SHA-256
  `F5CB98D5E944F1293119652CFEA03D6F3E1A434549E12A60F7C0946823E5D878`.
- Registry ID, two magic rows, resolver identity, and exact EA directory: PASS.
- Deterministic reference suite: 7 tests PASS. Coverage includes every allowed
  17-23-session month, exact ceiling arithmetic, upper/lower directions,
  threshold equality, strict ties, final-side confirmation, immutable anchor,
  synchronization and month boundaries, durable attempts, and aggregate
  equal-notional fixed-risk sizing.
- SPEC validator: PASS.
- Build guardrails: PASS with zero findings across source and set.
- Symbol-scope validator: `BASKET_OK`, zero violations, exactly XAU and XAG.
- Scoped whitespace validation: PASS.

The sole logical-basket set is backtest-only and locks `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. It retains
`build_hash=pending` because no compiler output exists.

## Governed compile handoff

A direct strict build check refused before compilation under
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; the guard prescribed the governed
compile path and was not bypassed. Exactly one source-fresh compile item was
enqueued:

- work item: `30ff1030-eb5b-412d-a293-f4bc3f275b85`;
- source SHA-256:
  `B5744054C9DEB95A28F44829E9934F5A9EDA6D697357F53EE40A860290237741`;
- initial hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- exact release dry run: one selected item, enqueued and actual source hashes
  equal;
- exact apply: one hold released through the sanctioned rollout utility, with
  backup
  `D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260823T030845Z_45edcd2a.sqlite`
  at SHA-256
  `bbf93ebcc05a48c9759f9275e8e8930bc5cfe4e309209341697c4941c3004702`;
- last status before the binding stop: pending, unclaimed, no activation hold,
  no EX5, no build-check result, and no Q01 verdict.

No terminal was started, stopped, reserved, or dispatched by this session.
The resident worker remains the only allowed compiler path.

## CPU-ceiling stop and Q02 state

The pre-release five-sample whole-host check completed below the ceiling:
`73.76, 70.55, 71.96, 76.88, 84.52` percent, average 75.53 percent and
maximum 84.52 percent.

The fresh binding check at `2026-08-23T03:13:06.7769657Z` was:

`92.93, 82.86, 83.57, 94.18, 98.73` percent.

Average CPU was 90.45 percent and maximum CPU was 98.73 percent. The maximum
breached the paced-fleet 97 percent ceiling. Six `terminal64.exe` and two
`metatester64.exe` processes were present at the final sample.

This is the mission's explicit stop condition. No Q02 preview, Q02 row,
dispatcher tick, terminal reservation, or manual backtest was created. Q02 is
also gated by the pending strict compile, absent EX5, pending final set hash,
and absent Q01 PASS.

## Safe continuation and safety boundary

Let the already released compile item be consumed only by a resident worker
after capacity returns. Require zero compile errors and warnings, non-empty
EX5, strict build-check PASS, final set hash binding, and Q01 PASS. Then take a
fresh CPU sample and enqueue exactly one logical-basket Q02 row only below the
unchanged ceiling. Q02 must retire below five completed packages in any full
post-warm-up year rather than alter the approved mechanic.

No AutoTrading action, live/deploy artifact, `T_Live` mutation,
`T_Live`-manifest change, portfolio-gate change, portfolio admission,
correlation waiver, or decorrelation claim occurred.

Machine-readable companion:
`artifacts/qm5_41120_xauxag_mopen_residence_rv_source_build_q02_cpu_ceiling_handoff_20260823T031306Z_board_advisor.json`.
