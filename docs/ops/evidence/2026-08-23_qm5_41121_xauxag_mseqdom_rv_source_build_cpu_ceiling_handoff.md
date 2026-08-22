# QM5_41121 XAU/XAG monthly sequence-dominance reversion — CPU-ceiling handoff

Date: 2026-08-23

Branch: `agents/board-advisor`

EA: `QM5_41121_xauxag-mseqdom-rv`

Outcome: **SOURCE BUILD COMMITTED; CPU CEILING HIT; Q01 PENDING; Q02 NOT ENQUEUED**

## New commodity relative-value edge

QM5_41121 is one low-frequency, opposite-leg gold/silver relative-value
package. At the first synchronized D1 boundary of a broker month, it rebuilds
the immediately completed 17-to-23-session month from timestamp-identical
`XAUUSD.DWX` and `XAGUSD.DWX` closes. It forms chronological gold-minus-silver
log-ratio returns, rejects any exact-zero return, and classifies every adjacent
return-sign transition exactly once. A month qualifies when same-sign
sequences are at least as numerous as sign reversals. The package then fades
the net monthly ratio displacement: positive net displacement sells XAU and
buys XAG; negative net displacement buys XAU and sells XAG.

The attempt is persisted before history, signal, news, spread, quote, ATR,
sizing, and order gates, so a failed or flat state cannot acquire a retry.
Accepted legs target equal absolute USD notionals, share one aggregate
`RISK_FIXED=1000` budget, use frozen `3.5*ATR(20,D1)` stops, have no target,
and normally exit at the next broker month. This is a structurally different
carrier from the certified outright XAU/SP500/NDX/XNG book, but construction
does not prove neutrality, profitability, or decorrelation. Q09 alone owns
that later portfolio finding.

## Reputable source and non-duplicate boundary

The approved bounded packet is
`strategy-seeds/sources/SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026/source.md`.
Its lineage is Schweikert (2018), *Journal of Banking & Finance* 88, 44-51,
DOI `10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045; Cowles and Jones (1937), *Econometrica* 5(3),
280-294, DOI `10.2307/1905515`; and CME Group's official *Gold & Silver Ratio
Spread* education. These sources support the related-metal carrier and
sequence/reversal vocabulary. The exact month window, inclusive majority,
contrarian side, CFD mapping, fixed risk, and expected performance are
disclosed QM falsification choices rather than transferred source claims.

The fail-closed dedup receipt separates the rule from QM5_20275's six-return
fresh-run state, monthly breadth/block/range/location systems, rolling
ratio-center or scale estimators, and the certified single-symbol XNG
oscillator pullback. This implementation exhaustively counts every adjacent
sign transition inside exactly one completed broker month and uses the net
month displacement only to select the inverse package side.

## Deterministic identity and commits

| Stage | Commit |
|---|---|
| durable OWNER source approval | `91e138677` |
| bounded reputable-source extraction | `b7cd42641` |
| atomic EA-ID reservation | `9b19a5024` |
| approved G0 card and dedup receipt | `4e1c0d698` |
| immutable first magic-preflight block receipt | `5d0aa9e0c` |
| directory-first magic recovery, resolver, EA source, SPEC, manifest, tests, and fixed-risk set | `693910199` |

Execution identities are slot 0 `XAUUSD.DWX` / magic `411210000` and slot 1
`XAGUSD.DWX` / magic `411210001`, both D1. The logical tester symbol is
`QM5_41121_XAU_XAG_MSEQDOM_RV_D1`.

The earlier allocator attempt correctly aborted when strict resolver
regeneration exposed unrelated active legacy IDs without EA directories. That
receipt remains unchanged. This continuation created the exact EA directory
first, appended only the two registered 41121 rows, and regenerated with the
script's supported `--keep-obsolete` preservation mode. It kept 17,817 rows,
dropped zero, used no `--allow-dropped` bypass, and bound registry SHA-256
`DC6D80A2A0D0427EFFDA527A9418138B30F4B5472DE2CCCCC7094BDD08D66B47`.

## Source-level validation

- Approved-card schema and prohibited-ML lint: PASS.
- Build-prerequisite guard: PASS for registry ID, two magic rows, and exact EA
  directory.
- Deterministic reference suite: 8 tests PASS. Coverage includes every allowed
  17-23-session month, both directions, inclusive transition ties, reversal
  majorities, zero-return and zero-net handling, chronology sensitivity,
  synchronization/month boundaries, durable attempts, and aggregate
  equal-notional fixed-risk sizing.
- SPEC validator: PASS.
- Build guardrails: PASS with zero findings.
- Symbol-scope validator: `BASKET_OK`, zero violations, exactly XAU and XAG.
- Approved and EA-local cards are byte-identical at SHA-256
  `7DDE178C642E0CA0E488B3036E3D979E3AEB1C6BDEB20E133FC913FBCB5747A5`.
- Scoped `git diff --check`: PASS.

The sole logical-basket set is backtest-only and locks `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. It deliberately retains
`build_hash=pending`: no strict compile, EX5, build-check binding, or Q01 run
was attempted after the capacity stop.

## CPU-ceiling stop and Q02 state

Five consecutive whole-host `Processor(_Total)` samples from
`2026-08-22T23:48:27.9466289Z` through `2026-08-22T23:48:37.3386868Z` were
all `100.0%`. Average and maximum CPU were therefore both 100 percent, above
the paced-fleet hard ceiling of 97 percent. Read-only `farmctl mt5-slots`
reported seven active governed terminals (`T1`, `T2`, `T4`, `T6`, `T7`,
`T9`, and `T10`), six active `metatester64.exe` processes at the end of the
sample, no duplicate terminal workers, and no orphaned tester process.

This is the mission's binding stop condition. Compile status for the target
was `NOT_ENQUEUED`; no compile utility, Q02 preview, Q02 work item, dispatcher
tick, tester, terminal reservation, or manual backtest was created. Q02 also
remains gated by absent strict compile/EX5/final set binding/Q01 PASS.

## Safe continuation and safety boundary

After sustained whole-host CPU is below 97 percent, enqueue the source-fresh
governed compile and require zero errors/warnings, a non-empty EX5,
build-check PASS, final set binding, and Q01 PASS. Then take a fresh capacity
sample and enqueue exactly one logical-basket Q02 row. Q02 must retire the
baseline below five completed packages per full post-warm-up year rather than
alter the approved rule.

No AutoTrading action, live/deploy artifact, `T_Live` mutation,
`T_Live`-manifest change, portfolio-gate change, portfolio admission,
correlation waiver, or decorrelation claim occurred. `T_Live` and FTMO were
visible only in the read-only process inventory and were not touched.

Machine-readable companion:
`artifacts/qm5_41121_xauxag_mseqdom_rv_source_build_q02_cpu_ceiling_handoff_20260822T235430Z_board_advisor.json`.
