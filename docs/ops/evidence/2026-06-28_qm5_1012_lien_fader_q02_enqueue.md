# QM5_1012 lien-fader Q02 enqueue evidence - 2026-06-28

## Scope

- EA: `QM5_1012_lien-fader`
- Card: `strategy-seeds/cards/lien-fader_card.md`
- Asset class: FX
- Timeframe: H1 entry with D1 ADX / prior-day range reference
- Build task: `5b5d24e3-0e29-428f-968f-19c29eca552c`
- Build result: `D:\QM\strategy_farm\artifacts\builds\5b5d24e3-0e29-428f-968f-19c29eca552c.json`

## Validation

- `compile_one.ps1 -Strict`: PASS, 0 errors, 0 warnings
- `build_check.ps1 -EALabel QM5_1012_lien-fader`: PASS, 0 failures
- `validate_spec_doc.py framework/EAs/QM5_1012_lien-fader`: PASS

## Q02 enqueue

`record_build_result` auto-enqueued the stage-1 Q02 wave:

| Work item | Symbol | TF | Status |
|---|---|---|---|
| `b7a7bb31` | `AUDCAD.DWX` | H1 | pending |
| `68ed0721` | `AUDUSD.DWX` | H1 | pending |
| `29b41685` | `EURCAD.DWX` | H1 | pending |

The remaining generated setfiles were staged in `D:\QM\strategy_farm\state\q02_deferred_symbols.json` by the standard Q02 staging rule: `EURCHF.DWX`, `EURGBP.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`, `USDJPY.DWX`.
