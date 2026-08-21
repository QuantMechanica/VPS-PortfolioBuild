# Codex review of Gemini build QM5_12940

Date: 2026-08-21

Review task: `395e4a56-b7a5-4c07-9187-253b4d2d6dd0`

Source build task: `f2e0fa39-1871-43b8-a282-e0f2ea55e1cf`

EA: `QM5_12940_bressert-cycle-trigger-line-h4-card`

Branch: `agents/board-advisor`

## Verdict

`FAIL` — mechanical rework is required before any later review can accept the
Gemini build.

## Blocking findings

1. `OnTick` consumes the same new-bar key twice. Line 352 calls
   `QM_IsNewBar(_Symbol, _Period)` and advances the framework tracker; line 374
   tests the identical key again. The second call is therefore false on every
   new-bar tick, making lines 374–381 unreachable and preventing all entries.
2. `DSS_ComputeAtShift` underallocates its first-stage array. With defaults,
   `k1_count = 13 + 8 + 4 = 25` (valid indices 0–24), while the last nested
   iteration reads index `(14 - 1) + (13 - 1) = 25`. This is a deterministic
   array-out-of-range runtime failure.
3. The request declared at line 376 is not zero-initialized, and the entry hook
   does not assign `expiration_seconds`. This violates the current skeleton
   request contract and leaves a field indeterminate.
4. `strategy_trigger_period` does not control the trigger calculation. The
   source hard-codes `(dss1+dss2+dss3)/3`; changing the documented input only
   changes the warmup count.
5. The approved card requires a 50% close at T1 and trailing only afterward.
   The source instead places a full-position 1.5 ATR TP and invokes ATR trailing
   from entry, with no partial-close or T1 activation state.

The news gate is also above position management. Because every constructed
entry has a server-side stop, the current Codex review contract classifies that
ordering as an advisory rather than an additional hard failure.

## Independent verification

- Approved card and source build artifact were read in full.
- MQ5 SHA-256 matched the source artifact:
  `921c217c825062815e89ff1d3fd34bf59dccb5a70a5ce525739ba7fcb1d3340d`.
- EX5 SHA-256 matched the source artifact:
  `a0e09832809f652fd62fb674208bf4b49f6775a173fa9a655e17b1f1ee292c28`.
- `validate_spec_doc.py`: `PASS`.
- `validate_build_guardrails.py`: `PASS`, 14 files, zero findings, news stale
  ceiling 336 hours.
- `compile_ea.py`: `COMPILED_CACHED`; existing EX5 is non-empty and newer than
  MQ5.
- Registry: 13 active rows, 13 distinct slots, 13 distinct magics, resolver
  entry present.
- Setfile audit: 13/13 use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Build-result sanity: PASS; files exist, hashes bind, compile/build booleans
  are true, and `blocked_reason` is null.
- Smoke sanity: `UNKNOWN`; the source artifact records
  `deferred_p2_smoke` and has no smoke report.

No terminal, Q pipeline phase, T_Live, AutoTrading, source-code repair, or
close-review action was performed. The task remains `REVIEW` for independent
adjudication and must not be self-approved or moved to `PIPELINE` by Codex.

Review JSON:
`C:/QM/repo/artifacts/reviews/395e4a56-b7a5-4c07-9187-253b4d2d6dd0.json`
