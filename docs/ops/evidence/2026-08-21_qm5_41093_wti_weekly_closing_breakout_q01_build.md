# QM5_41093 WTI Weekly Closing-Breakout Q01 Build

Date: 2026-08-21

Branch: `agents/board-advisor`

Scope: branch-only Q01 build and validation. No Strategy Tester run, terminal
control, AutoTrading, live/demo/shadow preset, portfolio-gate edit, deploy
manifest, or `T_Live` mutation was performed.

## Governed identity

- EA: `QM5_41093_wti-wclose-breakout-mom`
- Strategy: `MOP-SZAKMARY-WTI-WCLOSE-BRK-2026_S01`
- Host/traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- Magic: `410930000`
- Source approval: `f0d8fe585`
- Bounded source packet: `cfaabdb97`
- EA-ID reservation: `2a20468ce`
- G0-approved card: `04cbd4f8f`
- Governed magic allocation and resolver regeneration: `d904213d2`

The approved card and the EA-local `docs/strategy_card.md` copy are byte
identical at SHA-256
`f46c3ee72059be5739be27a6bac72e748e3e1452b8e891675825001c12020f7d`.

## Implemented mechanic

At the first tradable D1 bar of a normalized Monday-anchored broker week, the
EA reconstructs the exact two immediately completed three-to-five-session WTI
weekly OHLC packages. It buys only when the newer package's chronological
final close is strictly above the parent package's aggregate high, and sells
only when that close is strictly below the parent aggregate low. Endpoint
equality, an inside-range close, malformed or nonadjacent packages, and late
attachment consume the week flat.

The attempt is persisted before history, signal, spread, ATR, sizing, and
order gates. Risk is fixed at `RISK_FIXED=1000`, with `RISK_PERCENT=0`, a
frozen `3.5*ATR(20,D1)` hard stop, no target, and exact next-week closure with
a ten-day stale repair.

The implementation contains no newest-body gate, close-location threshold,
both-sided outside-expansion requirement, endpoint-migration rule, range
rank, current-week signal price, moving average, oscillator, volume,
inventory, external data, ML, grid, martingale, scale-in, or pyramid.

## Deterministic validation

1. `python framework/EAs/QM5_41093_wti-wclose-breakout-mom/docs/test_week_closing_breakout_reference.py`
   passed 13/13 tests. Coverage includes native and uniformly shifted labels,
   the 180-minute boundary, exact Monday adjacency, three/four/five-session
   acceptance, two/six rejection, strict long and short final-close
   breakouts, both endpoint equalities and an inside close flat, independence
   from newest-body sign and the opposite range endpoint, malformed,
   duplicate-date and current-week history rejection, one-attempt restart
   behavior, year boundaries, next-week exit, stale repair, and static
   fixed-risk/completed-data markers.
2. `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_41093_wti-wclose-breakout-mom_card.md`
   returned `status=ok`, no missing sections, and no ML hits.
3. `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_41093_wti-wclose-breakout-mom`
   returned one PASS and zero FAIL.
4. `framework/scripts/compile_one.ps1 ... -Strict` returned PASS with zero
   errors and zero warnings. Durable summary:
   `D:/QM/reports/compile/20260821_160343/summary.csv`.
5. Target-only strict `build_check.ps1` returned PASS with zero failures.
   Durable report:
   `D:/QM/reports/framework/21/build_check_20260821_160421.json`.
6. `python framework/scripts/p1_build_validation.py --ea QM5_41093`
   returned PASS. Durable report:
   `D:/QM/reports/pipeline/QM5_41093/P1/P1_QM5_41093_result.json`.

The build check emitted two advisory warnings because its card lookup checks
the flat draft store but does not recurse into the governed
`strategy-seeds/cards/approved/` store. No limit or GMT value was inferred.
The approved card exists, is G0 APPROVED, declares no GMT/UTC wall-clock
window or card-specific percentage loss limit, and is hash-identical to the
EA-local copy above; therefore the advisories do not change the Q01 verdict.

## Artifacts

| Artifact | SHA-256 |
|---|---|
| `QM5_41093_wti-wclose-breakout-mom.mq5` | `a08d389fc6c6d59acdf2bd8334ef122ff74227a3cb3eae7bb21f39366cfbf63d` |
| `QM5_41093_wti-wclose-breakout-mom.ex5` | `2e2988a0b87c4d9616bcf92a0ced83d45b94e75288814eb8c9a2d00ae29a8aee` |
| `QM5_41093_wti-wclose-breakout-mom_XTIUSD.DWX_D1_backtest.set` | `f49034b680a88f0589be29e50cce5c61c5dd5a8541e96b61c73ad6a687684ecc` |
| strict build report | `640d1d1e6c9b9aabaa9513371d6249179beb2fefb030efdfc26228e4fe024f7c` |
| static P1 report | `7fb3e9791335951037012c89b2c0989815b0e2056ec4e061fa6190610137d126` |

The setfile's normalized source build hash is
`234c1d9263097b7a2cd70bb79d8dbc181f38ce0d1e55a0866253dfc322d86eeb`.
Only the one D1 backtest preset exists. It explicitly locks both news axes
OFF, Friday close OFF, the exact weekly-package inputs, and fixed-dollar risk.

## Verdict

`Q01 PASS`. The EA is compile-PASS and target-registry-clean for a paced,
target-only Q02 handoff. This does not assert economic merit, activity,
decorrelation, or portfolio admission; those remain downstream empirical
gates.
