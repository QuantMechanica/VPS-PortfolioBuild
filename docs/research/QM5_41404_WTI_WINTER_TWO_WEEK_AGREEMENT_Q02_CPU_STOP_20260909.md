# QM5_41404 WTI winter two-week agreement — Q02 CPU stop

Recorded: 2026-09-09T20:56:18.3745671Z (22:56 Europe/Berlin)

## Outcome

`QM5_41404_wti-winter-w2agree` is a new approved, allocated, compiled WTI
candidate. Its governed compile work item
`30a605d5-e996-4729-b67b-03e7b8d53871` finished `COMPILE_OK` with zero errors,
zero warnings, and strict build check `PASS`. The EX5 SHA-256 is
`f0ac2e3e4f40a1b85ab3fb95085216d4fc166357edb9c1b462eb9accf88f8fa7`.

Q02 was not enqueued. The required five-sample host CPU window was
`97, 55, 63, 72, 91` percent. Its average was 75.6%, but its maximum was
exactly 97%, which fails the strict requirement that both statistics remain
below 97%. Six terminal/tester processes were observed immediately after the
window. The mission therefore stopped before calling Q02 intake.

## Build And Guard Evidence

- Card/source: reputable peer-reviewed WTI November-May seasonality and
  commodity own-return continuation lineages, with the two-week interaction
  explicitly marked as an untested QM translation.
- Dedup: no exact identity; expected fuzzy relatives were manually separated
  by carrier, seasonal window, signal orientation, and lifecycle. The closest
  WTI winter sibling fades two-week agreement; this candidate follows it.
- Registry: EA 41404, slot 0, `XTIUSD.DWX`, magic `414040000`.
- PACER input-pin audit: exit zero, `EA_FRAMEWORK_INPUT_PINNED` hit count zero,
  run before compile enqueue.
- Reference harness: 14 tests PASS.
- Governed compile: `COMPILE_OK`; build check PASS; no ad-hoc compile.

## Resume Condition

On a later paced wake, repeat the five-sample CPU window. Only if both average
and maximum are strictly below 97% may the exact compiled candidate be passed
to:

```powershell
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id 30a605d5-e996-4729-b67b-03e7b8d53871 --apply
```

No manual backtest, live/demo/shadow setfile, terminal control, portfolio-gate
edit, portfolio admission, correlation waiver, deploy/live manifest change,
`T_Live`, or AutoTrading action occurred.
