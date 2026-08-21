# Codex review of Gemini build QM5_12944

Date: 2026-08-21

Review task: `c74163e1-fd20-413d-a42f-e2f3eb432f4f`

Source build task: `01bd8a9d-bd3f-4da5-a275-be9192a763ed`

EA: `QM5_12944_sperandeo-trend-fault-line-h4`

Branch: `agents/board-advisor`

## Verdict

`FAIL` — mechanical rework is required before any later review can accept the
Gemini build.

## Blocking findings

1. `OnTick` omits `QM_FrameworkTrackOpenPositionMae()` before its first per-tick
   guard. That call is present in the current V5 skeleton specifically to keep
   the Q08 open-position MAE evidence lifecycle alive even when later guards
   return.
2. The spread filter is not the approved 100-bar rolling-mean-spread rule.
   Lines 193–200 compare spread to an ATR-derived threshold; with the default
   multiplier, the threshold is one full H4 ATR and will admit spreads the card
   says to reject.
3. The volatility-expansion rule uses `high-low` on the breaking bar rather
   than ATR(1)/true range, so it ignores gap distance while comparing against
   ATR(20).
4. The 0.5% pivot-deviation input is halved in both fault-line searches, and
   the exposed `strategy_min_pivots` input does not control the hard-coded
   three-pivot implementation.
5. Entry only checks that the latest close remains beyond the projected line;
   it does not verify an actual crossing from the preceding bar. A TP can
   therefore be followed by another entry into the same persistent condition.
6. The card's reverse-signal close is not implemented. Open positions block
   `Strategy_EntrySignal`, while the exit hook handles only a failed break of
   the same-direction line.

## Independent verification

- Approved card and source build artifact were read in full.
- MQ5 SHA-256 matched the source artifact:
  `18ece1138bf8394700421bedd273ff2fc5315640c613ead72f110249fe786a79`.
- EX5 SHA-256 matched the source artifact:
  `e19a9d287c247aaec8f074ff0469aeb977f0fc03b349a95617aa02a347c2d711`.
- SPEC SHA-256:
  `d412cf871d1f21b17e7167154310fa26e46cac990a3c332680f4da2767ccd23e`.
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
`C:/QM/repo/artifacts/reviews/c74163e1-fd20-413d-a42f-e2f3eb432f4f.json`
