# QM5_1628 Gemini review rework

Date: 2026-09-12

Router task: `3c46e814-d8b2-429c-9a15-d7660a3376d1`

EA: `QM5_1628_carney-5-0-pattern-h4`

## Decision

The governed build preflight fails before any implementation change is authorized. The OWNER-approved card exists at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1628_carney-5-0-pattern-h4.md`, has `g0_status: APPROVED`, and has SHA-256 `c1449f41e592e4ed4cfb772d1af30721289380a0acd1d15c566a03f961838130`.

`framework/registry/magic_numbers.csv` contains the four active, card-aligned allocations:

- slot 0: EURUSD.DWX / 16280000
- slot 1: GBPUSD.DWX / 16280001
- slot 2: USDJPY.DWX / 16280002
- slot 3: XAUUSD.DWX / 16280003

However, the exact anchored lookup `^1628,` returns no row from `framework/registry/ea_id_registry.csv`. A valid allocated EA-ID row is a mandatory precondition to source creation, SPEC creation, and governed compilation. The registry is single-writer governed; this review cannot invent or append the missing row.

## Disposition of prior findings

The prior review specifically reports a missing EA registry row, missing SPEC, missing build closure, and the mechanical defect that structural SL is anchored to the D pivot rather than the card-required C pivot. The current directory still has no `SPEC.md`. Those findings remain open. Under the failed preflight, this review did not modify the `.mq5`, did not create a SPEC, did not alter setfiles, and did not request `COMPILE_EA`. The existing `.ex5` is not accepted as fresh governed build evidence.

The approved and rejected card pools both contain a file with this name, but the approved copy explicitly records the rejected copy as superseded recovery provenance. That does not cure the missing deterministic EA-ID allocation.

## Required unblock

1. The governed registry writer must allocate/activate exact EA 1628 with slug `carney-5-0-pattern-h4` and the approved card's source ID.
2. Re-run build preflight and prove the EA-ID and all four magic rows agree with the approved card.
3. Only then repair the C-pivot structural stop, create the card-locked SPEC and tests, and enqueue `COMPILE_EA` through the guarded compiler path.
4. Return the resulting code/build evidence to Codex review. Do not advance it directly to any pipeline phase.

No terminal was started, no backtest was run or interrupted, and neither `T_Live` nor AutoTrading was touched.

RESULT: BLOCKED_PRECHECK — missing `ea_id_registry.csv` allocation; source/SPEC/build rework is unauthorized and the Gemini build remains REVIEW.
