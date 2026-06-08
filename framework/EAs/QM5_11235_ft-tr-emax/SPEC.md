# QM5_11235_ft-tr-emax - Strategy Spec

**EA ID:** QM5_11235
**Slug:** `ft-tr-emax`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long on H1 when EMA(9) crosses above EMA(16), RSI(16) is above 40 and below 75, the last closed bar closes above EMA(200), and tick volume is positive with current closed-bar volume greater than 0.5 times EMA(20) of tick volume. It exits when RSI(16) exceeds 78, when EMA(9) crosses below EMA(16) with negative MACD histogram and RSI above 50, when price crosses below EMA(200) thresholds from the card, or when the card's time and loss rules trigger. The initial stop is the tighter of a 6 percent source stop and 3.0 ATR(14), and the source trailing stop activates after 5 percent profit with a 3 percent trail.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H1` | H1 only | Source timeframe for all strategy calculations. |
| `strategy_ema_fast` | 9 | 2-100 | Fast EMA used for entry and exit crosses. |
| `strategy_ema_slow` | 16 | 2-150 | Slow EMA used for entry and exit crosses. |
| `strategy_ema_regime` | 200 | 20-400 | Long regime filter and EMA200 exit reference. |
| `strategy_rsi_period` | 16 | 2-100 | RSI period for entry and exit filters. |
| `strategy_rsi_entry_low` | 40.0 | 0-100 | Minimum RSI for entry. |
| `strategy_rsi_entry_high` | 75.0 | 0-100 | Maximum RSI for entry. |
| `strategy_rsi_exit_high` | 78.0 | 0-100 | RSI profit-exhaustion exit threshold. |
| `strategy_volume_ema_period` | 20 | 2-100 | Tick-volume EMA period for the volume ratio. |
| `strategy_volume_ratio_min` | 0.50 | 0.0-5.0 | Minimum current tick-volume / EMA(tick-volume) ratio. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the emergency stop. |
| `strategy_source_stop_pct` | 6.0 | 0.1-20.0 | Source fixed stop distance as percent of entry. |
| `strategy_atr_stop_mult` | 3.0 | 0.1-10.0 | ATR multiple for the V5 emergency stop. |
| `strategy_trail_start_pct` | 5.0 | 0.1-20.0 | Profit percent where trailing starts. |
| `strategy_trail_distance_pct` | 3.0 | 0.1-20.0 | Trailing stop distance as percent below bid. |
| `strategy_trail_step_points` | 10 | 1-1000 | Minimum SL improvement before modifying the trail. |
| `strategy_macd_fast` | 12 | 2-100 | MACD fast EMA period for source exits. |
| `strategy_macd_slow` | 26 | 2-150 | MACD slow EMA period for source exits. |
| `strategy_macd_signal` | 9 | 2-100 | MACD signal period for source exits. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX symbol with DWX OHLC, EMA, RSI, MACD, ATR, and tick volume.
- `GBPUSD.DWX` - card-listed major FX symbol with DWX OHLC, EMA, RSI, MACD, ATR, and tick volume.
- `XAUUSD.DWX` - card-listed metal symbol with DWX OHLC, EMA, RSI, MACD, ATR, and tick volume.
- `GDAXI.DWX` - DWX-matrix DAX symbol used as the nearest available port for the card's unavailable `GER40.DWX`.
- `NDX.DWX` - card-listed US index symbol with DWX OHLC, EMA, RSI, MACD, ATR, and tick volume.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; registered as `GDAXI.DWX` instead.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - broker/test data is not available for unregistered custom symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | 2 to 24 hours, with mandatory exit after 24 hours |
| Expected drawdown profile | Trend-following pullbacks can take clustered losses during sideways regimes. |
| Regime preference | trend-following / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** GitHub strategy repository
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/TrendRiderStrategy.py`, entry tag `ema_crossover`, commit `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11235_ft-tr-emax.md`

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
| v1 | 2026-06-08 | Initial build from card | 6edda4d6-9e97-440f-8cfa-861d34e182dc |
