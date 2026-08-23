# QM5_9466 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `bf0ead8d-bde8-4b4b-838f-cace0a26e5c3`

Source task: `ffdbf22e-3ec4-4027-88d5-5a6e4ba6c1c7` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_9466_connors-r2-d1/build_identity.json`

Verdict: **REQUEST_CHANGES — the D1 execution contract and approved index-market scope are not preserved, and the durable SPEC is corrupted; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the mandatory D1 execution contract is undeclared

`OnInit()` returns success immediately after `QM_FrameworkInit()` without
calling `QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` (source lines
158-166). Entry admission later uses the no-argument `QM_IsNewBar()` (line
217), which follows the attached chart timeframe while every strategy
indicator remains fixed to D1. A wrong-period attachment can therefore test
the same completed-D1 sequence at unrelated chart-bar boundaries instead of
failing closed at initialization.

Required correction: declare the D1 timeframe and intended Friday-close mode
immediately after framework initialization, and use that same D1 clock for the
strategy decision boundary.

### 2. High — the delivered market universe exceeds the approved index port

The approved card identifies the source as an SPX/SPY/E-mini strategy and
names `SP500.DWX`, `NDX.DWX`, and `WS30.DWX` as the available ports (card lines
19-20 and 72-76). The package and Gemini-authored SPEC expand that contract to
13 symbols, including seven FX pairs and `XAUUSD.DWX`, without a card revision.
Those markets are not index proxies for the published strategy. Registry
allocation establishes identity; it does not authorize a strategy-universe
change.

Required correction: restrict the package to the approved port, or obtain an
OWNER-approved card revision that explicitly authorizes and motivates each
additional market.

### 3. High — entry eligibility can suppress the RSI exit and time stop

`OnTick()` returns on `Strategy_NoTradeFilter()` before position management and
the strategy exit (source lines 188-193). That filter contains warmup, quote,
ATR, and spread entry eligibility (lines 52-66). A wide spread or invalid quote
can therefore block both the card's RSI-above-75 exit and its 10-D1-bar time
stop for an already-open position.

Required correction: keep Friday close, open-position management, and card
exits reachable independently of new-entry eligibility. Apply the spread gate
only to entry construction.

### 4. Medium — the durable SPEC is byte- and text-corrupted

`SPEC.md` contains `0x1B` at byte offset 2912 and `0x07` at offset 3165. They
corrupt the source ID on line 83 and the approved-card path on line 86. The
risk row on line 94 also says `,000` instead of `$1,000`, consistent with an
unescaped template write. `validate_spec_doc.py` still reports PASS, so its
structural result is not proof of clean text.

Required correction: regenerate the SPEC from literal text, verify zero
non-whitespace control bytes and the exact risk text, and add a focused
validator regression.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`.
- EA registry row `9466 / connors-r2-d1` is active.
- Thirteen active magic rows exist at slots 0-12; the active/reserved registry
  has zero global magic collisions, and all 13 target rows are present in the
  generated resolver with `magic = ea_id * 10000 + slot`.
- All delivered symbols are canonical entries in `dwx_symbol_matrix.csv`.
- All 13 setfiles use normal line endings, `RISK_FIXED=1000`, and
  `RISK_PERCENT=0`.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and zero warnings.
- `validate_spec_doc.py` returned structural `PASS`, subject to finding 4.
- MQ5 SHA-256 matches `build_identity.json`:
  `3537d969bb5c629d93eb18b91640f5227b44cd2290d92a564803b21dc47cd6d4`.
- EX5 SHA-256 matches `build_identity.json`:
  `f0f7faafebc99819cac1eff9c492a4b7b087d9fcecbda27f24de2d907bd8d681`.
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
