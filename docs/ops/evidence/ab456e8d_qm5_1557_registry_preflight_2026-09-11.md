# QM5_1557 build pre-flight — registry gate

- Task: `ab456e8d-a4fb-46bd-8d12-a75790ac6d7a`
- EA: `QM5_1557_aa-zak-psma10`
- Date: 2026-09-11
- Verdict: `REVIEW — deterministic pre-flight gate failed`

## Governed inputs

The approved card is `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1557_aa-zak-psma10.md`. Its front matter has `g0_status: APPROVED`, `ea_id: QM5_1557`, and `slug: aa-zak-psma10`. The card's baseline universe is:

`SP500.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, XAUUSD.DWX, USOIL.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX`

The canonical EA registry contains an active matching row for EA 1557 and slug `aa-zak-psma10`.

## Failed gate

`framework/registry/magic_numbers.csv` has 13 active rows for EA 1557, but none for the card-required `USOIL.DWX`. The allocated rows are:

`GDAXI.DWX, NDX.DWX, SP500.DWX, UK100.DWX, WS30.DWX, XAUUSD.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX, AUDUSD.DWX, USDCAD.DWX, NZDUSD.DWX`

This is not a build-time alias decision: the deterministic registry has neither `USOIL.DWX` nor an oil-symbol row for EA 1557. Several allocated symbols are not in the approved card. Building only a subset, silently substituting a symbol, or using an unrelated slot would deviate from the OWNER-approved strategy and violate the `qm-build-ea-from-card` pre-flight contract that requires an active `(ea_id, symbol_slot)` row for every card symbol used.

## Focused verification

Executed from `C:/QM/repo` on branch `agents/board-advisor`:

```powershell
rg -n '^1557,' framework/registry/ea_id_registry.csv
rg -n '^1557,' framework/registry/magic_numbers.csv
rg -n 'Baseline DWX symbols|USOIL\.DWX' D:/QM/strategy_farm/artifacts/cards_approved/QM5_1557_aa-zak-psma10.md
git diff --exit-code -- framework/EAs/QM5_1557_aa-zak-psma10/QM5_1557_aa-zak-psma10.mq5
```

Results: matching EA registry row present; 13 active magic rows enumerated; card requires `USOIL.DWX`; no source diff remains. Compile and pipeline phases were not run because the build pre-flight failed.

## Required close-out

OWNER-governed registry maintenance must reconcile the approved card universe with EA 1557's magic allocation, including an explicit decision for `USOIL.DWX` versus the canonical broker oil symbol. After the required active row exists and unrelated allocations are reconciled, the build task can be re-routed.
