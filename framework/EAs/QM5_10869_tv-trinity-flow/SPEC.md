# QM5_10869_tv-trinity-flow - Strategy Spec

**EA ID:** QM5_10869
**Slug:** tv-trinity-flow
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades a trend and momentum confluence from the Trinity Flow TradingView card. A long signal requires the fast EMA above the slow EMA, both above the 200 EMA, stochastic crossing up through either the oversold threshold or the midline, and the signal bar closing higher than the prior bar. A short signal mirrors that logic below the 200 EMA with a stochastic cross down and a lower signal-bar close. Exits occur at the initial ATR stop or ATR target, or early when the fast and slow EMAs cross against the position or stochastic crosses back from the opposite extreme.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | PERIOD_M15 | M15-M30-H1 | Timeframe used for EMA, stochastic, ATR, and close reads. |
| `strategy_fast_ema_period` | 9 | 1-200 | Fast EMA in the trend alignment rule. |
| `strategy_slow_ema_period` | 21 | 1-300 | Slow EMA in the trend alignment rule. |
| `strategy_long_ema_period` | 200 | 20-400 | Long EMA trend filter. |
| `strategy_stoch_k_period` | 14 | 5-30 | Stochastic K period. |
| `strategy_stoch_d_period` | 3 | 1-10 | Stochastic D period. |
| `strategy_stoch_slowing` | 3 | 1-10 | Stochastic slowing value. |
| `strategy_stoch_oversold` | 20.0 | 1-50 | Oversold threshold for long trigger and short exit. |
| `strategy_stoch_overbought` | 80.0 | 50-99 | Overbought threshold for short trigger and long exit. |
| `strategy_stoch_midline` | 50.0 | 1-99 | Midline threshold allowed by the card trigger. |
| `strategy_atr_period` | 14 | 5-50 | ATR period used for volatility filter and brackets. |
| `strategy_atr_median_bars` | 50 | 10-128 | Number of closed ATR samples for the median volatility filter. |
| `strategy_atr_sl_mult` | 1.5 | 0.5-5.0 | Stop distance multiplier in ATR units. |
| `strategy_atr_tp_mult` | 2.0 | 0.5-8.0 | Target distance multiplier in ATR units. |
| `strategy_cooldown_bars` | 3 | 0-20 | Closed bars to wait after a position closes before another entry. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 names this major FX symbol directly.
- `GBPUSD.DWX` - Card R3 names this major FX symbol directly.
- `XAUUSD.DWX` - Card R3 names this liquid metals symbol directly.
- `NDX.DWX` - Card R3 names this liquid index symbol directly.
- `GDAXI.DWX` - DWX matrix canonical DAX symbol used for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in the DWX symbol matrix; use `GDAXI.DWX`.
- `SPX500.DWX` - Not a valid canonical DWX symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none by default; `strategy_signal_tf` can be set to M30 or H1 from the card's test list |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | hours |
| Expected drawdown profile | Medium-cadence trend and momentum system with false-cross risk in sideways regimes. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source script
**Pointer:** https://www.tradingview.com/script/TN6z7ECu/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10869_tv-trinity-flow.md`

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
| v1 | 2026-06-06 | Initial build from card | cd82bde7-e5f4-4a45-af6e-46da360c824e |
