# QM5_41092 WTI Weekly Body-Dominance Q01 Build

Date: 2026-08-21

Branch: `agents/board-advisor`

Scope: branch-only Q01 build and validation. No Strategy Tester run, terminal
control, AutoTrading, live/demo/shadow preset, portfolio-gate edit, deploy
manifest, or `T_Live` mutation was performed.

## Governed identity

- EA: `QM5_41092_wti-wbody-dominance-mom`
- Strategy: `MOP-WTI-WBODY-DOMINANCE-MOM-2026_S01`
- Host/traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- Magic: `410920000`
- Source approval: `06f2ed136`
- Bounded source packet: `069b4af00`
- EA-ID reservation: `1a02d01dd`
- G0-approved card: `6d185e5bc`
- Governed magic allocation and resolver regeneration: `a1f576e5c`

The approved card and the EA-local `docs/strategy_card.md` copy are byte
identical at SHA-256
`adae0698c802cbf09a1572a02a80d044fb4f91e8615dec42e32adfbe40a00211`.

## Implemented mechanic

At the first tradable D1 bar of a normalized Monday-anchored broker week, the
EA aggregates only the immediately completed three-to-five-session WTI week.
It buys on a positive weekly body or sells on a negative weekly body only when
the strict integer rule `3*abs(close-open) > 2*(high-low)` holds. Equality and
all invalid states consume the week flat. The attempt is persisted before
history, signal, spread, ATR, sizing, and order gates. Risk is fixed at
`RISK_FIXED=1000`, with `RISK_PERCENT=0`, a frozen `3.5*ATR(20,D1)` hard stop,
no target, and exact next-week closure with a ten-day stale repair.

The implementation contains no parent-week geometry, current-week signal
price, wick rule, close-location filter, range rank, moving average,
oscillator, volume, inventory, external data, ML, grid, martingale, scale-in,
or pyramid.

## Deterministic validation

1. `python framework/EAs/QM5_41092_wti-wbody-dominance-mom/docs/test_week_body_dominance_reference.py`
   passed 11/11 tests. Covered native and uniformly shifted labels, the
   180-minute boundary, exact Monday adjacency, three/four/five-session
   acceptance, two/six rejection, long and short strict dominance, exact
   threshold equality, sub-threshold and body-equality flat states, malformed,
   duplicate-date and current-week history rejection, one-attempt restart
   behavior, year boundaries, next-week exit, stale repair, and static
   fixed-risk/completed-data markers.
2. `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_41092_wti-wbody-dominance-mom_card.md`
   returned `status=ok`, no missing sections, and no ML hits.
3. `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_41092_wti-wbody-dominance-mom`
   returned one PASS and zero FAIL.
4. `framework/scripts/compile_one.ps1 ... -Strict` returned PASS with zero
   errors and zero warnings. Durable summary:
   `D:/QM/reports/compile/20260821_142311/summary.csv`.
5. Target-only strict `build_check.ps1` returned PASS with zero failures.
   Durable report:
   `D:/QM/reports/framework/21/build_check_20260821_142337.json`.

The build check emitted two advisory warnings because its card lookup checks
the flat draft store but does not recurse into the governed
`strategy-seeds/cards/approved/` store. No limit or GMT value was inferred.
The approved card exists, is G0 APPROVED, declares no GMT/UTC wall-clock
window or card-specific percentage loss limit, and is hash-identical to the
EA-local copy above; therefore the advisories do not change the Q01 verdict.

## Artifacts

| Artifact | SHA-256 |
|---|---|
| `QM5_41092_wti-wbody-dominance-mom.mq5` | `8ab57c0fede965dcdf4435dd3e153725f1a8525b340bcf31ba78859dee55f14f` |
| `QM5_41092_wti-wbody-dominance-mom.ex5` | `da0e57dee8b4b16887ee74f5ce2627a1b029553d489fbdd2cb43862a8fb9e224` |
| `QM5_41092_wti-wbody-dominance-mom_XTIUSD.DWX_D1_backtest.set` | `1ab7ce5e4ebd8019b08295bcccc5f689dd2a8f8888fc86a186c8152c22d145bc` |

Only the one D1 backtest preset exists. It explicitly locks both news axes
OFF, Friday close OFF, the exact body/range integers, and fixed-dollar risk.

## Verdict

`Q01 PASS`. The EA is compile-PASS and registry-clean for a paced, target-only
Q02 handoff. This does not assert economic merit, activity, decorrelation, or
portfolio admission; those remain downstream empirical gates.
