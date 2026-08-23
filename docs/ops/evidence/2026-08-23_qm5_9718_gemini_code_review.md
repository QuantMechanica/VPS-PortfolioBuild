# QM5_9718 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `f53f8bcf-8bef-4277-8dec-405daa87e526`

Source task: `cadbb75f-8566-4326-92c6-912cae4b0da6` (`gemini`, build delivery only)

Reviewed artifact: `D:/QM/strategy_farm/artifacts/builds/cadbb75f-8566-4326-92c6-912cae4b0da6.json`

Verdict: **REQUEST_CHANGES — the D1 contract, exit reachability, framework lifecycle, explicit universe, SPEC, and producer evidence are incomplete; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the mandatory D1 execution contract is wholly undeclared

`OnInit()` returns success immediately after `QM_FrameworkInit()` (source lines
155-162). It has neither a D1 period precheck nor
`QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)`. The bare
`QM_IsNewBar()` at line 210 follows the attached chart period while all signal
and hold reads remain D1, and the Friday-close mode is never contract-checked.

Required correction: declare the framework D1/Friday-close execution contract
immediately after init and fail closed on any mismatch.

### 2. High — news blackout and entry filters suspend Friday close and exits

The active news gate returns at source lines 178-184 before Friday close (line
186), the six-day time stop (line 192), and RSI exit (line 194). The later
`Strategy_NoTradeFilter()` can independently return before both exit families
(lines 189-194). During those conditions the EA relies only on the catastrophic
server stop, which does not implement the card's mandatory temporal or RSI
exits and can also defeat the framework Friday flatten.

Required correction: order the path as kill switch, Friday close, management,
strategy exit, entry-only news/spread eligibility, D1 new-bar gate, then entry.

### 3. High — required framework lifecycle and evidence hooks are absent

The file ends after its entry path (source line 219). It has no `OnTimer()`
forwarder, no `OnTradeTransaction()` forwarder, no `OnTester()` objective, and
does not call `QM_EquityStreamOnNewBar()` at the new-bar boundary. Transaction
and equity evidence, timer servicing, and the canonical tester objective are
therefore omitted even though the producer calls this a V5 build.

Required correction: restore the complete V5 skeleton lifecycle and telemetry
hooks without bypassing the framework.

### 4. High — ten delivered symbols violate the explicit card universe

The card's `## Target Symbols` contract is exactly `SP500.DWX` (backtest),
`NDX.DWX`, and `WS30.DWX` on D1 (card lines 81-82). The build, setfiles, and
active magic rows instead cover 13 symbols, adding `GDAXI.DWX`, `UK100.DWX`,
`XAUUSD.DWX`, and seven FX pairs. The static D17 parser returned an empty
`card_target_symbols` list and missed the prose-format contract; that tooling
gap is not card authority.

Required correction: restrict the package to the three approved targets or
obtain an OWNER-approved card amendment.

### 5. High — the mandatory SPEC is missing

`framework/EAs/QM5_9718_bandy-cumulative-rsi2-mr-index/SPEC.md` does not exist,
and `validate_spec_doc.py` fails explicitly. The operator-facing strategy,
inputs, D1 binding, approved universe, and risk surface therefore have no
durable build contract.

Required correction: generate a truthful SPEC from the approved card and MQ5
and pass semantic D1/universe/input validation.

### 6. High — the producer artifact is not a canonical build result

The submitted identity JSON omits `compile_succeeded`, `ea_dir`, `magic_base`,
`symbols_registered`, `spec_md_path`, `smoke_result`, and `smoke_report_path`
required by `tools/strategy_farm/prompts/SCHEMAS.md`; its `ea_id` is also
`"9718"` rather than `"QM5_9718"`. No smoke summary is supplied. File hashes
match, but this record cannot prove a schema-complete build or runtime sanity.

Required correction: emit a canonical result bound to the immutable task and
exact files, plus smoke evidence or a canonical saturation-only deferral.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`.
- EA registry row `9718 / bandy-cumulative-rsi2-mr-index` is active.
- Thirteen active magic rows exist at slots 0-12; the active/reserved registry
  has zero global magic collisions, and all 13 expected magic values are in the
  generated resolver. This is consistency, not symbol authorization.
- The two closed-bar RSI reads, cumulative threshold, SMA regime, and RSI exit
  comparisons match the card's core signal formula.
- All 13 setfiles use normal line endings, `RISK_FIXED=1000`, and
  `RISK_PERCENT=0`; no control bytes were found.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and warnings, subject to the
  manual lifecycle, reachability, and target-symbol findings above.
- MQ5 SHA-256 matches the producer artifact:
  `a1f3e7c8c89e9493ee90575f38c32825127d01afc6f5c4a126a68f12014afacb`.
- EX5 SHA-256 matches the producer artifact:
  `4373e85b717dea0c9da860771b9e3f89392d53d611baad6617ee87ed6b071754`.
- The focused forbidden scan found no raw indicator handle, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML entry point.

These passes establish file identity and limited static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, setfile, work item, task verdict, or trade stream
was changed by this review. `T_Live` and AutoTrading were not touched. The task
remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code and evidence
require a fresh mandatory Codex review before acceptance or enqueue.
