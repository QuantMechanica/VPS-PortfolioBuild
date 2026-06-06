# QM5_10939_grimes-context-pb - Strategy Spec

**EA ID:** QM5_10939
**Slug:** grimes-context-pb
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H4 continuation pullbacks only when the D1 trend context agrees. A long setup requires the D1 close above EMA(50), EMA(20) above EMA(50), D1 ADX(14) at least 16, a recent H4 surprise leg that closes beyond a 30-bar high and moves at least 2.5 ATR(20), then a 25%-55% controlled pullback that holds H4 EMA(20). It enters long after an H4 close above the pullback's 3-bar high; shorts mirror the same rules in a D1 downtrend. The stop is placed beyond the pullback extreme by 0.25 ATR, target is 2R, stop moves to breakeven at 1R, and discretionary exits occur on an H4 close beyond the 61.8% adverse retracement level or after 18 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 20 | 1-200 | ATR period for surprise, pullback quality, stop buffer, and maximum stop checks. |
| strategy_d1_fast_ema | 20 | 1-200 | Fast D1 EMA used for trend context and H4 pullback EMA quality. |
| strategy_d1_slow_ema | 50 | 1-300 | Slow D1 EMA used for trend context. |
| strategy_d1_adx_period | 14 | 1-100 | D1 ADX period for weak-context rejection. |
| strategy_d1_adx_min | 16.0 | 0-100 | Minimum D1 ADX required before entry. |
| strategy_surprise_lookback | 12 | 1-50 | Maximum H4 bars over which the surprise leg may form. |
| strategy_breakout_lookback | 30 | 5-200 | Prior H4 high/low window the surprise leg must close beyond. |
| strategy_surprise_atr_mult | 2.5 | 0.1-10.0 | Minimum surprise-leg distance in ATR units. |
| strategy_climax_bar_atr_mult | 3.0 | 0.1-10.0 | Rejects surprise legs with a single oversize bar. |
| strategy_pullback_min_bars | 3 | 1-20 | Minimum H4 pullback length after the surprise leg. |
| strategy_pullback_max_bars | 10 | 1-50 | Maximum H4 pullback length after the surprise leg. |
| strategy_pullback_min_pct | 25.0 | 0-100 | Minimum pullback retracement as percent of surprise leg. |
| strategy_pullback_max_pct | 55.0 | 0-100 | Maximum pullback retracement as percent of surprise leg. |
| strategy_trigger_lookback | 3 | 1-10 | Pullback high/low trigger window for entry confirmation. |
| strategy_pullback_bar_atr_mult | 1.5 | 0.1-10.0 | Maximum allowed pullback bar range in ATR units. |
| strategy_stop_atr_buffer | 0.25 | 0-5.0 | ATR buffer beyond the pullback extreme for stop placement. |
| strategy_max_stop_atr_mult | 2.25 | 0.1-10.0 | Rejects entries whose stop distance exceeds this ATR multiple. |
| strategy_target_r_mult | 2.0 | 0.1-10.0 | Profit target in initial-risk units. |
| strategy_breakeven_r_mult | 1.0 | 0.1-5.0 | Open profit in R required before moving stop to breakeven. |
| strategy_time_exit_h4_bars | 18 | 1-100 | Time exit after this many base timeframe bars. |
| strategy_spread_stop_max_pct | 8.0 | 0-100 | Rejects entries when spread exceeds this percent of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid forex major with H4/D1 OHLC support.
- GBPUSD.DWX - card-listed liquid forex major with H4/D1 OHLC support.
- USDJPY.DWX - card-listed liquid forex major with H4/D1 OHLC support.
- XAUUSD.DWX - card-listed liquid metal CFD with H4/D1 OHLC support.
- GDAXI.DWX - matrix-available DAX CFD equivalent for the card's GER40.DWX target.

**Explicitly NOT for:**
- GER40.DWX - card-listed name is not present in `dwx_symbol_matrix.csv`; GDAXI.DWX is registered instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 EMA(20), D1 EMA(50), D1 ADX(14) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 28 |
| Typical hold time | Up to 18 H4 bars, roughly three trading days. |
| Expected drawdown profile | Controlled by structural stop capped at 2.25 ATR and one active position per symbol/magic. |
| Regime preference | Context-filtered trend continuation after volatility expansion and controlled pullback. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "Context in Pullbacks: What Should Happen?", 2023-11-29
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10939_grimes-context-pb.md`

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
| v1 | 2026-06-06 | Initial build from card | 544e801a-8c4f-4bdc-87b6-40d7820e8ee3 |
