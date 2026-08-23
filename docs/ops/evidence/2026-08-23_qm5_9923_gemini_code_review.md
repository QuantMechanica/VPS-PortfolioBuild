# QM5_9923 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `bcfe1a9b-ca66-4c45-bd5b-868b0167acb9`

Source task: `d2b4cd24-ae0d-4cbb-92fb-a8ffcf328003` (`gemini`, build delivery only)

Reviewed artifact:
`D:/QM/strategy_farm/artifacts/build_results/QM5_9923_bandy-hma-crossover-trend_build_result.json`

Verdict: **REQUEST_CHANGES — a wrong-timeframe attachment suppresses every
managed exit, the approved oil scope is replaced by unapproved indices, and the
claimed smoke deferral is not admissible; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer artifact, registries, setfiles, and focused repository checks directly.

## Findings

### 1. High — wrong-timeframe initialization disables the full lifecycle

The card is D1-only (card lines 43-51). `OnInit()` only calls the generic
framework initializer (source lines 261-268). The `_Period != PERIOD_D1` guard
is instead inside `Strategy_NoTradeFilter()` at lines 86-89, and `OnTick()`
returns through that guard before `Strategy_ManageOpenPosition()` (lines
288-290). An accidental intraday attachment therefore initializes successfully
and disables the opposite-HMA exit, 60-day time stop, and Chandelier ratchet for
an existing position.

Required correction: fail initialization outside the D1 execution contract and
keep all management/exits reachable before entry-only filters.

### 2. High — the delivered universe replaces approved oil with two indices

The card authorizes FX majors, XAUUSD, oil CFD, `NDX.DWX`, and `WS30.DWX`, with
`SP500.DWX` backtest-optional (card lines 24, 88, and 92). The package omits
`XTIUSD.DWX` and adds `GDAXI.DWX` and `UK100.DWX`. D17 cannot mechanize the
legacy prose-only universe, but that parser limitation does not authorize the
expansion.

Required correction: align the cohort with the approved card or obtain an
OWNER-approved explicit symbol amendment.

### 3. High — the deferred smoke fails the canonical admission rule

The producer reports `deferred_p2_smoke` and only a generic statement that live
terminals were active. It supplies no structured `capacity_evidence` or durable
slot/process census. The repository's `_q01_smoke_admission()` returns
`q01_smoke_waiver_missing_capacity_evidence` for this exact artifact.

Required correction: provide a real smoke or task-bound saturation evidence
that satisfies the canonical waiver.

## Checks that passed

- The OWNER-approved card and one active registry identity row for
  `9923 / bandy-hma-crossover-trend` exist.
- Thirteen active magic rows exist at slots 0-12. The committed resolver at
  review HEAD contains every corresponding magic exactly once; Codex did not
  touch the concurrent dirty working resolver.
- Closed-D1 HMA(9/21), SMA(200), symmetric crossover entries, initial and
  ratcheting 2.5-ATR Chandelier stop, opposite-cross exit, one-position
  enforcement, and 60-D1-bar time stop are materially present on a correct D1
  attachment, subject to the lifecycle finding above.
- `SPEC.md` passed its seven-section structural validator.
- All 13 setfiles use `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and the exact MQ5
  SHA-256 as `build_hash`.
- `validate_build_guardrails.py` returned `PASS`: 14 files, zero findings,
  `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and warnings; D17 could not
  mechanize the prose-only universe.
- MQ5 and EX5 hashes match the producer artifact. MQ5 SHA-256 is
  `457d114229c77f1c68bda4f9a65ed7b1a604fe0bfc68934a646d7dba2387ce0f`;
  EX5 SHA-256 is
  `20443824c83d4ef5ae9a0f254fa9b5d7404638e0eee493ae4efac6c8f1437c8f`.

These passes establish file identity and limited static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, resolver, setfile, work item, task verdict, or
trade stream was changed by this review. `T_Live` and AutoTrading were not
touched. The task remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini
code and evidence require a fresh mandatory Codex review.
