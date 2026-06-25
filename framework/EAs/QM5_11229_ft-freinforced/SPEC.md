# QM5_11229_ft-freinforced - Strategy Spec

**EA ID:** QM5_11229
**Slug:** ft-freinforced
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades M5 closed bars using a symmetric long and short EMA crossover rule. A long entry requires the M5 close to be above the H1 SMA50 regime line and EMA8 to cross above EMA21; a short entry requires the M5 close to be below the H1 SMA50 regime line and EMA8 to cross below EMA21. Positions use an ATR14 stop at 1.5 times ATR and close when ADX14 falls below 30, with the source ROI ladder disabled because the card notes its non-monotonic behavior must be normalized or disabled for MT5.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_short_period | 8 | 5, 8, 13 | Fast M5 EMA period used for crossover trigger. |
| strategy_ema_long_period | 21 | 21, 34, 55 | Slow M5 EMA period used for crossover trigger. |
| strategy_adx_period | 14 | 10, 14, 20 | M5 ADX period used for the weakening-trend exit. |
| strategy_adx_exit_max | 30.0 | 20-40 | Close open positions when ADX is below this threshold. |
| strategy_resample_sma_period | 50 | 25, 50, 100 | H1 SMA period used as the higher-timeframe regime filter. |
| strategy_atr_period | 14 | 10-20 | ATR period used for the baseline stop. |
| strategy_sl_atr_mult | 1.5 | Fixed by card | Stop distance multiplier applied to ATR. |
| strategy_spread_pct_of_stop | 6.0 | Fixed by card | Maximum modeled spread as a percent of planned stop distance. |
| strategy_warmup_bars | 650 | Fixed by card | Minimum M5 bars before trading for resampled SMA stability. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 primary P2 FX basket member; OHLC EMA/SMA/ADX logic is portable.
- GBPUSD.DWX - Card R3 primary P2 FX basket member; OHLC EMA/SMA/ADX logic is portable.
- USDJPY.DWX - Card R3 primary P2 FX basket member; OHLC EMA/SMA/ADX logic is portable.
- XAUUSD.DWX - Card R3 primary P2 metals basket member; OHLC EMA/SMA/ADX logic is portable.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - broker/tester data availability is not validated.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | H1 SMA50 regime filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Minutes to hours; positions exit on ADX weakening, ATR stop, or Friday close. |
| Expected drawdown profile | Medium risk class from card initial profile. |
| Regime preference | M5 trend/momentum continuation with H1 regime alignment. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/futures/FReinforcedStrategy.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11229_ft-freinforced.md`

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
| v1 | 2026-06-26 | Initial build from card | 04def559-60df-4409-919e-c2b7e47feb1a |
