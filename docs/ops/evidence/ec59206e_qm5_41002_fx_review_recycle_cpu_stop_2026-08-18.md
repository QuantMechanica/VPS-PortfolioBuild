# QM5_41002 FX mechanical review — recycle and CPU stop

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `CODE REVIEW FAIL / RECYCLE; Q02 NOT ENQUEUED — HARD CPU CEILING`

## Selection

The committed sign-aware reconciliation at `a80493291` covers every
relationship in the frozen 66-pair FX cointegration scan, so creating another
pair Card or EA would duplicate governed work. The two preferred anchors are
already beyond Q02: `QM5_12532` has Q02 PASS followed by Q04 PASS and Q05
FAIL; `QM5_12533` has Q02 PASS followed by Q04 FAIL.

Per the mission fallback, this review advanced the existing low-frequency H4
forex card `QM5_41002_robert-pardo-checkmate-breakout-engine`. The approved
Card, source claim, strategy parameters, EA source, binary, registry rows, and
fixed-risk setfiles were not changed.

## Mechanical review finding

Severity: `HIGH` (entry-permission contract; deterministic startup path)

The approved Card requires the strategy to remain inactive whenever current
spread exceeds `1.8 * ATR(14)[1]`. The implementation does not enforce that
condition on its first post-initialization signal:

- `g_state_ready` starts `false`.
- `Strategy_NoTradeFilter()` applies the spread comparison only when
  `g_state_ready` is already true (source line 215 at the reviewed hash).
- `OnTick()` calls that filter before the new-bar gate, then calls
  `AdvanceState_OnNewBar()` at line 416 and immediately evaluates
  `Strategy_EntrySignal()` at line 421.
- The freshly populated ATR and signal are therefore allowed to open a trade
  without another current-spread comparison. On later bars the pre-refresh
  filter also compares spread with the preceding cached ATR rather than the
  ATR used by the new signal.

A first H4 signal after EA attachment can consequently enter during a spread
wider than the Card-authorized ceiling. This is not an economic parameter
change or an optimization question; it is a mechanical Card-to-code mismatch.

Required repair: enforce the current `ask - bid <= g_atr_1 *
strategy_spread_filter_mult` predicate inside `Strategy_EntrySignal()` after
the current bar cache is ready, or refresh state and re-run the no-trade gate
before entry. Preserve the existing fixed-risk presets and recompile before a
new review.

Reviewed artifact bindings:

- MQ5 SHA-256:
  `8D886C0564BF1FE620C853F982E292F198CE5EC1F241B3F75500C4D724D84CA3`
- EX5 SHA-256:
  `6A8B189114F2770C8B248BF42FB9BC18A5522CB04BE62ED421DAE3FA2E184B30`
- Reviewed repository HEAD:
  `bd672a5c204edc450911b079c222492fb84007ac`
- Structured review:
  `artifacts/reviews/ec59206e-c92e-44ce-96e0-89f52d539ca1.json`

The governed build task `5d5cc9f6-e096-44a3-af78-99abc2d9e7ed` is returned
to `RECYCLE` with verdict
`FAIL_CODE_REVIEW_SPREAD_GATE_FIRST_SIGNAL_BYPASS`, keeping the review-entry
gate fail-closed.

## Binding CPU stop

At approximately `2026-08-18T05:50:43Z`, five consecutive two-second
whole-machine CPU samples were `100.00%`, `99.66%`, `99.32%`, `95.85%`, and
`96.46%` (average `98.26%`, maximum `100.00%`). The governed admission ceiling
is `97%`.

The supported path-aware operator census found eight occupied factory
terminals: `T1`, `T2`, `T3`, `T4`, `T5`, `T7`, `T8`, and `T9`. `T_Live` and
the unrelated FTMO terminal were observed only so they could be excluded;
neither was controlled. `farmctl work-items --ea QM5_41002` returned zero
rows before this review.

Per the explicit resource stop, no Q02 enqueue, dispatcher tick, smoke test,
backtest, tester launch, terminal reservation, terminal control, or priority
mutation followed.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution path changed.
- No `T_Live` manifest or terminal, AutoTrading state, deploy artifact, or
  live artifact changed.
- Concurrent unrelated staged, modified, and untracked work was left
  untouched.

