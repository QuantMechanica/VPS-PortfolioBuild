# QM5_12946 build preflight evidence

Date: 2026-08-21

Router task: `f3254781-8a6f-4d7b-bf99-8183ca5c892a`

EA: `QM5_12946_mql5-macd-obv-div-card`

Branch: `agents/board-advisor`

## Deterministic result

`PRECHECK_FAIL_MISSING_MAGIC_ROWS`

The `qm-build-ea-from-card` procedure requires active magic rows for every
symbol slot before strategy implementation. That gate fails, so the procedure
requires a stop and does not authorize Codex to allocate rows or continue into
source, SPEC, setfile, compile, smoke, or pipeline work.

## Verification

- Approved card exists at
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12946_mql5-macd-obv-div-card.md`.
- Card frontmatter has `g0_status: APPROVED` and slug
  `mql5-macd-obv-div-card`.
- `ea_id_registry.csv` has exactly one active `12946` row with the same slug.
- `magic_numbers.csv` has zero active rows for `ea_id=12946`.
- `QM_MagicResolver.mqh` contains no `12946` entry.
- The EA directory remains clean and contains only the tracked TODO MQ5 source;
  no `.ex5`, `SPEC.md`, or setfiles exist.
- Source SHA-256:
  `2c04e592e9e86ab86ecc180b0379369db93054f5b3c6fc521316d24515ac1ac5`.

## Required governed action

The OWNER-governed allocation flow must determine the required symbol surface,
create collision-free active `(12946, symbol_slot)` rows, regenerate
`QM_MagicResolver.mqh`, and verify that no allocated row was dropped. A later
router cycle may build only after those prerequisites pass.

No terminal, Q pipeline phase, T_Live, AutoTrading, registry, or EA source
mutation was performed.

## Handoff

Build result:
`C:/QM/repo/artifacts/qm5_12946_build_result.json`

Required state: `REVIEW` for governed adjudication. This artifact is not a
pipeline verdict and does not authorize self-approval.
