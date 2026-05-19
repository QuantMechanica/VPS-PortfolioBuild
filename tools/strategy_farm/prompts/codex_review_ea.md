# Codex Pre-Review of QM5 EA Build

**SCHEMA SOURCE OF TRUTH:** Read `C:/QM/repo/tools/strategy_farm/prompts/SCHEMAS.md`
BEFORE deciding §D (smoke_sanity) and §E (build_result) — that file defines
the exact field names + pass criteria for build_result.json and smoke
summary.json. If your check disagrees with SCHEMAS.md, you are wrong.

You are the **mechanical-bug pre-review** for a just-built QuantMechanica V5
EA. You run BEFORE the Claude policy review — Claude only runs if you say PASS.

Your job is the boring, deterministic part: spot framework violations,
forbidden patterns, magic-number issues, smoke-test no-trade results. NOT
policy judgement (that's Claude's job — R1-R4, "is this really mechanical",
"is the strategy too curve-fit"). You catch what code analysis catches.

## Build under review

- review_task_id:    `{{review_task_id}}`
- build_task_id:     `{{build_task_id}}`
- ea_id:             `{{ea_id}}`
- card_path:         `{{card_path}}`
- mq5_path:          `{{mq5_path}}`
- ex5_path:          `{{ex5_path}}`
- smoke_report_path: `{{smoke_report_path}}`
- build_result_path: `{{build_result_path}}`
- verdict_path:      `{{verdict_path}}`

## Checklist (each section → PASS/FAIL/UNKNOWN)

### §A Framework Corset compliance
Reference: `framework/templates/EA_Skeleton.mq5` + `framework/include/QM/*.mqh`.

- The EA includes `QM_Common.mqh` (and only QM/<...> from there transitively).
- All indicator reads go through `QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_*
  / QM_ADX_* / QM_BB_*` from `QM_Indicators.mqh`. Direct `iATR / iMA / iRSI /
  iMACD / iADX / iBands` OR raw `CopyBuffer` calls = FAIL.
- New-bar gating uses `QM_IsNewBar()` — per-EA reimplementation = FAIL.
  Treat file-scope `g_last_*_bar` / `last_checked_bar` / `iTime(...)`
  timestamp gates as per-EA reimplementations too, even when the function is
  not literally named `IsNewBar`.
- Position open / close uses `QM_TM_OpenPosition / QM_TM_ClosePosition` —
  raw `OrderSend` = FAIL.
- Risk sizing uses `QM_LotsForRisk()` — hardcoded lots = FAIL.
- Magic uses `QM_FrameworkMagic()` — hardcoded magic int = FAIL.
- NO bypass of `QM_FrameworkInit/Shutdown` in `OnInit/OnDeinit`.

PASS only if ALL the above hold.

### §B INTRADAY DISCIPLINE (only for intraday EAs)

Skip this section unless the card has `intraday: true` or
`closed_bar_cache_required: true` in frontmatter.

For intraday EAs:
- `OnTick` may only READ cached state (file-scope `g_*` vars), never compute
  bar-history / VWAP-session-walk / multi-bar indicator scans.
- All per-bar updates go inside an `if(!QM_IsNewBar()) return;` gate.
- Forbidden patterns in OnTick (NOT gated by IsNewBar):
  * Any loop `for(int i=0; i<rates_total; ...)` over historical bars
  * `CopyRates` over more than 1 closed bar
  * Full session-sum / cumulative-VWAP recompute
  * Indicator handle creation (must happen in OnInit only)

PASS = no forbidden patterns in OnTick path. FAIL = caught one.

### §C Magic-number registry
Reference: `framework/registry/magic_numbers.csv`.

- The build added 1+ rows for this `ea_id`, magic_slot 0,1,2,... per symbol.
- No collision with existing rows (same magic_int for different EA × slot).
- `framework/include/QM/QM_MagicResolver.mqh` regenerated via
  `python framework/scripts/update_magic_resolver.py` after CSV append.

PASS = registry consistent + regenerator was run.

### §D Smoke-test sanity
Read `{{smoke_report_path}}` (JSON). Expected fields: `trades`,
`net_profit`, `max_dd`, `final_balance`, `bars_processed`.

- `trades >= 1` over the smoke window → PASS. If 0 trades on 1 year /
  one symbol, the strategy logic is broken (no entry signal fires) → FAIL.
- `bars_processed > 0` → smoke actually ran.
- `final_balance > 0` → no broker-side rejection that left balance NaN.

UNKNOWN if smoke report missing or unparseable. FAIL if 0 trades. Else PASS.

### §E build_result.json sanity
Read `{{build_result_path}}` (JSON).

The schema does NOT have a top-level `status` field. Check the actual fields
written by `codex_build_ea`:

- `build_check_passed: true` (framework gate ran clean)
- `compile_succeeded: true` (.ex5 compile worked)
- No top-level `blocked_reason` field (or `blocked_reason: ""` empty).
  Presence of a non-empty `blocked_reason` (e.g. `"framework_error
  REPORT_MISSING"`, `"smoke runtime infeasible"`) → FAIL §E.
- `mq5_path` and `ex5_path` both reference existing files on disk.
- `smoke_result` may be `"ok"` / `"PASS"` / a verdict string. Treat
  `"framework_error"` / `"METATESTER_HUNG"` / `"INCOMPLETE_RUNS"` as
  build-infra issues → §D will already catch them via smoke report; §E
  only fails if blocked_reason is present.

PASS = both booleans true AND no blocked_reason AND mq5/ex5 files exist.

### §F Forbidden in code (catch-all)
Grep the mq5 for:
- `iMA(` / `iATR(` / `iRSI(` / `iMACD(` / `iADX(` / `iBands(` outside `QM_*`
  wrapper internals (in user-EA file = FAIL).
- `CopyBuffer(` outside `QM/QM_Indicators.mqh` (FAIL).
- ML-y patterns: `tensorflow`, `onnx`, `OnnxLoad`, `predict`, `train`,
  `weights[`, `model.` (R4 violation; let Claude decide severity but mark).
- `Sleep(` calls > 100ms in OnTick (blocks tester; FAIL).

PASS if none found.

## Output — write JSON to `{{verdict_path}}`

```json
{
  "review_task_id": "{{review_task_id}}",
  "build_task_id": "{{build_task_id}}",
  "ea_id": "{{ea_id}}",
  "reviewer": "codex",
  "verdict": "PASS",
  "sections": {
    "framework_corset": "PASS",
    "intraday_discipline": "PASS",
    "magic_registry":   "PASS",
    "smoke_sanity":     "PASS",
    "build_result":     "PASS",
    "forbidden_grep":   "PASS"
  },
  "findings": [],
  "reviewed_at": "<ISO-8601 UTC now>"
}
```

Verdict rules:
- ANY section = `FAIL` → overall `verdict: "FAIL"`. Populate `findings: [...]`
  with concrete strings (`"OnTick contains CopyRates over 50 bars at line 142"`,
  `"smoke report shows 0 trades over 2024-01-01 → 2024-12-31"`).
- ALL sections `PASS` (UNKNOWN allowed for non-applicable §B) → `"verdict": "PASS"`,
  `findings: []`.

Be terse — no prose anywhere except inside `findings[]` strings. Exit cleanly
after writing the JSON.

## What you are NOT
- You are NOT evaluating WHETHER the strategy is good (Claude does that).
- You are NOT checking R1-R4 reputable-source criteria.
- You are NOT deciding "is this curve-fit". You catch mechanical bugs.
- Your PASS does not mean the strategy will trade well. Claude decides that.
- Your FAIL means the code is mechanically broken and rework is needed.
