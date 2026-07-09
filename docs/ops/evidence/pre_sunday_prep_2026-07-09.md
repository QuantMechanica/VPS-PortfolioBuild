# Pre-Sunday prep briefing — 2026-07-09 (read-only)

## #2 Book readiness (DXZ Sunday 20-sleeve)

- Draft: 20 sleeves; KPIs {"max_drawdown_pct": 0.2455728641, "n_days": 1903, "n_sleeves": 20, "sharpe": 2.8900876181, "total_net_of_cost_profit": 9756.0846597946}
- **Verdict: READY: 20-sleeve additive draft current; no new candidates; all streams present. Deploy-staging + SHA remain the Sunday Claude step.**

## #3 FTMO trial P&L

- Latest pulse: verdict OK, equity 94015.8, total_dd 5.984199999999997%, day -111.79
- Buffer to limits: total 4.016pp (of 10%), daily 4.888pp (of 5%)
- Worst equity seen: {'ts': '2026-07-09T04:19:54Z', 'equity': 93905.79, 'dd_pct': 6.094}
- Fill coverage by class: {'METAL': '1/3', 'INDEX': '3/5', 'ENERGY': '1/1', 'FX': '2/3'}

| EA | symbol | class | fills | last_day_pnl |
|---|---|---|---|---|
| 10286 | USOIL.cash | ENERGY | 2 | -21.99 |
| 10847 | GBPUSD | FX | 2 | -111.79 |
| 12990 | GBPUSD | FX | 0 | 18.3 |
| 11476 | USDJPY | FX | 5 | 53.95 |
| 10911 | GER40.cash | INDEX | 3 | -0.88 |
| 10163 | US100.cash | INDEX | 0 | -10.74 |
| 10440 | US100.cash | INDEX | 1 | -9.83 |
| 10692 | US100.cash | INDEX | 0 | -215.47 |
| 12475 | US100.cash | INDEX | 6 | -3.53 |
| 10700 | XAUUSD | METAL | 0 | -17.16 |
| 10848 | XAUUSD | METAL | 3 | -3.17 |
| 12958 | XAUUSD | METAL | 0 | None |

_Deploy-staging (presets/binaries/SHA) + AutoTrading remain the OWNER+Claude Sunday session._