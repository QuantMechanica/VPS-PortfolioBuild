# Codex EA Build Handoff

You are the Development role for QuantMechanica Option A.

Your only job: implement **one** MQL5 EA mechanically from **one** APPROVED Strategy
Card, register it in the company registries, compile it, and run the smoke test.
No improvisation, no second card, no other pipeline phase work.

## Binding Process

Read and follow these documents:

- `C:\QM\repo\framework\V5_FRAMEWORK_DESIGN.md`
- `G:\My Drive\QuantMechanica - Company Reference\03 Pipeline\P1 Build Validation.md`
- `G:\My Drive\QuantMechanica - Company Reference\06 Infrastructure\EA Framework.md`
- `G:\My Drive\QuantMechanica - Company Reference\06 Infrastructure\Risk Conventions.md`
- `G:\My Drive\QuantMechanica - Company Reference\01 Identity\Hard Rules.md`
- `G:\My Drive\QuantMechanica - Company Reference\04 Processes\Determinism Over LLM Calls.md`

Structural reference EA (use only for layout/style, NOT to copy strategy logic):

- `C:\QM\repo\framework\EAs\QM5_1006_davey-eu-day\`

Registries (must update on success):

- `C:\QM\repo\framework\registry\magic_numbers.csv`
- `C:\QM\repo\framework\registry\ea_id_registry.csv`

## Current Build Task

Task ID: `{{task_id}}`
EA ID: `{{ea_id}}`
Slug: `{{slug}}`
Card path: `{{card_path}}`
Source ID: `{{source_id}}`
Target EA directory: `{{ea_dir}}`
Build artifact target: `{{build_result_path}}`

## Hard Rules (cannot violate)

- **HR3 Model 4** — backtest config must specify Model 4 (Every Real Tick).
- **HR4 Risk Model** — both `RISK_FIXED` ($1,000 backtest) and `RISK_PERCENT` (0.5% live)
  inputs MUST exist as user-visible EA inputs. Default to RISK_FIXED in tester.
- **HR5 Magic Schema** — `magic = ea_id_int * 10000 + symbol_slot`. Collision in
  `magic_numbers.csv` = HARD ABORT. Set `blocked_reason: "magic collision <details>"`
  and stop. Never silently overwrite.
- **HR9 Enhancement Doctrine** — this is a new EA; no existing positions to protect.
  But: do NOT deviate from the card during implementation. If the card is ambiguous,
  flag it in `open_questions` and proceed with the most literal reading.
- **HR14 NO ML** — no neural networks, no `MathNN_*`, no ONNX runtime calls, no
  Python-bridge inference, no adaptive parameters (parameters mutating based on
  running PnL or recent equity), no retraining-style logic.
- **Framework architecture** — the EA MUST implement these named sections/functions
  (verifiable by `build_check.ps1`):
  - No Trade Filter (time, spread, news)
  - Trade Entry
  - Trade Management
  - Trade Close
  - News Filter Hook (callable for P8 News Impact phase)

## Workflow

1. Read `{{card_path}}` fully. Extract Entry, Exit, Stop Loss, Position Sizing,
   and Filters sections. If the card has `g0_status: APPROVED` is NOT set in the
   frontmatter — STOP and return `blocked_reason: "card not APPROVED"`.

2. Reserve an ea_id row in `framework\registry\ea_id_registry.csv` if not already
   present. Append `{{ea_id}},{{slug}}` row (preserve CSV header + line endings).

3. Compute magic_base = numeric suffix of `{{ea_id}}` × 10000. For each symbol the
   card targets (or all symbols in `framework\registry\dwx_symbol_matrix.csv` if the
   card is symbol-agnostic), reserve a slot in `magic_numbers.csv`. One row per
   `(ea_id, symbol, magic)`. HARD ABORT on collision.

4. Create directory `{{ea_dir}}`.

5. Write `{{ea_id}}_{{slug}}.mq5` implementing the card mechanically against the
   framework architecture.

6. Run `pwsh -File C:\QM\repo\framework\scripts\build_check.ps1 -EALabel {{ea_id}}_{{slug}}`.
   Must pass.

7. Run `pwsh -File C:\QM\repo\framework\scripts\compile_one.ps1 -EALabel {{ea_id}}_{{slug}}`.
   Must produce `.ex5`.

8. Run `pwsh -File C:\QM\repo\framework\scripts\run_smoke.ps1 -EALabel {{ea_id}}_{{slug}}`.
   Must yield ≥1 trade for `smoke_result: passed`.

Do not generate full P2 set files at this stage — that is the next phase via
`gen_setfile.ps1`. A minimal smoke set is acceptable.

## Required Output Contract

Write **exactly one JSON object** to `{{build_result_path}}` AND echo it to stdout.
No prose around it. Schema:

```json
{
  "task_id": "{{task_id}}",
  "ea_id": "{{ea_id}}",
  "ea_dir": "framework/EAs/{{ea_id}}_{{slug}}",
  "mq5_path": "<absolute path>",
  "ex5_path": "<absolute path or null if compile failed>",
  "magic_base": <int>,
  "symbols_registered": ["EURUSD.DWX", "..."],
  "build_check_passed": true,
  "compile_succeeded": true,
  "smoke_result": "passed" | "zero_trades" | "compile_failed" | "build_check_failed" | "framework_error",
  "smoke_report_path": "<absolute path or null>",
  "blocked_reason": null,
  "open_questions": []
}
```

- `smoke_result: "zero_trades"` means the EA compiled and ran but produced no trades
  in the smoke window. Per HR7 NO_REPORT ≠ EA-Schwäche — record it, don't fake `passed`.
- `smoke_result: "compile_failed"` — `.ex5` was not produced; include the compile log
  path under `smoke_report_path`.
- `blocked_reason` non-null → set ALL boolean success fields to `false` and zero the
  paths. Do not pretend the build worked.

## Final Response Rule

Your final response to this prompt is **only** the JSON object. No commentary, no
markdown fences around it, no leading "Here is the result". Just the JSON. Board
Advisor will read the file at `{{build_result_path}}`.
