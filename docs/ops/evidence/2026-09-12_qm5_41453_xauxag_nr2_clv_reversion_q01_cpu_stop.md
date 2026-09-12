# QM5_41453 XAU/XAG NR2 CLV Reversion - Q01 PASS / Q02 CPU Stop

Date: 2026-09-12

The new market-neutral commodity sleeve identity is `QM5_41453_xauxag-nr2-clv-rv`. It trades
only a synchronized XAU/XAG equal-notional basket after a strict two-week log-ratio range
contraction and a strict outer-quartile close, fading the relative settlement extreme for one
week. It is distinct from the adjacent WR2/CLV fade, NR2/body fade, NR2/CLV continuation, and
WR2/CLV continuation identities.

## Deterministic Gates

- Card schema/ML lint: PASS.
- PACER input-pin audit before compile enqueue: PASS, `EA_FRAMEWORK_INPUT_PINNED` hit count zero.
- Reference suite: 6 tests and 9 subtests PASS.
- Governed compile work item: `b1113f37-0d43-41da-9cc1-3e964e12100e` on T3.
- Compiler: PASS, zero errors and zero warnings.
- Strict build check: PASS, zero failures and three non-gating undecidable optional-card warnings.
- MQ5 SHA-256: `c80ecf1cb3c1deca8ec28548b25ccab20b6c8765154a658992ac5c4026338d08`.
- EX5 SHA-256: `5351c74f3b89c6759d0af8c2959920b616f89cfbc9b6d9b89c6f1b457d030a99`.

## Q02 Stop

The mandatory whole-host CPU sample was `99.1, 93.1, 96.4, 98.8, 97.8%`: average `97.04%`,
maximum `99.1%`, above the `97%` ceiling. Q02 therefore stopped without an apply call or work-item
creation.

The read-only intake probe also reported empty `strategy_host_symbol` and
`strategy_companion_symbol` in the compile-regenerated per-leg presets. Those values were
restored to the card lock (`XAUUSD.DWX` / `XAGUSD.DWX`), but the intake probe was not retried after
the CPU stop. A later paced operator must re-run the read-only admission check under fresh CPU
headroom before any Q02 enqueue.

No manual backtest, terminal control, portfolio-gate edit, `T_Live`, deploy/live manifest,
AutoTrading, or live action occurred.
