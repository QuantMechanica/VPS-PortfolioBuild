# STR-002 / QM5_20101 — Build record (2026-07-24, tranche 2)

- Scaffold: dirs + registry (ea_id 20101, magics 201010000-03) + resolver
  regen/verify + skeleton + SPEC.md (validator PASS). Hooks: codex (router
  task 01724557) per 04_spec_final; spliced unchanged except section splice.
- Claude integration review (reciprocal): PASS — no QM_IsNewBar in hooks (own
  static bar guards), ZeroMemory+symbol_slot, session gate in EntrySignal
  only, UTC via QM_BrokerToUTC (QM_DSTAware, news-filter primitive), campaign
  partial-close 2/3@+1R once-only with per-bar retry latch + min-volume
  guard, HA-extreme runner trail never widening, campaign state derived from
  volume+position (restart-safe). New event TM_PARTIAL_RETRY_DEFERRED
  registered (vocabulary regen).
- build_check PASS; strict compile 0 errors / 0 warnings; 4 sets
  (RISK_FIXED=1000, RISK_PERCENT=0).
- Commits: scaffolds + integration (this tranche's feat commits on
  agents/board-advisor).
