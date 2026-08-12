# STR-008-notable-number-fade / QM5_20104 — Build record (2026-07-24, tranche 3)

- Scaffold: registry + 8 magic slots + resolver regen/verify + skeleton +
  SPEC.md (validator PASS). Hooks: codex (router task 126038e4), G0_REVIEW_T3
  APPROVE; spliced unchanged.
- Claude integration review (reciprocal): PASS — no QM_IsNewBar in hooks,
  ZeroMemory+symbol_slot, closed-bar discipline, framework enums/helpers
  verified (QM_BUY_STOP/QM_SELL_STOP exist; pending expiry via
  expiration_seconds + Manage day-roll cancel for 20106; lattice/latch
  machinery shared 20104/20105 with mirrored polarity).
- build_check PASS (with sets), strict compile 0/0.
