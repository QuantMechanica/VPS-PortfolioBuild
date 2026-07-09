# QM5_13084_xng-lng-pb - Strategy Spec

**EA ID:** QM5_13084
**Slug:** `xng-lng-pb`
**Source:** `EIA-XNG-LNG-PB-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

The EA trades `XNGUSD.DWX` on D1 in fixed LNG-demand months. On each new D1 bar
it inspects the prior completed bar as a pullback/reclaim signal. The strategy
requires a recent close-confirmed upside channel breakout in the same structural
theme, then waits for the signal bar to pull back toward the slow SMA and close
back above it with a bullish body. It enters long with ATR stop/target and exits
on SMA failure, adverse exit-channel failure, max-hold timeout, target, stop, or
framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for range, pullback band, stop, and target. |
| `strategy_trend_period` | 63 | 50-84 | Slow SMA period. |
| `strategy_sma_slope_shift` | 8 | 5-13 | Bars back for rising-SMA confirmation. |
| `strategy_breakout_lookback` | 42 | 34-55 | Prior channel used by recent breakout memory. |
| `strategy_breakout_memory` | 10 | 6-15 | Completed bars searched for a prior LNG-demand breakout. |
| `strategy_exit_channel` | 13 | 8-21 | Adverse channel-failure exit lookback. |
| `strategy_break_buffer_points` | 20 | 10-40 | Minimum prior breakout close buffer above channel high. |
| `strategy_reclaim_buffer_points` | 10 | 0-25 | Minimum signal close buffer above SMA. |
| `strategy_pullback_band_atr` | 0.45 | 0.25-0.70 | Pullback zone above SMA in ATR units. |
| `strategy_min_signal_range_atr` | 0.45 | 0.30-0.70 | Minimum signal-bar range. |
| `strategy_max_signal_range_atr` | 2.20 | 1.80-2.80 | Maximum signal-bar range. |
| `strategy_min_body_atr` | 0.12 | 0.08-0.20 | Minimum bullish body size. |
| `strategy_atr_sl_mult` | 3.00 | 2.50-3.75 | ATR multiple for hard stop. |
| `strategy_atr_tp_mult` | 3.50 | 2.50-4.50 | ATR multiple for profit target. |
| `strategy_max_hold_days` | 16 | 10-24 | Maximum calendar days to hold. |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Skip entries above this modeled spread. |

---

## 3. Symbol Universe

**Designed for:**

- `XNGUSD.DWX` - natural-gas CFD proxy with local D1 history and EIA LNG export
  demand source exposure.

**Explicitly NOT for:**

- `XTIUSD.DWX` - oil has separate demand/supply mechanics and many existing
  WTI cards.
- `XAUUSD.DWX` and `XAGUSD.DWX` - metals are outside natural-gas LNG source
  lineage.
- Index and FX symbols - outside the commodity/energy sleeve intent.

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
| Typical hold time | 4-16 calendar days |
| Expected drawdown profile | High, natural-gas gaps bounded by ATR stop and Friday close. |
| Regime preference | LNG-demand upside breakouts that pull back without losing the D1 SMA. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `EIA-XNG-LNG-PB-2026`  
**Source type:** official EIA natural-gas reference and LNG export demand analysis  
**Pointer:** `https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php`, `https://www.eia.gov/todayinenergy/detail.php?id=67004`, `https://www.eia.gov/todayinenergy/detail.php?id=67484`, and `https://www.eia.gov/naturalgas/weekly/`  
**R1-R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/xng-lng-pb_card.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV->mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). The committed Q02 setfile uses
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-09 | Initial build from card | Mission-directed XNG LNG export-demand pullback continuation |
