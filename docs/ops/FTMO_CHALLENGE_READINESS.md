# FTMO Challenge Readiness (living)

Generated 2026-09-15T15:32:47Z by `tools/strategy_farm/ftmo/challenge_readiness.py`.
OWNER-DEC-CBE-20260915 (directive 2026-09-15 sections 62-63). Read-model: `D:/QM/reports/state/ftmo_challenge_readiness.json`.

This is not one number. Readiness is a multi-axis picture; the paid decision is OWNER-only and cannot be taken by automation.

## Recommendation: **NOT_READY**

a demo cycle realized a >=10% total-loss breach

**Would Fable buy a 100k 2-Step Challenge today?** NO - No. Total-loss breach in a demo cycle: realized max-DD -10.26% vs 10% limit. Recommendation: NOT_READY.

**Strongest current failure mode:** Total-loss breach in a demo cycle: realized max-DD -10.26% vs 10% limit.

## Demo cycle

- Roster under validation: `6c5383d8777728ba17abd1a836858b9db87c306d2931445ac642762075ac9bf2` (chart_profile), 8 sleeves
- Cycle start: 2026-09-15T14:12:11Z  ·  validation days: 0.023 (min 14)  ·  state: RUNNING  ·  representative: False
- Material changes this cycle: 0

## Metrics (latest demo cycle)

- Target progress: -1.46%  ·  net: -0.1464%
- Worst daily loss: -0.1808% (limit 5%; worst across cycles -2.3389%)  ·  realized max-DD: -0.2856% (limit 10%; worst across cycles -10.2649%)
- Trade density: 1.125/day over 8 entry days  ·  max losing streak: 3
- Swap: -14.73 USD  ·  commission: -6.29 USD  ·  median holding: 5.056 h

## Fitness

- Overall verdict: **NOT_FIT**  ·  admitted pairs: EVIDENCE_MISSING
- Best FUND_SCORE: 0.4076 vs floor 1.0

## Rules snapshot

- Source: https://ftmo.com/en/trading-objectives/  ·  fetched: 2026-09-15T13:59:31Z  ·  freshness: 0.065 days (OK)

## How it is computed

- Demo cycle + material-change state machine: `tools/strategy_farm/ftmo/demo_cycle.py` (contract `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md`).
- Account/sleeve metrics from the demo journal: `tools/strategy_farm/ftmo/demo_metrics.py`.
- FTMO fitness (separate from DXZ): `tools/strategy_farm/ftmo/ftmo_fitness.py`, reusing the FUND_SCORE cache and, when present, first-passage outputs.
- Rule freshness: `tools/strategy_farm/ftmo/rules_snapshot.py` against `docs/ops/evidence/2026-09-15_ftmo_official_rules_snapshot.json`.

