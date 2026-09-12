# QM5_2076 Gemini build review rework

Date: 2026-09-12

Router review task: `5621852c-fd19-429e-8286-ef4e8254d35e`

EA: `QM5_2076_chaikin-oscillator-h4`

## Decision

This item remains OWNER-gated before further source repair or compilation. The approved runtime card is internally complete and the EA-ID, eight magic rows, folder, and setfiles agree. Its SHA-256 is `26105264dfbf8c1bb8ec628f0e29d3a7534534b67e974cf59ff28bbafbc21082`.

However, the card declares `expected_dd_pct: 20.0`. The prior task review explicitly classified this EA as an Edge Lab item and flagged that value. The active charter binds every Edge Lab EA to no more than 5% daily loss and 10% total loss for the FTMO/DarwinexZero intersection. The 20% card contract is outside that design box; code review cannot silently halve its risk assumption or amend the approved card.

The later eight-EA battery repaired the formerly unwired `strategy_stddev_period` and `strategy_volume_mean_bars` inputs, and that work remains preserved. It does not cure the card gate or the earlier stale exit wiring: current OnTick still evaluates news/spread entry blockers before trailing management, opposite-cross/divergence exit, and the 50-H4-bar timeout. Current static fleet evidence also records three dynamic-buffer guard findings. Those source findings remain open, but editing them before the OWNER card decision would advance an out-of-charter Edge Lab build.

The current MQ5 is intentionally unchanged at SHA-256 `24e7ea01cb598aac3c67cca013384605845a54a1355c0c7981be66ee067490a4`. Historical Q outcomes and the old `.ex5` are not reinterpreted as fresh build or pipeline evidence.

## Required unblock

1. OWNER/Strategy Governance must replace the 20% expected-DD contract with an explicitly approved Edge-Lab-compliant ≤10% total-DD design, or remove the EA from Edge Lab scope through a durable decision.
2. Development may then repair exit-first ordering and current static guard findings without changing the newly approved economics.
3. The exact repaired source must compile only through guarded `COMPILE_EA` and return to Codex review. Historical Q verdicts remain immutable.

No source, SPEC, setfile, card, registry, binary, work item, or pipeline row was modified. No compile was requested, no terminal was started, no backtest was run or interrupted, and neither `T_Live` nor AutoTrading was touched.

RESULT: BLOCKED_OWNER_CARD — 20% expected DD violates the active Edge Lab ≤10% total-loss contract; stale exit/static findings remain for post-card repair.
