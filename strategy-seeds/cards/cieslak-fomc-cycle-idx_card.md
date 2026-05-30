---
ea_id: 10260
slug: cieslak-fomc-cycle-idx
strategy_id: QM5_10260
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-26
---

# QM5_10260 Cieslak FOMC-Cycle Even-Week Long (US Index)

## 4. Implementation Details

PARAMETERS
- strategy_atr_period = 14
- strategy_atr_sl_mult = 3.0
- strategy_entry_hour_broker = 0
- strategy_entry_minute = 0
- strategy_exit_hour_broker = 20
- strategy_exit_minute = 30
- strategy_max_cycle_week = 8
- strategy_max_spread_points = 0
- strategy_allow_fomc_hold = false
- qm_news_mode = 3

## Mechanik

### Entry
- **Universe**: 3 US-equity-index CFDs — NDX, WS30 (live-routable on DXZ) and SP500.DWX (backtest-only).
- **Trigger**: open long position at the **Monday session open** of any week whose `cycle_week` is even (0, 2, 4, 6, 8).

### Exit
- **Trigger**: close long position at the **Friday session close** of the same even-cycle week.

### News Compliance (FTMO)
- Mandatory news blackout enforced via `qm_news_mode = 3` (QM_NEWS_FTMO_PAUSE).
- Position holding across FOMC release is disabled (`strategy_allow_fomc_hold = false`).
