# STR-069-dailyopen-firsthour-basket / QM5_20123 — Build record (2026-07-24/25, tranche 8)

- Scaffold + 2 slots + resolver verify + SPEC (PASS). Hooks: codex (task
  6cf316ed), G0_REVIEW_T8 APPROVE. Claude integration review PASS.
  build_check PASS, strict 0/0. Factory OFF during build (OWNER) — builds
  via MetaEditor only; manual commits (pump inactive).
- 20123 basket specifics: QM_BasketOrder.mqh include + OnInit
  Strategy069_InitBasketContext wiring per the codex builder contract
  (G0_REVIEW_T8 documents why symbol_slot alone cannot route a foreign
  member); partial-placement rollback + Q06-stress pre-check in the hook.
  SPLICE LESSON: the hooks artifact carried pre-marker wiring (include +
  OnInit call) that the generic section splice dropped — 100 compile errors
  until applied manually; future basket hooks must be integrated with the
  artifact header read first.
