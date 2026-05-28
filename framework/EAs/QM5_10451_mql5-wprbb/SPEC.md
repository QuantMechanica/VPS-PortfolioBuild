# QM5_10451_mql5-wprbb - Strategy Spec

**EA ID:** QM5_10451
**Slug:** `mql5-wprbb`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates completed H4 bars by default. It buys when Williams %R(14) crosses upward out of oversold territory at -80 while the completed bar opened below the Bollinger Bands(20, 2.0) middle line. It sells when Williams %R(14) crosses downward out of overbought territory at -20 while the completed bar opened above the Bollinger middle line. Each entry uses a fixed stop distance equal to 0.5 times Bollinger Band width times the stop multiplier, and a fixed target distance derived from ATR(14) times the target multiplier.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_wpr_period` | 14 | 2-200 | Williams %R lookback period. |
| `strategy_wpr_oversold` | -80.0 | -100 to 0 | Long trigger level; WPR exits upward through this value. |
| `strategy_wpr_overbought` | -20.0 | -100 to 0 | Short trigger level; WPR exits downward through this value. |
| `strategy_bb_period` | 20 | 2-200 | Bollinger Bands lookback period. |
| `strategy_bb_deviation` | 2.0 | 0.5-5.0 | Bollinger Bands standard deviation multiplier. |
| `strategy_atr_period` | 14 | 2-200 | ATR lookback period used for target distance. |
| `strategy_bb_sl_mult` | 1.0 | 0.1-10.0 | Multiplier applied to half Bollinger Band width for stop distance. |
| `strategy_atr_tp_mult` | 1.0 | 0.1-10.0 | Multiplier applied to ATR for target distance. |
| `strategy_max_spread_stop_fraction` | 0.20 | 0.0-1.0 | Blocks entries when spread exceeds this fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with standard OHLC indicator coverage.
- `GBPUSD.DWX` - card-listed FX major with standard OHLC indicator coverage.
- `USDJPY.DWX` - card-listed FX major with standard OHLC indicator coverage.
- `XAUUSD.DWX` - card-listed metal with standard OHLC indicator coverage.
- `GDAXI.DWX` - canonical DWX DAX symbol replacing the card shorthand `DAX.DWX`.
- `NDX.DWX` - card-listed optional index robustness symbol.

**Explicitly NOT for:**
- `DAX.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable phantom S&P variants.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | hours to a few days |
| Expected drawdown profile | mean-reversion drawdowns during persistent directional moves |
| Regime preference | mean-revert / momentum-reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/63916`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10451_mql5-wprbb.md`

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
| v1 | 2026-05-28 | Initial build from card | f18559ba-79ee-4ab1-856a-1eec228271d0 |
