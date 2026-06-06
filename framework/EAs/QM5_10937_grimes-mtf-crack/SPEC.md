# QM5_10937_grimes-mtf-crack - Strategy Spec

**EA ID:** QM5_10937
**Slug:** grimes-mtf-crack
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA evaluates H4 entries using D1 context. A short setup requires a prior D1 uptrend, a 5-20 bar D1 pullback with lower highs, and a D1 close below both the flag low and EMA(20) by at least 0.25 ATR(20); the H4 trigger is the first closed H4 bar below the D1 crack bar low. A long setup mirrors this after a D1 downtrend and higher-low pullback, with the H4 trigger above the D1 crack bar high. The EA places a structural D1 flag stop, a 2R target, moves to breakeven at 1R, exits if D1 closes back inside the broken flag range, and time-exits after 12 H4 bars if progress is below 0.5R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_d1_ema_period | 20 | >= 2 | D1 EMA period used for trend context and crack confirmation. |
| strategy_d1_atr_period | 20 | >= 2 | D1 ATR period used for crack buffer, crack range, and stop checks. |
| strategy_d1_ema_slope_bars | 10 | >= 1 | Bars over which D1 EMA slope must confirm the prior trend. |
| strategy_d1_price_above_bars | 5 | >= 1 | Recent D1 bars checked for price above or below EMA before the crack. |
| strategy_flag_min_bars | 5 | >= 2 | Minimum D1 pullback or flag length. |
| strategy_flag_max_bars | 20 | >= min | Maximum D1 pullback or flag length. |
| strategy_d1_crack_max_age | 3 | >= 1 | Maximum recent D1 closed bars searched for the crack setup. |
| strategy_crack_atr_buffer | 0.25 | >= 0 | ATR multiple required beyond EMA and used as structural stop buffer. |
| strategy_max_d1_crack_range_atr | 3.0 | > 0 | Rejects exhausted D1 crack bars whose range exceeds this ATR multiple. |
| strategy_max_stop_atr_mult | 3.0 | > 0 | Rejects entries whose stop distance exceeds this D1 ATR multiple. |
| strategy_spread_stop_fraction | 0.08 | > 0 | Rejects entries when spread exceeds this fraction of stop distance. |
| strategy_target_r_mult | 2.0 | > 0 | Fixed reward-to-risk target multiple. |
| strategy_be_trigger_r | 1.0 | > 0 | Favorable R multiple at which SL is moved to breakeven. |
| strategy_time_exit_h4_bars | 12 | >= 1 | H4 bars after which weak progress can force exit. |
| strategy_time_exit_min_r | 0.5 | >= 0 | Minimum favorable R required to avoid the time exit. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed major FX symbol with D1/H4 OHLC, EMA, and ATR support.
- GBPUSD.DWX - card-listed major FX symbol with D1/H4 OHLC, EMA, and ATR support.
- USDJPY.DWX - card-listed major FX symbol with D1/H4 OHLC, EMA, and ATR support.
- XAUUSD.DWX - card-listed metal CFD with D1/H4 OHLC, EMA, and ATR support.
- GDAXI.DWX - canonical available DWX DAX symbol, used in place of card-stated GER40.DWX.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 EMA(20), D1 ATR(20), D1 flag/crack OHLC |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | 1-3 trading days, bounded by a 12 H4 bar weak-progress exit |
| Expected drawdown profile | Structural-stop breakout/failure strategy with fixed 2R target and breakeven after 1R. |
| Regime preference | Higher-timeframe pattern failure into volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, Being right being wrong (and multiple timeframe analysis), 2019-04-18, https://www.adamhgrimes.com/being-right-being-wrong-and-multiple-timeframe-analysis/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10937_grimes-mtf-crack.md`

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
| v1 | 2026-06-06 | Initial build from card | c8077f48-982a-4da0-8860-2793e448a5d1 |
