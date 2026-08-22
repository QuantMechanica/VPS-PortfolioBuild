# QM5_1611 Build Pre-flight Evidence — 2026-08-22

- Task: `315fdaf0-eec9-4bf2-bac7-69f0acc143ff` (`build_ea`, priority 50, assigned to Codex)
- Requested EA: `QM5_1611_aa-dsp-hpes024`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1611_aa-dsp-hpes024.md`
- Gate result: `BLOCKED_PRE_FLIGHT`

## Deterministic findings

1. The card exists and declares `g0_status: APPROVED`, `ea_id: QM5_1611`, and `slug: aa-dsp-hpes024`.
2. `framework/registry/ea_id_registry.csv` has the matching active identity for EA ID `1611`.
3. The approved card's baseline symbol scope explicitly includes `USOIL.DWX`.
4. The active `framework/registry/magic_numbers.csv` rows for EA ID `1611` contain neither `USOIL.DWX` nor the current DWX oil symbol `XTIUSD.DWX`. The allocated rows are GDAXI, NDX, SP500, UK100, WS30, XAUUSD, EURUSD, GBPUSD, USDJPY, USDCHF, AUDUSD, USDCAD, and NZDUSD.
5. Existing generated setfiles mirror those allocated rows and therefore do not cure the missing card-required oil allocation.

## Disposition

The governed build procedure requires magic rows for every card symbol the EA will use. Substituting or omitting the oil symbol would change the approved card contract, while allocating registry rows is outside the build skill boundary. No source, registry, resolver, binary, terminal, or pipeline mutation was performed for this task.

OWNER-governed card/registry reconciliation is required: either allocate the approved oil symbol under EA 1611 or approve an amended symbol scope.

Short verdict: `BLOCKED_PRE_FLIGHT: card requires USOIL.DWX, but EA 1611 has no oil magic allocation.`
