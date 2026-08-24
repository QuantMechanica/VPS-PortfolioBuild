# Codex recycled Gemini EA reviews — QM5_1407 and QM5_1410 — 2026-08-24

- Lane: `codex`, `agents/board-advisor`
- Reviewed canonical HEAD: `e8a88ec9bf3235ac76045d9a956136f6acc89c44`
- Router order: `c789e9ec-4aeb-41c4-acdd-ad8aff760737`, then `ee84a2b6-1d7a-4cbf-b7bd-393469e9a8be`
- Verdict: **both FAIL and remain REVIEW; no pipeline handoff**
- Review timestamp: `2026-08-24T07:36:00Z`

The payload-requested `code-review` and `gemini-output-review` skills are not
installed in this session. The canonical review prompt/schema, approved cards,
live producer artifacts, current sources/binaries, registries, setfiles, and
static gates were reviewed directly.

## QM5_1407 — FAIL

The live producer identity is task
`ea5327f9-2e58-4f02-b542-3861c7432401`, MQ5 SHA-256
`ec703768d87320dbcffbc2742a7780cfa9aed76729dbf441980af64a90dea39a`,
and EX5 SHA-256
`3511e99858e36be123a908b6b43d3fad5dd98bb30f2c53e205b81da0237a9760`.
Those live hashes match the supplied producer JSON. An older review record
contains a different colliding `ea5327f9-*` producer UUID and different hashes,
so no identity claim was inherited from it.

Current label-scoped hardening reports nine failures: the card's BUY-STOP and
SELL-STOP are both absent, the approved 480/480-minute news window is implemented
as 30/30 minutes, and six emitted symbols are outside the exact card universe.
The build also omits the card-required `XTIUSD.DWX` symbol. Direct inspection
reconfirms that the required OCO bracket is replaced by a post-breakout market
request (source lines 406-488), the card's `0.25 * ATR` spread ceiling is
replaced by `1.5 * rolling-average-spread` (lines 147-170), past-apex rejection
is absent (lines 355-362), invalidation/pivot-overlap reuse is not recorded
(lines 117-145), TP1 success is not checked (lines 518-525), and the failure
projection remains frozen (lines 543-559). Managed state is still process-local
and not reconstructed after restart.

The broad guardrail and SPEC validators pass, all 13 setfiles use
`RISK_FIXED > 0` and `RISK_PERCENT = 0`, and forbidden-code grep is clean. Those
checks do not cure the card divergence. The producer JSON is also not a valid
canonical build result: `compile_succeeded`, `smoke_result`, and
`smoke_report_path` are absent, and no governed smoke summary exists.

## QM5_1410 — FAIL

The current MQ5/EX5 hashes are unchanged from the prior RECYCLE review and match
the live producer JSON: MQ5
`b03a04ce49e412bdecfaa06f383130cc6b93c02ae8b8d80bb2d835335c88ce96`,
EX5 `4b539331592b0a65e507bf61baf5b1343aa722d7c0983f743724759eaabb764f`.

Current label-scoped hardening reports ten failures: missing MAE tracking,
incomplete `QM_EntryRequest` initialization, six unsafe indicator-buffer/index
accesses, a 30/30-minute implementation versus the approved 480/480-minute news
window, and news blocking before management. Three direct `CopyBuffer` calls
also fail the Codex framework corset and forbidden-code contract. The unchanged
manual defects remain: TP1 state is not reconstructed after restart, and the
card's MAE-adjusted 4-ATR gain cap is replaced by a static initial-price TP.

The broad guardrail and SPEC validators pass, and all 14 setfiles satisfy the
required fixed-risk backtest contract. The producer build result nevertheless
fails: `spec_md_path` is absent and literal `smoke_result="deferred_p2_smoke"`
has an empty `blocked_reason`, not the durable tester-capacity evidence required
by the canonical saturation-only exception. No smoke summary was supplied.

## Verification and safety boundary

Focused checks used label-scoped `build_gate_hardening.py`,
`validate_build_guardrails.py --max-news-stale-hours 336`,
`validate_spec_doc.py`, SHA-256 identity comparison, exact build-result schema
inspection, setfile-risk inspection, registry/card comparison, and focused
source review. No EA, card, setfile, registry, resolver, EX5, terminal,
backtest, Q-phase state, T_Live setting, AutoTrading setting, risk threshold,
or news staleness ceiling was changed. No compile or pipeline verdict was
claimed.
