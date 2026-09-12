# QM5_20179 Gemini build review rework

Date: 2026-09-12

Router review task: `9df810a8-9783-4f10-9378-83989f69ac36`

EA: `QM5_20179_pesavento-abcd-pattern-h4-r1-recovery`

## Decision

This item remains OWNER-gated before source repair or compilation. The runtime approved card (SHA-256 `a542268855bbf9c5a45f13a87ec82ce0f30db0b1d4f47a3354ae73f3d32d2c75`) simultaneously declares `g0_status: APPROVED`, `status: draft`, `card_body_incomplete: true`, and `card_body_missing: "target_symbols"`, even though a target-symbol field was later inserted. That self-inconsistent authority record is not a complete build contract.

The card also declares `expected_dd_pct: 18.0`. The active Edge Lab charter binds every Edge Lab EA to the FTMO/DarwinexZero intersection: no more than 5% daily loss and 10% total loss, mandatory news blackout, H1-D1 swing or M5-M15 scalping horizon, and deterministic non-ML mechanics. Eighteen percent is outside the authorized total-loss design box. This is the same OWNER-only blocker recorded in the 2026-08-22 non-ready triage.

The EA-ID, six magic rows, and folder slug are mutually consistent, but registry consistency cannot override an incomplete/out-of-charter card. Prior implementation findings—broker-invalid projected stop cases, stale exit ordering, and contradicted build evidence—remain open. The current MQ5 is intentionally unchanged at SHA-256 `550f69b011ffa9f0138e73c9ddf4bfe57cc057e24399dbc3d4022b83c41ab3b6`.

## Required unblock

1. OWNER/Strategy Governance must repair or reject the card, remove the incomplete self-declaration, and supply an Edge-Lab-compliant ≤10% total-DD risk contract and FTMO fit.
2. Only after a coherent approved card exists may Development repair stop validation and exit wiring without altering the approved economics.
3. A repaired exact source must use guarded `COMPILE_EA` and return to independent Codex review; historical results cannot supply a new verdict.

No source, SPEC, setfile, card, registry, binary, work item, or pipeline row was modified. No compile was requested, no terminal was started, no backtest was run or interrupted, and neither `T_Live` nor AutoTrading was touched.

RESULT: BLOCKED_OWNER_CARD — incomplete/self-inconsistent card and 18% expected DD violate the active Edge Lab contract; source/build rework remains unauthorized.
