# QM5_11389_munzer-d1-ema34-sma150-double-cci — Strategy Spec

**EA ID:** QM5_11389
**Slug:** `munzer-d1-ema34-sma150-double-cci`
**Source:** `dfd32799-2055-5ef8-b99b-dcbfa51daba0` (Mohammed Munzer Complex System #7, forex-strategies-revealed.com compilation)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A D1 trend-with-momentum-trigger system on forex. The EMA(34)/SMA(150) pair fixes
the trend STATE: EMA above SMA = uptrend, below = downtrend. When price (the last
closed daily bar's close) sits BETWEEN the two moving averages it is a no-trade
zone and the EA stands aside. The single entry EVENT is the fast CCI(14) crossing
zero in the trend direction on the last closed bar; the slow CCI(50) sign, the
EMA/SMA stack, the price-vs-EMA(34) side, and the Stochastic %K level are all
confirming STATES (never a second fresh cross on the same bar — this avoids the
two-cross-same-bar zero-trade trap).

Long: EMA34 > SMA150, close above EMA34, fast CCI(14) crosses up through 0, slow
CCI(50) > 0, and Stoch %K not overbought (< 80). Short is the mirror (CCI cross
down, CCI(50) < 0, Stoch %K not oversold > 20). Entry is a market order on the
confirming closed bar. Stop is placed at the signal candle's opposite extreme
±10 pips, with the stop distance capped at 60 pips (D1 candles can be large).
Take profit is 2× ATR(14). The stop is moved to breakeven once price advances
+1× ATR(14) in favour.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 34 | 13-100 | Fast trend EMA |
| `strategy_sma_period` | 150 | 50-300 | Slow trend SMA |
| `strategy_cci_slow_period` | 50 | 20-100 | Slow CCI sign-confirmation state |
| `strategy_cci_fast_period` | 14 | 7-30 | Fast CCI zero-cross trigger event |
| `strategy_stoch_k` | 5 | 3-21 | Stochastic %K period |
| `strategy_stoch_d` | 3 | 1-10 | Stochastic %D period |
| `strategy_stoch_slow` | 3 | 1-10 | Stochastic slowing |
| `strategy_stoch_ob` | 80.0 | 60-95 | Overbought ceiling (block longs above) |
| `strategy_stoch_os` | 20.0 | 5-40 | Oversold floor (block shorts below) |
| `strategy_atr_period` | 14 | 7-30 | ATR period for TP and breakeven |
| `strategy_tp_atr_mult` | 2.0 | 1.0-4.0 | Take-profit distance = mult × ATR |
| `strategy_sl_buffer_pips` | 10 | 2-30 | Stop placed this many pips beyond candle extreme |
| `strategy_sl_max_pips` | 60 | 20-150 | Hard cap on stop distance (D1) |
| `strategy_be_atr_mult` | 1.0 | 0.5-3.0 | Move SL to breakeven once +mult × ATR in profit |
| `strategy_spread_pct_of_stop` | 25.0 | 5-100 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid major; clean D1 trends, low spread cost.
- `GBPUSD.DWX` — liquid major with strong directional D1 swings.
- `USDJPY.DWX` — liquid major; pip-factor handling verified for 3-digit quote.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the card's R3 PASS scopes this strategy to the
  three forex majors above; trend/CCI calibration is not validated outside FX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~30` |
| Typical hold time | `several days (D1 swing)` |
| Expected drawdown profile | `moderate; capped per-trade by 60-pip stop ceiling` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `dfd32799-2055-5ef8-b99b-dcbfa51daba0`
**Source type:** `paper` (forex-strategies-revealed.com PDF compilation)
**Pointer:** Mohammed Munzer "Complex Trading System #7", `pdfcoffee.com_forex-strategy-7-pdf-free.pdf`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11389_munzer-d1-ema34-sma150-double-cci.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
