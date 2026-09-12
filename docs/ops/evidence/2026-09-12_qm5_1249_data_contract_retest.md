# QM5_1249 governed-data preflight retest

Date: 2026-09-12  
Router task: `e8f31c15-cf2e-4210-bd4c-4459aadee494`  
EA: `QM5_1249_hsu-carry-stop`  
Disposition: REVIEW — blocking condition confirmed; no build or requeue authorized

## Binding preflight result

The approved card requires a deterministic monthly short-rate CSV to rank six FX pairs by base-minus-quote interest-rate differential. The implementation reads `QM5_1249_fx_monthly_rates.csv` from terminal Files or FILE_COMMON and deliberately stays flat if it is absent or stale.

A read-only exact-name search on 2026-09-12 found no `QM5_1249_fx_monthly_rates.csv` under:

- `D:/QM/data`
- `D:/QM/strategy_farm`
- `C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files`

The card itself records the dependency in Mechanics and says in its R3 assessment that an OWNER-provided deterministic monthly short-rate CSV is required. Its frontmatter nevertheless says `r3_data_available: PASS`. That unresolved governance contradiction cannot be corrected by substituting price data or by fabricating a rate series.

## Package and queue observations

- Source SHA-256: `3314d0434f3dab90e90e1a101e1f7f677e9b5677491382f851968fa6233274ab`.
- SPEC validation: PASS.
- Six backtest setfiles and six active magic rows exist.
- Farm inventory: 18 historical Q02 rows, comprising six `RETIRED_LOW_FREQ` completions and twelve `INFRA_FAIL` failures; no open row and no later successful governed result.

Passing static package validation does not make the external economic input reproducible. A compile would only reproduce a binary that must remain flat without the missing series.

## Decision

The task's `blocked_retest` remains true and explicitly says Development must not requeue the current card. Therefore:

- no source or setfile was changed;
- no COMPILE_EA or Q02 work was enqueued;
- no existing work item or verdict was mutated;
- no terminal, T_Live, or AutoTrading state was touched.

The required next action belongs to Strategy Governance/OWNER: issue a dated card disposition that either (a) defines a governed, reproducible rate-series source and data contract and re-approves R3, or (b) rejects/retires the card and closes the EA identity. This artifact makes no choice between those materially different outcomes.

