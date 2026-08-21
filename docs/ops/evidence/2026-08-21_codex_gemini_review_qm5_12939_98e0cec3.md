# Codex review of Gemini build QM5_12939

Date: 2026-08-21

Review task: `98e0cec3-d7a2-46f7-b8ad-f09146151f78`

Source build task: `2a3580e3-ddbf-4853-b012-0cab4471109e`

EA: `QM5_12939_carney-alternate-bat-h4`

Branch: `agents/board-advisor`

## Verdict

`FAIL` — mechanical rework is required before any later review can accept the
Gemini build.

## Blocking findings

1. `OnTick` consumes the same new-bar key twice. Line 391 calls
   `QM_IsNewBar(_Symbol, _Period)` and advances the framework tracker; line 413
   tests the identical key again. The second call is therefore false on every
   new-bar tick, making lines 413–420 unreachable and preventing all entries.
2. The request declared at line 415 is not zero-initialized, and the entry hook
   does not assign `expiration_seconds`. This violates the current skeleton
   request contract and leaves a field indeterminate.
3. The approved card defines two partial targets: 50% at 38.2% of AD, the
   remaining 50% at 61.8%, then a 1.0 ATR trail after T1. The EA sets one
   full-position 38.2% broker TP and contains no partial-close, T2, or post-T1
   trailing state.
4. The approved card requires an opposite-direction Alternate-Bat to close the
   current position before reversal. `Strategy_ExitSignal` always returns
   false, `OnTick` never invokes it, and `Strategy_ManageOpenPosition` implements
   only the 30-bar time stop.

The news gate is also above Friday close and position management. Because every
constructed entry has a server-side stop, the current Codex review contract
classifies that ordering as an advisory rather than an additional hard failure.

## Independent verification

- Approved card and source build artifact were read in full.
- MQ5 SHA-256 matched the source artifact:
  `4ed2a0726fd83298dd606d60d81e6355dc65af13225d80f2268f88b3a35f7157`.
- EX5 SHA-256 matched the source artifact:
  `6fb96e5765d999f831928c89955e89393371d17bcb5e8ac667d01b73e72735a2`.
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
`C:/QM/repo/artifacts/reviews/98e0cec3-d7a2-46f7-b8ad-f09146151f78.json`
