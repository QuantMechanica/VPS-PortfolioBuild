# QM5_9914 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `3ba5f88c-e843-4969-b8b7-152a38d240e9`

Source task: `25102f3e-14f6-4a82-b25d-1805dd49ce14` (`gemini`, build delivery only)

Reviewed artifact: `D:/QM/strategy_farm/artifacts/builds/25102f3e-14f6-4a82-b25d-1805dd49ce14.json`

Verdict: **REQUEST_CHANGES — chart timeframe can change daily cadence and stop
risk, exits are filter-dependent, 12 setfiles are bound to other hashes, the
universe is expanded, and the smoke waiver is unsupported; do not promote to
PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer artifact, registries, setfiles, and focused repository checks directly.

## Findings

### 1. High — D1 cadence and ATR risk are not bound to a D1 execution contract

The card evaluates once per daily close and sizes from D1 ATR (card lines 15,
43-65). `OnInit()` does not declare or validate D1 (source lines 206-214), and
entry uses bare chart-clock `QM_IsNewBar()` at line 261. `QM_StopATR()` at lines
124 and 139 reads `PERIOD_CURRENT`; an intraday attachment therefore replaces
the approved 3-D1-ATR backstop with an intraday ATR distance.

Required correction: declare/validate D1 at initialization, use an explicit D1
entry edge, and bind stop sizing to D1.

### 2. High — an invented spread filter can suppress signal and time exits

The only optional card filter is two-bar same-sign distance confirmation (card
line 70). The source adds `strategy_spread_max_atr = 0.25` (line 45) and runs
`Strategy_NoTradeFilter()` before `Strategy_ManageOpenPosition()` (lines
232-235). Missing quotes, warmup insufficiency, or wide spread can therefore
delay the ZLEMA cross-back exit and 30-day time stop.

Required correction: remove or approve the filter and keep management/exits
reachable independently of entry eligibility.

### 3. High — 12 of 13 setfiles are bound to unrelated hashes

The delivered/current MQ5 SHA-256 is
`92bbba767ef24e3c7307ccfb73685261d38110c57782b1eaf2ccaf251031474e`.
Only the EURUSD setfile contains that `build_hash`. Each of the other 12 files
contains a different hash. Commit `3acbfb356` changed all 13 QM5_9913 setfiles
but only the EURUSD QM5_9914 setfile despite its broader commit title.

Required correction: after source repair, bind all 13 setfiles to one exact MQ5
hash and regenerate the producer artifact/binary identity.

### 4. High — the delivered cohort adds two indices and omits approved oil scope

The card authorizes FX majors, XAUUSD, oil CFD, `NDX.DWX`, `WS30.DWX`, and
optionally backtest-only `SP500.DWX` (card lines 24, 81, and 85). The package
adds `GDAXI.DWX` and `UK100.DWX` while omitting `XTIUSD.DWX`. The absent
machine-readable `target_symbols` field is not permission to expand scope.

Required correction: align the cohort with approved prose or obtain an
OWNER-approved explicit `target_symbols` amendment.

### 5. High — the claimed smoke deferral fails the canonical admission test

The producer reports `deferred_p2_smoke` with only a generic T1-T10 running
statement. It supplies no durable `capacity_evidence`. The repository's own
`_q01_smoke_admission()` returns
`q01_smoke_waiver_missing_capacity_evidence` for this artifact.

Required correction: provide a real smoke or task-bound saturation evidence
with a concrete terminal/slot/process census.

## Checks that passed

- The approved card and one active identity row for
  `9914 / bandy-zlema-distance-trend` exist.
- Thirteen active magic rows exist at slots 0-12. The committed resolver at
  review HEAD contains each corresponding magic exactly once; the dirty working
  resolver was not touched.
- The default ZLEMA(20) calculation implements the card's `2*close-close[10]`
  input and closed-bar EMA recursion. Symmetric distance/regime entries, 3-ATR
  stop input, one-position enforcement, ZLEMA exits, and 30-D1-bar time stop are
  materially present apart from the cadence/risk and reachability findings.
- `SPEC.md` passed its seven-section structural validator.
- All 13 setfiles use `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- `validate_build_guardrails.py` returned `PASS`: 14 files, zero findings,
  `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and warnings; D17 could not
  mechanize the prose-only universe.
- MQ5 and EX5 hashes match the producer artifact. EX5 SHA-256 is
  `fcffbe005da21a7c504a30ff1627dab8b94d550c6d8dd50dac89b3e17f48ae8d`.

These passes establish file identity and limited static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, resolver, setfile, work item, task verdict, or trade
stream was changed by this review. `T_Live` and AutoTrading were not touched.
The task remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code and
evidence require a fresh mandatory Codex review.
