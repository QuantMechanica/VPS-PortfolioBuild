# QM5_41407 WTI summer two-week fade — Q02 CPU stop

Recorded: 2026-09-10 02:26 Europe/Berlin

## Outcome

`QM5_41407_wti-summer-w2fade` is a new approved, allocated, compiled WTI D1
candidate. It trades only June-October Monday-anchored weeks and fades the
common direction of the two immediately completed adjacent weeks. This is
mechanically opposite to the incumbent summer continuation, seasonally
disjoint from the winter fade, and structurally distinct from RSI/XNG sleeves.

Governed compile item `4810479a-091e-4c02-b778-2578b06d7f3d` finished
`COMPILE_OK` with zero errors, zero warnings, and build check `PASS`. The EX5
SHA-256 is
`f61d8c8fec5df03b70396238c72b8af17087538dd56eacedfc77445adfcfbd23`.

Q02 was not enqueued. The first intake dry-run exposed an empty regenerated
`strategy_symbol`; restoring the card-locked `XTIUSD.DWX` value made the exact
fixed-risk intake dry-run eligible. Immediately before apply, however, the
five-sample host CPU window measured `96, 97, 99, 100, 97` percent (average
97.8%, maximum 100%). This violates the strict below-97% admission ceiling, so
the apply command was skipped and the mission stopped.

## Build And Guard Evidence

- Source/card: peer-reviewed WTI May-October seasonality plus academic
  commodity-reversal context; the two-week interaction is explicitly an
  untested QM translation.
- Dedup: no exact identity; the high-similarity summer continuation is the
  opposite trade orientation, while the winter fade is calendar-disjoint.
- Registry: EA 41407, slot 0, `XTIUSD.DWX`, magic `414070000`.
- PACER audit: exit zero and zero `EA_FRAMEWORK_INPUT_PINNED` hits immediately
  before compile enqueue. RNG, news, and Friday inputs are not compared;
  stress rejection receives only finite/range validation.
- Reference harness: 15 tests pass.
- Preset: `RISK_FIXED=1000`, `RISK_PERCENT=0`; no live preset.

The first compile row `e6e8338b-5f2d-4abc-9e74-c01549917015` was refused at
candidate recheck because the precompile set had been restored too early. It
remains immutable. A real source hardening added finite checks for the two
floating-point strategy pins, after which the append-only governed successor
above compiled successfully.

## Resume Condition

On a later paced wake, repeat the five-sample CPU window. Only if both average
and maximum are strictly below 97% may the exact compiled candidate be passed
to:

```powershell
python tools/strategy_farm/farmctl.py intake-first-q02 --compile-work-item-id 4810479a-091e-4c02-b778-2578b06d7f3d --apply
```

No manual backtest, optimization, portfolio-gate edit, portfolio admission,
correlation waiver, deploy/live manifest change, `T_Live`, AutoTrading, or
terminal-control action occurred.
