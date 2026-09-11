# QM5_41151 USDJPY diversity build and Q02 handoff — 2026-09-11

## Scope and selection

- Branch: `agents/board-advisor`.
- Governed magic prerequisite task: `c3adccaa-27b4-4045-85c8-4e675a1561f2` (`PASSED`).
- Build task: `c41b054d-8bb2-4c6a-9506-8d366b4f5869`.
- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_41151_usdjpy-local-session-inventory-drift.md`.
- G0: `APPROVED`; R1 Tier A; R2–R4 `PASS`.
- Target: `USDJPY.DWX`, H1, structural Asia/Tokyo local-session inventory drift.
- Non-duplicate coordination: before claim, the EA had no directory, magic allocation, agent task, compile row, or pipeline work item. The farm-created prerequisite task was claimed before allocation, and the build was then opened through `farmctl build-ea`.

This was selected over additional index/metal/energy volume because the current Q08 survivors are concentrated in those asset classes. No live terminal, AutoTrading control, deploy manifest, portfolio gate, or `T_Live` artifact was touched.

## Mechanical implementation

- Resolve the only traded instrument from `_Symbol`; slot 0 is registered to `USDJPY.DWX`.
- On the exact 09:00 Asia/Tokyo H1 bar, make at most one BUY attempt per JST weekday.
- Persist and flush the local-date attempt marker before submission and reconstruct it from history after restart.
- Use a completed H1 ATR(14) hard stop at 1.5 ATR, with no take-profit or stop widening.
- Flatten owned exposure by 18:00 JST on the same local date.
- Use fixed UTC+09:00 JST conversion and nine fresh trailing-hour news checks covering the full [09:00,18:00] owned interval.
- Preserve the canonical five strategy hooks and framework lifecycle callbacks.

The approved card names no versioned Japanese holiday calendar. The build therefore does not invent a holiday proxy; this is recorded in the build result as an open question for a governed card/calendar revision.

## Identity and artifacts

- EA ID: `41151`.
- Magic: slot 0, `USDJPY.DWX`, `411510000`, active.
- Governed allocation: one EA / one row, zero status-aware magic collisions; resolver regenerated.
- MQ5 SHA-256: `4375b6caa745e4981639016dca598d877d0918f974642884f3f670724815a490`.
- EX5 SHA-256: `c1ca92f34c1f40536fb5e354e3392441945b99335908fe88c87217014a17e43d`.
- Setfile SHA-256: `fd95a78b1661d685b1c606f009a4c1ce2a30c0fb0715c27ec33d913959a0e770`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Binding PACER guard

After source creation and again immediately before compile enqueue, the required command was run:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_41151_usdjpy-local-session-inventory-drift/QM5_41151_usdjpy-local-session-inventory-drift.mq5"
```

Exact result on both checks:

```json
{
  "ok": true,
  "predicate": "EA_FRAMEWORK_INPUT_PINNED",
  "source_count": 1,
  "hit_count": 0,
  "hits": []
}
```

The source locks only `qm_ea_id`, `qm_magic_slot_offset`, the two `strategy_*` values, and fixed-risk mode. RNG, news, and Friday inputs are not compared. Stress rejection is checked only for finiteness and inclusive 0..1 range.

## Verification and funnel handoff

- Spec validator: PASS.
- Python reference suite: 4 PASS.
- Build hardening: PASS, zero failures/warnings.
- Build guardrails: PASS, zero findings.
- Governed compile work item: `1af83001-e7db-4af0-bf69-f64577261828`.
- Compile: `COMPILE_OK`, 0 errors, 0 warnings; strict build check PASS.
- Authenticated evidence: `D:\QM\reports\work_items\1af83001-e7db-4af0-bf69-f64577261828\QM5_41151\COMPILE_EA\compile_evidence.json`.
- The one scoped smoke attempt was refused before terminal launch with `status=no_capacity`; build result recorded `deferred_p2_smoke` under the explicit capacity waiver.
- Build result: `D:\QM\strategy_farm\artifacts\builds\c41b054d-8bb2-4c6a-9506-8d366b4f5869.json`.
- `record-build` appended exactly one Q02 row: `850e674b-72cf-4b89-8547-631eef4d275f`, `USDJPY.DWX` / H1, state `pending`, attempt count 0.

The pre-release five-sample CPU window was `92.7, 92.4, 78.8, 94.3, 82.5` (maximum 94.3%, below the 97% stop threshold). After Q02 intake, the observed window was `91.3, 92.9, 93.8, 99.5, 94.1`; the 99.5% maximum hit the PACER ceiling. No further smoke, tester, pipeline, or queue work was started after that observation.

