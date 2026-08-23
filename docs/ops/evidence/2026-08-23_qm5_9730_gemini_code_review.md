# QM5_9730 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `a6de7c37-1c79-4bbe-b97a-7ab0acba91b4`

Source task: `b3706cb0-1e2f-403c-a3a9-ffc9e87e6835` (`gemini`, build delivery only)

Reviewed artifact: `C:/QM/repo/framework/EAs/QM5_9730_bandy-weekly-rsi-extreme-d1-trigger-mr-index/build_identity.json`

Verdict: **REQUEST_CHANGES — daily cadence, exit reachability, RSI-zero
handling, approved universe, and producer evidence do not satisfy the approved
card; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the D1 execution contract is undeclared and entry uses the chart clock

The approved mechanic evaluates a closed D1 trigger and a closed W1 setup once
per daily close (card lines 41-51). `OnInit()` only calls `QM_FrameworkInit()`
(source lines 168-176); it neither declares
`QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` nor rejects a non-D1
chart. Entry is gated by bare `QM_IsNewBar()` at line 227, whose clock is the
attached chart period. On an intraday chart, the same closed D1/W1 signal can be
reconsidered on every intraday bar after a same-day close.

Required correction: declare and validate the D1 execution contract during
initialization and use one explicit D1 new-bar edge for entry.

### 2. High — an invented spread filter can suppress every mandatory exit

The card's only optional filter is the weekly-low continuation guard; it does
not authorize a spread/ATR rule. The EA adds `strategy_spread_max_atr = 0.30`
(source line 48) and calls `Strategy_NoTradeFilter()` before both
`Strategy_ManageOpenPosition()` and `Strategy_ExitSignal()` (lines 198-203).
Wide spread, missing quotes, or warmup insufficiency can therefore delay the
10-day time stop and both RSI exits for an existing position.

Required correction: remove or obtain approval for the new entry filter, and
keep all position management and exit paths reachable independently of entry
eligibility.

### 3. High — the delivered 13-symbol package exceeds the approved index scope

The approved card identifies the index family `SP500.DWX` for backtest plus
`NDX.DWX` and `WS30.DWX` for live validation (card lines 25, 81, and 85). The
delivery registers and emits setfiles for those three plus `GDAXI.DWX`,
`UK100.DWX`, seven FX majors, and `XAUUSD.DWX`. The D17 parser returns an empty
list because the older card expresses scope in prose; that tooling limitation
does not authorize ten additional instruments.

Required correction: restrict the package to the approved index cohort or
obtain an OWNER-approved card amendment with an explicit `target_symbols`
contract.

### 4. Medium — valid RSI values of exactly zero are treated as missing data

`Strategy_EntrySignal()` rejects when either RSI is `<= 0.0` (source line 87).
RSI can legitimately equal zero after an uninterrupted decline, and zero is
the strongest possible satisfaction of the card's `W1 RSI(3) <= 20` and
`D1 RSI(2) <= 10` entry conditions. The implementation therefore drops a valid
edge case instead of distinguishing indicator failure from a valid zero.

Required correction: use an indicator-read validity proof that permits the
closed-form RSI range `[0, 100]`.

### 5. High — producer evidence is not a canonical build result and has no smoke proof

`build_identity.json` provides hashes, paths, setfiles, and
`build_check_passed`, but omits the required build-result fields documented in
`tools/strategy_farm/prompts/SCHEMAS.md`: `task_id`, `ea_id`, `ea_dir`,
`magic_base`, `symbols_registered`, `spec_md_path`, `compile_succeeded`,
`smoke_result`, and `smoke_report_path`. No smoke result or sanctioned
capacity-only deferral was found.

Required correction: emit a schema-complete result bound to the immutable task
and exact files, with smoke evidence or a canonical `deferred_p2_smoke` record.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`; the identity registry
  has one active `9730 / bandy-weekly-rsi-extreme-d1-trigger-mr-index` row.
- Thirteen active magic rows exist at slots 0-12. The committed resolver at
  review HEAD contains every corresponding magic exactly once. A separate
  concurrent process had the resolver dirty in the shared worktree, so Codex
  did not overwrite or treat that transient file as pipeline evidence.
- Closed-bar W1 RSI(3), D1 RSI(2), SMA(200), long-only entry, 3-ATR stop sizing,
  one-position enforcement, RSI exits, and the 10-D1-bar time stop are
  materially present apart from the reachability/cadence findings above.
- `SPEC.md` has all seven required sections and `validate_spec_doc.py` returned
  `PASS`; its symbol and cadence claims inherit the manual discrepancies above.
- All 13 setfiles use `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and warnings; D17 could not
  mechanize the prose-only universe.
- MQ5 SHA-256 matches the producer identity:
  `406a8740c2469fac9e6fd384fee1380532f13a65bb15b65350f11ecd30bdde92`.
- EX5 SHA-256 matches the producer identity:
  `ceef802588a001e12961a1a6f20e2a76755cd676cf72841da9076b8f136cd92f`.
- The source and setfiles contain no control bytes; the source uses consistent
  LF endings and the focused forbidden scan found no raw `CopyBuffer`, raw
  `OrderSend`, blocking `Sleep`, ML entry point, or stop-modification bypass.

These passes establish file identity and limited static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, setfile, work item, task verdict, or trade stream
was changed by this review. `T_Live` and AutoTrading were not touched. The task
remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code and evidence
require a fresh mandatory Codex review.
