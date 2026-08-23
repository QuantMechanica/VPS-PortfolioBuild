# QM5_9465 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `088f128e-39c7-4193-a2a6-6b088d0eab0b`

Source task: `1b490cf7-9172-410b-8e5b-07b24c0cb517` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_9465_connors-rsi25-d1/build_identity.json`

Verdict: **REQUEST_CHANGES — the required bounded second entry is absent, and the D1 execution and approved-market contracts are not preserved; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. Critical — the approved bounded second unit is entirely absent

The card requires an initial RSI(4) below 25 entry and a bounded second unit
when RSI(4) later closes below 20, using a distinct sub-magic, two slots at
most, risk split evenly, and a stop recomputed from average entry only when the
second unit is added (card lines 42-43, 49-53). It permits single-slot testing
only if allocation is rejected at G0/P1 and the deviation is recorded.

The EA exposes no RSI20 threshold, blocks entry whenever the one chart magic
already has a position (source lines 74-76), constructs only the RSI25 request
(lines 78-99), and contains no add-on, second sub-magic, split-risk, average
entry, or stop-recompute path. The Gemini SPEC silently omits the second-unit
contract as well. The 13 registry rows are one symbol slot per delivered
symbol; they do not provide a second same-symbol position identity. No
allocation rejection or approved deviation is recorded.

Required correction: implement the governed two-slot contract and its risk and
stop invariants, or produce the required G0/P1 rejection evidence and record an
OWNER-approved single-slot deviation in the card and SPEC before rebuilding.

### 2. High — the mandatory D1 execution contract is undeclared

`OnInit()` returns success immediately after `QM_FrameworkInit()` without
calling `QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` (source lines
152-160). Entry admission later uses the no-argument `QM_IsNewBar()` (line
211), which follows the attached chart timeframe while every strategy
indicator remains fixed to D1. A wrong-period attachment can therefore test
the same completed-D1 condition at unrelated chart-bar boundaries instead of
failing closed at initialization.

Required correction: declare the D1 timeframe and intended Friday-close mode
immediately after framework initialization, and use that same D1 clock for the
strategy decision boundary.

### 3. High — the delivered market universe exceeds the approved port

The approved card identifies `SP500.DWX` as the SPY-equivalent backtest market
and `NDX.DWX` / `WS30.DWX` as live-routable validation analogues (card lines
19-20 and 70-74). The package and Gemini-authored SPEC expand that port to 13
symbols, including seven FX pairs and `XAUUSD.DWX`, without a card revision.
Those markets are not index analogues of the source ETF strategy. Registry
allocation establishes identity; it does not authorize a strategy-universe
change.

Required correction: restrict the package to the approved port, or obtain an
OWNER-approved card revision that explicitly authorizes and motivates each
additional market.

### 4. High — entry eligibility can suppress the RSI exit and time stop

`OnTick()` returns on `Strategy_NoTradeFilter()` before position management and
the strategy exit (source lines 182-187). That filter contains warmup, quote,
ATR, and spread entry eligibility (lines 52-66). A wide spread or invalid quote
can therefore block both the card's RSI-above-55 exit and its 12-D1-bar time
stop for an already-open position.

Required correction: keep Friday close, open-position management, and card
exits reachable independently of new-entry eligibility. Apply the spread gate
only to entry construction.

### 5. Medium — every delivered setfile has malformed `CR CR LF` endings

All 13 setfiles contain exactly 32 `0D 0D 0A` sequences. Their visible risk
values are correct, but the malformed records are not byte-stable inputs for
normal line-oriented tooling. Normalize them through the governed generator
and refresh the build identity before resubmission.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`.
- EA registry row `9465 / connors-rsi25-d1` is active.
- Thirteen active magic rows exist at slots 0-12; the active/reserved registry
  has zero global magic collisions, and all 13 target rows are present in the
  generated resolver with `magic = ea_id * 10000 + slot`.
- All delivered symbols are canonical entries in `dwx_symbol_matrix.csv`.
- All 13 setfiles visibly use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and zero warnings.
- `validate_spec_doc.py` returned `PASS`.
- MQ5 SHA-256 matches `build_identity.json`:
  `286d70a1c6978b66b48983d132fc53984e9fad3865468d12ff0cadb6a2005713`.
- EX5 SHA-256 matches `build_identity.json`:
  `36c62db9ad70b6c0ca14cb5a7f9a5733a29ff2017d3cabd6504e05f36221a272`.
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
