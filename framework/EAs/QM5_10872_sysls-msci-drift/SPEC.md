# QM5_10872_sysls-msci-drift - Strategy Spec

**EA ID:** QM5_10872
**Slug:** sysls-msci-drift
**Source:** 66a6c726-c456-5899-be49-561e86612e8a (see `strategy-seeds/sources/66a6c726-c456-5899-be49-561e86612e8a/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA reads a static MSCI rebalance event CSV with `index_name`, `announcement_date`, `effective_date`, `net_add_weight`, `net_delete_weight`, and `region`. On the first D1 tick after an announcement-date bar has closed, it sums mapped event pressure as `net_add_weight - net_delete_weight` for the current chart symbol. It buys the mapped index CFD when net pressure is above the threshold and sells it when net pressure is below the negative threshold. The position uses a 1.5 ATR(20) initial stop and exits on the first D1 tick after ED-1 has closed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_event_csv_path` | `QM5_10872_msci_rebalance_events.csv` | file name/path | Static MSCI rebalance-event CSV. |
| `strategy_net_pressure_pct` | `0.20` | `0.10-0.35` | Minimum absolute net rebalance pressure in percentage points. |
| `strategy_min_trading_days` | `5` | `1-20` | Minimum weekday trading days between announcement and effective date. |
| `strategy_atr_period_d1` | `20` | `10-40` | D1 ATR period for stop sizing. |
| `strategy_atr_stop_mult` | `1.5` | `1.0-2.0` | ATR multiple for the initial stop. |
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
| Typical hold time | `5-15 trading days` |
| Expected drawdown profile | Low-cadence event risk; losses bounded by a 1.5 ATR stop. |
| Regime preference | event-driven flow-pressure drift |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 66a6c726-c456-5899-be49-561e86612e8a
**Source type:** paper / archived X longpost
**Pointer:** https://archive.ph/2025.12.09-211525/https%3A/x.com/systematicls/status/1998452605308252448?s=12
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10872_sysls-msci-drift.md`

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
| v1 | 2026-06-14 | Initial build from card | 03506962-51b2-4a42-be4b-b2715c9c7791 |
