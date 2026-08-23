# QM5_9579 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `ad98fd21-0459-4b0b-a673-69d41d2b1a0d`

Source task: `34ffb386-bb5b-4c08-8319-c8b893fc50cc` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_9579_bandy-atr-channel-breakout-trend/build_identity.json`

Verdict: **REQUEST_CHANGES — the D1 execution and risk-management reachability contracts are not preserved, and the SPEC contradicts the build; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the mandatory D1 execution contract is undeclared

`OnInit()` returns success immediately after `QM_FrameworkInit()` without
calling `QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` (source lines
187-195). Entry admission later uses the no-argument `QM_IsNewBar()` (line
242), which follows the attached chart timeframe while every strategy
indicator remains fixed to D1. A wrong-period attachment can therefore test
the same completed-D1 breakout at unrelated chart-bar boundaries instead of
failing closed at initialization.

Required correction: declare the D1 timeframe and intended Friday-close mode
immediately after framework initialization, and use that same D1 clock for the
strategy decision boundary.

### 2. High — entry eligibility can suspend the ATR trail and time stop

`OnTick()` returns on `Strategy_NoTradeFilter()` before
`Strategy_ManageOpenPosition()` (source lines 213-216). That filter contains
warmup, quote, ATR, and spread entry eligibility (lines 51-65). During a wide
spread or invalid quote/ATR observation, an existing position therefore skips
both the card's ratcheting two-ATR Chandelier stop and its 30-trading-day
market exit. The server-side stop does not replace the required daily ratchet
or time stop.

Required correction: keep Friday close and open-position management reachable
independently of all new-entry filters. Apply spread eligibility only before a
new request is constructed.

### 3. High — the durable SPEC contradicts both card and source

The approved card and every strategy read are D1, and the source exposes eight
strategy inputs (source lines 37-45). `SPEC.md` instead declares base timeframe
`H1` (SPEC line 64) and says there are no strategy-specific inputs (line 28).
This is not a cosmetic omission: the SPEC is the durable execution surface
used by downstream reviewers and operators.

Required correction: regenerate the SPEC from the actual card and MQ5, list
the eight inputs with their governed meanings/ranges, and assert D1 in the
document validator.

### 4. Medium — the declared five-ATR backstop input is not wired

The card separately names a five-ATR catastrophic backstop (card line 58), and
the MQ5 exposes `strategy_sl_atr_mult = 5.0` (source line 42). No executable
path reads that input. Entry uses `strategy_trail_atr_mult` at two ATR (lines
93-110), and management only ratchets the same two-ATR value. The tighter
initial trail is protective, but an unused advertised safety input is not an
implemented contract.

Required correction: either implement and document the distinct backstop
invariant or remove it through an approved card/input revision; do not leave a
non-functional risk control exposed.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`.
- EA registry row `9579 / bandy-atr-channel-breakout-trend` is active.
- Thirteen active magic rows exist at slots 0-12; the active/reserved registry
  has zero global magic collisions, and all 13 target rows are present in the
  generated resolver with `magic = ea_id * 10000 + slot`.
- The 13-symbol package is within the card's FX-major, XAUUSD, and major-index
  portability statement; every delivered symbol is canonical.
- All 13 setfiles use normal line endings, `RISK_FIXED=1000`, and
  `RISK_PERCENT=0`.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and zero warnings.
- `validate_spec_doc.py` returned structural `PASS`, subject to finding 3.
- MQ5 SHA-256 matches `build_identity.json`:
  `dde31d552fb197f3d16f311353b553d7956cb90a5b84ef2efb79cddf1f7fdd44`.
- EX5 SHA-256 matches `build_identity.json`:
  `35c47c98faa8e7b5dfdeb466b91556136c704f869a00a7b1ded767e3f4ceff51`.
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
