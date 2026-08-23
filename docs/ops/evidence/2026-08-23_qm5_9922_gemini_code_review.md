# QM5_9922 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `9cb9c40c-317e-4a6b-be47-513aa088ecee`

Source task: `39477905-5cfe-43eb-bebf-3ad5ba8d10b3` (`gemini`, build delivery only)

Reviewed artifact:
`docs/ops/evidence/39477905_qm5_9922_bandy-vortex-crossover-trend_build_identity.json`

Verdict: **REQUEST_CHANGES — D1 cadence and exit reachability are not safely
bound, no setfile identifies the delivered source, the approved oil scope is
replaced by unapproved indices, and producer smoke evidence is absent; do not
promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer artifact, registries, setfiles, and focused repository checks directly.

## Findings

### 1. High — the D1 strategy is driven by the chart's bar clock

The card evaluates on each daily close and enters at the next bar open (card
lines 44-54). `OnInit()` has no D1 execution contract (source lines 305-312),
while entry uses bare `QM_IsNewBar()` at line 348. An intraday attachment can
therefore reconsider the unchanged daily crossover on every chart bar and
re-enter it after a same-day exit.

Required correction: fail initialization outside the approved D1 contract and
use an explicit D1 entry edge.

### 2. High — entry-only filters can suppress the mandatory exits and trail

`Strategy_NoTradeFilter()` rejects insufficient warmup or missing bid/ask
(source lines 132-142). `OnTick()` calls it before the opposite-cross exit,
time stop, and Chandelier ratchet in `Strategy_ManageOpenPosition()` (lines
332-334). Those lifecycle protections can therefore become unreachable for an
existing position.

Required correction: keep position management and exits reachable before all
entry-eligibility returns.

### 3. High — all 13 setfiles are bound to unrelated hashes

The reviewed MQ5 SHA-256 is
`77d234edd9c1234d169972858ba489a5453ddecfecf47762e91aaade5c132ced`.
The 13 setfile headers contain 13 distinct `build_hash` values, and none equals
that source hash.

Required correction: after source repair, bind every setfile to one exact MQ5
SHA-256 and regenerate the producer/binary identity.

### 4. High — the delivered universe replaces approved oil with two indices

The card authorizes FX majors, XAUUSD, oil CFD, `NDX.DWX`, and `WS30.DWX`, with
`SP500.DWX` backtest-optional (card lines 25, 82, and 86). The package omits
`XTIUSD.DWX` and adds `GDAXI.DWX` and `UK100.DWX`. The absent machine-readable
`target_symbols` list is not permission to rewrite that prose scope.

Required correction: align the cohort with the approved card or obtain an
OWNER-approved explicit symbol amendment.

### 5. High — the producer record has no compile/smoke admission proof

The task-bound JSON records file hashes, setfiles, and
`build_check_passed=true`, but omits `compile_succeeded`, `smoke_result`,
`smoke_report_path`, `blocked_reason`, and structured tester-capacity evidence.
The matching EX5 bytes prove identity only, not a passing Q01 smoke or eligible
saturation waiver.

Required correction: emit a schema-complete task-bound build result with fresh
compile and smoke evidence, or canonical saturation evidence if applicable.

## Checks that passed

- The OWNER-approved card and one active registry identity row for
  `9922 / bandy-vortex-crossover-trend` exist.
- Thirteen active magic rows exist at slots 0-12. The committed resolver at
  review HEAD contains every corresponding magic exactly once; Codex did not
  touch the concurrent dirty working resolver.
- Closed-D1 Vortex(14), ADX(14)>=20, SMA(200), symmetric crossover entries,
  near-tie filter, initial/ratcheting 2.5-ATR Chandelier stop, opposite-cross
  exit, one-position enforcement, and 60-D1-bar time stop are materially
  present, subject to the cadence/reachability findings above.
- `SPEC.md` passed its seven-section structural validator.
- All 13 setfiles use `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- `validate_build_guardrails.py` returned `PASS`: 14 files, zero findings,
  `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and warnings; D17 could not
  mechanize the prose-only universe.
- MQ5 and EX5 hashes match the producer artifact. EX5 SHA-256 is
  `7509b7bb413c9cf367e404886788533d4ff866044d70dbde53a126ffa7677ea7`.

These passes establish file identity and limited static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, resolver, setfile, work item, task verdict, or
trade stream was changed by this review. `T_Live` and AutoTrading were not
touched. The task remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini
code and evidence require a fresh mandatory Codex review.
