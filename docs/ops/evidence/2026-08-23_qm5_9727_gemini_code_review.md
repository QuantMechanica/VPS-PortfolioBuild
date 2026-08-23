# QM5_9727 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `fa4876c7-25a0-404a-87df-9da71348d252`

Source task: `d820be5a-675c-411f-b761-6c09aad2b811` (`gemini`, build delivery only)

Reviewed artifact: `D:/QM/strategy_farm/artifacts/builds/d820be5a-675c-411f-b761-6c09aad2b811.json`

Verdict: **REQUEST_CHANGES — the implementation changes the approved signal,
omits two risk/lifecycle requirements, can suppress exits, exceeds the approved
universe, and lacks a valid D1/SPEC/evidence contract; do not promote to
PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the compression rule is not the approved prior-bar rule

The card requires the ATR ratio to be compressed on the prior bar and expresses
entry as `compressed[prior_bar] AND breakout` (card lines 41-45). The source
instead calculates ratios at shifts 1 and 2 and sets
`g_compressed = comp1 || comp2` (source lines 74-84). Its SPEC repeats this
unauthorized "prior or current closed bar" rule. That broadens the signal and
changes which trades enter.

Required correction: implement one unambiguous shift convention matching the
approved prior-bar contract, and make the SPEC describe that exact convention.

### 2. High — compression-episode reset and two-bar re-entry lockout are absent

The card requires resetting the compression flag on entry and forbids immediate
re-entry on the same compression episode when stopped within two bars (card
line 63). The implementation has no episode-consumed state, entry reset, or
two-bar cooldown; `g_compressed` is simply recomputed on every D1 edge.

Required correction: persist a deterministic compression-episode identity and
enforce the approved reset/cooldown without weakening exits.

### 3. High — the required 5.0 ATR catastrophic backstop is absent

The card requires a separate `5.0 * ATR(14)` catastrophic stop in addition to
the primary 2.5 ATR ratcheting stop (card lines 54-55 and R2 line 75). The source
exposes only the 2.5 ATR trail inputs (lines 48-50) and uses that distance for
entry/management; no 5.0 ATR input or execution path exists.

Required correction: implement the separate catastrophic server-side backstop
and document how it coexists with the primary ratchet.

### 4. High — the mandatory D1 execution contract is undeclared

`OnInit()` calls `QM_FrameworkInit()` and reports success (source lines
254-275), but never calls
`QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` and does not fail on a
non-D1 chart. The only timeframe check is the later entry filter at lines
112-120, while the bare `QM_IsNewBar()` follows the attached chart period.

Required correction: declare and validate the D1 execution contract immediately
after framework initialization, failing closed on a mismatch.

### 5. High — invalid cached state can suppress every strategy exit

On each new bar, the EA advances state and then calls
`Strategy_NoTradeFilter()` before management and exits (source lines 301-309).
When history/indicator state is temporarily invalid, or parameters/timeframe are
invalid, the filter returns early and skips the card's 45-day stop, ATR ratchet,
and opposite-breakout exit for an already-open position.

Required correction: validate immutable parameters at `OnInit()`, keep
management and exit paths reachable for open positions, and apply transient
entry filters only to entry.

### 6. High — the delivered universe adds two indices and omits oil

The card targets FX majors, XAUUSD, oil CFD/XTIUSD, NDX.DWX, and WS30.DWX, with
SP500.DWX optional (card lines 76 and 79-80). The 13 delivered setfiles include
`GDAXI.DWX` and `UK100.DWX`, which the card never authorizes, and omit
`XTIUSD`. The D17 parser returned an empty target-symbol list and missed the
prose-format mismatch; that result does not expand card authority.

Required correction: restrict the package to the approved asset set and include
oil in the chosen primary cohort, or obtain an OWNER-approved card amendment.

### 7. High — the mandatory SPEC is incomplete and contradicts the card

`SPEC.md` stops after strategy logic and parameters. `validate_spec_doc.py`
fails because required sections 3-7 — Symbol Universe, Timeframe, Expected
Behaviour, Source Citation, and Risk Model — are absent. Its existing strategy
paragraph also embeds the unauthorized current-or-prior compression rule.

Required correction: produce a complete, card-faithful SPEC and pass the
repository validator.

### 8. High — the producer artifact is not a canonical build result

The submitted JSON records file paths, hashes, 13 setfiles, and
`build_check_passed`, but omits canonical build-result fields including
`compile_succeeded`, `ea_dir`, `magic_base`, `symbols_registered`,
`smoke_result`, and `smoke_report_path`. No smoke summary is supplied. Matching
hashes do not establish schema-complete build or runtime evidence.

Required correction: emit a canonical result bound to the immutable task and
exact files, plus smoke evidence or a canonical saturation-only deferral.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`.
- EA registry row `9727 / bandy-atr-ratio-compression-breakout-trend` is active.
- Thirteen active magic rows exist at slots 0-12; the active/reserved registry
  has zero global magic collisions, and all 13 expected magic values occur
  exactly once in the generated resolver. This is consistency, not symbol
  authorization.
- The Donchian window correctly excludes the signal bar by reading shifts 2-21;
  long/short symmetry, one-position enforcement, primary ATR ratchet, 45-day
  time stop, and close-before-reverse lifecycle are materially present for valid
  D1 state.
- All 13 setfiles use `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- The MQ5 has CRLF line endings, no bare LF, and no NUL byte.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and warnings, subject to the
  manual signal, stop, lifecycle, D1, exit-reachability, and universe findings
  above.
- MQ5 SHA-256 matches the producer artifact:
  `ece192603106d3fbddfdec4d74564cc423f4142c4424fd6b310478146f2e992e`.
- EX5 SHA-256 matches the producer artifact:
  `82f39a6b06b56b39098dd27266b3a198cca3b55802201fdca411e92b4022e02a`.
- The focused forbidden scan found no raw indicator handle, `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, or ML entry point.

These passes establish file identity and limited static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, setfile, work item, task verdict, or trade stream
was changed by this review. `T_Live` and AutoTrading were not touched. The task
remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code and evidence
require a fresh mandatory Codex review before acceptance or enqueue.
