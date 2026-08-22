# QM5_41110 XAU/XAG monthly outside-range residence build and CPU stop

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41110_xauxag-moutside-res-rv`

## Outcome

QM5_41110 is a committed, non-duplicate source build for one low-frequency,
market-neutral commodity package. It is not compiled and Q02 is not enqueued.
The exact governed compile item is released and pending, but the fresh whole-
host capacity sample reached 100.00%, above the binding 97% backtest CPU
ceiling. The mission's explicit stop rule therefore ended work before any Q02
queue mutation or tester start.

The diversification case is structural, not a realized-correlation claim. The
EA trades an equal-notional XAU/XAG relative-value package rather than outright
XAU beta; only downstream governed portfolio testing may establish actual
decorrelation from the certified XAU/SP500/NDX/XNG book.

## Edge and reputable source case

At the first synchronized D1 boundary of a broker month, the EA reconstructs
the immediately completed and parent calendar months, requiring 17 to 23 exact
synchronized XAU/XAG sessions in each. It computes the fixed-unit log ratio
`log(XAU close) - log(XAG close)` and the parent's observed range.

It sells XAU and buys XAG only when at least five newest-month ratio closes are
strictly above the parent maximum, none is below the parent minimum, and the
chronologically final newest-month close remains above the range. The exact
lower mirror buys XAU and sells XAG. Equality is inside; any opposite breach,
sub-threshold residence, or final close back inside stays flat.

The governed intake combines:

- Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
  `10.1016/j.jbankfin.2017.11.010`, for reputable peer-reviewed evidence that
  the gold/silver long-run relationship can be state-dependent; and
- CME Group's official *Gold & Silver Ratio Spread* research for the
  intermarket carrier definition and differing gold/silver economic drivers.

The exact completed-month residence-and-final-close rule is disclosed as a QM
mechanization. No source performance, constant cointegrating-vector claim, CFD
result, or portfolio-correlation claim transfers.

## Identity and duplicate control

The canonical pre-allocation scan covered 4,599 EA-registry rows and 1,278
cards. Its default Strategy-Wiki path was absent, so it failed closed rather
than claiming a complete pass. The corrected post-allocation scan used the
actual governed Wiki vault and covered 4,600 registry rows, 1,278 cards, and 45
Wiki nodes. It returned only the expected self identity.

Manual family review separates QM5_41110 from rolling z-score, OLS,
variance-ratio, weekly closing-extreme, weekly sign-breadth, monthly
range-migration, monthly median-shift, and within-month mean-versus-median
XAU/XAG rules. None counts persistent one-sided closes beyond a separate
parent-month range while requiring zero opposite breaches and final-close
persistence.

## Durable build trail

| Stage | Commit |
|---|---|
| OWNER source approval | `58523766b` |
| reproducible source extraction | `7df05e3f7` |
| deterministic EA-ID reservation | `5c35ee622` |
| approved G0 Strategy Card | `bccc8224f` |
| two-slot magic allocation and resolver | `02d461b58` |
| EA source, SPEC, basket manifest, reference suite, fixed-risk set | `04db53787` |

Allocated execution identities:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | `XAUUSD.DWX` | `411100000` |
| 1 | `XAGUSD.DWX` | `411100001` |

The logical test carrier is
`QM5_41110_XAU_XAG_MOUTSIDE_RES_RV_D1`, hosted on `XAUUSD.DWX` D1. The preset
locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes
OFF, Friday close OFF, one combined package risk budget, frozen
`3.5*ATR(20,D1)` stops on both legs, no targets, a maximum 20% notional
mismatch, one attempt per month, next-month exit, and 40-day stale repair.

## Source validation

- Card-schema and prohibited-output lint: PASS.
- Deterministic G0 lint: PASS.
- Build prerequisites: PASS for the active EA row, exact slug/directory, and
  both active magic rows.
- SPEC validator: PASS.
- Build guardrails: PASS across the MQ5 and fixed-risk set.
- Symbol-scope validator: `BASKET_OK`, exactly XAU and XAG.
- Independent deterministic reference suite: 11/11 PASS, covering both
  directions, exact threshold, final-close requirement, opposite-breach veto,
  endpoint equality, session bounds, parent-range validity, synchronization,
  calendar adjacency, one-shot state, joint sizing, and static contract.
- Approved and EA-local cards are byte-identical.
- Stale scaffold-token scan: no hits.
- No `.ex5` exists, no compile PASS is claimed, and the set remains explicitly
  `build_hash=pending`.

Key SHA-256 bindings:

| File | SHA-256 |
|---|---|
| MQ5 | `402EBB6D33219222BC29B7484354DD7E144F1CA3312F2D415E9CD8157427579E` |
| SPEC | `56D19A4381E462EBB7A74C95195A5A95D813384AC4430788F4E1A84536D2C7DF` |
| Basket manifest | `0B1838DCE5888004A1FBBDDD573DB13D7DE151715C32850BCE081D5EAA7E0CFA` |
| Reference suite | `8A194A6E5DCD195E1F9C2B75E9304B42191CF5D2DB19E1A362367E2911062928` |
| Approved/local card | `4CAFE267C3192C5D583CD7C6A3D1F9DDA2A7D54C22B27D088C5A5E507AAA22D7` |
| Backtest set | `371C50341658850F146DA6F78A1A4426D37E2975A6D51A040779EBAF0CD0B397` |

## Governed compile handoff

The strict ad-hoc build path refused fail-closed with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because live factory `terminal64`
processes make shared include mirroring unsafe. No terminal was stopped and no
override or retry loop was used.

The canonical compile enqueue and exact bounded release are:

- work item: `58d5cd89-d9db-4a82-82e1-66e93171b8cd`;
- phase/kind: `COMPILE_EA` / `compile`;
- status at stop: `pending`, attempt 0, unclaimed;
- activation hold: none after exact one-item release;
- source SHA at enqueue and release:
  `402ebb6d33219222bc29b7484354dd7e144f1ca3312f2d415e9cd8157427579e`;
- pre-release database backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260822T103011Z_e050f7d5.sqlite`,
  SHA-256
  `01923681f9f2617e3b74f5cb29cb21b2db165de324126d94569043318dd27b41`.

The release changed only this exact source-fresh item's activation hold. It did
not claim a terminal, start MetaEditor, launch a tester, or create a gate
verdict.

## Capacity stop and Q02

Read-only `farmctl mt5-slots` at `2026-08-22T10:37:53Z` reported active
governed tester terminals T1, T2, T3, and T5, ten resident terminal workers,
zero duplicate workers, and zero orphaned tester processes. Separate T_Live
and FTMO terminal processes were excluded from governed occupancy and were not
accessed or controlled.

The binding whole-host sample was:

| UTC | CPU | Ceiling |
|---|---:|---:|
| `2026-08-22T10:40:56.6684382Z` | 100.00% | 97.00% |

Because that sample crossed the ceiling, no Q02 preview/apply, dispatcher tick,
reservation, tester process, or manual backtest followed. The post-stop EA
work-item query contains exactly one row: the pending `COMPILE_EA` item above.
There is no Q02 row.

The lawful handoff is: let the paced fleet finish the governed compile when it
has a quiescent slot, require strict compile/build-check PASS and a real `.ex5`
binding, then take a fresh below-ceiling capacity sample before enqueuing
exactly one logical-basket Q02 row from the committed fixed-risk preset.

## Safety

No AutoTrading state was toggled, no terminal process was stopped, no manual
backtest was run, and no T_Live file, T_Live manifest, portfolio gate, or
portfolio manifest was touched.

Machine-readable companions:

- `artifacts/qm5_41110_compile_wave_release_20260822.json`
- `artifacts/qm5_41110_compile_q02_cpu_stop_20260822T104056Z_board_advisor.json`
