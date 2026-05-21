# Q11 Portfolio Target 2026-05-21

Status: CURRENT TARGET

Operational target:

- Reach at least 5 distinct Q11/P8 PASS EAs.
- Prefer multiple robust symbols per EA.
- Avoid counting same-edge variants as independent portfolio slots.
- Q12 starts only after real Q11 PASS evidence exists.

Q12 review must analyze:

- symbol-level Q11 evidence,
- Q08 crisis behavior,
- drawdown overlap,
- correlation/regime concentration,
- whether the EA is a true independent return source or just a parameter/symbol variant.

Automation:

- `python tools/strategy_farm/agent_router.py sync-q11-candidates` mirrors Q11/P8 PASS work items into `portfolio_candidates`.
- Cockpit shows `Q12 queue` with target 5 EAs.
- Current sync on 2026-05-21 found `0` Q11/P8 PASS rows.
