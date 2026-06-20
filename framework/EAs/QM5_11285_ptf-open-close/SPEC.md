# QM5_11285_ptf-open-close — Strategy Spec

**EA ID:** QM5_11285
**Slug:** `ptf-open-close`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

On each completed daily (D1) bar the EA forecasts the prior open-close move,
scaled by return volatility: `forecast = forecast_scalar * (close - open) / ATR(atr_period)`,
read from prior closed bars only (shift >= 1). The source `norm_forecast`
normalizes with in-sample lookahead, so this build uses a fixed no-lookahead
scaling input while preserving the card's threshold crossing rule. The EA goes
long at the next bar when the normalized forecast crosses above `+entry_threshold`
(default +5) and short when it crosses below `-entry_threshold` (default -5);
only one fresh threshold cross per bar triggers. It exits when the forecast
reverts through `exit_level` (0), or after `max_hold_bars` completed daily bars,
whichever comes first. A catastrophic `sl_atr_mult * ATR(atr_period)` stop guards
each position. One position per symbol/magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 5-50 | ATR period used as return-volatility proxy and stop basis |
| `strategy_forecast_scalar` | 4.0 | 1.0-20.0 | Fixed no-lookahead scale approximating PyTrendFollow `norm_forecast` |
| `strategy_entry_threshold` | 5.0 | 2.0-15.0 | `\|forecast\|` cross level that fires an entry (card +/-5) |
| `strategy_exit_level` | 0.0 | 0.0-3.0 | Forecast level for the mean-revert exit (card: 0) |
| `strategy_max_hold_bars` | 5 | 1-30 | Time-stop in completed daily bars (card: 5) |
| `strategy_sl_atr_mult` | 1.5 | 0.5-4.0 | Catastrophic stop distance = mult * ATR (card: 1.5) |
| `strategy_spread_pct_of_stop` | 15.0 | 1.0-100.0 | Block only if live spread exceeds this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair with reliable D1 open construction in DWX history
- `GBPUSD.DWX` — liquid major, card-listed target
- `USDJPY.DWX` — liquid major, card-listed target
- `AUDUSD.DWX` — liquid major, card-listed target
- `EURJPY.DWX` — liquid cross, card-listed target

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — the open-close daily forecast was sourced
  and approved (R3) only for the FX majors basket above.

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
| Trades / year / symbol | `~90` |
| Typical hold time | `1-5 days` (forecast-revert or 5-bar time-stop) |
| Expected drawdown profile | `moderate; momentum entries with a tight ATR catastrophic stop` |
| Regime preference | `momentum / intraday-seasonality (prior open-close persistence)` |
| Expected trade frequency | `daily signal checks with about 90 trades/year/symbol` |
| Win rate target (qualitative) | `low-to-medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** `forum` (open-source GitHub repository)
**Pointer:** `https://github.com/chrism2671/PyTrendFollow/blob/master/trading/rules.py` (`open_close()`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11285_ptf-open-close.md`

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
| v1 | 2026-06-20 | Initial build from card | 970edb68-97ce-48ee-a505-2232d489104e |
