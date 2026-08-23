# QM5_1636 Build Pre-flight Evidence — 2026-08-23

- Task: df5d260-bc78-4503-a517-0aaf63de797e\ (\uild_ea\, priority 10, assigned to Gemini)
- Requested EA: \QM5_1636_sperandeo-3day-pivot-rule-h4- Approved card: \D:/QM/strategy_farm/artifacts/cards_approved/QM5_1636_sperandeo-3day-pivot-rule-h4.md- Gate result: \BLOCKED_PRE_FLIGHT- Canonical checkout: \C:/QM/repo- Branch: \gents/board-advisor
## Deterministic findings

1. The card exists and declares \g0_status: APPROVED\, \a_id: QM5_1636\, and \slug: sperandeo-3day-pivot-rule-h4\.
2. \ramework/registry/ea_id_registry.csv\ line 430 binds active EA ID s6\ to slug \mql5-adx-di-trend\:
   \\	ext
   1636,mql5-adx-di-trend,ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb,active,Research,2026-05-19,,,
   \   The approved card slug \sperandeo-3day-pivot-rule-h4\ is not registered under s6\.
3. \ramework/registry/magic_numbers.csv\ has 0 rows for EA ID s6\ (the only rows matching s6\ belong to EA N36\).
4. The requested folder \ramework/EAs/QM5_1636_sperandeo-3day-pivot-rule-h4\ exists with only an auto-generated skeleton \.mq5\; no \.ex5\, \SPEC.md\, or setfiles exist.

## Disposition

The governed build procedure requires an immediate fail-closed stop when identity or magic allocation fails. No source, registry, resolver, setfile, binary, terminal, or pipeline mutation was performed for this task. Governed registry allocation/reconciliation is tracked under task \8d1d903f-39cc-461f-ab90-7b932ce62fee\ before the requested EA can be built.

Short verdict: \BLOCKED_PRE_FLIGHT: EA 1636 registered to mql5-adx-di-trend not sperandeo-3day-pivot-rule-h4; 0 active magic rows.
