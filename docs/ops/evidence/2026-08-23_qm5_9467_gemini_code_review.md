# QM5_9467 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `f5be58aa-c65f-4652-8fdb-6816c30957b0`

Source task: `5de38382-e3f2-4179-b63b-6f60222bccc3` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_9467_connors-crsi-pullback-d1/build_identity.json`

Verdict: **REQUEST_CHANGES — pending-order risk, D1 execution cadence, and approved index-market scope are not preserved; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the pending-order stop and risk are based on limit price, not fill

The card requires the protective stop at `3.0 * ATR(14)` below the actual fill
(card line 55). For a pending order, the EA computes the stop from
`limit_price` before the fill exists and never adjusts it in
`OnTradeTransaction()` (source lines 239-256 and 385-390). A buy limit can fill
below its requested price after a gap. The delivered stop distance and the
fixed-risk sizing can then differ from the approved fill-relative contract;
with a sufficiently deep gap the submitted stop can even be above the fill.

Required correction: bind sizing and the final protective stop to the actual
fill, with an idempotent transaction-time adjustment and a fail-closed path if
the approved protection cannot be established.

### 2. High — a 120-bar recursive reconstruction runs on every tick

`Strategy_ExitSignal()` calls `Strategy_ComputeCRSI(1)` before the new-D1-bar
gate on every market tick (source lines 285-295 and 323-366). That calculation
copies `rank_period + 20` D1 bars, reverses them into a second array, rebuilds a
streak series, performs a recursive RSI walk, and scans the percent-rank window
(lines 106-175). It runs even when there is no open position. The card defines
closed-D1 decisions; this repeated history walk is the wrong cadence and a
material tester-timeout risk.

Required correction: calculate and cache one immutable ConnorsRSI snapshot on
the explicit D1 boundary. Per-tick risk handling may read that snapshot but
must not reconstruct D1 history.

### 3. High — the next-bar expiry is encoded as wall-clock 86,400 seconds

The card says the buy-limit expires at the end of D1 bar `t+1` (card line 47).
The EA uses `expiration_seconds = 86400` (source line 256), measured from the
submission tick. That is not the next completed trading-day boundary across a
Friday/weekend, holiday, DST transition, or shortened session. The old pending
order is also not explicitly reconciled before a later setup constructs a new
request.

Required correction: derive the expiry from the governed next D1 calendar/bar
boundary and prove that at most one pending/open exposure exists per magic.

### 4. High — the mandatory D1 execution contract is undeclared

`OnInit()` returns success immediately after `QM_FrameworkInit()` without
calling `QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` (source lines
307-315). Entry admission later uses the no-argument `QM_IsNewBar()` (line
366), which follows the attached chart timeframe while strategy data remains
fixed to D1.

Required correction: declare the D1 timeframe and intended Friday-close mode
at initialization, and use that same D1 clock for the strategy boundary.

### 5. High — the delivered market universe exceeds the approved index port

The approved card names `SP500.DWX`, `NDX.DWX`, and `WS30.DWX` as the source
stock/index strategy's CFD ports (card lines 19-20 and 75-79). The package and
Gemini-authored SPEC expand that contract to 13 symbols, including seven FX
pairs and `XAUUSD.DWX`, without a card revision. Registry allocation proves
identity, not strategy-universe authorization.

Required correction: restrict the package to the approved port, or obtain an
OWNER-approved card revision for each additional market.

### 6. High — entry eligibility can suppress the CRSI exit and time stop

`OnTick()` returns on `Strategy_NoTradeFilter()` before position management and
the strategy exit (source lines 337-342). Its quote, ATR, and spread checks are
entry eligibility, yet can block both the CRSI-above-80 exit and the eight-D1-
bar time stop of an existing position.

Required correction: keep risk-reducing management and exits reachable
independently of every new-entry filter.

### 7. Medium — the durable SPEC is byte- and text-corrupted

`SPEC.md` contains `0x1B` at byte offset 3577 and `0x07` at offset 3846. They
corrupt the source ID on line 90 and the approved-card path on line 93. The
risk row on line 101 also says `,000` instead of `$1,000`.
`validate_spec_doc.py` still reports PASS.

Required correction: regenerate literal clean text and add a focused validator
regression for control bytes and escaped currency values.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`.
- EA registry row `9467 / connors-crsi-pullback-d1` is active.
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
- `validate_spec_doc.py` returned structural `PASS`, subject to finding 7.
- MQ5 SHA-256 matches `build_identity.json`:
  `008b3a0179ed4848bd798c51bc8b8b08489d8ec51aba0b08130a03f2ab373904`.
- EX5 SHA-256 matches `build_identity.json`:
  `a90ef1612388ea95d376b2060fda8dd076af2d0f7254f6fed268312ce2a08af6`.
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
