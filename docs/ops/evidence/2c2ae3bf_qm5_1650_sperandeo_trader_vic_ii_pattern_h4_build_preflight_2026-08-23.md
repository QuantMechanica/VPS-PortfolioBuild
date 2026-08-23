# QM5_1650 Build Evidence — Preflight Precondition Hold (Registry & Magic Slots)

- Task: `2c2ae3bf-b1db-401a-8725-cb109f7eb98d` (`build_ea`, priority 10, assigned to Gemini)
- EA ID: `QM5_1650`
- Slug: `sperandeo-trader-vic-ii-pattern-h4`
- Date: 2026-08-23
- Branch: `agents/board-advisor`
- Outcome: `PRECONDITION_HOLD_REGISTRY_MISSING`

---

## 1. Registry & Card Discovery

1. **Strategy Card Status**:
   - Card location: `D:/QM/strategy_farm/artifacts/cards_recovery/QM5_1650_sperandeo-trader-vic-ii-pattern-h4.md` / `cards_rejected/QM5_1650_sperandeo-trader-vic-ii-pattern-h4.md`.
   - Card not present in `cards_approved/`.

2. **EA ID Registry Status**:
   - `framework/registry/ea_id_registry.csv` contains 0 active rows for `1650`.
   - Rekeyed duplicate identity `QM5_12258` (referencing slug `QM5_1650_sperandeo-trader-vic-ii-pattern-h4`) was retired under OWNER-approved D1 disposition on 2026-08-21 (`docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`).

3. **Magic Numbers Registry Status**:
   - `framework/registry/magic_numbers.csv` has 0 active magic rows for base `16500000`.

---

## 2. Verification & Preflight Gates

- Compile check: `python C:/QM/repo/tools/strategy_farm/compile_ea.py --ea-id 1650` reports `MAGIC_NOT_REGISTERED` (`ea_id 1650 not in framework/registry/magic_numbers.csv`).
- Directory status: `framework/EAs/QM5_1650_sperandeo-trader-vic-ii-pattern-h4/` contains only an auto-generated skeleton `.mq5`; no `.ex5`, `SPEC.md`, or setfiles exist.
- Per orchestrator deprioritisation metadata:
  - `orchestrator_deprioritised.reason`: `"registry precondition missing (ea_id_unregistered); build is structurally guaranteed to refuse. Reversible: restore priority once task 8d1d903f re-registers and allocates. No row deleted."`

---

## 3. Disposition & Review Handoff

In accordance with Edge Lab charter and strategy farm rules:
- Code build and compilation are structurally held until governed magic allocator (tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee`) re-registers EA 1650 and allocates its magic slots in `magic_numbers.csv` and `QM_MagicResolver.mqh`.
- Ticket is moved to `REVIEW` with durable evidence committed on `agents/board-advisor`.

**Short Verdict**: `BLOCKED_PRE_FLIGHT: EA 1650 has 0 active ea_id registry rows and 0 active magic rows; awaiting re-registration under tracking task 8d1d903f-39cc-461f-ab90-7b932ce62fee.`
