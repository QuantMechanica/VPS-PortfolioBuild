# QM5_41392 XNG shoulder reversal — build complete / Q02 CPU stop

Date: 2026-09-09 (`2026-09-09T06:42:17.878998+00:00`)

Branch: `agents/board-advisor`

Status: a new low-frequency structural XNG shoulder-month weekly reversal was
carded, allocated, implemented, tested, and compiled. Q02 was not enqueued
because the binding whole-host CPU ceiling was reached in the final admission
window.

## Edge and non-duplicate boundary

`QM5_41392_xng-shoulder-wrev` trades only April, May, September, and October.
At the first eligible D1 bar of a new normalized broker week it fades the sign
of the immediately completed adjacent three-to-five-session week's
open-to-close log return, makes one attempt per week, and exits at the next
normalized week. The frozen hard stop is `3.5 * ATR(20)` and the expected
cadence is approximately 16–18 completed packages per year before gates.

This is mechanically distinct from the existing cumulative-RSI plus slow-trend
XNG strategy and the existing all-year five-day-return/high-volatility-rank XNG
strategy. That is a design-level diversity claim only; realized correlation
remains for governed backtest evidence.

Canonical repository and Strategy Wiki dedup returned CLEAN before allocation:
4,872 registry rows, 1,485 cards, and 45 Wiki nodes scanned. The source packet
uses locally preserved official U.S. Energy Information Administration
seasonal-demand context and explicitly separates that context from the bounded
weekly-reversal mechanization.

## Build result

The PACER source audit ran after generation and before compile enqueue and
returned `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`, and
an empty findings list. The single-symbol validator and build guardrails passed,
the spec validated, and all 13 deterministic reference tests passed.

Governed compile work item
`77c729b5-2928-4a8e-a106-540724f73210` finished `done/COMPILE_OK` on T2. The
compiler produced zero errors and zero warnings. The source hash is
`3fa2b36b4504bf74b906c8f40efe7b4f0376a0d57a12327281893da65bfd6558`
and the EX5 hash is
`d8e2d537ce6c448b4644c4c1edc3b22c37e585aa33fe142bedc605da3279d820`.
The fixed-risk Q02 setfile binds `strategy_symbol=XNGUSD.DWX`,
`RISK_FIXED=1000`, and `RISK_PERCENT=0`.

## Q02 admission and binding stop

The canonical dry run was:

```text
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id 77c729b5-2928-4a8e-a106-540724f73210
```

It returned `eligible=true`, `would_enqueue=true`, reason `ELIGIBLE`, one
`XNGUSD.DWX` D1 canary, active magic `413920000`, and setfile hash
`bbd60a4f7b0302d9041721bce23f5df28c36491ed14e48a6d9c5974bdac53053`.

The final five one-second CPU samples were `97.7%`, `96.9%`, `94.9%`, `98.8%`,
and `89.9%` (average `95.64%`, maximum `98.8%`). Admission requires both the
average and maximum to be strictly below `97%`, so the maximum refused the
mutation. No `--apply`, dispatch, or manual tester command ran. Readback shows
one compile row and zero Q02 rows for `QM5_41392`.

Machine-readable evidence is in
`artifacts/qm5_41392_q02_cpu_ceiling_stop_20260909T064217Z.json`.

## Safety boundary and continuation

No portfolio gate, portfolio-admission state, deploy/live manifest, `T_Live`
surface, AutoTrading control, or manual MT5 tester surface was touched.

On a later paced wake, repeat the zero-Q02 collision check, canonical dry run,
and a fresh five-sample CPU gate. Apply exactly one first-Q02 canary only when
both average and maximum remain strictly below 97%.
