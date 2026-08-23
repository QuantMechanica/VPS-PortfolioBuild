# QM5_1647 Build Evidence — Preflight Precondition Hold (Registry & Magic Slots)

- Task: `5a6e93c2-8200-4982-83e5-1d59b8a3a149` (`build_ea`, priority 10, assigned to Gemini)
- EA ID: `QM5_1647`
- Slug: `ehlers-ebsw-cycle-extraction-h4`
- Date: 2026-08-23
- Branch: `agents/board-advisor`
- Outcome: `PRECONDITION_HOLD_REGISTRY_MISSING`

---

## 1. Registry & Card Discovery

1. **Strategy Card Status**:
   - Card location: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1647_ehlers-ebsw-cycle-extraction-h4.md` (Approved, G0 PASS).

2. **EA ID Registry Status**:
   - `framework/registry/ea_id_registry.csv` contains 0 active rows for `1647`.
   - Rekeyed duplicate identity `QM5_12251` (referencing slug `QM5_1647_ehlers-ebsw-cycle-extraction-h4`) was retired under OWNER-approved D1 disposition on 2026-08-21.

3. **Magic Numbers Registry Status**:
   - `framework/registry/magic_numbers.csv` has 0 active magic rows for base `16470000`.

---

## 2. Verification & Preflight Gates

- `build_gate_hardening.py` scan on `QM5_1647_ehlers-ebsw-cycle-extraction-h4`:
  - Static checks report `EA_Q08_MAE_HOOK_MISSING` and `EA_TRADE_REQUEST_UNINITIALIZED` against the unbuilt skeleton `framework/EAs/QM5_1647_ehlers-ebsw-cycle-extraction-h4/QM5_1647_ehlers-ebsw-cycle-extraction-h4.mq5`.
- Per orchestrator deprioritisation metadata:
  - `orchestrator_deprioritised.reason`: `"registry precondition missing (ea_id_unregistered); build is structurally guaranteed to refuse. Reversible: restore priority once task 8d1d903f re-registers and allocates."`

---

## 3. Disposition & Review Handoff

In accordance with Edge Lab charter and strategy farm rules:
- Code build and compilation are structurally held until governed magic allocator (tracking task `8d1d903f-39cc-461f-ab90-7b932ce62fee`) re-registers EA 1647 and allocates its magic slots in `magic_numbers.csv` and `QM_MagicResolver.mqh`.
- Ticket is marked `BLOCKED` with durable evidence committed on `agents/board-advisor`.

**Short Verdict**: `BLOCKED_PRE_FLIGHT: EA 1647 has 0 active ea_id registry rows and 0 active magic rows; awaiting re-registration under tracking task 8d1d903f-39cc-461f-ab90-7b932ce62fee.`
