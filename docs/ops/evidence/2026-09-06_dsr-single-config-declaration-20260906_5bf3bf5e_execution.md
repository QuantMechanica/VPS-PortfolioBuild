# Execution record — OWNER-DEC-DSR-SINGLE-CONFIG-DECLARATION-20260906 = YES (Option A)

- Receipt: `5bf3bf5e-e3a9-40f8-8346-d2df9ca9b1e2` (OWNER via chat, 2026-09-06 ~16:20Z: "DSR-Single-Config-Deklaration: Ja."; recorded by the Orchestrator on explicit OWNER instruction; card + plan SHA-bound).
- Execution task (Claude lane): `8fe2bac0-5cb7-5c51-873f-af506a851867` (mode APPLY_AND_VERIFY).
- Boundary: no threshold, no stored verdict, no T_Live/AutoTrading; append-only Q08 reruns only after the card declarations exist.

## Steps
1. **Codex ticket `f9ce2102-e858-435f-b83d-33ca7b9506dd`** (Sol/high, P90): declaration blocks for QM5_11167 and QM5_11196 via the approve-card path (both card locations), producer machine check for condition (i) (no optimisation row before the Q08 claim), card-linter rule "sweep list = Q14 proposal", tests, evidence. Status: commissioned 16:25Z.
2. After integration: `farmctl enqueue-backtest --phase Q08 --append-only-rerun-of d7ab61ae-c7eb-400c-81d3-94b30a1a74e2` (11167/XAUUSD) and the 11196/XAUUSD INVALID row; 11015 excluded until its set-lock question is resolved.
3. OPEN_ITEMS + Vault (03 Pipeline/Q08 addendum "sweep list = Q14 proposal").

## Acceptance (independent, after step 2)
Q08 reruns end PASS or FAIL (not INVALID); old INVALID rows preserved; no threshold/verdict change.
