# QM5_41094 XNG Weekly Body-Dominance Q01 Build

Date: 2026-08-21

Branch: `agents/board-advisor`

Scope: branch-only Q01 build and validation. No Strategy Tester run, terminal
control, AutoTrading, live/demo/shadow preset, portfolio-gate edit, deploy
manifest, or `T_Live` mutation was performed.

## Governed identity

- EA: `QM5_41094_xng-wbody-dominance-mom`
- Strategy: `MOP-XNG-WBODY-DOMINANCE-MOM-2026_S01`
- Host/traded symbol: exact `XNGUSD.DWX`, D1, slot 0
- Magic: `410940000`
- Source approval: `dde254814`
- Bounded source packet: `e9ef00eee`
- EA-ID reservation: `7f96a75e4`
- G0-approved card: `195d0eb84`
- Governed magic allocation and resolver regeneration: `2afc53d26`

The approved card and EA-local `docs/strategy_card.md` copy are byte identical
at SHA-256
`5d74fe7eddf14683efa68d3830a0a99f4eefc045805e616744289ac310f88594`
after the Q02 CPU-ceiling status handoff; the Q01 build commit carried the
same card contract with its pre-handoff pipeline-status fields.

## Implemented mechanic

At the first tradable D1 bar of a normalized Monday-anchored broker week, the
EA aggregates only the immediately completed three-to-five-session natural-
gas week. It buys on a positive weekly body or sells on a negative weekly body
only when the strict integer rule `3*abs(close-open) > 2*(high-low)` holds.
Equality and every invalid state consume the week flat. The attempt is
persisted before history, signal, news, spread, quote, ATR, sizing, and order
gates.

Risk is `RISK_FIXED=1000`, with `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, a 3,000-point XNG entry-spread ceiling,
and exact next-week closure with a ten-day stale repair. The implementation
contains no parent comparison, current-week signal price, wick rule, close-
location filter, range rank, moving average, oscillator, volume, inventory,
external data, ML, grid, martingale, scale-in, or pyramid.

This logic is structurally different from certified `QM5_12567`, which is a
long-only two-day cumulative-RSI2 pullback below a slow mean. Reusing the XNG
carrier does not establish decorrelation; Q09 alone owns that result.

## Deterministic validation

1. `python -m unittest framework/EAs/QM5_41094_xng-wbody-dominance-mom/docs/test_week_body_dominance_reference.py -v`
   passed 11/11 tests. Coverage includes native and uniformly shifted labels,
   the 180-minute boundary, exact Monday adjacency, three/four/five-session
   acceptance, two/six rejection, long and short strict dominance, exact
   threshold equality, sub-threshold and body-equality flat states, malformed,
   duplicate-date and current-week history rejection, one-attempt restart
   behavior, year boundaries, next-week exit, stale repair, and static
   XNG/fixed-risk/completed-data markers.
2. `python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_41094_xng-wbody-dominance-mom_card.md`
   returned `status=ok`, no missing sections, and no prohibited-token hits.
3. `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_41094_xng-wbody-dominance-mom`
   returned one PASS and zero FAIL.
4. `framework/scripts/compile_one.ps1 ... -Strict` returned PASS with zero
   errors and zero warnings. Durable summary:
   `D:/QM/reports/compile/20260821_183048/summary.csv`.
5. Target-only strict `build_check.ps1 -EALabel
   QM5_41094_xng-wbody-dominance-mom -SkipCompile` returned PASS with zero
   failures. Durable report:
   `D:/QM/reports/framework/21/build_check_20260821_183207.json`.
6. `python framework/scripts/p1_build_validation.py --ea QM5_41094` returned
   PASS. Durable static artifact report:
   `D:/QM/reports/pipeline/QM5_41094/P1/P1_QM5_41094_result.json`.

The build check emitted two advisory warnings because its legacy card lookup
does not resolve the approved-store card/local governed copy as a unique card.
The approved card exists, is G0 APPROVED, declares no GMT/UTC wall-clock
window or card-specific percentage loss limit, and is hash-identical to the
EA-local copy; no limit or broker-time value was inferred.

## Artifacts

| Artifact | SHA-256 |
|---|---|
| `QM5_41094_xng-wbody-dominance-mom.mq5` | `a2af78367f02ebc234f12a2599a41be0a72efbd7ef1d4aa938dba28037906dfc` |
| `QM5_41094_xng-wbody-dominance-mom.ex5` | `ac9ea07053bec915e64dc462d9ca8707aa0bfdc4a3f0d02fecda79ecf65618fb` |
| `QM5_41094_xng-wbody-dominance-mom_XNGUSD.DWX_D1_backtest.set` | `9c2339795e10ee02abc275c7f3ee65e319474b1ddf9a0f9a7e92846beaff97d4` |

The setfile's normalized build hash is
`893b63e4bd75a946fbfa8e841ba8d515ae74a3cd31be2924d08117f0890c6486`.
Only the one D1 backtest preset exists. It locks `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, Friday close OFF,
the exact body/range integers, label offset, ATR stop, and XNG spread ceiling.

## Verdict

`Q01 PASS`. The EA is compile-PASS and registry-clean for one paced,
target-only Q02 handoff. This does not assert economic merit, activity,
decorrelation, or portfolio admission; those remain downstream empirical
gates.
