# QM5_41150 GBPUSD diversity build and Q02 handoff — 2026-09-11

## Scope and selection

- Branch: `agents/board-advisor`.
- Claimed agent task: `e107e2b1-4ee2-4f4c-bf3f-6c67e7afbbbb`.
- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_41150_gbpusd-local-session-inventory-drift.md`.
- G0: `APPROVED`; R1–R4: `PASS`.
- Target: `GBPUSD.DWX`, H1, structural Europe/London local-session inventory drift.
- Diversity rationale: the immediately preceding sibling build was AUDUSD; this is the next approved, registry-allocated FX sleeve with no existing EA directory, build task, or work item. Rates candidates QM5_1457/QM5_1459 were excluded because their current R3 records fail on unavailable Treasury/lumber/bond data.

The public PDF router deferred retrieval under source policy. No bypass was attempted. The build used the approved card plus durable local source evidence in `strategy-seeds/sources/SRC09/source.md` and the governed London-session convention in `framework/EAs/QM5_1333_chan-fx-local-hours/SPEC.md`.

No live terminal, AutoTrading control, deploy manifest, portfolio gate, or `T_Live` artifact was touched.

## Mechanical strategy implementation

- Resolve the host instrument from `_Symbol`; the only authorized carrier is the registered `GBPUSD.DWX` slot.
- At 07:00 Europe/London civil time on weekdays, make at most one SELL attempt for that civil session.
- Exit any owned position by 16:00 Europe/London on the same session date.
- Use completed-H1 ATR(14) with a 1.5 ATR hard stop and no take-profit.
- Persist the attempt marker before order submission, reconstruct it from history on restart, and process management/exit before new-entry gating.
- Use the central London calendar conversion helper so UTC transitions follow the validated civil-time DST contract.

The expected rate is approximately 100 attempts per year. It is a single-entry structural session sleeve: no ML, optimization, grid, martingale, averaging, pyramiding, or discretionary override.

## Identity and deterministic artifacts

- EA ID: `41150`.
- Magic slot 0: `GBPUSD.DWX` / `411500000`, status `active`.
- Governed allocator dry-run and apply both completed with zero status-aware collisions; the resolver was regenerated.
- MQ5 SHA-256: `c6e682803e066399b79c7f20153008bcc535753ce12384458a3a7c34a4fc9021`.
- EX5 SHA-256: `033eea3b4dc328f3c1cc7db362dabcc3dd42244445f2eff33571f1f6b1844f4d`.
- Canonical setfile SHA-256: `8da19241af16ba0ded8e5338d34d6ba10e57e6e19a8238e2b778b2fa627a4e9c`.
- Setfile risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`; strategy values are ATR period 14 and stop multiple 1.5.

## PACER guard and verification

The mandatory source audit was run after the MQ5 was written and again immediately before compile enqueue:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_41150_gbpusd-local-session-inventory-drift/QM5_41150_gbpusd-local-session-inventory-drift.mq5"
```

Both runs returned exit 0, `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`, and no findings. The lock guard compares only the EA identity, magic slot, strategy parameters, and fixed-risk mode. It does not compare RNG, news, Friday-close, portfolio-weight, or stress defaults; stress is checked only for finiteness and inclusive 0..1 range.

- `validate_spec_doc.py`: PASS.
- Python reference suite: 4 PASS.
- `build_gate_hardening.py`: PASS, zero failures and warnings.
- `validate_build_guardrails.py`: PASS, zero findings.
- Governed compile work item: `d21006d6-1baa-4672-8f4f-0df0e4923352`.
- Compile result: `COMPILE_OK`; strict build check PASS; 0 compiler errors; 0 compiler warnings.
- Authenticated compile evidence: `D:\QM\reports\work_items\d21006d6-1baa-4672-8f4f-0df0e4923352\QM5_41150\COMPILE_EA\compile_evidence.json`.

The exact-item rollout hold was released only after a five-sample capacity gate passed (samples `76.3, 74.8, 82.7, 80.1, 91.7`; average `81.12%`, maximum `91.7%`, zero active tester rows). The release wrote backup `farm_state_before_compile_wave_20260911T172438Z_0403e382.sqlite`, SHA-256 `7b674821fa03ef020872c750797fa091a175079ffc41fb3edbb14f415e5af5bf`.

## Build handback and Q02

The first two append-only build-result records exposed metadata-contract defects only: the first omitted the smoke contract and the second omitted `ea_dir`. They produced one failed and one blocked farm task without changing source, identity, setfile, or binary. The final full-schema successor task `30d31c04-da65-4b13-9aea-8493d55d13c1` recorded `done`. A scoped Q01 smoke attempt returned `status=no_capacity` before terminal launch, so the standard handback used the explicit `deferred_p2_smoke` path.

Before Q02 intake, the five CPU samples were `65.3, 63.3, 74.4, 92.1, 90.0` (average `77.02%`, maximum `92.1%`) with five active work items. The successful build handback appended exactly one fixed-risk Q02 canary:

- Work item: `9d1e7019-3e29-4f67-9c8c-df9c2abd20b0`.
- Symbol/timeframe: `GBPUSD.DWX` / H1.
- Exact bindings: MQ5 `c6e68280...`, EX5 `033eea3b...`, setfile `8da19241...`.
- State at handoff: `active`, claimed by T8.
- Execution remains owned by the paced terminal fleet.

The post-intake CPU samples were `87.8, 85.1, 93.9, 92.9, 95.7` (average `91.08%`, maximum `95.7%`). The fleet then reached seven active work items, which is the binding PACER tester-drain ceiling. All further tester and pipeline activity stopped at that point.
