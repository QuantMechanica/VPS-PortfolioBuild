# QM5_10851_tv-pb-wt - Strategy Spec

**EA ID:** QM5_10851
**Slug:** tv-pb-wt
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades pullbacks in the direction of an EMA(200) regime. A long setup requires the last closed bar to close above EMA(200), below EMA(50), and for WaveTrend WT1 to cross above WT2 on that closed bar. A short setup is symmetric: close below EMA(200), above EMA(50), and WT1 crossing below WT2. Exits occur on the opposite WaveTrend cross, an EMA(200) breach on the last closed bar, the fixed 2.0R target, stop loss, or a 48-bar time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_trend_ema_period | 200 | 100-200 | EMA period for the primary trend filter. |
| strategy_pullback_ema_period | 50 | 34-89 | EMA period for the pullback-zone reference. |
| strategy_wt_channel_period | 10 | 5-20 | WaveTrend channel EMA period. |
| strategy_wt_average_period | 21 | 10-35 | WaveTrend average EMA period. |
| strategy_wt_signal_period | 4 | 2-8 | SMA period used for WT2 signal line. |
| strategy_atr_period | 14 | 10-30 | ATR period for stop sizing. |
| strategy_swing_lookback_bars | 10 | 5-20 | Recent swing window used for the structural stop. |
| strategy_min_stop_atr_mult | 1.0 | 0.5-2.0 | Minimum stop distance as ATR multiple. |
| strategy_stop_cap_atr_mult | 2.0 | 1.5-2.5 | Maximum stop distance as ATR multiple. |
| strategy_target_rr | 2.0 | 1.5-3.0 | Hard target in reward-to-risk units. |
| strategy_time_exit_bars | 48 | 24-96 | Maximum holding period in bars. |
| strategy_wt_warmup_bars | 260 | 120-400 | Closed-bar history used to warm up WaveTrend. |
| strategy_max_spread_stop_frac | 0.15 | 0.05-0.25 | Skip entry if spread exceeds this fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Liquid major FX pair with native DWX history.
- GBPUSD.DWX - Liquid major FX pair with native DWX history.
- XAUUSD.DWX - Liquid metal CFD named in the card's portable basket.
- GDAXI.DWX - DWX DAX equivalent used because GER40.DWX is not present in the matrix.
- NDX.DWX - Liquid index CFD named in the card's portable basket.

**Explicitly NOT for:**
- GER40.DWX - Card-stated symbol is absent from `dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX port.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Up to 48 bars |
| Expected drawdown profile | Medium-cadence pullback continuation risk; whipsaw risk when EMA200 trend breaks. |
| Regime preference | trend-following pullback continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `Trend Pullback EMA Combo: Algorithmic Trend Following`, author `MyStrategyHub`, Apr 19.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10851_tv-pb-wt.md`

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
| v1 | 2026-06-14 | Initial build from card | b64792d9-b98a-450b-a019-7c012ef15b3f |
