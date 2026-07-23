# QM5_20057 XAU/XAG One-Month Momentum Build And Q02 Enqueue

- Date: 2026-07-23
- Branch: `agents/board-advisor`
- EA: `QM5_20057_xauxag-xmom1`
- Logical symbol: `QM5_20057_XAU_XAG_XMOM1_D1`
- Source: Fuertes, Miffre, and Rallis (2010), *Journal of Banking & Finance* 34(10), 2530-2548.

## Decision

Build one monthly two-leg precious-metals package: rank XAU and XAG by the
immediately completed broker-month return, buy the winner, short the loser,
and renew at the next month boundary. This one-month formation horizon is
source-supported and distinct from the existing twelve-month XAU/XAG rank,
ratio reversion, ratio breakout, return-spread reversion, and conditional
quantile/threshold baskets. Neutrality and book correlation remain claims for
later deterministic gates, not assumptions.

## Validation

- Strategy-card schema lint: PASS, with no missing sections or ML hits.
- EA ID `20057`; active magic rows `200570000` (XAU slot 0) and `200570001`
  (XAG slot 1); resolver regenerated after directory and registry creation.
- Strict compile: PASS, 0 errors and 0 warnings.
- Compiled EX5 SHA256:
  `88E5F745B9168C9946D31D813E1FC493495DFEE8B1805EC99416C45E66E9D910`.
- Backtest setfile SHA256:
  `02CD9F94B5B2EBB01BEFCEB184700C0094AE88A3076F90C57374CA92FC5B583E`.
- Setfile is `RISK_FIXED=1000`, `RISK_PERCENT=0`; no live setfile exists.
- Review was explicitly marked `SELF_REVIEW` for later Codex spot-check.
- Q02 task: `524f2762-aac1-4127-bd95-5ff0bf2828f4`.
- Q02 work item: `96c14d4d-0a62-4935-85ec-dd75f570aafa`, one logical basket,
  priority track, pending and not manually dispatched.

No backtest was started in this session. No T_Live, AutoTrading, live setfile,
deploy manifest, portfolio gate, portfolio KPI, or T_Live manifest was touched.
