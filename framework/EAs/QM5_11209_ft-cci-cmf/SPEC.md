# QM5_11209_ft-cci-cmf - Strategy Spec

**EA ID:** QM5_11209
**Slug:** `ft-cci-cmf`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long-only M1 mean reversion. It enters when both CCI(170) and CCI(34) are below -100, CMF(20) is below -0.10, MFI(14) is below 25, and the M5 resampled SMA gate has SMA(50) above SMA(25) with price above SMA(200). It exits when both CCIs are above 100, CMF(20) is above 0.30, and the M5 SMA stack reverses with SMA(100) below SMA(50) and SMA(50) below SMA(25). Initial protection uses ATR(14) times 1.5 with the source 2% stoploss as a hard cap, and the source immediate 10% ROI target is set as the take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_cci_slow_period` | 170 | 100-200 | Slow CCI period used in entry and exit thresholds. |
| `strategy_cci_fast_period` | 34 | 21-55 | Fast CCI period used in entry and exit thresholds. |
| `strategy_mfi_period` | 14 | 1+ | MFI lookback using MT5 tick volume as the Freqtrade volume proxy. |
| `strategy_mfi_entry` | 25.0 | 20-30 | Maximum MFI value allowed for oversold entry. |
| `strategy_cmf_period` | 20 | 1+ | Chaikin Money Flow lookback using MT5 tick volume. |
| `strategy_cmf_entry` | -0.10 | -0.20-0.00 | Maximum CMF value allowed for entry. |
| `strategy_cmf_exit` | 0.30 | fixed | Minimum CMF value required for source signal exit. |
| `strategy_m5_sma_fast_period` | 25 | fixed | Fast M5 resampled SMA gate. |
| `strategy_m5_sma_mid_period` | 50 | fixed | Mid M5 resampled SMA gate. |
| `strategy_m5_sma_exit_period` | 100 | fixed | Exit M5 resampled SMA gate. |
| `strategy_m5_sma_slow_period` | 200 | fixed | Slow M5 resampled SMA gate. |
| `strategy_atr_period` | 14 | fixed | ATR period for MT5 baseline stop. |
| `strategy_atr_stop_mult` | 1.50 | 1.0-2.0 | ATR multiplier for MT5 baseline stop. |
| `strategy_source_stop_pct` | 2.00 | fixed | Source -2% stoploss cap. |
| `strategy_roi_target_pct` | 10.00 | fixed | Source immediate ROI target. |
| `strategy_max_spread_stop_pct` | 6.00 | fixed | Maximum spread as percent of planned stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 primary P2 forex basket member with DWX tick/OHLC coverage.
- `GBPUSD.DWX` - Card R3 primary P2 forex basket member with DWX tick/OHLC coverage.
- `USDJPY.DWX` - Card R3 primary P2 forex basket member with DWX tick/OHLC coverage.
- `XAUUSD.DWX` - Card R3 primary P2 metals basket member with DWX tick/OHLC coverage.

**Explicitly NOT for:**
- Non-DWX symbols - Build and P2 registration require canonical `.DWX` symbols from `dwx_symbol_matrix.csv`.
- Equity or crypto spot symbols - The card was approved only for the listed DWX forex/metals basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | `M5` resampled SMA(25), SMA(50), SMA(100), SMA(200) via `PERIOD_M5` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `160` |
| Typical hold time | M1 scalping / intraday holds |
| Expected drawdown profile | High risk due M1 mean reversion and volume-proxy dependence |
| Regime preference | Mean-revert oversold reversals with money-flow confirmation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** GitHub strategy source
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/CCIStrategy.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11209_ft-cci-cmf.md`

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
| v1 | 2026-06-08 | Initial build from card | 254b5511-3e07-4913-b954-4c1f267dafe8 |
