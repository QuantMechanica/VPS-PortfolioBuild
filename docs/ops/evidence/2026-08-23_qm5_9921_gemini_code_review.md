# QM5_9921 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `69651689-9c02-4df7-8385-a89fe0e90903`

Source task: `3386130d-8fec-49ff-bf2c-c238d8807121` (`gemini`, build delivery only)

Reviewed artifact:
`docs/ops/evidence/3386130d_qm5_9921_bandy-cmo-extreme-fade-mr-index_build_identity.json`

Verdict: **REQUEST_CHANGES — D1 cadence and exit reachability are not safely
bound, no setfile identifies the delivered source, the universe exceeds the
approved index-MR scope, and producer smoke evidence is absent; do not promote
to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer artifact, registries, setfiles, and focused repository checks directly.

## Findings

### 1. High — the D1 strategy is driven by the chart's bar clock

The approved card evaluates on each daily close and enters at the next bar open
(card lines 43-50). `OnInit()` only calls the generic framework initializer
(source lines 190-197), with no D1 execution contract. Entry is gated by bare
`QM_IsNewBar()` at line 233, which follows the attachment timeframe. On an
intraday chart the unchanged closed-D1 signal is therefore reconsidered on each
intraday bar and can be re-entered after a same-day close.

Required correction: fail initialization outside the approved D1 contract and
use an explicit D1 entry edge.

### 2. High — entry-only filters can suppress the mandatory exits

`Strategy_NoTradeFilter()` rejects insufficient warmup or missing bid/ask
(source lines 83-95). `OnTick()` calls it before
`Strategy_ManageOpenPosition()` (lines 217-219), so the CMO-neutral exit and
eight-D1-bar time stop can both become unreachable for an existing position.

Required correction: keep position management and exits reachable before all
entry-eligibility returns.

### 3. High — all 13 setfiles are bound to unrelated hashes

The reviewed MQ5 SHA-256 is
`d83dd96dd179e830cf280f62da4fc263df35762d401f98928373ea00d728f517`.
The 13 setfile headers contain 13 distinct `build_hash` values, and none equals
that source hash. They identify per-file intermediate bytes rather than one
immutable EA build.

Required correction: after source repair, regenerate every setfile with the
same exact MQ5 SHA-256, then emit fresh binary/build evidence.

### 4. High — the delivered universe exceeds the approved index-MR scope

The card authorizes `SP500.DWX`, `NDX.DWX`, and `WS30.DWX`, with FX majors only
as optional cross-asset breadth (card lines 24, 77, and 81). The 13-symbol
registry/setfile cohort also adds `GDAXI.DWX`, `UK100.DWX`, and `XAUUSD.DWX`.
The legacy prose card has no machine-readable `target_symbols`; that parser gap
is not scope authority.

Required correction: restrict the cohort to approved instruments or obtain an
OWNER-approved explicit symbol amendment.

### 5. High — the producer record has no compile/smoke admission proof

The task-bound JSON records file hashes, setfiles, and
`build_check_passed=true`, but omits `compile_succeeded`, `smoke_result`,
`smoke_report_path`, `blocked_reason`, and structured tester-capacity evidence.
The matching EX5 bytes prove identity only; they do not establish a passing Q01
smoke or an eligible saturation waiver.

Required correction: emit a schema-complete task-bound build result with fresh
compile and smoke evidence, or canonical saturation evidence if applicable.

## Checks that passed

- The OWNER-approved card and one active registry identity row for
  `9921 / bandy-cmo-extreme-fade-mr-index` exist.
- Thirteen active magic rows exist at slots 0-12. The committed resolver at
  review HEAD contains every corresponding magic exactly once; Codex did not
  touch the concurrent dirty working resolver.
- Closed-D1 CMO(20), SMA(200), long-only threshold entry, 2.5-D1-ATR initial
  stop, CMO-neutral exit, one-position enforcement, and eight-D1-bar time stop
  are materially present, subject to the cadence/reachability findings above.
- `SPEC.md` passed its seven-section structural validator.
- All 13 setfiles use `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- `validate_build_guardrails.py` returned `PASS`: 14 files, zero findings,
  `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and warnings; D17 could not
  mechanize the prose-only universe.
- MQ5 and EX5 hashes match the producer artifact. EX5 SHA-256 is
  `7e92a3cf9c5fe21f1b29b7682790ec4275f62f258f6b371e0f99175156938174`.

These passes establish file identity and limited static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, resolver, setfile, work item, task verdict, or
trade stream was changed by this review. `T_Live` and AutoTrading were not
touched. The task remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini
code and evidence require a fresh mandatory Codex review.
