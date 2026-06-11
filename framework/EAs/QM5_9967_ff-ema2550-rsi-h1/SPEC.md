# QM5_9967_ff-ema2550-rsi-h1 - Strategy Spec

**EA ID:** QM5_9967
**Slug:** ff-ema2550-rsi-h1
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades the H1 ForexFactory EMA50 and RSI midline rule. A long entry is allowed when the current H1 bar opens above EMA(50, close), RSI(14) is at or above 50, and the previous closed H1 bar was not already long-qualified. A short entry is the mirror rule: current H1 bar open below EMA(50, close), RSI(14) at or below 50, and the previous closed H1 bar not already short-qualified. Positions close on an opposite qualified signal, RSI crossing back through the 50 midline, a 36-H1-bar time stop, the broker SL/TP, breakeven management, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | H1 baseline; H4 P3 variant | Signal timeframe. |
| `strategy_ema_period` | `50` | `1+` | EMA period used for price-vs-EMA qualification. |
| `strategy_rsi_period` | `14` | `1+` | RSI period used for midline confirmation. |
| `strategy_rsi_midline` | `50.0` | `0-100` | RSI threshold for long/short confirmation and exits. |
| `strategy_atr_period` | `14` | `1+` | ATR period used in the baseline stop calculation. |
| `strategy_atr_stop_mult` | `1.5` | `>0` | ATR multiplier for the stop floor. |
| `strategy_stop_min_pips` | `70` | `1+` | Minimum hard stop distance in pips. |
| `strategy_stop_max_pips` | `130` | `1+` | Maximum hard stop distance in pips. |
| `strategy_take_profit_pips` | `100` | `1+` | Baseline fixed take-profit distance in pips. |
| `strategy_breakeven_pips` | `50` | `1+` | Move stop to breakeven after this profit in pips. |
| `strategy_breakeven_buffer_pips` | `0` | `0+` | Extra pips beyond entry when moving to breakeven. |
| `strategy_time_stop_bars` | `36` | `1+` | Maximum hold time measured in H1 bars. |
| `strategy_slope_bars` | `3` | `1+` | EMA slope lookback bars for flat-market filtering. |
| `strategy_flat_slope_atr_frac` | `0.03` | `>=0` | Skip entries when EMA slope is within this ATR fraction. |
| `strategy_max_spread_stop_frac` | `0.10` | `>=0` | Skip entries when spread exceeds this fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 primary FX basket member with DWX data.
- `GBPUSD.DWX` - card R3 primary FX basket member with DWX data.
- `USDJPY.DWX` - card R3 primary FX basket member with DWX data.
- `AUDUSD.DWX` - card R3 primary FX basket member with DWX data.

**Explicitly NOT for:**
- Non-FX symbols - the card defines 70/100/130 pip FX-major stop and target distances.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none in P2 baseline; card notes H4 as a P3 slower variant |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `85` |
| Typical hold time | up to 36 H1 bars |
| Expected drawdown profile | trend-following FX drawdowns during flat EMA regimes, mitigated by slope and spread filters |
| Regime preference | H1 trend / momentum continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** ForexFactory post #1,733, https://www.forexfactory.com/thread/post/2036206
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9967_ff-ema2550-rsi-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | 7cf71995-abf8-4e34-9646-9c214a8638c9 |
