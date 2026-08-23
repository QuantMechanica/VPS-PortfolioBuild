# QM5_9417 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `cbbb8d4a-b6d4-4a5d-8f2e-06f8b4af5bbe`

Source task: `cc4549cc-1955-47fb-9801-78d2aad3f77b` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_9417_qs-sma10-30/build_identity.json`

Verdict: **REQUEST_CHANGES — the D1 execution contract and approved three-symbol port are not preserved; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the mandatory D1 execution contract is undeclared

`OnInit()` returns success immediately after `QM_FrameworkInit()` without
calling `QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` (source lines
133-141). Entry admission later uses the no-argument `QM_IsNewBar()` (line
192), which follows the attached chart timeframe while every strategy
indicator remains fixed to D1. A wrong-period attachment can therefore test
the same completed-D1 crossover at unrelated chart-bar boundaries instead of
failing closed at initialization.

Required correction: declare the D1 timeframe and intended Friday-close mode
immediately after framework initialization, and use that same D1 clock for the
strategy decision boundary.

### 2. High — ten delivered symbols are outside the approved port

The approved card ports the source SPY strategy to `SP500.DWX` for backtest and
to `NDX.DWX` / `WS30.DWX` for live-routable validation (card lines 41-43). The
package and Gemini-authored SPEC expand that three-symbol contract to 13,
adding `GDAXI.DWX`, `UK100.DWX`, `XAUUSD.DWX`, and seven FX pairs without an
approved card revision. Registry allocation establishes identity; it does not
authorize a new market universe for a source strategy.

Required correction: generate sets only for the approved three-symbol port,
or obtain an OWNER-approved card revision that explicitly authorizes and
motivates the expanded universe.

### 3. High — entry eligibility can suppress the reverse-cross exit

`OnTick()` returns on `Strategy_NoTradeFilter()` before the strategy exit
(source lines 163-168). That filter contains warmup, quote, ATR, and spread
entry eligibility (lines 49-63). A wide spread or invalid quote can therefore
delay the card's reverse-cross close of an existing long. These are new-entry
conditions, not approved exit-blackout rules.

Required correction: keep Friday close and the card exit reachable
independently of new-entry eligibility. Apply the spread gate only to entry
construction.

### 4. Medium — every delivered setfile has malformed `CR CR LF` endings

All 13 setfiles contain exactly 29 `0D 0D 0A` sequences. Their visible risk
values are correct, but the malformed records are not byte-stable inputs for
normal line-oriented tooling. Normalize them through the governed generator
and refresh the build identity before resubmission.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`.
- EA registry row `9417 / qs-sma10-30` is active.
- Thirteen active magic rows exist at slots 0-12; the active/reserved registry
  has zero global magic collisions, and all 13 target rows are present in the
  generated resolver with `magic = ea_id * 10000 + slot`.
- All delivered symbols are canonical entries in `dwx_symbol_matrix.csv`.
- All 13 setfiles visibly use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and zero warnings.
- `validate_spec_doc.py` returned `PASS`, and the SPEC has zero non-whitespace
  control bytes.
- MQ5 SHA-256 matches `build_identity.json`:
  `92ef652c3ffe4783ba04a449b54029738cc08ee8d4eec0eaa00b8947694bb604`.
- EX5 SHA-256 matches `build_identity.json`:
  `491ae34df7b1285f2bf7867dc8b38434ad7bf8e7e799550dbab089e8a32d9bc0`.
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
