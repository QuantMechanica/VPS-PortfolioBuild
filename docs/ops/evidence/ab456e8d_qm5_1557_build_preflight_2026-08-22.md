# QM5_1557 build preflight — deterministic symbol/magic stop

- Router task: `ab456e8d-a4fb-46bd-8d12-a75790ac6d7a`
- Task type / priority: `build_ea` / `50`
- Canonical checkout: `C:/QM/repo`
- Branch / inspected HEAD: `agents/board-advisor` / `a2a0e9aaece6e791b2ef0ce45f62c94cbedb3733`
- Verdict: `REVIEW — BUILD_NOT_STARTED_REQUIRED_SYMBOL_MAGIC_GATE_FAIL`

## Governed preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved Strategy Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1557_aa-zak-psma10.md` declares `ea_id: QM5_1557`, slug `aa-zak-psma10`, and `g0_status: APPROVED` | PASS |
| Exact active EA registry identity | `1557,aa-zak-psma10,...,active` | PASS |
| Existing magic allocation | 13 active rows exist for the standard index/gold/FX symbol set | PARTIAL |
| Card-required symbol coverage | The card's baseline explicitly includes `USOIL.DWX`; EA 1557 has no magic row for it | FAIL |
| Exact DWX namespace | `USOIL.DWX` is absent from `framework/registry/dwx_symbol_matrix.csv` | FAIL |
| Existing source | The canonical EA directory contains only the tracked skeleton and approved-card copy | OBSERVED |

The exact DWX matrix contains `XTIUSD.DWX`, but the card says `USOIL.DWX`.
Build-time `.DWX` substitution by hand is forbidden, and the build skill
requires a magic allocation for every card symbol the EA will use. Omitting
the oil baseline or silently replacing it with XTIUSD would both change the
approved card contract.

No source, registry, resolver, setfile, or binary was changed, and no compile
or pipeline phase was run. An OWNER-governed card correction plus matching
magic allocation, or an explicit scope disposition removing that baseline
symbol, is required before implementation.

## Focused verification

```text
rg 'Baseline DWX symbols|USOIL.DWX' D:/QM/strategy_farm/artifacts/cards_approved/QM5_1557_aa-zak-psma10.md
=> baseline includes USOIL.DWX

rg '^1557,.*USOIL.DWX' framework/registry/magic_numbers.csv
=> no matches

rg '^USOIL.DWX,' framework/registry/dwx_symbol_matrix.csv
=> no matches

rg '^XTIUSD.DWX,' framework/registry/dwx_symbol_matrix.csv
=> XTIUSD.DWX exists; it was not substituted
```
