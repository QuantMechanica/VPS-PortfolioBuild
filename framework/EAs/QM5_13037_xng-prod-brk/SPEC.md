# QM5_13037_xng-prod-brk - Strategy Spec

**EA ID:** QM5_13037
**Slug:** `xng-prod-brk`
**Source:** `EIA-XNG-DRYPROD-BRK-2026` (see `strategy-seeds/cards/approved/QM5_13037_xng-prod-brk_card.md`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA trades `XNGUSD.DWX` on D1 around the EIA monthly dry natural gas
production release window. On a new D1 bar it inspects the prior completed
bar; that bar must be a late-month production-window bar, follow a compressed
multi-bar range, and close outside a Donchian channel in the same direction as
a slow SMA slope. It enters in the breakout direction with an ATR stop and
target, then exits on SMA failure, opposite-channel failure, time stop, target,
stop, or framework Friday close. Entries are limited to one per calendar month.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_event_day_min` | 25 | 24-27 | First day-of-month accepted as dry-production update window. |
| `strategy_event_day_max` | 31 | 29-31 | Last day-of-month accepted as dry-production update window. |
| `strategy_compression_lookback` | 12 | 8-16 | Completed D1 bars used for pre-signal compression. |
| `strategy_entry_channel` | 34 | 21-55 | Donchian breakout lookback, excluding the signal bar. |
| `strategy_exit_channel` | 13 | 8-21 | Opposite-channel exit lookback, excluding latest close. |
| `strategy_trend_period` | 80 | 50-120 | SMA period for trend direction and trend-failure exit. |
| `strategy_sma_slope_shift` | 5 | 3-10 | Bars back for confirming SMA slope. |
| `strategy_atr_period` | 20 | 14-30 | ATR period for compression, stop, and target distance. |
| `strategy_max_compression_atr` | 1.05 | 0.80-1.30 | Maximum multi-bar range in ATR*sqrt(N) units before breakout. |
| `strategy_min_signal_range_atr` | 0.80 | 0.60-1.10 | Minimum signal-bar range in ATR units. |
| `strategy_min_body_ratio` | 0.30 | 0.20-0.50 | Minimum signal-body share of full signal range. |
| `strategy_atr_sl_mult` | 3.25 | 2.50-4.25 | ATR multiple for hard stop. |
| `strategy_atr_tp_mult` | 4.00 | 3.00-5.50 | ATR multiple for profit target. |
| `strategy_max_hold_days` | 10 | 6-15 | Maximum calendar days to hold a position. |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Skip entries above this modeled spread. |

---

## 3. Symbol Universe

**Designed for:**
- `XNGUSD.DWX` - natural gas CFD proxy with local D1 history and source
  lineage tied to official U.S. dry natural gas production.

**Explicitly NOT for:**
- `XTIUSD.DWX` - crude oil has separate field-production, product-supplied,
  storage, refinery, roll, and calendar sleeves.
- `XAUUSD.DWX` and `XAGUSD.DWX` - metals do not represent natural gas supply.
- Index CFDs - equity-index exposure is outside the source lineage.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 6 |
| Typical hold time | 4-10 calendar days |
| Expected drawdown profile | Medium-high, natural-gas gaps bounded by ATR hard stop and Friday close. |
| Regime preference | Volatility expansion breakout after late-month supply-window compression. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `EIA-XNG-DRYPROD-BRK-2026`  
**Source type:** official EIA natural gas monthly report and dry production data  
**Pointer:** `https://www.eia.gov/naturalgas/monthly/`,
`https://www.eia.gov/naturalgas/data.php`, and
`https://www.eia.gov/dnav/ng/ng_prod_sum_a_epg0_fpd_mmcf_a.htm`  
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_13037_xng-prod-brk.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-07 | Initial build from card | Mission-directed commodity/energy sleeve build |
