# QM5_1649 Build Evidence — Preflight Precondition Hold (Registry & Magic Slots)

- Task: `9a7db6ac-3117-4e68-a53f-ea0aa36dea1d` (`build_ea`, priority 10, assigned to Gemini)
- EA ID: `QM5_1649`
- Slug: `carney-cypher-pattern-h4`
- Date: 2026-08-23
- Branch: `agents/board-advisor`
- Outcome: `PRECONDITION_HOLD_REGISTRY_MISSING`

---

## 1. Registry & Card Discovery

1. **Strategy Card Status**:
   - Card location: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1649_carney-cypher-pattern-h4.md` (Approved, G0 PASS).

2. **EA ID Registry Status**:
   - `framework/registry/ea_id_registry.csv` contains 0 active rows for `1649`.
   - Rekeyed duplicate identity `QM5_12255` (referencing slug `QM5_1649_carney-cypher-pattern-h4`) was retired under OWNER-approved D1 disposition on 2026-08-21 (`docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`).

3. **Magic Numbers Registry Status**:
   - `framework/registry/magic_numbers.csv` has 0 active magic rows for base `16490000`.

---

## 2. Verification & Preflight Gates

- Compile check: `python C:/QM/repo/tools/strategy_farm/compile_ea.py --ea-id 1649` reports `MAGIC_NOT_REGISTERED` (`ea_id 1649 not in framework/registry/magic_numbers.csv`).
- Directory status: `framework/EAs/QM5_1649_carney-cypher-pattern-h4/` contains only an auto-generated skeleton `.mq5`; no `.ex5`, `SPEC.md`, or setfiles exist.
- Per orchestrator deprioritisation metadata:
  - `orchestrator_deprioritised.reason`: `"registry precondition missing (ea_id_unregistered); build is structurally guaranteed to refuse. Reversible: restore priority once task 8d1d903f re-registers and allocates. No row deleted."`

---

## 3. Disposition & Review Handoff

In accordance with Edge Lab charter and strategy farm rules:
- Code build and compilation are structurally held until governed magic allocator (tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee`) re-registers EA 1649 and allocates its magic slots in `magic_numbers.csv` and `QM_MagicResolver.mqh`.
- Ticket is moved to `BLOCKED` with durable evidence committed on `agents/board-advisor`.

**Short Verdict**: `BLOCKED_PRE_FLIGHT: EA 1649 has 0 active ea_id registry rows and 0 active magic rows; awaiting re-registration under tracking task 8d1d903f-39cc-461f-ab90-7b932ce62fee.`
