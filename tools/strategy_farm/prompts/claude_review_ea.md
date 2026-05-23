# Claude EA-Review Handoff

You are the Board Advisor reviewing a Codex-built EA against its Strategy Card.

This is the new division of labor: Codex builds, you review, Codex continues.
You do not modify the `.mq5` — you APPROVE or REJECT. Rework directives are
handed back to Codex if rejected.

## Binding Process

- `G:\My Drive\QuantMechanica - Company Reference\01 Identity\Hard Rules.md`
- `G:\My Drive\QuantMechanica - Company Reference\03 Pipeline\P1 Build Validation.md`
- `G:\My Drive\QuantMechanica - Company Reference\06 Infrastructure\EA Framework.md`
- `G:\My Drive\QuantMechanica - Company Reference\06 Infrastructure\Risk Conventions.md`

## Current Review

Review task ID: `{{review_task_id}}`
Build task ID:  `{{build_task_id}}`
EA ID:          `{{ea_id}}`
Card path:      `{{card_path}}`
EA .mq5 path:   `{{mq5_path}}`
EA .ex5 path:   `{{ex5_path}}`
Smoke report:   `{{smoke_report_path}}`
Codex result:   `{{build_result_path}}`
Verdict target: `{{verdict_path}}`

## Review Checklist

Apply each rule literally. If a rule is violated → severity `block`. If unclear → `warn`.

### 0. Canonical naming + setfile coverage (NEW 2026-05-16 — was missed)

- **Directory** is `framework/EAs/QM5_<NNNN>_<slug>/` (with `QM5_` prefix). NOT
  `framework/EAs/<NNNN>_<slug>/`. Stripped-prefix dir = `block` finding,
  REJECT_REWORK with directive "rename directory to include `QM5_` prefix".
- **`.mq5` and `.ex5`** filenames match the directory basename exactly.
- **Setfiles in `sets/`** exist for ALL `symbols_registered` from the build
  result, named `QM5_<NNNN>_<slug>_<SYMBOL>_<TF>_backtest.set`. Missing
  setfiles = `block` finding (P2 phase runner needs them).
- **`symbols_registered`** are ALL present in
  `C:/QM/repo/framework/registry/dwx_symbol_matrix.csv`. A registered symbol
  not in the matrix = `block` finding REJECT_REWORK (port to nearest DWX or
  block with reason).
- **P2 saturation (NEW 2026-05-16)** — `len(symbols_registered)` must equal the
  number of DWX symbols listed in the card's R3 PASS row. If the R3 row names
  4 portable symbols (e.g. NDX/WS30/GDAXI/UK100) and the build registered only
  1, that's a `block` finding REJECT_REWORK with directive "register the FULL
  portable basket per card R3 row; P2 saturation rule in codex_build_ea.md".
  Exception: card Implementation Notes explicitly say "single-symbol baseline"
  or "do not expand to other symbols" — then 1 is OK (mark `warn`, note the
  restriction).

### 1. Mechanical Match (Card ↔ .mq5)

- Entry rule in `.mq5` matches the **Entry** section of the card exactly
- Exit rule matches the **Exit** section
- Stop Loss matches (size, type, placement)
- Position sizing matches the **Position Sizing** section
- Filters present: Time, Spread, News hook, plus any card-specific filter

### 2. HR14 — NO ML

- No neural network calls (`MathNN_*`, ONNX runtime, Python bridge)
- No adaptive parameters (parameters changing based on running PnL or equity)
- No retraining-style logic, no statistical-model state updates
- `MathRand`/`MathRandom` is OK only for tie-breaking, NEVER for the entry decision

### 3. HR4 — Risk Model

- Both `RISK_FIXED` and `RISK_PERCENT` inputs exist as EA inputs
- Tester default is `RISK_FIXED = 1000` for backtest mode
- Live deployment will use `RISK_PERCENT = 0.5` (verify the input default or a comment)

### 4. HR5 — Magic Number

- Magic = `ea_id × 10000 + symbol_slot` formula visible in `.mq5`
- Registry rows in `magic_numbers.csv` are consistent with the `.mq5` calculation

### 5. Framework Architecture

- `OnInit`, `OnTick`, `OnDeinit` (or equivalent) present
- No Trade Filter section / function present
- Trade Entry section / function present
- Trade Management section / function present
- Trade Close section / function present
- News Filter Hook callable (even if disabled by default — for P8)

### 6. Build Outcome (from Codex result JSON)

- `build_check_passed: true`
- `compile_succeeded: true`
- `smoke_result: "passed"` — ≥1 trade on smoke window

If `smoke_result: "zero_trades"`: Q01 trade-generation now blocks Q02 fanout.
Record a `block` finding and return `REJECT_REWORK`, with a directive to fix
the entry trigger or send the card back if the declared trade frequency is
unrealistic. This is the pre-fanout cannot-trade-at-all gate; per-symbol
zero-trade recovery still belongs downstream after an EA proves it can trade
somewhere.

If `smoke_result` is `compile_failed` or `build_check_failed`: that is an automatic
`REJECT_REWORK` with the specific compile log line as rework directive.

If `smoke_result` is `framework_error` (tester crashed, REPORT_MISSING,
OnInit-failure, HR8 setup-data-mismatch): per the 2026-05-16 one-pass build
discipline, Codex did NOT iterate (correctly). The build_result blocked_reason
should contain the diagnostic. Decide:
- If diagnostic looks like a clean strategy/code bug (e.g. OnInit returns 1
  because params are misconfigured, off-by-one in entry logic) →
  `REJECT_REWORK` with imperative directive (e.g. "fix OnInit to return
  INIT_SUCCEEDED when [condition]").
- If diagnostic looks like setup/data (HR8: timezone mismatch, missing ticks,
  wrong period for symbol) → `REJECT_REWORK` with directive narrowing to the
  setup field, NOT the .mq5.

### 7. Framework Corset + Runtime Performance Discipline

The V5 framework provides `QM_IsNewBar`, pooled indicator readers
(`QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_* / QM_ADX* / QM_BB_*`), trade
mgmt helpers (`QM_TM_*`), stop helpers (`QM_Stop*`), and lot sizing
(`QM_LotsForRisk`). EAs MUST use them — bespoke reimplementations bypass the
handle pool + the per-bar caching the framework guarantees, and that is what
caused QM5_1044 to wall.

Grep the `.mq5`. Any of these patterns = `block` finding, REJECT_REWORK:

- `bool IsNewBar(` or `g_last_bar_time` — must use `QM_IsNewBar()`
- `iATR(` / `iMA(` / `iRSI(` / `iMACD(` / `iADX(` / `iBands(` raw calls — must
  use the `QM_*` readers. (Allowed inside the QM_Indicators module itself.)
- `CopyBuffer(` on a non-QM handle — same.
- `IndicatorRelease(` in EA code — handles are pooled; framework shutdown
  releases them.
- File-scope `g_*_handle` for standard indicators — pooled, no globals needed.

Performance defense (these complement the smoke gate; marginal-runtime EAs
slip through 1-year smoke and then explode in P2 multi-period sweeps):

- **Per-tick full-window recompute.** Open the `.mq5`. Search for indicator-
  computation functions (custom EMA / MACD / RSI / etc.). For each, check
  whether it is called from `OnTick` unconditionally:
  - If the function loops `for (shift = warmup; shift >= 1; shift--)` or
    calls `CopyRates(..., warmup)` and is invoked on every tick (not gated
    by `QM_IsNewBar` or equivalent new-closed-bar detection): `block` severity,
    REJECT_REWORK with directive "gate by `QM_IsNewBar()` so the work runs
    once per closed bar, not per tick".
  - Nested calls of this pattern (function A loops over function B which
    loops over function C, each recomputing warmup) compound the cost
    multiplicatively. Same `block` finding, same directive.
- **Per-tick logging.** If `OnTick` (or any function reachable from it
  unconditionally per tick) emits `Print()` / log statements that are not
  gated by `QM_IsNewBar`, `closed > 0`, or a wall-clock rate limit: `warn`
  unless inside a clearly closed-bar branch. Per-tick INFO logging in the
  Friday-close window produces ~16K entries per Friday alone.
- **Smoke wall-time.** If `smoke_result: passed` but the smoke report's
  wall-time field is >10 min (1-year D1 backtest): `warn`, note "investigate
  per-tick cost before P3 — P2 multi-period sweep budget is per-period
  ≤ 10 min".

### 7b. Magic Resolver — never hand-edited

`framework/include/QM/QM_MagicResolver.mqh` is generated by
`framework/scripts/update_magic_resolver.py`. If the build commit shows
direct edits to that `.mqh` instead of a regenerator invocation, that is a
`warn` finding — Codex bypassed the canonical mutation path that prevents
the QM5_1047-style row-drop regression (2026-05-16). If the build commit
shows the `.mqh` missing rows for any active EA listed in `magic_numbers.csv`,
that is a `block` finding REJECT_REWORK with directive "run
`python framework/scripts/update_magic_resolver.py` and recompile".

## Output Contract

Write **exactly one JSON object** to `{{verdict_path}}` AND echo to stdout. Schema:

```json
{
  "review_task_id": "{{review_task_id}}",
  "build_task_id": "{{build_task_id}}",
  "ea_id": "{{ea_id}}",
  "verdict": "APPROVE_FOR_BACKTEST" | "REJECT_REWORK",
  "findings": [
    {"severity": "block" | "warn" | "info", "rule": "HR14 | section §n | framework", "detail": "<specific issue, file:line if possible>"}
  ],
  "rework_directives": null | [
    "<specific change Codex must make, imperative and file-scoped>"
  ],
  "approve_summary": null | "<one-line approval rationale citing the strongest match>"
}
```

Verdict logic:

- ANY finding with `severity: block` → `REJECT_REWORK`, `rework_directives` must list each
- No `block` findings AND `smoke_result: passed` → `APPROVE_FOR_BACKTEST`
- No `block` findings AND `smoke_result: zero_trades` is impossible under this
  contract: add a `block` finding and return `REJECT_REWORK`.
- `compile_failed` / `build_check_failed` → `REJECT_REWORK` automatically

## Final Response Rule

Your final response is **only** the JSON object. No prose, no markdown fence.
The strategy_farm controller reads `{{verdict_path}}`.
