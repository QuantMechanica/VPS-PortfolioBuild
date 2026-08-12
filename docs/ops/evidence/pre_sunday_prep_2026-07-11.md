# Pre-Sunday prep briefing — 2026-07-11 (read-only)

## #2 Book readiness (DXZ Sunday 20-sleeve)

- Draft: 20 sleeves; KPIs {"max_drawdown_pct": 0.2455728641, "n_days": 1903, "n_sleeves": 20, "sharpe": 2.8900876181, "total_net_of_cost_profit": 9756.0846597946}
- **Verdict: RECOMPUTE_REVIEW: 1 new Q12 candidate(s) since draft — a human/Claude must decide admission (check rework flag) and recompute weights.**
- New Q12 candidates since draft:
    - QM5_13128 / NDX.DWX (2026-07-11)  — verify rework flag before admitting

## #3 FTMO trial P&L

- Latest pulse: verdict WARN, equity 94241.75, total_dd 5.75825%, day 225.95
- Buffer to limits: total 4.242pp (of 10%), daily 5.0pp (of 5%)
- Paid Challenge: **NO_GO_NO_STRICTLY_QUALIFIED_EAS**; qualification {'counts': {'NOT_QUALIFIED': 108, 'RESEARCH_LEAD': 1}, 'challenge_ready_count': 0, 'research_leads': [{'ea_id': 'QM5_13013', 'symbol': 'NDX.DWX', 'blockers': ['q08_not_pass:FAIL_SOFT', 'q10_pass_missing']}]}
- Logged server-request lower bound: 8 on 2026-07-10
- Equity snapshot age: 1489.9066321 minutes
- Kill-switch rollout proof: day-anchor 0/12, book-tag 0/12
- Worst equity seen: {'ts': '2026-07-09T04:19:54Z', 'equity': 93905.79, 'dd_pct': 6.094}
- Fill coverage by class: {'METAL': '1/3', 'INDEX': '5/5', 'ENERGY': '1/1', 'FX': '2/3'}

| EA | symbol | class | fills | account_day_pnl_at_last_tick |
|---|---|---|---|---|
| 10286 | USOIL.cash | ENERGY | 2 | 508.59 |
| 10847 | GBPUSD | FX | 2 | 225.95 |
| 12990 | GBPUSD | FX | 0 | 433.86 |
| 11476 | USDJPY | FX | 6 | 390.52 |
| 10911 | GER40.cash | INDEX | 3 | 488.6 |
| 10163 | US100.cash | INDEX | 1 | 485.63 |
| 10440 | US100.cash | INDEX | 2 | 485.63 |
| 10692 | US100.cash | INDEX | 2 | 676.6 |
| 12475 | US100.cash | INDEX | 6 | 485.63 |
| 10700 | XAUUSD | METAL | 0 | 515.68 |
| 10848 | XAUUSD | METAL | 3 | 515.68 |
| 12958 | XAUUSD | METAL | 0 | None |

_The per-EA snapshot column is account-wide and is not EA-level PnL attribution._

_Deploy-staging (presets/binaries/SHA) + AutoTrading remain the OWNER+Claude Sunday session._