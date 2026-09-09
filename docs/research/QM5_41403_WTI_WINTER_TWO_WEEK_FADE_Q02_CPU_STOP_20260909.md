# QM5_41403 WTI winter two-week fade — Q02 CPU stop

Recorded: 2026-09-09T19:52:37.6309157Z (21:52 Europe/Berlin)

## Outcome

`QM5_41403_wti-winter-w2fade` is a new approved, allocated, compiled WTI
candidate. Its governed compile work item
`9e86e4c6-04ad-47d2-abe2-ef9601fda53b` finished `COMPILE_OK` with zero errors,
zero warnings, and strict build check `PASS`. The EX5 SHA-256 is
`b5bd89bb111a7f05b0409179b5135fb90ef4726508f939b26cce4a316df45f27`.

Q02 was not enqueued. The first intake dry-run exposed an empty regenerated
`strategy_symbol`; the canonical setfile was repaired and committed as
`f62956bc8a`. Before retrying intake, the required five-sample host CPU window
was `90, 93, 91, 97, 91` percent. Its average was 92.4%, but its maximum was
exactly 97%, which fails the strict requirement that both statistics remain
below 97%. Nine terminal/tester processes were observed immediately after the
window. The mission therefore stopped before another intake command.

## Build And Guard Evidence

- Card/source: reputable WTI November-May seasonality plus commodity-reversal
  lineage, with the weekly interaction explicitly marked as an untested QM
  translation.
- Dedup: no exact identity; expected fuzzy XNG relatives were manually
  separated by carrier, season, and direction. The WTI 252-D1 counterfade,
  monthly reversal, and split-week continuation also use different
  information objects or lifecycles.
- Registry: EA 41403, slot 0, `XTIUSD.DWX`, magic `414030000`.
- PACER input-pin audit: exit zero, `EA_FRAMEWORK_INPUT_PINNED` hit count zero,
  run before compile enqueue.
- Reference harness: 14 tests PASS.
- Governed compile: `COMPILE_OK`; build check PASS; no ad-hoc compile.

## Resume Condition

On a later paced wake, repeat the five-sample CPU window. Only if both average
and maximum are strictly below 97% may the exact compiled candidate be passed
to:

```powershell
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id 9e86e4c6-04ad-47d2-abe2-ef9601fda53b --apply
```

No manual backtest, live/demo/shadow setfile, terminal control, portfolio-gate
edit, portfolio admission, correlation waiver, deploy/live manifest change,
`T_Live`, or AutoTrading action occurred.

