# QM5_9468 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `cd6442dd-4ad9-4845-862a-2ef6e3ec0172`

Source task: `e7fdd25e-d16c-44d3-bcbe-c22756021747` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_9468_connors-rsi4-3day-d1/build_identity.json`

Verdict: **REQUEST_CHANGES — D1 execution, exit-management reachability, cooldown, durable SPEC, and approved-universe contracts are not preserved; do not promote to PIPELINE**

The router-requested `code-review` and `gemini-output-review` skills were not
installed in this session. Codex reviewed the approved card, implementation,
producer evidence, registries, and focused repository checks directly.

## Findings

### 1. High — the mandatory D1 execution contract is undeclared

`OnInit()` returns success immediately after `QM_FrameworkInit()` without
calling `QM_FrameworkDeclareExecutionContract(PERIOD_D1, ...)` (source lines
165-172). Entry admission later uses the no-argument `QM_IsNewBar()` (line
223), which follows the attached chart timeframe while every strategy read and
the three-bar hold calculation remain fixed to D1. A wrong-period attachment
can therefore admit repeated decisions on chart bars instead of failing closed.

Required correction: declare the D1 execution contract immediately after
framework initialization and gate decisions on that same D1 clock.

### 2. High — an entry-only filter can suspend the three-day exit

`OnTick()` returns on `Strategy_NoTradeFilter()` before calling
`Strategy_ManageOpenPosition()` (source lines 191-194). The filter rejects
warmup, invalid quote, and wide-spread conditions (lines 55-69). An already-open
position therefore skips the card's fixed three-D1-bar exit whenever any
entry-only condition is active. A server stop does not implement the mandatory
source-study horizon.

Required correction: keep Friday close and open-position management reachable
independently of every entry-eligibility filter; apply the spread filter only
before constructing a new entry request.

### 3. High — the three-bar cooldown is neither complete nor restart-safe

The card requires three bars of cooldown after exit (card line 58), but
`g_last_exit_time` is set only when this EA's local time-stop close succeeds
(source lines 139-146). Stop-loss exits, framework Friday closes, and any other
trade exit do not update it. The value is also volatile and is never rebuilt
from history after initialization or restart (line 49). Those paths can
re-enter without the required cooldown.

Required correction: reconstruct the last qualifying exit durably from trade
history on init and update it from the transaction stream for every exit owned
by this symbol/magic, with an explicit fail-closed fallback.

### 4. High — the durable SPEC contradicts the D1 build

The approved card is explicitly D1 and the MQ5 exposes nine strategy inputs
(source lines 37-46). `SPEC.md` instead declares base timeframe `H1` (SPEC line
64) and says there are no strategy-specific inputs (line 28). This is a
downstream operator contract, not a cosmetic summary.

Required correction: regenerate the SPEC from the card and actual MQ5, list
the governed strategy inputs and ranges, and assert D1 in validation.

### 5. High — the 13-symbol package exceeds the approved equity-index port

The approved card identifies the original SPY/QQQ concept and names
`SP500.DWX` for backtest plus `NDX.DWX` / `WS30.DWX` for live parallel
validation (card lines 18-19 and 72-73). The delivered package and active magic
rows cover 13 symbols, adding `GDAXI.DWX`, `UK100.DWX`, `XAUUSD.DWX`, and seven
FX pairs without card authority. The automated D17 check cannot catch this
because the card lacks a machine-readable `target_symbols` field; its empty
parse is not approval for an unrestricted universe.

Required correction: restrict the build/setfiles/registry allocation to the
approved port or obtain an OWNER-approved card amendment before expanding it.

## Checks that passed

- The canonical card exists with `g0_status: APPROVED`.
- EA registry row `9468 / connors-rsi4-3day-d1` is active.
- Thirteen active magic rows exist at slots 0-12; the active/reserved registry
  has zero global magic collisions, and all 13 expected magic values are
  present in the generated resolver.
- All 13 setfiles use normal line endings, `RISK_FIXED=1000`, and
  `RISK_PERCENT=0`; no control bytes were found.
- `validate_build_guardrails.py` returned `PASS`: 14 files checked, zero
  findings, `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak` returned `SINGLE_SYMBOL_OK`.
- `build_gate_hardening.py` returned zero failures and zero warnings, subject
  to the manual informal-universe finding above.
- `validate_spec_doc.py` returned structural `PASS`, subject to finding 4.
- MQ5 SHA-256 matches `build_identity.json`:
  `f34b09783e49b2b84319c15b56ff1d42620bb6ab76a16af21ef9954d5e76b4c7`.
- EX5 SHA-256 matches `build_identity.json`:
  `b466bc58004efef8f721cbc0e19fe40add71bf71605fac7e00a47a23ccba0729`.
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
