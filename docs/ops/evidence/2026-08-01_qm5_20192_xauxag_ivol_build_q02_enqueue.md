# QM5_20192 XAU/XAG Pure-IVol Basket Build And Q02 Enqueue

Date: 2026-08-01 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20192_xauxag-ivol`

Strategy ID: `FUERTES-MOMIVOL-2015_XAU_XAG_S03`

## Outcome

One new low-frequency structural commodity candidate was researched, carded,
allocated, built, strictly compiled, and handed to the paced Q02 fleet. Once
per broker month it estimates 252 XAU and XAG residual returns against an
equal-weight XTI/XNG/XAU/XAG commodity factor, buys the lower-idiosyncratic-
volatility metal, and shorts the higher-idiosyncratic-volatility metal.

This is a two-leg relative-value construction. It does not establish dollar,
beta, volatility, market, or portfolio neutrality. Q01 is `PASS`. Q02 has
exactly one work item, `37be7fda-97c5-403a-9e99-4dfc22594621`, which was
`pending`, attempt 0, and unclaimed at enqueue confirmation. No Q02 result or
certification is claimed here.

## Source And Approval Boundary

The governed source packet is
`strategy-seeds/sources/FUERTES-MOMIVOL-2015/source.md`. Its primary source is
Fuertes, Miffre, and Fernandez-Perez (2015), "Commodity Strategies Based on
Momentum, Term Structure and Idiosyncratic Volatility," *Journal of Futures
Markets* 35(3), 274-297, DOI `10.1002/fut.21656`.

The packet records a prior complete accepted-manuscript review and the
2026-08-01 OWNER commodity/energy sleeve mission as the durable S03 extraction
basis. A bounded public-source refresh through the deterministic reader
returned `PERMISSION_REQUIRED` / `DEFERRED:SOURCE_POLICY`; no arbitrary fresh
page text was substituted. The source supports rolling OLS residual
volatility, monthly low-IVol-long/high-IVol-short ranking, an equal-weight
commodity-factor alternative, and one-top/one-bottom portfolios. It does not
test this four-CFD factor, two-metal carrier, QM stops, costs, or portfolio.

## Frozen Mechanic

- Logical basket: `QM5_20192_XAU_XAG_IVOL_D1`; tester host:
  `XAUUSD.DWX` D1.
- Traded slot 0: `XAUUSD.DWX`, magic `201920000`; traded slot 1:
  `XAGUSD.DWX`, magic `201920001`.
- Read-only factor members: `XTIUSD.DWX` and `XNGUSD.DWX`.
- Decision: first tradable XAU D1 bar after a genuine broker-month change.
- State: exactly 253 synchronized completed closes and 252 log returns for all
  four symbols; gaps over seven calendar days fail closed.
- Signal: regress XAU and XAG separately on an intercept plus the equal-weight
  four-commodity return; buy the lower residual standard deviation and sell
  the higher. Absolute differences at or below `1e-12` stay flat.
- Attempt state: persist and consume the month before history, news, signal,
  spread, sizing, or order gates; no same-month retry.
- Risk: one `RISK_FIXED=1000` package budget, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, independent `3.0 * ATR(20,D1)` hard stops, and a 20%
  maximum rounded dollar-notional mismatch.
- Exit: next broker-month transition or 35-calendar-day stale guard, plus hard
  stops and atomic orphan/partial-package repair.
- Both news axes, legacy news mode, Friday close, and stress rejection are OFF.
- Density prior: approximately 12 completed packages/year after warm-up; Q02
  retires below five/year.

## Non-Duplicate Evidence

Before allocation, `research_dedup_check.py check` evaluated the full mechanic
against 4,248 registry rows and 379 cards. It returned no exact duplicate. The
only fuzzy matches were the expected same-source systems:

- `QM5_13133_energy-ivol` trades XTI/XNG with the pure-IVol estimator; and
- `QM5_13113_energy-mom-ivol` trades XTI/XNG and also requires momentum/IVol
  agreement.

Manual carrier review resolved both because S03 trades XAU/XAG and has no
momentum gate. Existing XAU/XAG systems use ratio or level convergence,
conditional quantiles, calendar differentials, return shocks, or momentum
ranks; none ranks the metals by factor-residual volatility. Changing the
carrier, factor, estimator, lookback, cadence, or direction requires a new
card.

## Deterministic Allocation

EA ID `20192` is active in `ea_id_registry.csv`. The magic registry contains
the two active traded-leg rows above; read-only factor members receive no magic
rows.

The supported resolver generator was run with `--keep-obsolete`, retaining
15,372 rows and dropping zero. A prefix comparison against HEAD confirmed all
15,370 prior EA, slot, symbol, and magic entries were byte-for-byte equivalent
at the parsed-array level, followed only by the two new rows. Resolver registry
SHA-256: `27628210621E3D48B638DE5E30018BA742655D28EA7843DC157679FDC3651E35`.

The complete source, card, registries, resolver, MQ5, EX5, SPEC, manifest,
build-time card, and fixed-risk setfile were committed on this branch as
`60ecf46e4`.

## Q01 Evidence

- Strategy-card schema lint: PASS, no missing sections or ML hits.
- Card-v2 source/QM/execution/dependency/falsification section lint: PASS.
- Candidate build guard: PASS for approved G0 card, registry rows, folder, and
  slug.
- Seven-section SPEC validation: PASS.
- Basket symbol-scope validation: `BASKET_OK`, zero violations.
- Basket work-item routing tests: 15 passed.
- Strict MetaEditor compile:
  `D:/QM/reports/compile/20260801_084326/summary.csv` -- `PASS`, reason `OK`,
  strict true, zero errors, zero warnings.
- Strict compile log:
  `framework/build/compile/20260801_084326/QM5_20192_xauxag-ivol.compile.log`.
- Full strict V5 build check:
  `D:/QM/reports/framework/21/build_check_20260801_083647.json` -- `PASS`, zero
  failures, zero warnings.
- Setfile build hash:
  `d91cd572b8afb79a991caf95559110ea79a9d324512ecef2b6991cefd5feaabe`.

The execution contract remains `DRAFT` and has no promotable registry entry.
That is intentional: G0 authorizes this build and non-live Q02 handoff, while
execution-contract approval remains a separate future promotion gate.

## Artifact Hashes

| Artifact | SHA-256 |
|---|---|
| MQ5 | `82d036a82edff44213f6fdfb9a1692602da8b1bbdf5cbfdf8a27a6b48ed786e8` |
| EX5 | `c5b2dc8ca3da31fc5639333631e40e2ba83b66e9cebea6890edc6e887d97c4e7` |
| SPEC | `27383a9a7eaefccb01805de072f2a195eb513d3d4f123c903f7f879f6a2b4791` |
| basket manifest | `b9f7235f04ca4116ddd8383405dd8ce0e9847fb600b275343f75e4bd56fa3eb5` |
| build-time card | `1e7f11cb24a357686228f2f114d82d98f54fab692fbf613bb2e34feb31fb0287` |
| backtest setfile | `a56320adac1cc01a6b58a8393126b53241e68e1525498a77d7c9a30d7793633c` |
| canonical card after Q02 handoff | `2595c8e2026f5f28daa5cc1035364422868f067ca3ee4b8c2f315cc4d9c7d91a` |
| approved card pointer after Q02 handoff | `cbe07fe7445d9a0f9df64268dd5c8cd4d0f38bc707aee3548b5f61503fd36f47` |
| source packet | `27ea217cdd7a919ee8628b19d3e5ec1b0f5dc52d050032861d99fd0dcfeb62b0` |
| magic resolver | `083af3b5465086d78d3f804bb8ee21ead0af40e8bb3b32873c5cc50bbfd0aeec` |

## Paced Q02 Handoff

The EA-and-symbol-scoped dry run selected exactly one never-tested logical
basket, with no stranded retry and no deferred promotion. Initial apply
attempts encountered the live factory mutation lock and made no mutation. The
same idempotent scope then acquired the lock and inserted exactly one row:

- item: `37be7fda-97c5-403a-9e99-4dfc22594621`;
- phase/kind: `Q02` / `backtest`;
- logical symbol/timeframe: `QM5_20192_XAU_XAG_IVOL_D1` / D1;
- setfile:
  `QM5_20192_xauxag-ivol_QM5_20192_XAU_XAG_IVOL_D1_D1_backtest.set`;
- created: `2026-08-01T08:46:27+00:00`;
- status at confirmation: `pending`, attempt 0, unclaimed;
- priority track: true; and
- queue at apply: 2,005 pending against the 7,000-row ceiling.

The pre-enqueue and immediate post-enqueue capacity scans each found three
non-live factory tester processes, below the seven-process ceiling. The
separate `C:/QM/mt5/T_Live/MT5_Base/terminal64.exe` process was excluded. This
work did not launch or reserve a tester or terminal.

## Safety And Next Gate

No live setfile, AutoTrading toggle, `T_Live` mutation, deploy manifest,
T_Live manifest, portfolio-gate change, portfolio admission, or correlation
waiver was created. The paced fleet owns Q02 from this point. A Q02 pass would
still not certify the strategy or prove portfolio orthogonality; the remaining
gates, including Q09 portfolio correlation, must be satisfied independently.
