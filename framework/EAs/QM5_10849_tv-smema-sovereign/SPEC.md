# QM5_10849_tv-smema-sovereign - Strategy Spec

**EA ID:** QM5_10849
**Slug:** tv-smema-sovereign
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView source citation in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades a double-smoothed moving average crossover. Fast SMEMA is calculated as SMA of EMA(close, 2) over 2 bars, and slow SMEMA is calculated as SMA of EMA(close, 5) over 5 bars. It opens long when fast SMEMA crosses above slow SMEMA on a confirmed bar and opens short when fast SMEMA crosses below slow SMEMA. Exits use a 1.8 ATR initial stop, a 4.5 ATR target, breakeven and 1.5 ATR trailing after the 2.5 ATR TP1 distance, opposite SMEMA crossover, max 10 bars, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_signal_tf | PERIOD_CURRENT | M15, M30, H1 | Signal timeframe used by the SMEMA and ATR rules. |
| strategy_fast_smema | 2 | 2, 3, 5 | Fast SMEMA period from the card. |
| strategy_slow_smema | 5 | 5, 8, 13 | Slow SMEMA period from the card. |
| strategy_baseline_smema | 15 | 1+ | Optional baseline SMEMA period. |
| strategy_atr_period | 14 | 1+ | ATR period for stop, target, and trail distances. |
| strategy_atr_sl_mult | 1.8 | 1.5, 1.8, 2.2 | Initial hard stop ATR multiple. |
| strategy_tp1_atr_mult | 2.5 | 0+ | ATR distance that activates breakeven and trailing. |
| strategy_tp2_atr_mult | 4.5 | 0+ | Final target ATR multiple. |
| strategy_trail_atr_mult | 1.5 | 0+ | ATR trailing stop multiple after TP1 distance. |
| strategy_max_bars | 10 | 7, 10, 20 | Time exit after this many signal bars. |
| strategy_max_spread_stop | 0.15 | 0-1 | Skip entries when spread exceeds this share of stop distance. |
| strategy_filter_adx | false | true/false | Optional P3 ADX quality filter. |
| strategy_adx_min | 18.0 | 0+ | Minimum ADX when the optional ADX filter is enabled. |
| strategy_filter_rsi | false | true/false | Optional P3 RSI quality filter. |
| strategy_rsi_period | 14 | 1+ | RSI period for optional filter. |
| strategy_rsi_long_min | 52.0 | 0-100 | Minimum RSI for long entries when enabled. |
| strategy_rsi_short_max | 48.0 | 0-100 | Maximum RSI for short entries when enabled. |
| strategy_filter_atr_ratio | false | true/false | Optional P3 volatility ratio filter. |
| strategy_atr_ratio_sma | 20 | 1+ | ATR averaging length for volatility ratio. |
| strategy_atr_ratio_min | 0.8 | 0+ | Minimum ATR / SMA(ATR) when enabled. |
| strategy_filter_baseline | false | true/false | Optional P3 close-vs-baseline SMEMA filter. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card P2 basket forex major.
- GBPUSD.DWX - card P2 basket forex major.
- XAUUSD.DWX - card P2 basket liquid metal CFD.
- GDAXI.DWX - DAX equivalent available in the DWX matrix for card-stated GER40.DWX.
- NDX.DWX - card P2 basket liquid US index CFD.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

> Card states "Use M15/H1 baseline"; H1 is chosen as the P2 base timeframe because
> it matches the card's expected ~120 trades/year/symbol. P3 sweeps may test M15/M30.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday to 10 bars |
| Expected drawdown profile | High-cadence whipsaw risk in range-bound markets |
| Regime preference | Trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/DGHCEcnB-Sovereign-Trend-Strategy-JOAT/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10849_tv-smema-sovereign.md`

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
| v1 | 2026-06-06 | Initial build from card | ef21f6f9-7920-4050-a729-facb19110add |
