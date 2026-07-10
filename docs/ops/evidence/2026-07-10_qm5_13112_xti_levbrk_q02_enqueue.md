# QM5_13112 XTI Negative-Impulse Leverage Breakout Q02 Enqueue

Date: 2026-07-10
Branch: `agents/board-advisor`

## Outcome

One new structural WTI downside-trend sleeve was carded, built, compiled, and
enqueued:

- EA: `QM5_13112_xti-levbrk`.
- Signal: once-weekly-capped, short-only `XTIUSD.DWX` H4 continuation below a
  large completed negative D1 impulse.
- Q02 work item: `f15fcbab-42d7-45cb-af23-c0baf40bc56f`.
- Handoff: pending, unclaimed, `XTIUSD.DWX`, H4.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Magic: `131120000`, slot 0.

No manual MT5 run was launched. At `2026-07-10T09:27:18+00:00` the CPU guard
found active path-anchored non-live terminals on T1, T2, T3, T4, T7, and T8;
paced workers covered T1, T2, T3, T4, T6, T7, and T8. The build therefore used
`deferred_p2_smoke` and handed the setfile to Q02 without competing with the
factory.

## Source And Mechanization

Primary source: Ladislav Kristoufek (2014), "Leverage effect in energy
futures," *Energy Economics* 45, 1-9, DOI
https://doi.org/10.1016/j.eneco.2014.06.009. Institutional full paper:
https://library.utia.cas.cz/separaty/2014/E/kristoufek-0433531.pdf.

The complete paper was reviewed. It finds a stable and statistically
significant standard leverage effect for both crude oils: negative returns and
range-based volatility are associated, with a stronger effect at longer
measurement scales. It also finds no long-range return/volatility dependence
and records mixed earlier WTI asymmetry results.

The paper does not claim a tradable downside breakout. The card uses a large
completed negative D1 candle only as a short-lived volatility regime. A later
completed H4 close during the next broker D1 session must break below the
impulse low before the EA enters short. The EA permits one accepted entry per
week, uses a stop above the impulse high, a 1.75R target, a 48-hour time exit,
and framework Friday close. No DCCA/DMCA/GARCH/Hurst calculation, ML, banned
indicator, or external runtime data is used.

## Non-Duplicate Decision

Repository dedup returned CLEAN before allocating QM5_13112. Manual content
review also separated the edge from:

- `QM5_12567`: cumulative-RSI2 pullback;
- `QM5_12603`, `QM5_12616`, and `QM5_13100`: slow symmetric WTI trend;
- `QM5_13049`: five-day momentum in low volatility;
- `QM5_13050` and `QM5_13046`: high-volatility WTI fades;
- `QM5_13096` and `QM5_13103`: narrow/inside-range breakouts;
- `QM5_13111`: positive-impulse, direction-neutral XNG expansion.

QM5_13112 is negative-D1-shock, short-only WTI continuation confirmed on H4.
It is not a parameter variant of those families. Portfolio orthogonality
remains unclaimed; only a surviving Q09 return stream may establish it.

## Build Evidence

- Card of record: `strategy-seeds/cards/xti-levbrk_card.md`.
- Source packet:
  `strategy-seeds/sources/KRISTOUFEK-ENERGY-LEV-2014/source.md`.
- EA source, binary, setfile, SPEC, and build-time card:
  `framework/EAs/QM5_13112_xti-levbrk/`.
- Build record: `artifacts/qm5_13112_build_result.json`.
- Enqueue record: `artifacts/qm5_13112_q02_enqueue_20260710.json`.

Verification:

- Directory-first EA-ID allocation: QM5_13112.
- Research dedup: CLEAN before allocation.
- Card schema lint and G0 lint: PASS.
- SPEC validation: PASS.
- Symbol scope: `SINGLE_SYMBOL_OK`, zero violations.
- Magic resolver: `131120000` present after regeneration.
- Strict compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 0 warnings.
- Backtest setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`, Friday close enabled.
- Q02 enqueue: one pending row, zero skipped.

Resolver generation repeated three pre-existing missing-directory warnings for
EA IDs 1001, 1015, and 1016. None was caused or repaired by QM5_13112.

## Guardrails

- No `T_Live` file or process action.
- No AutoTrading action.
- No live setfile or deploy manifest.
- No portfolio gate, admission, KPI, or correlation-code change.
- Existing unrelated dirty FTMO/Q08 paths were left untouched.
