# QM5_41123 XAU/XAG monthly path-efficiency reversion — CPU-ceiling handoff

Date: 2026-08-23

Branch: `agents/board-advisor`

EA: `QM5_41123_xauxag-mpath-eff-rv`

Outcome: **SOURCE BUILD COMMITTED; COMPILE ENQUEUED AND ACTIVATION-HELD; CPU CEILING HIT; Q01 PENDING; Q02 NOT ENQUEUED**

## New commodity relative-value edge

QM5_41123 is one low-frequency, opposite-leg gold/silver relative-value
package. At the first synchronized D1 boundary of a broker month, it rebuilds
the immediately completed 17-to-23-session month from timestamp-identical
`XAUUSD.DWX` and `XAGUSD.DWX` closes. For chronological log-ratio closes
`s[i]=log(XAU[i])-log(XAG[i])`, it sums every adjacent return into signed net
`N` and absolute path `P`. Exact-zero constituent returns remain valid.
When `P>0`, `abs(N)/P>=0.20`, and `N!=0`, the package fades the completed
month: positive N sells XAU and buys XAG; negative N buys XAU and sells XAG.

The attempt is persisted before history, signal, news, spread, quote, ATR,
sizing, and order gates, so a flat or failed state cannot acquire a retry.
Accepted legs target equal absolute USD notionals, share one aggregate
`RISK_FIXED=1000` budget, use frozen `3.5*ATR(20,D1)` stops, have no target,
and normally exit at the next broker month. This is a market-neutral design on
a commodity relative carrier, not evidence of beta neutrality, profitability,
or decorrelation. Q09 alone owns the realized portfolio result.

## Reputable source and non-duplicate boundary

The approved bounded packet is
`strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026/source.md`.
Its lineage is Schweikert (2018), *Journal of Banking & Finance* 88, 44-51,
DOI `10.1016/j.jbankfin.2017.11.010`; Moskowitz, Ooi, and Pedersen (2012),
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`; and CME Group's official *Gold-Silver Ratio
Spread*. Those sources support a related-metal carrier, completed-price path,
monthly clock, and auditable path statistic. The daily-ratio month, inclusive
0.20 gate, contrarian translation, CFD mapping, risk, and cadence are disclosed
QM falsification choices rather than transferred source results.

The fail-closed pre-allocation checker scanned 4,622 registry identities, 1,291
cards, and 45 Strategy-Wiki nodes and returned `CLEAN`. The post-allocation
receipt found only expected 41123 self-hits. This mechanic does not estimate a
rolling ratio center, scale, regression, rank, quantile, sign count, block
vote, sequence count, range location, or outright trend. Unlike
`QM5_20274_wti-path-eff`, it uses one synchronized XAU/XAG relative month,
two opposite legs, a 0.20 gate, and a contrarian side.

## Deterministic identity and commits

| Stage | Commit |
|---|---|
| durable OWNER source approval and pre-allocation dedup | `13cb898ac` |
| bounded reputable-source extraction | `e6fda1b67` |
| atomic EA-ID reservation | `7ca524a9d` |
| approved G0 card and post-allocation dedup | `533e6e78f` |
| two magic rows | `9ed11967e` |
| regenerated resolver binding | `ff8559a5c` |
| EA source, SPEC, manifest, reference suite, and fixed-risk set | `4129a2e7c` |
| byte-identical approved card binding and EOF cleanup | `5cae18728` |

Execution identities are slot 0 `XAUUSD.DWX` / magic `411230000` and slot 1
`XAGUSD.DWX` / magic `411230001`, both D1. The logical tester symbol is
`QM5_41123_XAU_XAG_MPATH_EFF_RV_D1`.

The resolver generator initially failed closed on three unrelated active
legacy IDs whose EA directories are absent. Regeneration retained those
pre-existing rows through transient directory materialization, kept 17,820
rows, dropped zero, used no `--allow-dropped` switch, and added exactly the
two 41123 rows. Its embedded registry SHA-256 is
`A25763A7B81D9A84400821CB859874EAFC00E5D7F3C51FADA42BD8687B4B1124`.

## Source-level validation

- Approved-card schema, G0 status, and prohibited-ML lint: PASS.
- Registry ID, two magic rows, resolver identity, and exact EA directory: PASS.
- Deterministic reference suite: 8 tests PASS. Coverage includes every allowed
  17-23-session month, both directions, zero constituent returns, P=0 and N=0
  flat, efficiency below/equal/above 0.20, path-order sensitivity,
  synchronization and month boundaries, durable attempts, and aggregate
  equal-notional fixed-risk sizing.
- SPEC validator: PASS.
- Build guardrails: PASS with zero findings across source and set.
- Symbol-scope validator: `BASKET_OK`, zero violations, exactly XAU and XAG.
- Approved and EA-local cards are byte-identical at SHA-256
  `77CCB0095F0CEAFAAA8C0599D752D565F5379A81795064EC8FE74275FAED000A`.
- Scoped whitespace validation: PASS after EOF cleanup.

The sole logical-basket set is backtest-only and locks `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. It deliberately retains
`build_hash=pending` because no compiler output exists.

## Compile handoff

A direct strict compile was attempted and refused before compilation by the
live-factory include-mirror guard with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry bypass was used. The
prescribed governed command enqueued only this EA:

- compile work item: `96d25526-218a-434f-95eb-36d80f1016b8`
- status at handoff: `pending`
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`
- EX5: absent
- build-check result: absent
- Q01: pending

The queue accepted the request but the compile worker cannot activate under
the current rollout hold. Build PASS is therefore not claimed.

## CPU-ceiling stop and Q02 state

Five consecutive whole-host `Processor(_Total)\% Processor Time` samples
completed at `2026-08-23T02:19:01.0799111Z`:

`86.94, 100.00, 100.00, 100.00, 98.39`

Average CPU was 97.07 percent and maximum CPU was 100 percent, breaching the
paced-fleet ceiling of 97 percent. The process sample saw ten
`terminal64.exe` and six `metatester64.exe` processes. A subsequent
read-only `farmctl mt5-slots` scan at `2026-08-23T02:21:44Z` reported eight
active governed terminals (`T2` through `T9`), no duplicate terminal
workers, and no orphaned tester process.

This is the mission's binding stop condition. No Q02 preview, Q02 work item,
dispatcher tick, terminal reservation, or manual backtest was created. Q02 is
also gated by absent strict compile, EX5, final set hash binding, and Q01 PASS.

## Safe continuation and safety boundary

After the compile-worker hold clears and sustained whole-host CPU is below 97
percent, consume the existing compile work item. Require zero compile errors
and warnings, a non-empty EX5, build-check PASS, final set hash binding, and
Q01 PASS. Then take a fresh capacity sample and enqueue exactly one logical
basket Q02 row. Q02 must retire the baseline below five completed packages in
any full post-warm-up year rather than alter the approved mechanic.

No AutoTrading action, live/deploy artifact, `T_Live` mutation,
`T_Live`-manifest change, portfolio-gate change, portfolio admission,
correlation waiver, or decorrelation claim occurred. `T_Live` and FTMO were
visible only in the read-only process inventory and were not touched.

Machine-readable companion:
`artifacts/qm5_41123_xauxag_mpath_eff_rv_source_build_q02_cpu_ceiling_handoff_20260823T022237Z_board_advisor.json`.
