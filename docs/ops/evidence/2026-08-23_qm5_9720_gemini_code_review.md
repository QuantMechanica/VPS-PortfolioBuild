# QM5_9720 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `41c5ecbf-caa4-4f3b-989c-1490a2b767f5`

Source task: `2dc0025a-7b2d-472c-ac65-58c806c5a768` (`gemini`, build delivery only)

Reviewed artifact: `D:/QM/strategy_farm/artifacts/builds/2dc0025a-7b2d-472c-ac65-58c806c5a768.json`

Verdict: **REQUEST_CHANGES — the D1 contract, exit reachability, approved
symbol universe, SPEC, and producer evidence are incomplete; do not promote to
PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the mandatory D1 execution contract is undeclared

`OnInit()` calls `QM_FrameworkInit()` and then reports `INIT_OK` (source lines
243-264), but never calls
`QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` and does not reject a
non-D1 chart at initialization. The only timeframe check is the late
`_Period != PERIOD_D1` branch in `Strategy_NoTradeFilter()` (lines 94-103),
after the bare `QM_IsNewBar()` has already followed the attached chart period.

Required correction: declare and validate the D1 execution contract immediately
after framework initialization, failing closed on a mismatch.

### 2. High — invalid cached state can suppress every strategy exit

On each new bar, the EA advances state (source lines 61-88) and then calls
`Strategy_NoTradeFilter()` before management and exits (lines 290-298). When
history/indicator state is temporarily invalid, or when parameters/timeframe are
invalid, that filter returns early. This skips the card's 60-day hard stop, ATR
ratchet, and opposite-cross exit for an already-open position. Entry
ineligibility must not make mandatory exits unreachable.

Required correction: validate immutable parameters at `OnInit()`, keep
management and exit paths reachable for open positions, and apply transient
state/news/spread filters to new entries only.

### 3. High — five delivered symbols are outside the approved card and oil is missing

The card authorizes the primary set EURUSD, GBPUSD, USDJPY, AUDUSD, XAUUSD,
NDX.DWX, WS30.DWX, and XTIUSD, with optional SP500.DWX (card lines 76 and
82-83). The 13 delivered setfiles and magic rows add `GDAXI.DWX`, `UK100.DWX`,
`USDCHF.DWX`, `USDCAD.DWX`, and `NZDUSD.DWX`, while omitting `XTIUSD`. The D17
parser returned an empty target-symbol list and therefore did not detect this
prose-format scope mismatch; that tooling result does not expand card authority.

Required correction: package only the approved symbols, including oil if it is
part of the chosen primary cohort, or obtain an OWNER-approved card amendment.

### 4. High — the mandatory SPEC is structurally incomplete

`SPEC.md` stops after strategy logic and parameters (lines 1-19).
`validate_spec_doc.py` fails because required sections 3-7 — Symbol Universe,
Timeframe, Expected Behaviour, Source Citation, and Risk Model — are absent.

Required correction: produce a truthful, complete SPEC that names the exact
authorized universe and passes the repository validator.

### 5. High — the producer artifact is not a canonical build result

The submitted JSON records file paths, hashes, 13 setfiles, and
`build_check_passed`, but omits canonical build-result fields including
`compile_succeeded`, `ea_dir`, `magic_base`, `symbols_registered`,
`smoke_result`, and `smoke_report_path`. No smoke summary is supplied. Matching
hashes do not establish schema-complete build or runtime evidence.

Required correction: emit a canonical result bound to the immutable task and
exact files, plus smoke evidence or a canonical saturation-only deferral.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`.
- EA registry row `9720 / bandy-adx-regime-filter-trend` is active.
- Thirteen active magic rows exist at slots 0-12; the active/reserved registry
  has zero global magic collisions, and all 13 expected magic values occur
  exactly once in the generated resolver. This is consistency, not symbol
  authorization.
- The SMA cross, ADX threshold, ATR trail, 60-day time stop, one-position rule,
  and close-before-reverse lifecycle are materially implemented for valid D1
  state.
- All 13 setfiles use `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- The MQ5 has CRLF line endings, no bare LF, and no NUL byte.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and warnings, subject to the
  manual D1, exit-reachability, and approved-universe findings above.
- MQ5 SHA-256 matches the producer artifact:
  `0a432e165805faa1f08eed7e775d3ac0ca16a0429729ac29075b27bbf56d9d3d`.
- EX5 SHA-256 matches the producer artifact:
  `90760f8de52ce58f124b7c265c9373cdc04815d37ba739c4b7730563313a0533`.
- The focused forbidden scan found no raw indicator handle, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML entry point.

These passes establish file identity and limited static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, setfile, work item, task verdict, or trade stream
was changed by this review. `T_Live` and AutoTrading were not touched. The task
remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code and evidence
require a fresh mandatory Codex review before acceptance or enqueue.
