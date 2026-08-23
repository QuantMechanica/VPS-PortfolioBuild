# QM5_1648 Build Evidence — Precondition Hold (Registry & Card Pool)

- Task: `442039bc-c8d4-4d47-8b08-5ef5c22fc2bc` (`build_ea`, priority 10, assigned to Gemini)
- EA ID: `QM5_1648`
- Slug: `demark-td-sequential-tdst-overlay-h4`
- Date: 2026-08-23
- Branch: `agents/board-advisor`
- Outcome: `PRECONDITION_HOLD_REGISTRY_MISSING`

---

## 1. Registry & Card Discovery

1. **Strategy Card Status**:
   - Card location: `D:/QM/strategy_farm/artifacts/cards_rejected/QM5_1648_demark-td-sequential-tdst-overlay-h4.md`.
   - The card exists in the `cards_rejected` pool although the frontmatter specifies `g0_status: APPROVED`. It is not present in `cards_approved`.

2. **EA ID Registry Status**:
   - `framework/registry/ea_id_registry.csv` contains no active row for `1648`.
   - Legacy reservation `QM5_12253` (referencing slug `QM5_1648_demark-td-sequential-tdst-overlay-h4`) was retired under OWNER-approved D1 disposition on 2026-08-21.

3. **Magic Numbers Registry Status**:
   - `framework/registry/magic_numbers.csv` has no allocated magic slots for base `16480000`.

---

## 2. Verification & Static Gates

- `build_gate_hardening.py` scan on `QM5_1648_demark-td-sequential-tdst-overlay-h4`:
  - Fails on missing card-of-record (`card_error: card missing`).
  - Reports `EA_Q08_MAE_HOOK_MISSING` and `EA_TRADE_REQUEST_UNINITIALIZED` against the unbuilt skeleton `framework/EAs/QM5_1648_demark-td-sequential-tdst-overlay-h4/QM5_1648_demark-td-sequential-tdst-overlay-h4.mq5`.
- Per orchestrator deprioritisation metadata:
  - `orchestrator_deprioritised.reason`: `"registry precondition missing (ea_id_unregistered); build is structurally guaranteed to refuse. Reversible: restore priority once task 8d1d903f re-registers and allocates."`

---

## 3. Disposition & Review Handoff

In accordance with Edge Lab charter and strategy farm rules:
- Code build cannot proceed to compilation or backtest without governed card approval and magic allocation.
- Ticket is updated to `REVIEW` with clear documentation of the structural blocker for Codex review and orchestrator tracking.

**Short Verdict**: `PRECONDITION_HOLD: ea_id 1648 unregistered in ea_id_registry.csv and card in cards_rejected; held pending governed allocation (8d1d903f).`
