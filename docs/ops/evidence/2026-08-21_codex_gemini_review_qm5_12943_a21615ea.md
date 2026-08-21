# Codex review of Gemini build QM5_12943

Date: 2026-08-21

Review task: `a21615ea-2d27-4bd9-9e72-c217d3e5de72`

Source build task: `e3a2083b-eeb7-40e0-b865-0cc7d001997e`

EA: `QM5_12943_robopip-hlhb-trend-catcher-h1`

Branch: `agents/board-advisor`

## Verdict

`FAIL` — mechanical rework is required before any later review can accept the
Gemini build.

## Blocking findings

1. `OnTick` omits `QM_FrameworkTrackOpenPositionMae()` before its first per-tick
   guard. That call is present in the current V5 skeleton specifically to keep
   the Q08 open-position MAE evidence lifecycle alive even when later guards
   return.
2. The approved volatility gate is H1 ATR(14) multiplied by 24. Lines 102–107
   instead use native D1 ATR(14) whenever it is available and apply the H1
   formula only as a fallback, changing signal eligibility.
3. The time stop is not measured in 96 closed H1 bars. It is implemented as
   96 wall-clock hours since `POSITION_TIME`, so a weekend or market closure
   advances the timer without producing bars. It also closes at market without
   implementing the card's stated break-even condition.
4. The approved card lists four target symbols. The build generates setfiles
   for all 13 allocated hosts, adding nine FX/index symbols that the card did
   not authorize. Registry rows are internally valid, but do not amend the
   approved strategy universe.

## Independent verification

- Approved card and source build artifact were read in full.
- MQ5 SHA-256 matched the source artifact:
  `47a9cedf8657968f440b19dce6924e656686167a19707f9c165263cd370d7b67`.
- EX5 SHA-256 matched the source artifact:
  `e8566960b6f6e3ad3af0238fdf7868855e17a6aa51033b85886785b6b5470acb`.
- SPEC SHA-256:
  `400328dd1243d3de28b35aef991588048bc39d6e24fc5562d3b393bf8ea75063`.
- `validate_spec_doc.py`: `PASS`.
- `validate_build_guardrails.py`: `PASS`, 14 files, zero findings, news stale
  ceiling 336 hours.
- `compile_ea.py`: `COMPILED_CACHED`; the existing EX5 is non-empty and newer
  than the MQ5.
- Registry: 13 active rows, slots 0–12, 13 distinct magics, no cross-EA magic
  collisions; resolver dry-run kept all 17,582 rows with zero drops.
- Setfile audit: 13/13 use `RISK_FIXED>0` and `RISK_PERCENT=0`.
- Build-result sanity: `PASS` under `SCHEMAS.md`; files exist, hashes bind,
  compile/build booleans are true, and deferred P2 smoke is a sanctioned
  capacity outcome.
- Smoke sanity: `UNKNOWN`; the source artifact records
  `deferred_p2_smoke` and has no smoke report.

No terminal, Q pipeline phase, T_Live, AutoTrading, source-code repair, or
close-review action was performed. The task remains `REVIEW` for independent
adjudication and must not be self-approved or moved to `PIPELINE` by Codex.

Review JSON:
`C:/QM/repo/artifacts/reviews/a21615ea-2d27-4bd9-9e72-c217d3e5de72.json`
