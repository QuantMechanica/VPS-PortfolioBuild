# QM5_1604 Build Pre-flight Evidence — 2026-08-22

- Task: `5abe871c-8cef-4f0d-b8bf-b995c181ed4a` (`build_ea`, priority 50, assigned to Codex)
- Requested EA: `QM5_1604_sperandeo-123-reversal-h4`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1604_sperandeo-123-reversal-h4.md`
- Gate result: `BLOCKED_PRE_FLIGHT`

## Deterministic findings

1. The card exists and declares `g0_status: APPROVED`, `ea_id: QM5_1604`, and `slug: sperandeo-123-reversal-h4`.
2. `framework/registry/ea_id_registry.csv` instead binds active EA ID `1604` to slug `aa-mom-ex3-filter`:

   ```text
   1604,aa-mom-ex3-filter,ede348b4-0fa7-5be1-baa8-09e9089b67b7,active,Research,2026-05-19,,,
   ```

3. `framework/registry/magic_numbers.csv` has no row for EA ID `1604`.
4. The requested folder/source exists, but the mandatory identity relation `card slug == EA folder slug == active ea_id registry slug` is false.

## Disposition

The governed build procedure requires an immediate stop when identity or magic allocation fails. No source, registry, resolver, setfile, binary, terminal, or pipeline mutation was performed for this task. OWNER-governed registry allocation/reconciliation is required before the requested EA can be built.

Short verdict: `BLOCKED_PRE_FLIGHT: EA 1604 is registered to aa-mom-ex3-filter, not the approved card slug; magic rows absent.`
