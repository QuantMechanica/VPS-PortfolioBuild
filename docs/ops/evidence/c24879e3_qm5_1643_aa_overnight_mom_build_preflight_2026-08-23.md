# QM5_1643 Build Pre-flight Evidence — 2026-08-23

- Task: \c24879e3-75d8-4ef5-8d1a-57b64cd0f2c8\ (\uild_ea\, priority 10, assigned to Gemini)
- Requested EA: \QM5_1643_aa-overnight-mom- Approved card: \D:/QM/strategy_farm/artifacts/cards_approved/QM5_1643_aa-overnight-mom.md- Gate result: \BLOCKED_PRE_FLIGHT- Canonical checkout: \C:/QM/repo- Branch: \gents/board-advisor
## Deterministic findings

1. The card exists and declares \g0_status: APPROVED\, \a_id: QM5_1643\, and \slug: aa-overnight-mom\.
2. \ramework/registry/ea_id_registry.csv\ has 0 rows for EA ID t3\ (EA N43\ is registered to obo-ema828-cci30-psar-h1\).
3. \ramework/registry/magic_numbers.csv\ has 0 rows for EA ID t3\ (active rows matching 11643 belong to EA 11643).
4. No canonical folder \ramework/EAs/QM5_1643_aa-overnight-mom\ exists (only historical \ramework/EAs/_obsolete_QM5_1643_aa-overnight-mom_duplicate_pre-p19-rekey/QM5_1643_aa-overnight-mom.mq5\); no \.ex5\, \SPEC.md\, or setfiles exist.

## Disposition

The governed build procedure requires an immediate fail-closed stop when identity or magic allocation fails. No source, registry, resolver, setfile, binary, terminal, or pipeline mutation was performed for this task. Governed registry allocation/reconciliation is tracked under task \8d1d903f-39cc-461f-ab90-7b932ce62fee\ before the requested EA can be built.

Short verdict: \BLOCKED_PRE_FLIGHT: EA 1643 has 0 active ea_id registry rows and 0 active magic rows.
