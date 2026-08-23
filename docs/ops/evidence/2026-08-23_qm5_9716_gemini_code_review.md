# QM5_9716 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `a06e3ace-6c6a-437e-9a6e-da3e37700a59`

Source task: `d573fb90-49fa-4f73-87a5-4f01d0254002` (`gemini`, build delivery only)

Reviewed artifact: `docs/ops/evidence/2026-08-23_QM5_9716_bandy-trend-stretch-ratio-mr-index_build_result.json`

Verdict: **REQUEST_CHANGES — execution-contract, exit-management, symbol-universe, SPEC, and producer-evidence defects remain; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the mandatory framework execution contract is undeclared

`OnInit()` manually rejects charts other than D1 and then returns success after
`QM_FrameworkInit()` (source lines 182-192), but never calls
`QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)`. The raw period check is
only a partial substitute: it neither validates the card/framework Friday-close
mode nor emits the machine-searchable `EXECUTION_CONTRACT` record required by
`QM_Common.mqh` lines 470-534.

Required correction: call the framework declaration immediately after a
successful init with the approved D1 and Friday-close contract, and fail init if
that declaration fails.

### 2. High — entry eligibility can suspend both mandatory exit families

`OnTick()` returns on `Strategy_NoTradeFilter()` before both
`Strategy_ManageOpenPosition()` and `Strategy_ExitSignal()` (source lines
211-216). The filter rejects warmup, invalid quote, and wide-spread conditions
(lines 71-85). An already-open position therefore skips the seven-trading-day
time stop and TSR zero-cross exit whenever an entry-only condition is active.
The server-side catastrophic stop does not implement either card exit.

Required correction: keep Friday close, time-stop management, and strategy
exit evaluation reachable independently of every new-entry filter.

### 3. High — ten delivered symbols violate the explicit card universe

The card's `## Target Symbols` contract is exactly `SP500.DWX` (backtest),
`NDX.DWX`, and `WS30.DWX` on D1 (card lines 81-82). The build, setfiles, and
active magic rows instead cover 13 symbols, adding `GDAXI.DWX`, `UK100.DWX`,
`XAUUSD.DWX`, and seven FX pairs. `build_gate_hardening.py` reported an empty
`card_target_symbols` parse and therefore missed this prose-format D17 breach;
that parser limitation does not expand card authority.

Required correction: restrict the build/setfiles/registry allocation to the
three approved targets or obtain an OWNER-approved card amendment.

### 4. High — the durable SPEC contradicts card and source

The card says D1 only (card line 63), and the MQ5 exposes nine strategy inputs
(source lines 37-46). `SPEC.md` instead declares base timeframe `H1` (SPEC line
64), claims there are no strategy-specific inputs (line 28), and advertises the
unauthorized 13-symbol universe (lines 37-52).

Required correction: regenerate the SPEC from the approved card and actual
MQ5, list the governed parameters and ranges, and validate the D1/three-symbol
contract semantically rather than only checking document shape.

### 5. High — the producer build result is not schema-complete

The submitted JSON claims `compile_succeeded` and `build_check_passed`, but it
omits required canonical fields from
`tools/strategy_farm/prompts/SCHEMAS.md`: `task_id`, `magic_base`,
`symbols_registered`, `smoke_result`, and `smoke_report_path`. No smoke summary
or `build_identity.json` accompanies it. Consequently smoke sanity is UNKNOWN
and the producer's "D1-D11 passed" claim cannot establish runtime readiness.

Required correction: emit a schema-complete result bound to the immutable task
and exact files, plus the required smoke summary or a canonical, evidenced
fleet-saturation deferral.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`.
- EA registry row `9716 / bandy-trend-stretch-ratio-mr-index` is active.
- Thirteen active magic rows exist at slots 0-12; the active/reserved registry
  has zero global magic collisions, and all 13 expected magic values are in the
  generated resolver. This is consistency, not symbol authorization.
- TSR, regime, entry, exit, and positive-stop comparisons match the card.
- All 13 setfiles use normal line endings, `RISK_FIXED=1000`, and
  `RISK_PERCENT=0`; no control bytes were found.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and warnings, subject to its
  demonstrated failure to parse the card's explicit target-symbol line.
- `validate_spec_doc.py` returned structural `PASS`, subject to finding 4.
- MQ5 SHA-256 matches the producer JSON:
  `549544da3cba15017b487c0ebd16e19d4778c7a2f85ba09e0c79f19a3bf43a5e`.
- EX5 SHA-256 matches the producer JSON:
  `c59061e92e9e9ff364e6651bfd6c7b479b1caa84f37e4cbcf340829c298f9fc6`.
- The focused forbidden scan found no raw indicator handle, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML entry point.

These passes establish file identity and baseline static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, setfile, work item, task verdict, or trade stream
was changed by this review. `T_Live` and AutoTrading were not touched. The task
remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code and evidence
require a fresh mandatory Codex review before acceptance or enqueue.
