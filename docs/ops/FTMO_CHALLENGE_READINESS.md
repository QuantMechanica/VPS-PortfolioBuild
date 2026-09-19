# FTMO Challenge Readiness (living)

Generated 2026-09-19T09:07:02Z by `tools/strategy_farm/ftmo/challenge_readiness.py`.
OWNER-DEC-CBE-20260915 (directive 2026-09-15 sections 62-63). Read-model: `D:/QM/reports/state/ftmo_challenge_readiness.json`.

This is not one number. Readiness is a multi-axis picture; the paid decision is OWNER-only and cannot be taken by automation.

## Recommendation: **NOT_READY**

a demo cycle realized a >=10% total-loss breach

**Would Fable buy a 100k 2-Step Challenge today?** NO - No. Total-loss breach in a demo cycle: realized max-DD -10.26% vs 10% limit. Recommendation: NOT_READY.

**Strongest current failure mode:** Total-loss breach in a demo cycle: realized max-DD -10.26% vs 10% limit.

## Demo cycle

- Roster under validation: `5432d3db11b02c64a3c5357d94d9f59b425c270e600b87ad65ddf42310771e53` (chart_profile), 6 sleeves
- Cycle start: 2026-09-18T04:50:00Z  ·  validation days: 1.178 (min 14)  ·  state: RUNNING  ·  representative: False
- Material changes this cycle: 0

## Metrics (latest demo cycle)

- Target progress: -1.46%  ·  net: -0.1464%
- Worst daily loss: -0.1808% (limit 5%; worst across cycles -2.3389%)  ·  realized max-DD: -0.2856% (limit 10%; worst across cycles -10.2649%)
- Trade density: 1.125/day over 8 entry days  ·  max losing streak: 3
- Swap: -14.73 USD  ·  commission: -6.29 USD  ·  median holding: 5.056 h

## Fitness

- Overall verdict: **NOT_FIT**  ·  admitted pairs: EVIDENCE_MISSING
- Best FUND_SCORE: 0.4076 vs floor 1.0

## First-passage / breach model

Seeded calendar-aligned block-bootstrap path simulation over the representative intended Demo portfolio (per-sleeve daily-PnL streams scaled to each sleeve's risk), official parameters from the bound rulepack, breaches on a conservative per-trade-MAE intraday-low proxy, no time limit. Read-model: `D:/QM/reports/state/ftmo_first_passage.json` (`tools/strategy_farm/ftmo/first_passage.py`). Not one number:

- P(profit target hit, within horizon): 0.9634  ·  conditional on resolution: 0.9845
- P(daily-loss breach): 0.0  ·  P(max-loss breach): 0.0152  ·  censored (still live at horizon): 0.0214
- P(pass within 30 cal-days): 0.0001  ·  within 60 cal-days: 0.0019  ·  median business days to target: 286.0

Speed, not eventual pass, is the binding constraint on the current book. Full time distribution (p10/p50/p90), cost/slippage sensitivity and conditional failure modes (dominant breach sleeve/symbol/weekday) are in the read-model.

## Rules snapshot

- Source: EVIDENCE_MISSING  ·  fetched: 2026-09-18T02:37:46Z  ·  freshness: 1.27 days (OK)

## How it is computed

- Demo cycle + material-change state machine: `tools/strategy_farm/ftmo/demo_cycle.py` (contract `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md`).
- Account/sleeve metrics from the demo journal: `tools/strategy_farm/ftmo/demo_metrics.py`.
- FTMO fitness (separate from DXZ): `tools/strategy_farm/ftmo/ftmo_fitness.py`, reusing the FUND_SCORE cache and, when present, first-passage outputs.
- First-passage / breach model: `tools/strategy_farm/ftmo/first_passage.py` (read-model `D:/QM/reports/state/ftmo_first_passage.json`, schema `qm.ftmo-first-passage/v1`).
- Rule freshness: `tools/strategy_farm/ftmo/rules_snapshot.py` against `docs/ops/evidence/2026-09-15_ftmo_official_rules_snapshot.json`.

