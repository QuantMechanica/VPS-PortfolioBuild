# QM5_1605 Build Pre-flight Evidence — 2026-08-22

- Task: `00946895-b594-4740-8e9f-884d3e3ea58a` (`build_ea`, priority 50, assigned to Codex)
- Requested EA: `QM5_1605_ehlers-spectral-dilation-h4`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1605_ehlers-spectral-dilation-h4.md`
- Gate result: `BLOCKED_PRE_FLIGHT`

## Deterministic findings

1. The card exists and declares `g0_status: APPROVED`, `ea_id: QM5_1605`, and `slug: ehlers-spectral-dilation-h4`.
2. `framework/registry/ea_id_registry.csv` instead binds active EA ID `1605` to slug `aa-jan-yc-risk`:

   ```text
   1605,aa-jan-yc-risk,ede348b4-0fa7-5be1-baa8-09e9089b67b7,active,Research,2026-05-19,,,
   ```

3. `framework/registry/magic_numbers.csv` has no row for EA ID `1605`.
4. The requested folder/source exists, but the mandatory identity relation `card slug == EA folder slug == active ea_id registry slug` is false.

## Disposition

The governed build procedure requires an immediate stop when identity or magic allocation fails. No source, registry, resolver, setfile, binary, terminal, or pipeline mutation was performed for this task. OWNER-governed registry allocation/reconciliation is required before the requested EA can be built.

Short verdict: `BLOCKED_PRE_FLIGHT: EA 1605 is registered to aa-jan-yc-risk, not the approved card slug; magic rows absent.`
