# QM5_41117 WTI monthly late-half dominance — CPU ceiling handoff

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41117_wti-mlatehalf-dom-mom`

Outcome: **SOURCE BUILD COMMITTED; COMPILE WITHHELD; Q01 PENDING; Q02 NOT ENQUEUED**

## Edge delivered

The EA trades `XTIUSD.DWX` on the first tradable D1 bar of a new broker month. It reconstructs the immediately completed month, splits its 17–23 normalized sessions into exhaustive early and late halves, and trades only when the absolute late-half return strictly exceeds the absolute early-half return. Direction follows the late-half return. The position exits at the first later broker month, with a 40-day stale-position repair.

This is a low-frequency structural WTI continuation edge. It is distinct from the certified `QM5_12567` XNG RSI2 oscillator and from existing WTI month-end, weekly, three-block-majority, half-agreement, endpoint-momentum, and 12-month path-efficiency mechanics. Portfolio decorrelation remains a downstream empirical gate; it is not asserted by the card.

## Governance and allocation

- Reputable source: Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, Journal of Financial Economics 104(2), 228–250, DOI `10.1016/j.jfineco.2011.11.003`.
- The source packet explicitly discloses that the paper supports WTI/time-series momentum, but does not test this late-half dominance gate or report WTI-only results.
- Pre-allocation dedup: CLEAN across 4,613 EA-registry rows, 1,285 cards, and 45 Strategy Wiki nodes.
- Post-allocation dedup: only the expected `QM5_41117` self-hits.
- Card: OWNER-authorized `g0_status: APPROVED`; `q01_status: PENDING_BUILD`; `q02_status: NOT_QUEUED`.
- EA ID: `41117`.
- Magic allocation: slot 0, `XTIUSD.DWX`, magic `411170000`.

## Committed work

| Commit | Scope |
|---|---|
| `30a262765` | durable source approval and pre-allocation dedup receipt |
| `7bf802d65` | reproducible source packet and extracted mechanic |
| `ac8cd835a` | deterministic EA-ID reservation |
| `7fba457e9` | approved Strategy Card, G0 decision, and post-allocation receipt |
| `c2b7d5d0e` | governed magic allocation and resolver regeneration |
| `0270fb19c` | EA source, specification, card-of-record, reference tests, and fixed-risk backtest setfile |

## Static verification completed

- Strategy Card schema lint: PASS, with no ML/banned-indicator hits and no missing sections.
- G0 decision lint: PASS.
- Specification validation: PASS.
- Single-symbol scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- Deterministic reference suite: 14 tests PASS, including long/short selection, 17/20/23-session acceptance, 16/24-session rejection, opposed-sign eligibility, strict magnitude handling, odd-month split exhaustiveness, date-label normalization, restart consumption, lifecycle, source markers, and setfile/card locking.
- Backtest setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`; strategy inputs locked; `build_hash=pending` until governed compilation.
- No `.ex5` was produced and no backtest was launched.

## CPU-ceiling stop

Five consecutive whole-host samples were `100%`. Active MetaTrader tester processes were already present across several T terminals. This met the mission's explicit stop condition, so no compilation, Q01 run, backtest dispatch, or Q02 mutation was attempted.

No terminal or tester process was stopped. `T_Live`, AutoTrading, the portfolio gate, and the T_Live manifest were not touched.

## Safe continuation

When governed tester capacity is available below the CPU ceiling:

1. Compile the committed canonical source and record the `.ex5` build hash.
2. Run the governed Q01 build/static checks.
3. If Q01 passes, enqueue exactly one Q02 job using the committed `RISK_FIXED` setfile.
4. Preserve the card's Q02 retirement criterion: fewer than 5 trades/year is a failure.
