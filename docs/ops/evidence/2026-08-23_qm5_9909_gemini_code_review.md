# QM5_9909 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `d6ea3abe-d44b-4861-b466-475a28899eaa`

Source task: `a944cf09-4a86-43b5-90b5-1d6fc5108ae6` (`gemini`, build delivery only)

Reviewed artifact: `C:/QM/repo/framework/EAs/QM5_9909_bandy-lrchannel-breakout-trend/build_identity.json`

Verdict: **REQUEST_CHANGES — daily cadence, exit reachability, catastrophic-stop
contract, approved universe, and producer evidence do not satisfy the approved
card; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the D1 execution contract is undeclared and entry uses the chart clock

The card is D1-only. `OnInit()` only calls `QM_FrameworkInit()` (source lines
242-250); it does not declare or validate a D1 execution contract. Entry is
gated by bare `QM_IsNewBar()` at line 301, and the Gemini SPEC explicitly calls
that `PERIOD_CURRENT`. An intraday attachment can therefore reconsider the same
closed-D1 breakout on each intraday bar after a same-day close.

Required correction: declare and validate `PERIOD_D1` during initialization and
use one explicit D1 new-bar edge for entry.

### 2. High — an invented spread filter suppresses the trail and time stop

The approved card does not define a spread/ATR filter. The build adds
`strategy_spread_max_atr = 0.30` (source line 44) and executes
`Strategy_NoTradeFilter()` before `Strategy_ManageOpenPosition()` (lines
272-275). Wide spread, missing quotes, or warmup insufficiency can therefore
prevent both the mandatory Chandelier ratchet and the 40-day time stop from
running on an open position.

Required correction: remove or approve the new entry filter and move all
management/exit work ahead of every entry-only eligibility return.

### 3. High — the declared 5-ATR catastrophic backstop is never implemented

The card requires a 2.5-ATR Chandelier primary stop plus a separate 5-ATR
catastrophic backstop (card lines 55-64). The EA declares
`strategy_sl_atr_mult = 5.0` at line 42 but never reads it. Both entry branches
set the only protective stop with `strategy_trail_atr_mult = 2.5` (lines 147
and 164), and management maintains only that Chandelier stop. The fixed-risk
sizing distance is therefore correct at 2.5 ATR, but the separately claimed
catastrophic protection and its SPEC statement are absent.

Required correction: implement the approved two-layer stop lifecycle, or amend
the card and SPEC so the executable risk contract is unambiguous.

### 4. High — the delivered cohort adds two indices and omits approved oil scope

The card authorizes FX majors, XAUUSD, oil CFD, `NDX.DWX`, `WS30.DWX`, and
backtest-only `SP500.DWX` in prose (card lines 25, 82, and 86). The 13 delivered
setfiles add `GDAXI.DWX` and `UK100.DWX` while omitting `XTIUSD.DWX`. The empty
D17 target-symbol parse is a legacy-card limitation, not permission to expand
the universe.

Required correction: align the registered/setfile cohort with the approved
scope, including oil where selected, or obtain an OWNER-approved explicit
`target_symbols` amendment.

### 5. High — producer evidence is not a canonical build result and has no smoke proof

`build_identity.json` omits `task_id`, `ea_id`, `ea_dir`, `magic_base`,
`symbols_registered`, `spec_md_path`, `compile_succeeded`, `smoke_result`, and
`smoke_report_path` from the required build-result schema. No smoke result or
sanctioned capacity-only deferral was found.

Required correction: emit a schema-complete task-bound result plus smoke
evidence or canonical `deferred_p2_smoke` evidence.

## Checks that passed

- The approved card and one active identity row for
  `9909 / bandy-lrchannel-breakout-trend` exist.
- Thirteen active magic rows exist at slots 0-12; the committed resolver at
  review HEAD contains every corresponding magic exactly once. Codex did not
  touch the resolver while another process had it dirty in the shared worktree.
- The 50-bar OLS calculation uses closed D1 bars in oldest-to-newest order,
  computes the newest fitted centerline and sample residual deviation, and
  implements symmetric long/short breakouts without look-ahead.
- The 2.5-ATR fixed-risk initial distance, ratcheting long/short Chandelier
  management, one-position enforcement, and 40-D1-bar time stop are materially
  present subject to the reachability and catastrophic-stop findings above.
- `SPEC.md` has all seven required sections and its structural validator passed.
- All 13 setfiles use `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and one non-failing
  `EA_CARD_SMA_DIRECTION_UNDECIDABLE` warning; the manual findings remain.
- MQ5 SHA-256 matches the producer identity:
  `3c5c7dd75f7501698280a3c89fcc8b26bcb4ff2012c09657b9fc7516c623d2fc`.
- EX5 SHA-256 matches the producer identity:
  `e83cdf3119b6e008198cb326edab358740c51220b1050ea4dab2c736952531ee`.
- The source/setfiles contain no control bytes; the source uses consistent LF
  endings and no raw `CopyBuffer`, raw `OrderSend`, blocking `Sleep`, or ML
  entry point was found. Stop moves use `QM_TM_MoveSL`.

These passes establish file identity and limited static consistency only. No
pipeline verdict is inferred.

## Disposition

No source, binary, registry, setfile, work item, task verdict, or trade stream
was changed by this review. `T_Live` and AutoTrading were not touched. The task
remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code and evidence
require a fresh mandatory Codex review.
