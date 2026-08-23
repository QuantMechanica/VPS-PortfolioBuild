# QM5_9719 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `1ba1f9a9-0250-40a3-9a77-d8451b992fbb`

Source task: `568405c9-6c59-464d-ba22-b3e9512a638e` (`gemini`, build delivery only)

Reviewed artifact: `D:/QM/strategy_farm/artifacts/builds/568405c9-6c59-464d-ba22-b3e9512a638e.json`

Verdict: **REQUEST_CHANGES — the D1 contract, exit reachability, per-bar computation, framework lifecycle, explicit universe, SPEC, and producer evidence are incomplete; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the mandatory D1 execution contract is wholly undeclared

`OnInit()` returns success immediately after `QM_FrameworkInit()` (source lines
183-190). It has neither a D1 precheck nor
`QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)`. The bare
`QM_IsNewBar()` at line 238 follows the attached chart period while all reads
remain D1, and the Friday-close mode is never contract-checked.

Required correction: declare the framework D1/Friday-close execution contract
immediately after init and fail closed on any mismatch.

### 2. High — news blackout and entry filters suspend Friday close and exits

The active news gate returns at source lines 206-212 before Friday close (line
214), the ten-day time stop (line 220), and PercentRank exit (line 222). The
later `Strategy_NoTradeFilter()` can independently return before both exit
families (lines 217-222). The catastrophic server stop does not implement the
card's temporal/median exits and cannot replace the framework Friday flatten.

Required correction: order the path as kill switch, Friday close, management,
strategy exit, entry-only news/spread eligibility, D1 new-bar gate, then entry.

### 3. High — the 100-bar reduction runs on every market tick

The card explicitly requires maintaining/updating the 100-close buffer once per
new D1 bar and calls the O(N) cost acceptable because it runs once daily (card
lines 66-68). `Strategy_ExitSignal()` instead invokes `CopyClose(...,100)` plus
the 100-element count (source lines 51-70 and 158-169) before the new-bar gate
(line 238). Every tick while any position is open therefore rebuilds the full
D1 window, directly contradicting the approved computation cadence and creating
avoidable tester-timeout pressure.

Required correction: cache the PercentRank on the framework D1 new-bar edge and
let both entry and exit consume that immutable per-bar value.

### 4. High — required framework lifecycle and evidence hooks are absent

The file ends after its entry path (source line 247). It has no `OnTimer()`
forwarder, no `OnTradeTransaction()` forwarder, no `OnTester()` objective, and
does not call `QM_EquityStreamOnNewBar()`. Transaction/equity evidence, timer
servicing, and the canonical tester objective are therefore omitted.

Required correction: restore the complete V5 skeleton lifecycle and telemetry
hooks without bypassing the framework.

### 5. High — ten delivered symbols violate the explicit card universe

The card's target contract is exactly `SP500.DWX` (backtest), `NDX.DWX`, and
`WS30.DWX` on D1 (card lines 86-87). The build, setfiles, and active magic rows
cover 13 symbols, adding two other indices, gold, and seven FX pairs. The D17
parser returned an empty card target list and missed this prose-format contract;
that tooling gap does not expand card authority.

Required correction: restrict the package to the three approved targets or
obtain an OWNER-approved card amendment.

### 6. High — the mandatory SPEC is missing

`framework/EAs/QM5_9719_bandy-percentrank-channel-mr-index/SPEC.md` does not
exist, and `validate_spec_doc.py` fails explicitly. Operators therefore have no
durable contract for the signal, inputs, D1 binding, universe, or risk surface.

Required correction: generate a truthful SPEC from the approved card and MQ5
and pass semantic D1/universe/input validation.

### 7. High — the producer artifact is not a canonical build result

The submitted identity JSON omits `compile_succeeded`, `ea_dir`, `magic_base`,
`symbols_registered`, `spec_md_path`, `smoke_result`, and `smoke_report_path`
required by `tools/strategy_farm/prompts/SCHEMAS.md`; its `ea_id` is also
`"9719"` rather than `"QM5_9719"`. No smoke summary is supplied. Matching
hashes cannot prove a schema-complete build or runtime sanity.

Required correction: emit a canonical result bound to the immutable task and
exact files, plus smoke evidence or a canonical saturation-only deferral.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`.
- EA registry row `9719 / bandy-percentrank-channel-mr-index` is active.
- Thirteen active magic rows exist at slots 0-12; the active/reserved registry
  has zero global magic collisions, and all 13 expected magic values are in the
  generated resolver. This is consistency, not symbol authorization.
- The closed-bar empirical-rank formula and entry/exit comparisons match the
  card when evaluated on a valid 100-close window.
- All 13 setfiles use normal line endings, `RISK_FIXED=1000`, and
  `RISK_PERCENT=0`; no control bytes were found.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and warnings, subject to the
  manual cadence, lifecycle, reachability, and target-symbol findings above.
- MQ5 SHA-256 matches the producer artifact:
  `daf7f3bde16ead8d3e4d474430ee6724709bf05671fe32838d6c8b46f0a3035e`.
- EX5 SHA-256 matches the producer artifact:
  `ac6889489a33f138049c2f69627160f54847d56462f6dd608b0bf643bd202ff5`.
- The focused forbidden scan found no raw indicator handle, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML entry point.

These passes establish file identity and limited static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, setfile, work item, task verdict, or trade stream
was changed by this review. `T_Live` and AutoTrading were not touched. The task
remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code and evidence
require a fresh mandatory Codex review before acceptance or enqueue.
