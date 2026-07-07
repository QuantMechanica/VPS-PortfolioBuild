# QM5_13028_xti-prod-brk - Strategy Spec

**EA ID:** QM5_13028
**Slug:** `xti-prod-brk`
**Source:** `EIA-XTI-FIELDPROD-BRK-2026` (see `strategy-seeds/cards/approved/QM5_13028_xti-prod-brk_card.md`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA trades `XTIUSD.DWX` on D1 around the EIA weekly petroleum release
window. On a new D1 bar it inspects the prior completed bar; that bar must be
Wednesday or Thursday, follow a compressed multi-bar range, and close outside a
Donchian channel in the same direction as a slow SMA slope. It enters in the
breakout direction with an ATR stop and target, then exits on SMA failure,
opposite-channel failure, time stop, target, stop, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_event_dow_1` | 3 | 3 | First broker day-of-week accepted as WPSR proxy, Wednesday. |
| `strategy_event_dow_2` | 4 | 4 | Second broker day-of-week accepted as WPSR proxy, Thursday. |
| `strategy_compression_lookback` | 12 | 8-16 | Completed D1 bars used for pre-signal compression. |
| `strategy_entry_channel` | 34 | 21-55 | Donchian breakout lookback, excluding the signal bar. |
| `strategy_exit_channel` | 13 | 8-21 | Opposite-channel exit lookback, excluding latest close. |
| `strategy_trend_period` | 80 | 50-120 | SMA period for trend direction and trend-failure exit. |
| `strategy_sma_slope_shift` | 5 | 3-10 | Bars back for confirming SMA slope. |
| `strategy_atr_period` | 20 | 14-30 | ATR period for compression, stop, and target distance. |
| `strategy_max_compression_atr` | 0.95 | 0.75-1.15 | Maximum multi-bar range in ATR*sqrt(N) units before breakout. |
| `strategy_min_signal_range_atr` | 0.80 | 0.60-1.05 | Minimum signal-bar range in ATR units. |
| `strategy_min_body_ratio` | 0.35 | 0.25-0.50 | Minimum signal-body share of full signal range. |
| `strategy_atr_sl_mult` | 2.75 | 2.25-3.50 | ATR multiple for hard stop. |
| `strategy_atr_tp_mult` | 3.25 | 2.25-4.25 | ATR multiple for profit target. |
| `strategy_max_hold_days` | 8 | 5-12 | Maximum calendar days to hold a position. |
| `strategy_max_spread_points` | 1000 | 700-1500 | Skip entries above this modeled spread. |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - WTI crude CFD proxy with local D1/H4/H1/M15/M5 history and the source's crude-oil field-production exposure.

**Explicitly NOT for:**
- `XNGUSD.DWX` - natural gas has different storage/weather drivers and is already represented by separate XNG sleeves.
- `XAUUSD.DWX` and `XAGUSD.DWX` - metals do not represent EIA crude field-production supply capacity.
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
| Trades / year / symbol | 7 |
| Typical hold time | 3-8 calendar days |
| Expected drawdown profile | Medium-high, crude gaps bounded by ATR hard stop and Friday close. |
| Regime preference | Volatility expansion breakout after release-window compression. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `EIA-XTI-FIELDPROD-BRK-2026`  
**Source type:** official EIA data series and weekly report cadence  
**Pointer:** `https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCRFPUS2` and `https://www.eia.gov/petroleum/supply/weekly/`  
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_13028_xti-prod-brk.md`

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
| v1 | 2026-07-07 | Initial build from card | Mission-directed commodity sleeve build |
