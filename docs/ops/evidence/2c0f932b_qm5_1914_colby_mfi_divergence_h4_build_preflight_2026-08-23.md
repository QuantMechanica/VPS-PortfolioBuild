# QM5_1914 Build Evidence — Preflight Precondition Hold (Registry & Magic Slots)

- Task: `2c0f932b-668c-4c3c-96ec-53a5fb8cdcbc` (`build_ea`, priority 10, assigned to Gemini)
- EA ID: `QM5_1914`
- Slug: `colby-mfi-divergence-h4`
- Date: 2026-08-23
- Branch: `agents/board-advisor`
- Canonical checkout: `C:/QM/repo`
- Outcome: `PRECONDITION_HOLD_REGISTRY_MISSING`

---

## 1. Registry & Card Discovery

1. **Strategy Card Status**:
   - Card location: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1914_colby-mfi-divergence-h4.md`
   - Declares `ea_id: QM5_1914`, `slug: colby-mfi-divergence-h4`, `g0_status: APPROVED`

2. **EA ID Registry Status**:
   - `framework/registry/ea_id_registry.csv` contains 0 active rows for `1914` (line 2803 is `11914,ciurea-100sma-cross-h4`).
   - Rekeyed duplicate identity `12276` (slug `QM5_1914_colby-mfi-divergence-h4`) is `retired` under OWNER-approved D1 disposition on 2026-08-21 (`docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`).

3. **Magic Numbers Registry Status**:
   - `framework/registry/magic_numbers.csv` has 0 active magic rows for EA ID `1914` (existing rows 14937-14946 belong to EA `11914`).

---

## 2. Verification & Preflight Gates

- Compile check: `python C:/QM/repo/tools/strategy_farm/compile_ea.py --ea-id 1914 --json` reports `MAGIC_NOT_REGISTERED` (`ea_id 1914 not in framework/registry/magic_numbers.csv`).
- Directory status: `framework/EAs/QM5_1914_colby-mfi-divergence-h4/` contains only an auto-generated skeleton `.mq5`; no `.ex5`, `SPEC.md`, or setfiles exist.
- Per orchestrator deprioritisation metadata:
  - `orchestrator_deprioritised.reason`: `"registry precondition missing (ea_id_unregistered); build is structurally guaranteed to refuse. Reversible: restore priority once task 8d1d903f re-registers and allocates. No row deleted."`
  - `tracking_task`: `8d1d903f-39cc-461f-ab90-7b932ce62fee`

---

## 3. Disposition & Review Handoff

In accordance with Edge Lab charter and strategy farm rules:
- Code build and compilation are structurally held until governed magic allocator (tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee`) re-registers EA 1914 and allocates its magic slots in `magic_numbers.csv` and `QM_MagicResolver.mqh`.
- No source, registry, resolver, setfile, binary, terminal, or pipeline mutation was performed for this task.
- Ticket is moved to `REVIEW` with durable evidence committed on `agents/board-advisor`.

**Short Verdict**: `BLOCKED_PRE_FLIGHT: EA 1914 has 0 active ea_id registry rows and 0 active magic rows; awaiting re-registration under tracking task 8d1d903f-39cc-461f-ab90-7b932ce62fee.`
