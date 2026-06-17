# QM5_11228_ft-smoothscalp — Strategy Spec

**EA ID:** QM5_11228
**Slug:** `ft-smoothscalp`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (SmoothScalp.py, freqtrade-strategies)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Long-only M1 oversold-reversal scalp ported from freqtrade's SmoothScalp.py. On
each closed M1 bar the EA goes long when ALL of the following hold: the bar opened
below the 5-period EMA of lows; ADX(14) is above 30 (trend strength present);
MFI(14) is below 30 (money-flow oversold); CCI(20) is below -150 (deeply
oversold); and the Fast Stochastic %K and %D are both below 30. The single fresh
trigger is %K crossing above %D on that bar — all other conditions are evaluated
as states, so the entry never requires two simultaneous cross events. The stop is
1× ATR(14) below entry and the take-profit is a 1:1 reward:risk target (a proxy
for the source's 1% ROI). The position is closed early when CCI(20) rises above
150 AND either the bar opened at/above the 5-period EMA of highs or Fast %K is
above 70. One open position per symbol/magic — the source's many-parallel-trades
assumption is deliberately not adopted.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 5 | 3-10 | EMA period applied to highs/lows (EMA5) |
| `strategy_stoch_k` | 5 | 3-14 | Fast Stochastic %K period |
| `strategy_stoch_d` | 3 | 2-5 | Fast Stochastic %D period |
| `strategy_stoch_slowing` | 3 | 1-5 | Fast Stochastic slowing |
| `strategy_adx_period` | 14 | 7-21 | ADX period |
| `strategy_adx_min` | 30.0 | 25-35 | ADX trend-strength floor |
| `strategy_mfi_period` | 14 | 7-21 | MFI period |
| `strategy_mfi_max` | 30.0 | 20-40 | MFI oversold ceiling (entry) |
| `strategy_stoch_max` | 30.0 | 20-40 | FastK/FastD oversold ceiling (entry) |
| `strategy_cci_period` | 20 | 14-30 | CCI period |
| `strategy_cci_entry_max` | -150.0 | -200 to -100 | CCI entry oversold ceiling |
| `strategy_cci_exit_min` | 150.0 | 100-200 | CCI exit overbought floor |
| `strategy_stoch_exit_hi` | 70.0 | 60-80 | FastK overbought exit level |
| `strategy_atr_period` | 14 | 7-21 | ATR period (stop) |
| `strategy_sl_atr_mult` | 1.0 | 0.5-3.0 | Stop distance = mult × ATR |
| `strategy_tp_rr` | 1.0 | 0.5-3.0 | Take-profit reward:risk multiple |
| `strategy_spread_pct_of_stop` | 4.0 | 2-15 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid FX major; tight cost base suits an M1 scalp
- `GBPUSD.DWX` — liquid FX major with enough M1 volatility for reversal scalps
- `USDJPY.DWX` — liquid FX major; pip-factor handled by QM stop helpers
- `XAUUSD.DWX` — high intraday volatility metal; card flags high M1 cost sensitivity

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/etc.) — not in the card's portable basket; the M1 EMA-low
  reversal edge is FX/metals-calibrated, not validated on index microstructure

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~300` |
| Typical hold time | `minutes (M1 scalp)` |
| Expected drawdown profile | `high-frequency small wins; M1 cost sensitivity is the main risk` |
| Regime preference | `mean-revert (oversold reversal within an ADX-confirmed move)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** `forum` (open-source GitHub strategy repository)
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/SmoothScalp.py` (commit `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11228_ft-smoothscalp.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor worktree |
