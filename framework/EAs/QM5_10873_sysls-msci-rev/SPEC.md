# QM5_10873_sysls-msci-rev - Strategy Spec

**EA ID:** QM5_10873
**Slug:** sysls-msci-rev
**Source:** 66a6c726-c456-5899-be49-561e86612e8a (see `strategy-seeds/sources/66a6c726-c456-5899-be49-561e86612e8a/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA reads a static MSCI rebalance event CSV with `index_name`, `announcement_date`, `effective_date`, `net_add_weight`, `net_delete_weight`, and `region`. On the first D1 tick after the ED-1 bar has closed, it computes net pressure as `net_add_weight - net_delete_weight` for events whose effective date is the current D1 session and whose region maps to the chart symbol. If pressure is above the threshold and ED-1 return confirms the same direction, it shorts the mapped CFD; if pressure is below the negative threshold and ED-1 return confirms downward pressure, it buys the mapped CFD. The position has a 1.0 ATR(20) stop, a 1.0R target, and is closed after the effective day completes if TP/SL has not already closed it.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_event_csv_path` | `QM5_10872_msci_rebalance_events.csv` | file name/path | Static MSCI rebalance-event CSV shared with QM5_10872. |
| `strategy_net_pressure_pct` | `0.20` | `0.10-0.35` | Minimum absolute net rebalance pressure in percentage points. |
| `strategy_move_atr_frac` | `0.35` | `0.20-0.50` | Required ED-1 return magnitude as a fraction of ATR(20)/close. |
| `strategy_atr_period_d1` | `20` | `10-40` | D1 ATR period for confirmation and stop sizing. |
| `strategy_atr_stop_mult` | `1.0` | `0.8-1.2` | ATR multiple for the initial stop. |
| `strategy_take_profit_r` | `1.0` | `0.8-1.2` | Reward-to-risk target before the ED close. |
| `strategy_max_spread_stop_frac` | `0.10` | `0.01-0.25` | Maximum spread as a fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - DAX proxy for the card's Europe/Germany MSCI event basket; `GER40.DWX` is not in `dwx_symbol_matrix.csv`.
- `NDX.DWX` - US Nasdaq 100 proxy for US and broad developed-market MSCI pressure events.
- `WS30.DWX` - US Dow 30 proxy for US MSCI pressure events.
- `SP500.DWX` - S&P 500 backtest-only proxy explicitly allowed by the current DWX symbol discipline.

**Explicitly NOT for:**
- `GER40.DWX` - card language names it, but the matrix canonical DAX symbol available here is `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; use `SP500.DWX` only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `4` |
| Typical hold time | `1 trading day` |
| Expected drawdown profile | Very low-cadence event risk; losses bounded by 1.0 ATR stop. |
| Regime preference | event-driven mean-revert / flow-exhaustion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 66a6c726-c456-5899-be49-561e86612e8a
**Source type:** paper / archived X longpost
**Pointer:** https://archive.ph/2025.12.09-211525/https%3A/x.com/systematicls/status/1998452605308252448?s=12
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10873_sysls-msci-rev.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-12 | Initial build from card | aaee2060-c58c-4cbc-a420-d843df5831d4 |
