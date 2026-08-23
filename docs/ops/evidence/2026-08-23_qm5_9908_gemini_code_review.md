# QM5_9908 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `9bd88385-fdac-4b6d-9437-0cdc14fb3f25`

Source task: `ce7ef250-d7c0-418a-aa51-fff4f7a8136e` (`gemini`, build delivery only)

Reviewed artifact: `C:/QM/repo/framework/EAs/QM5_9908_bandy-psar-flip-trend/build_identity.json`

Verdict: **REQUEST_CHANGES — D1 gating, fixed-risk sizing, exit reachability,
PSAR stop behaviour, approved symbol scope, and producer evidence do not satisfy
the approved card; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the D1 execution contract is undeclared and entries use the chart clock

The card is D1-only (card lines 43-50). `OnInit()` merely calls
`QM_FrameworkInit()` (source lines 185-192); it neither declares
`QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` nor rejects a non-D1
chart. Entry is gated by bare `QM_IsNewBar()` at line 244, whose default is the
attached chart timeframe even though every signal read is D1. On an intraday
chart the same closed-D1 flip can therefore be reconsidered each intraday bar,
including after a same-day position close. The SPEC itself exposes the mismatch
by claiming a D1 base timeframe but `PERIOD_CURRENT` bar gating.

Required correction: declare and validate the D1 execution contract during
initialization and use one explicit D1 new-bar edge for daily signal entry.

### 2. High — fixed-risk sizing uses the catastrophic stop instead of PSAR distance

The card requires P2 fixed $1,000 risk based on the distance from entry to the
initial PSAR level (card lines 59-63). Both entry branches instead set `req.sl`
to `4.0 * ATR(14)` (source lines 94-100 and 112-118). The framework derives
`sl_points` and lots from `req.sl`, so the delivered EA sizes against the wide
catastrophic backstop rather than the card's primary PSAR risk distance. This is
a different exposure model, not a parameterization detail.

Required correction: bind risk sizing to the initial PSAR distance while
preserving the separate 4-ATR catastrophe protection required by the card.

### 3. High — the PSAR level is never maintained as the card's trailing stop

The card says the PSAR level itself is the trail, with 4 ATR only as a
catastrophic backstop (card lines 53-60). The implementation installs only the
fixed 4-ATR stop and never modifies it. Management closes at market once the
closed-bar PSAR is already on the opposite side of the close (source lines
125-168); there is no PSAR-level protective-stop ratchet. This leaves the
primary stop behaviour described by the card absent.

Required correction: implement the approved PSAR stop/trail lifecycle and keep
the catastrophic protection distinct and restart-safe.

### 4. High — an invented spread rule can suppress mandatory exits

The approved card does not define a spread/ATR filter, but the build adds
`strategy_spread_max_atr = 0.30` and rejects when spread exceeds that threshold
(source lines 44 and 51-65). More critically, `OnTick()` executes this
entry-oriented filter before `Strategy_ManageOpenPosition()` (lines 215-218).
Wide spread or insufficient warmup can therefore delay the 60-day exit and PSAR
flip exit for an existing position. The mandatory news gate is correctly later
than management, but that does not cure this independent early return.

Required correction: remove or obtain approval for the new signal filter, and
keep all management/exit paths reachable regardless of entry eligibility.

### 5. High — two delivered indices are not named by the card and oil is omitted

The card names FX majors, XAUUSD, oil CFD/XTIUSD, NDX.DWX, and WS30.DWX, with
SP500.DWX backtest-only (card lines 23-24 and 79-83). The 13 delivered setfiles
add `GDAXI.DWX` and `UK100.DWX` while omitting `XTIUSD.DWX`. The D17 parser
returned an empty target-symbol list because this card expresses scope in
prose; that tooling limitation does not expand card authority. The Gemini SPEC
then treats the delivered package as if it were the approved universe.

Required correction: restrict the package to the named approved universe and
include oil in the chosen primary cohort, or obtain an OWNER-approved card
amendment.

### 6. High — the producer identity is not a canonical build result

`build_identity.json` contains hashes, file paths, setfiles, and
`build_check_passed`, but omits required fields from
`tools/strategy_farm/prompts/SCHEMAS.md`: `task_id`, `ea_id`, `ea_dir`,
`magic_base`, `symbols_registered`, `spec_md_path`, `compile_succeeded`,
`smoke_result`, and `smoke_report_path`. No smoke result or sanctioned
capacity-deferral evidence is supplied. A committed EX5 and matching hashes do
not satisfy the canonical producer/evidence contract.

Required correction: emit a schema-complete result bound to the immutable task
and exact files, plus smoke evidence or a canonical saturation-only deferral.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`.
- EA registry row `9908 / bandy-psar-flip-trend` is active.
- Thirteen active magic rows exist at slots 0-12; the active/reserved registry
  has zero global magic collisions, and all 13 expected magic values occur
  exactly once in the generated resolver. This is consistency, not symbol
  authorization.
- Two-bar PSAR flip detection, the 200-SMA directional regime gate, long/short
  symmetry, one-position enforcement, 60-D1-bar time stop, close-before-reverse
  ordering, and the complete framework timer/transaction/tester hooks are
  materially present.
- `SPEC.md` contains the seven required structural sections and
  `validate_spec_doc.py` returned `PASS`; the semantic discrepancies above
  remain manual review failures.
- All 13 setfiles use `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- Source and setfiles contain no control bytes; the MQ5 consistently uses LF
  line endings.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and warnings, subject to the
  manual risk, trailing-stop, cadence, reachability, and authorized-universe
  findings above.
- MQ5 SHA-256 matches the producer identity:
  `fb914b7c3fe2d0104db00d57b947f7f384aceb79a8927e3bf56f1b96e621da13`.
- EX5 SHA-256 matches the producer identity:
  `e22aa23e895d0342763d5c0afeb152090831b80f64b300123c5261af942b2b8f`.
- The focused forbidden scan found no raw `CopyBuffer`, raw `OrderSend`,
  blocking `Sleep`, ML entry point, or stop-modification bypass.

These passes establish file identity and limited static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, setfile, work item, task verdict, or trade stream
was changed by this review. `T_Live` and AutoTrading were not touched. The task
remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code and evidence
require a fresh mandatory Codex review before acceptance or enqueue.
