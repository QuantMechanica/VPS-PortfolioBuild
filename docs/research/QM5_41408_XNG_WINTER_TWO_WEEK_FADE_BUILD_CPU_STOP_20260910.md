# QM5_41408 XNG winter two-week fade — build complete, Q02 CPU stop

Recorded: 2026-09-10 Europe/Berlin

## Outcome

`QM5_41408_xng-winter-w2fade` is a new approved and allocated XNG D1
candidate. During November-March it trades opposite the shared strict sign of
the two immediately completed adjacent normalized weeks and exits at the next
week boundary. It is symmetric and calendar-conditioned, with no RSI or slow
trend filter, so it is structurally distinct from certified `QM5_12567`.

Governed compile item `927a738f-3b07-4e6b-bb8d-fd8a22bc9736` completed
`COMPILE_OK` with zero errors, zero warnings, and build check `PASS`. The EX5
SHA-256 is
`0c2a4e941bf81583ae469478eb6002185bdfaf67beba95f41cc8ff02f53af9c9`.

The exact fixed-risk XNG D1 Q02 intake dry run was eligible. The binding CPU
check then sampled `100, 97, 94, 96, 90` percent: average `95.4%`, maximum
`100%`, against an exclusive `97%` ceiling. Q02 apply was not called.

## Build And Guard Evidence

- Source: official EIA natural-gas winter-demand context plus academic
  Yang-Goncu-Pantelous commodity-reversal lineage; the exact weekly
  interaction is an explicitly untested QM translation.
- Dedup: no exact identity; manual review separates same-carrier winter
  continuation, WTI winter fade, disjoint XNG shoulder fade, one-week winter
  momentum, and certified two-day RSI pullback.
- Registry: EA 41408, slot 0, `XNGUSD.DWX`, magic `414080000`.
- PACER audit: exit zero and zero `EA_FRAMEWORK_INPUT_PINNED` hits before the
  compile enqueue. Framework RNG, news, and Friday inputs are not compared;
  stress rejection receives only finite/range validation.
- Reference harness: 15 tests pass.
- Backtest preset: `RISK_FIXED=1000`, `RISK_PERCENT=0`; no live preset.

## Boundary

No Q02 apply, manual backtest, optimization, portfolio-gate edit, portfolio
admission, correlation waiver, deploy/live manifest change, `T_Live`,
AutoTrading, or terminal-control action occurred. A future paced operator may
re-run the CPU check and enqueue the already eligible intake when capacity is
strictly below the ceiling.

