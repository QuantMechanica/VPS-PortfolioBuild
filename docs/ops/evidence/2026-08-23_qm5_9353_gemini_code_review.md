# QM5_9353 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `5fdc87be-5559-456c-9c2e-d6e4c9243070`

Source task: `7bc95960-7134-4d02-88c2-87ce2cb8761c` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_9353_chande-stochrsi-base-cross-h4/build_identity.json`

Verdict: **REQUEST_CHANGES — the configurable StochRSI window can write out of bounds, and the H4/news execution contracts are not preserved; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. Critical — an allowed StochRSI input writes beyond a fixed array

`ComputeStochRSIRaw()` allocates `double rsi_vals[14]`, then writes
`rsi_vals[i]` while `i < strategy_stoch_period` (source lines 58 and 62-65).
The parameter is an unrestricted EA input, and the durable SPEC explicitly
advertises values from 7 through 30 (SPEC line 27). Any value from 15 through
30 therefore indexes beyond the 14-element array. The default setfiles happen
to use 14; that does not make the published optimization/input range safe.

Required correction: remove the unnecessary fixed array or size and validate
storage against the accepted period before any indicator evaluation. Add a
focused boundary test for the maximum supported period.

### 2. High — the mandatory H4 execution contract is undeclared

`OnInit()` returns success immediately after `QM_FrameworkInit()` without
calling `QM_FrameworkDeclareExecutionContract(PERIOD_H4, ...)` (source lines
267-275). Entry admission later uses the no-argument `QM_IsNewBar()` (line
326), which follows the attached chart timeframe while every strategy
indicator remains fixed to H4. A wrong-period attachment can therefore test
the same completed-H4 crossover at unrelated chart-bar boundaries instead of
failing closed at initialization.

Required correction: declare the H4 timeframe and intended Friday-close mode
immediately after framework initialization, and use that same H4 clock for the
strategy decision boundary.

### 3. High — the delivered news blackout is half the approved window

The approved card requires a HIGH-impact blackout within plus/minus 60 minutes
of bar open (card lines 123-124). The EA defaults to
`QM_NEWS_TEMPORAL_PRE30_POST30` (source line 24) and also passes literal 30/30
legacy windows to framework initialization (lines 269-272). The framework has
the explicit `QM_NEWS_TEMPORAL_PRE60_POST60` mode, so this is not an unavailable
representation.

Required correction: encode the approved 60/60 window consistently in the
temporal mode, framework declaration, SPEC, and regenerated setfiles.

### 4. High — entry eligibility can suppress required exits and the time stop

`OnTick()` returns on `Strategy_NoTradeFilter()` before management and strategy
exit handling (source lines 297-302). That filter contains warmup, quote, ATR,
and spread entry eligibility. A wide spread or invalid quote can therefore
block the card's 25-H4-bar time stop and opposite-cross exit even though every
position has already been admitted.

Required correction: keep Friday close, open-position management, and card
exits reachable independently of new-entry eligibility. Apply the spread gate
only to entry construction.

### 5. Medium — every delivered setfile has malformed `CR CR LF` endings

All 13 setfiles contain exactly 36 `0D 0D 0A` sequences. Their visible risk
values are correct, but the malformed records are not byte-stable inputs for
normal line-oriented tooling. Normalize them through the governed generator
and refresh the build identity before resubmission.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`.
- EA registry row `9353 / chande-stochrsi-base-cross-h4` is active.
- Thirteen active magic rows exist at slots 0-12; the active/reserved registry
  has zero global magic collisions, and all 13 target rows are present in the
  generated resolver with `magic = ea_id * 10000 + slot`.
- All delivered symbols are canonical entries in `dwx_symbol_matrix.csv`.
- All 13 setfiles visibly use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and zero warnings.
- `validate_spec_doc.py` returned `PASS`, and the SPEC has zero non-whitespace
  control bytes.
- MQ5 SHA-256 matches `build_identity.json`:
  `d41133892dcfeb01aff347777b549118f2ee275ab7eee1faf6b2be08caec991f`.
- EX5 SHA-256 matches `build_identity.json`:
  `6a2ac128e2be3d728206f969a94d28430d8e77c0b390ccf3327aa0314bdc74fe`.
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
