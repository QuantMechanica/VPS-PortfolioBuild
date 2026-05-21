# Profitability Track: Event-Cycle Index Risk Premium

Date: 2026-05-21
Status: ACTIVE OPERATING TRACK

## Objective

Find one EA with enough real evidence to reach Q11, then only discuss Q12+ with OWNER/Board context.

The current track is not "more indicators". It is a controlled family of scheduled macro/event-cycle index strategies, led by the FOMC-cycle equity risk-premium thesis.

## Flagship Candidate

| EA | Thesis | Current state | Evidence |
|---|---|---|---|
| `QM5_10260_cieslak-fomc-cycle-idx` | FOMC-cycle exposure, tested broadly across DWX symbols | Q02 priority track across 37 M15 DWX symbols | `docs/research/EDGE_BRIEF_FOMC_CYCLE_2026-05-21.md` |

Why this is the lead:

- Published academic support.
- Deterministic calendar implementation.
- Low degrees of freedom compared with indicator stacks.
- Natural fit for Q08 crisis slices and Q11 news/event replay.

## Promotion Rules

`QM5_10260` may advance only if the normal pipeline gates pass. OWNER decisions, 2026-05-21:

- `QM5_10260` is the active lead and should be prioritized in the queue.
- No deploy-relevance restriction by symbol at this stage.
- Forex, metals, energy, and index symbols are all valid P2 discovery surface.
- Controlled same-family variants are approved if the first implementation fails.
- Q11 must prove the EA is deliberately handling FOMC/news exposure, not accidentally benefiting from unmodeled event risk.
- No Q12 portfolio discussion before a fresh Q08 PASS and Q11 PASS exist.

## Kill / Rework Rules

- Zero trades across the broad P2 cohort means zero-trade recovery, not immediate strategy kill.
- Negative P2 on all symbols with nonzero trades means strategy-fail for the initial implementation, not thesis-fail for the whole family.
- If the initial implementation fails but the event-cycle thesis remains intact, branch into small same-family variants rather than hand-tuning the failed build.

## Variant Queue

Only create variants after the flagship P2 result is known.

1. Broad even-week FOMC cycle, current `QM5_10260`.
2. Decay-aware pre-FOMC drift, post-2015 constrained.
3. Post-FOMC continuation window.
4. FOMC blackout-window carry exposure.
5. Index-strength filter: NDX/WS30 relative momentum.
6. Volatility-regime filter using realized ATR compression/expansion.
7. Crisis-exclusion variant for Q08 sensitivity.
8. Risk-off guard using USD/JPY or gold proxy behavior.
9. Month-end interaction filter.
10. Event-week only, flat outside declared Fed-cycle windows.

Each variant must stay simple enough that a failed test teaches something. No broad parameter mining before P2/P3 proves trade generation and basic expectancy.

## Current Execution

As of 2026-05-21:

- Strategy card/build exists.
- Codex review verdict is `APPROVE_FOR_BACKTEST`.
- Q02 work items are pending across 37 M15 DWX symbols: FX, metals, energy, and indices.
- Work items carry `priority_track=true`, so they are promoted in the pending queue after current active terminal jobs finish.
- T1-T10 are saturated, so the correct immediate action is to let active jobs finish, not manually interrupt terminal processes.

Useful checks:

```powershell
cd C:/QM/repo
python tools/strategy_farm/farmctl.py work-items --ea QM5_10260
python tools/strategy_farm/farmctl.py pipeline | rg -C 8 "QM5_10260|cieslak"
python tools/strategy_farm/farmctl.py health
```

## Operating Decision

This track becomes the primary route toward a profitable EA. General backlog candidates remain useful as factory fill, but decisions and attention should favor candidates with:

- external source support,
- low implementation degrees of freedom,
- clear falsification,
- Q08/Q11 relevance,
- deployable symbols.
