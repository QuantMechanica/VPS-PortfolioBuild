# QM5_9580 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `ac694029-ea0a-4d27-ae10-6a22963b8d0e`

Source task: `c3f03e05-3064-4a1e-93ff-097150115ffe` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_9580_bandy-regslope-pullback-mr-index/build_identity.json`

Verdict: **REQUEST_CHANGES — D1 execution, exit-management reachability, durable SPEC, and approved-universe contracts are not preserved; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the mandatory D1 execution contract is undeclared

`OnInit()` returns success immediately after `QM_FrameworkInit()` without
calling `QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` (source lines
220-227). Entry admission later uses the no-argument `QM_IsNewBar()` (line
275), which follows the attached chart timeframe while the regression, RSI,
SMA, and time-stop reads remain fixed to D1. A wrong-period attachment can
therefore admit repeated decisions on chart bars instead of failing closed.

Required correction: declare the D1 execution contract immediately after
framework initialization and gate decisions on that same D1 clock.

### 2. High — entry eligibility can suspend both mandatory exit families

`OnTick()` returns on `Strategy_NoTradeFilter()` before both
`Strategy_ManageOpenPosition()` and `Strategy_ExitSignal()` (source lines
246-251). The filter rejects warmup, invalid quote, and wide-spread conditions
(lines 110-124). An already-open position therefore skips the five-trading-day
time stop and the RSI(2) >= 70 exit whenever an entry-only condition is active.
The server-side catastrophic stop does not implement either card exit.

Required correction: keep Friday close, time-stop management, and strategy
exit evaluation reachable independently of all new-entry filters; apply the
spread filter only before a new request is constructed.

### 3. High — the durable SPEC contradicts both card and source

The approved card and all strategy calculations are D1, and the MQ5 exposes 11
strategy inputs (source lines 37-48). `SPEC.md` instead declares base timeframe
`H1` (SPEC line 64) and says there are no strategy-specific inputs (line 28).
This is a downstream operator contract, not a cosmetic summary.

Required correction: regenerate the SPEC from the card and actual MQ5, list
the governed strategy inputs and ranges, and assert D1 in validation.

### 4. High — the 13-symbol package exceeds the approved index port

The approved card names `SP500.DWX` for backtest and `NDX.DWX` / `WS30.DWX`
for live promotion (card lines 23-24 and 79-80). The delivered package and
active magic rows cover 13 symbols, adding two other indices, `XAUUSD.DWX`, and
seven FX pairs without card authority. The automated D17 check cannot catch
this because the card lacks a machine-readable `target_symbols` field; its
empty parse is not approval for an unrestricted universe.

Required correction: restrict the build/setfiles/registry allocation to the
approved index port or obtain an OWNER-approved card amendment before expanding
it.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`.
- EA registry row `9580 / bandy-regslope-pullback-mr-index` is active.
- Thirteen active magic rows exist at slots 0-12; the active/reserved registry
  has zero global magic collisions, and all 13 expected magic values are
  present in the generated resolver.
- The OLS slope/R-squared ordering is oldest-to-newest and matches the card's
  positive-slope regime; RSI and SMA comparisons use closed D1 bars.
- All 13 setfiles use normal line endings, `RISK_FIXED=1000`, and
  `RISK_PERCENT=0`; no control bytes were found.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and zero warnings, subject
  to the manual informal-universe finding above.
- `validate_spec_doc.py` returned structural `PASS`, subject to finding 3.
- MQ5 SHA-256 matches `build_identity.json`:
  `5ec3aa4d8249340e85702365a53d291c120730419971dfe711df6a31e797ccbf`.
- EX5 SHA-256 matches `build_identity.json`:
  `b2d3f34e7fec21f31fa29fec2ee447beb296449c51c4e5694fa04ddef2ae4336`.
- The focused forbidden scan found no raw indicator handles, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ONNX entry point.

These passes establish artifact identity and baseline hardening only. No smoke
report, schema-complete `build_result.json`, or pipeline evidence was supplied,
so no runtime or pipeline verdict is inferred.

## Disposition

No source, binary, registry, setfile, work item, task verdict, or trade stream
was changed by this review. `T_Live` and AutoTrading were not touched. The task
remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code requires a
fresh mandatory Codex review before acceptance or enqueue.
