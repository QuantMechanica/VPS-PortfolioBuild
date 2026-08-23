# QM5_9911 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `afef5155-0368-4013-89c2-918df766d6e6`

Source task: `970379cc-27ef-4f71-a07e-5421e45171ef` (`gemini`, build delivery only)

Reviewed artifact: `D:/QM/strategy_farm/artifacts/builds/970379cc-27ef-4f71-a07e-5421e45171ef.json`

Verdict: **REQUEST_CHANGES — the D1 execution/exit contract, approved universe,
and producer evidence remain incomplete; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — wrong-timeframe attachment succeeds initialization and disables exits

The card is explicitly D1 (card lines 15 and 43). `OnInit()` calls the generic
framework initializer but never declares
`QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` (source lines 252-274).
The later `_Period != PERIOD_D1` check in `Strategy_NoTradeFilter()` (lines
130-133) runs before `Strategy_ExitSignal()` in `OnTick()` (lines 293-298).
Consequently, an accidental non-D1 attachment initializes successfully and then
suppresses both the 10-bar channel exit and 60-day time stop for an existing
position. Entry also uses bare chart-period `QM_IsNewBar()` at line 323.

Required correction: fail initialization on an invalid attachment through the
framework D1 execution contract and use an explicit D1 entry edge; entry
eligibility must never gate position exits.

### 2. High — the delivered cohort adds two indices and omits approved oil scope

The card authorizes FX majors, XAUUSD, oil CFD, live-routable `NDX.DWX` and
`WS30.DWX`, with `SP500.DWX` optional for backtest (card lines 24, 79, and 83).
The delivered 13-symbol registry/setfile cohort adds `GDAXI.DWX` and
`UK100.DWX` while omitting `XTIUSD.DWX`. As with the other legacy cards, D17
cannot parse prose into `target_symbols`; that is not authority to add symbols.

Required correction: align the cohort with the approved prose scope or obtain
an OWNER-approved explicit `target_symbols` amendment.

### 3. High — the source artifact is schema-incomplete and provides no smoke proof

The external build JSON contains `task_id`, `ea_id`, paths, hashes, setfiles,
and `build_check_passed`, but omits required `ea_dir`, `magic_base`,
`symbols_registered`, `compile_succeeded`, `smoke_result`, and
`smoke_report_path` fields. No smoke report or canonical capacity-only deferral
was found.

Required correction: emit a schema-complete result bound to the immutable task
and exact build, with smoke evidence or canonical `deferred_p2_smoke` evidence.

## Checks that passed

- The approved card and one active identity row for
  `9911 / bandy-donchian-20-classic-breakout-trend` exist.
- Thirteen active magic rows exist at slots 0-12; the committed resolver at
  review HEAD contains each corresponding magic exactly once. Codex did not
  touch a concurrent dirty resolver in the shared worktree.
- The entry and exit channels correctly exclude the just-finished signal bar,
  use closed D1 shifts, and cache by D1 calendar key without same-bar look-ahead.
- The 200-SMA directional gates, long/short symmetry, 2.5-ATR catastrophe stop
  and fixed-risk distance, one-position enforcement, 10-bar channel exits,
  60-D1-period time stop, and management-before-news ordering are materially
  present on a correct D1 attachment.
- `SPEC.md` has all seven required sections and its structural validator passed.
- All 13 setfiles use `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and warnings; D17 could not
  mechanize the prose-only universe.
- MQ5 SHA-256 matches the source artifact:
  `13b1bfefd404cddf97e0086b4212c0f1bc1f053c6bd51aa48e67a0307499cdf0`.
- EX5 SHA-256 matches the source artifact:
  `607c9675c25083743b71c478a620881d0f1551de767b4dd04e7b3c426bcd319d`.
- The source/setfiles contain no control bytes; the source uses consistent LF
  endings and the focused forbidden scan found no raw `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, ML entry point, or stop-modification bypass.

These passes establish file identity and limited static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, setfile, work item, task verdict, or trade stream
was changed by this review. `T_Live` and AutoTrading were not touched. The task
remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code and evidence
require a fresh mandatory Codex review.
