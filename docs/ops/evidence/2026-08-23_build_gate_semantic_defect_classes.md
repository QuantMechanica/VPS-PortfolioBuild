# Build-gate semantic defect-class hardening — 2026-08-23

- Router task: `5254b29a-3ec5-463b-acd6-c07fb2e2fd99`
- Lane: Codex / `agents/board-advisor`
- Verdict: **IMPLEMENTED — REVIEW; no compile or pipeline verdict**
- Scope: decide seven recurring review defect classes, automate only safe
  predicates, and prove that the previously invisible QM5_1417 and QM5_1425
  builds are no longer strict-gate clean.

## Mechanizability decision

| Defect class | Decision | Enforced boundary or missing declaration |
|---|---|---|
| Invented inputs / proxies | **Not safely mechanizable from current prose cards** | A source can reuse plausible variable names while fabricating the series. Cards need `required_data_inputs[]` with canonical identifier, source kind, point-in-time/as-of lag, allowed transforms, and explicit proxy policy before absence/substitution can be decided mechanically. |
| Pending-stop versus market entry | **Mechanizable for explicit contracts** | D13 extracts only the card's Entry section or an explicitly labeled entry bullet. A literal BUY-STOP / SELL-STOP or stop-entry OCO contract requires the corresponding executable `QM_*_STOP`, `ORDER_TYPE_*_STOP`, or typed stop call. A market request cannot satisfy it. |
| Inverted directional condition | **Mechanizable for a narrow, proven series shape** | D14 activates only when the card explicitly says SMA rising/falling. For `CopyBuffer(start=1,count=2)` without a series-marked target, index 0 is the older shift 2 and index 1 the newer shift 1; the inverse comparison fails. Explicit `QM_SMA(...,shift=1/2)` scalar comparisons are recognized as satisfying evidence. Unclassified aliases warn rather than fail. |
| Wrong news window / non-entry-only blocking | **Mechanizable for explicit bar windows and literal source configuration** | D15 converts a card's `N` M/H/D bars to minutes, compares it with literal temporal defaults and entry-side `QM_NewsInWindow` calls, and fails an active news return that occurs before management/exit when the card says skip entry. Variable/indirect configurations remain warnings. |
| Restart-unsafe management | **Not safely mechanizable from current prose cards** | Global state alone does not prove a defect: broker SL/TP may be sufficient for one strategy and insufficient for another. Cards need `restart_state_contract[]` naming required state, durable reconstruction source, reconstruction trigger, idempotency invariant, and fail-closed fallback. |
| Unauthorized universe | **Mechanizable for explicit lists** | D17 compares exact current magic/setfile observations with front-matter `target_symbols` or a labeled `Target symbols:` list. It does not infer a universe from narrative R3 prose. Broker aliases are not guessed; for example, a GER40-to-GDAXI reconciliation remains explicit governance work. |
| Deterministic zero-trade ordering | **Mechanizable only for a proof-grade recurrent shape** | D18 follows a strictly descending shift append through a simple by-reference output alias and rejects a later-index `<=` earlier-index guard that is necessarily true. It does not claim general symbolic reachability or classify ordinary zero-trade runs. |

The same decisions are emitted in every JSON report as
`semantic_automation_scope`; D12 and D16 name their missing card declarations
instead of pretending to automate them.

## Implementation

`tools/strategy_farm/build_gate_hardening.py` now contains:

- D13 pending-order card/source matching;
- D14 two-bar SMA direction/order proof;
- D15 literal news-duration and entry-only reachability checks;
- D17 explicit card-universe enforcement layered on the existing D11 matrix
  and registry observations; and
- D18 descending-pivot ordering contradiction detection, including the simple
  by-reference parameter-to-caller alias used by the reviewed build.

The predicates blank comments and quoted literals before source matching where
applicable. They deliberately accept false negatives outside their stated
source shapes instead of turning ambiguous prose or aliases into false build
failures.

`tools/strategy_farm/tests/test_build_gate_hardening.py` adds a passing and a
failing fixture for every automated predicate, plus real-source satisfying
evidence:

- `QM5_20045_london-box`: real two-sided pending-stop OCO, management before
  active central news entry gating, exact two-symbol card/build universe, and
  zero strict analyzer failures;
- `QM5_10000_ff-tasayc-cci-breakout`: real explicit 120/120-minute entry-side
  news call satisfying its two-H1-bar card window;
- `QM5_10418_et-sma5-trend`: real shift-1/shift-2 scalar SMA comparisons
  satisfying both rising and falling directions; and
- `QM5_1417_classical-pennant-continuation-h1`: real descending pivot-array
  production without D18's impossible later-index guard.

## Required regressions now fail

Label-scoped full analyzer results (source, approved card, current magic rows,
setfiles, and canonical symbol matrix) were:

| EA | New strict findings |
|---|---|
| `QM5_1417_classical-pennant-continuation-h1` | 6 findings: missing BUY-STOP and SELL-STOP; inverted rising and falling SMA comparisons; 180/180-minute card window versus 30/30 source; active news return before management. |
| `QM5_1425_classical-triple-bottom-reversal-h4` | 5 findings: missing BUY-STOP; inverted rising SMA comparison; 480/480-minute card window versus 30/30 source; active news return before management; proven descending-append/later-index ordering contradiction. |

The D17 registry gap is also reproduced mechanically:

- QM5_1405: explicit 3-symbol card versus 13 observed symbols; 10 unauthorized
  symbol findings.
- QM5_1407: explicit 8-symbol card versus 13 observed symbols; six unauthorized
  symbol findings, alongside its pending-order and news-window findings.
- QM5_1409: the explicit list is enforced without silently treating GER40.DWX
  as GDAXI.DWX; added symbols and the unresolved alias are surfaced.

## Verification

- `python -m py_compile tools/strategy_farm/build_gate_hardening.py`: PASS.
- Semantic fixture/real-source selection: **9 passed, 18 deselected**.
- Complete bounded hardening suite excluding only the pre-existing all-EA D6
  corpus census: **26 passed, 1 deselected** in 16.06 seconds. This includes the
  PowerShell `build_check.ps1` pass/fail integration fixtures.
- Build-guardrail regression suite: **20 passed** in 1.61 seconds.
- Label-scoped full analyzer: QM5_20045 **0 failures**, exact card/build symbols
  `EURGBP.DWX` and `GBPUSD.DWX`.
- `git diff --check` on both changed Python files: PASS (line-ending warnings
  only).

An attempted run of the pre-existing all-EA D6 census was stopped after 14
minutes while still traversing the repository/setfile corpus; seven preceding
tests had passed, but the census produced no result and is not cited as passing
evidence. D6 logic was not changed. The bounded suite and label-scoped probes
are the focused verification for this task.

No EA, Strategy Card, setfile, registry, resolver, EX5, terminal, backtest,
pipeline state, T_Live file, AutoTrading setting, risk threshold, or news
staleness ceiling was changed. This evidence authorizes REVIEW only.
