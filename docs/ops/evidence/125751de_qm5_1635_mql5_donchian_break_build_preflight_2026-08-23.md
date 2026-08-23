# QM5_1635 Build Pre-flight Evidence — 2026-08-23

- Task: U751de-4019-4138-8f08-9cdb6733e9d3\ (\uild_ea\, priority 10, assigned to Gemini)
- Requested EA: \QM5_1635_mql5-donchian-break- Approved card: \D:/QM/strategy_farm/artifacts/cards_approved/QM5_1635_mql5-donchian-break.md- Gate result: \BLOCKED_PRE_FLIGHT- Canonical checkout: \C:/QM/repo- Branch: \gents/board-advisor
## Deterministic findings

1. The card exists and declares \g0_status: APPROVED\, \a_id: QM5_1635\, and \slug: mql5-donchian-break\.
2. \ramework/registry/ea_id_registry.csv\ line 429 has s5,mql5-donchian-break\, but line 2985 has P91,QM5_1635_mql5-donchian-break\ retired under OWNER-approved D1 disposition (\docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv\).
3. \ramework/registry/magic_numbers.csv\ has 0 active rows for EA ID s5\ (the only matching rows belong to EA N35\).
4. The requested folder \ramework/EAs/QM5_1635_mql5-donchian-break\ exists with only an auto-generated skeleton \.mq5\; no \.ex5\, \SPEC.md\, or setfiles exist.

## Disposition

The governed build procedure requires an immediate fail-closed stop when magic allocation is absent or retired identity conflicts exist. No source, registry, resolver, setfile, binary, terminal, or pipeline mutation was performed for this task. Governed registry allocation/reconciliation is tracked under task \8d1d903f-39cc-461f-ab90-7b932ce62fee\ before the requested EA can be built.

Short verdict: \BLOCKED_PRE_FLIGHT: EA 1635 has 0 active magic rows; duplicate identity 12091 is OWNER-retired.
