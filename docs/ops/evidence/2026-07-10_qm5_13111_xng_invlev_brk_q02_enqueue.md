# QM5_13111 XNG Inverse-Leverage Expansion Q02 Enqueue

Date: 2026-07-10
Branch: `agents/board-advisor`

## Outcome

One new structural natural-gas sleeve was carded, built, compiled, and
enqueued:

- EA: `QM5_13111_xng-invlev-brk`.
- Signal: once-weekly-capped, direction-neutral `XNGUSD.DWX` H4 range break
  after a large positive same-session impulse.
- Q02 work item: `91fa45bb-7c0e-47f3-91dd-238689b7884b`.
- Handoff: pending, unclaimed, `XNGUSD.DWX`, H4.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Magic: `131110000`, slot 0.

No manual MT5 run was launched. At 2026-07-10T10:31:04+02:00 the CPU guard
found active path-anchored non-live terminals on T2, T4, T6, T7, and T8;
paced workers covered T1, T2, T3, T4, T6, T7, and T8. The build therefore
used `deferred_p2_smoke` and handed the setfile to Q02 without competing with
the factory.

## Source And Mechanization

Primary source: Ladislav Kristoufek (2014), "Leverage effect in energy
futures," *Energy Economics* 45, 1-9, DOI
https://doi.org/10.1016/j.eneco.2014.06.009. Institutional full paper:
https://library.utia.cas.cz/separaty/2014/E/kristoufek-0433531.pdf.

The complete paper was reviewed. Its natural-gas result is inverse leverage:
positive returns are associated with increased future volatility, with weak
cross-correlation persistence. The paper does not claim a tradable breakout.
The card therefore uses a large positive partial-D1 H4 impulse only as a
short-lived volatility regime. The next completed H4 candle defines a setup
range; a later completed close beyond that range discovers long or short
direction. The EA permits one accepted entry per week, uses a structural stop,
a 1.50R target, a 24-hour time exit, and framework Friday close.

The peer-reviewed replication by Carnero and Perez (2019), *Energy Economics*
82, 237-252, DOI https://doi.org/10.1016/j.eneco.2017.12.029, finds the natural-
gas result sensitive to method and return definition. That limitation is
explicit in the card and is a Q02 falsification risk. No DCCA/DMCA/GARCH/Hurst
calculation, ML, banned indicator, or external runtime data is used.

## Non-Duplicate Decision

Repository dedup returned CLEAN before allocating QM5_13111. Manual content
review also separated the edge from:

- `QM5_12567`: cumulative-RSI2 pullback;
- `QM5_12817`: multi-day volatility-shock fade;
- `QM5_13101`: five-day momentum in low volatility;
- `QM5_13102`: five-day reversal in high volatility;
- `QM5_13104`: compressed-Friday Monday expansion;
- `QM5_13105`: inside/NR4 breakout;
- `QM5_13110`: source-calendar prior-D1 range breakout.

QM5_13111 is a positive-return-conditioned volatility regime followed by a
separate, direction-neutral H4 setup-range break. It is not a parameter variant
of those families. Portfolio orthogonality remains unclaimed; only a surviving
Q09 return stream may establish it.

## Build Evidence

- Card of record: `strategy-seeds/cards/xng-invlev-brk_card.md`.
- Source packet: `strategy-seeds/sources/KRISTOUFEK-ENERGY-LEV-2014/source.md`.
- EA source, binary, setfile, SPEC, and build-time card:
  `framework/EAs/QM5_13111_xng-invlev-brk/`.
- Build record: `artifacts/qm5_13111_build_result.json`.
- Enqueue record: `artifacts/qm5_13111_q02_enqueue_20260710.json`.

Verification:

- Directory-first EA-ID allocation: QM5_13111.
- Research dedup: CLEAN before allocation.
- Card schema lint and G0 lint: PASS.
- SPEC validation: PASS.
- Symbol scope: `SINGLE_SYMBOL_OK`, zero violations.
- Magic resolver: `131110000` present after regeneration.
- Strict compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 0 warnings.
- Backtest setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`, Friday close enabled.
- Q02 enqueue: one pending row, zero skipped.

Resolver generation repeated three pre-existing missing-directory warnings for
EA IDs 1001, 1015, and 1016. None was caused or repaired by QM5_13111.

## Guardrails

- No `T_Live` file or process action.
- No AutoTrading action.
- No live setfile or deploy manifest.
- No portfolio gate, admission, KPI, or correlation-code change.
- Existing unrelated dirty FTMO/Q08 paths were left untouched.
