# QM5_9925_bandy-cci-momentum-breakout-trend — Strategy Spec

**EA ID:** QM5_9925
**Slug:** `bandy-cci-momentum-breakout-trend`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Author of this spec:** Gemini Orchestration
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

Mechanical trend breakout strategy based on Howard Bandy's *Quantitative Technical Analysis* (2015) using Lambert's Commodities Channel Index (1980).
On each completed D1 bar close:
1. Calculates 20-period CCI on typical price: `cci20 = CCI(typical_price, 20)`.
2. Calculates 200-period simple moving average regime gate: `regime = SMA(close, 200)`.
3. Checks doji filter: rejects entry if `|close - open| < 0.10 * (high - low)`.
4. Long entry at next bar open when `cci20` crosses above `+100` (`cci20[1] <= 100` and `cci20[0] > 100`), `close > regime`, and not doji.
5. Short entry at next bar open when `cci20` crosses below `-100` (`cci20[1] >= -100` and `cci20[0] < -100`), `close < regime`, and not doji.
6. One position per magic; long/short mutually exclusive.
7. Attaches a catastrophic stop loss at `3.0 * ATR(14)` away from fill (below for long, above for short).
8. Exit on momentum recovery to neutral: long exits when `cci20 < 0`, short exits when `cci20 > 0`, or when 45 trading days have elapsed (time stop), or when catastrophic stop is hit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_cci_period` | 20 | 14 / 20 / 28 | Lookback period in D1 bars for CCI calculation. |
| `strategy_cci_entry_threshold` | 100.0 | 80 / 100 / 120 | Absolute threshold for momentum breakout entry (+100 for long, -100 for short). |
| `strategy_cci_exit_threshold` | 0.0 | -20 / 0 / +20 | CCI threshold for momentum exit. |
| `strategy_regime_sma_period` | 200 | 100 / 200 / 300 | D1 simple moving average regime filter period. |
| `strategy_atr_period` | 14 | fixed | D1 ATR period for catastrophic stop loss. |
| `strategy_atr_stop_mult` | 3.0 | 2.5 / 3.0 / 3.5 | ATR multiplier for catastrophic stop loss distance. |
| `strategy_time_stop_bars` | 45 | 30 / 45 / 60 | Maximum holding duration in completed D1 bars. |
| `strategy_doji_threshold` | 0.1 | fixed | Minimum body-to-range ratio required to reject indecision bars. |
| `strategy_warmup_bars` | 250 | 200 .. 300 | Minimum D1 bars required before trading. |

> Framework-level inputs (`RISK_PERCENT`, `RISK_FIXED`, `PORTFOLIO_WEIGHT`, `qm_news_*`, `qm_rng_seed`, `qm_friday_close_*`) are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — liquid index CFD.
- `NDX.DWX` — liquid index CFD.
- `SP500.DWX` — canonical equity index backtest instrument.
- `UK100.DWX` — liquid index CFD.
- `WS30.DWX` — liquid index CFD.
- `XAUUSD.DWX` — liquid gold CFD.
- `EURUSD.DWX` — liquid FX major.
- `GBPUSD.DWX` — liquid FX major.
- `USDJPY.DWX` — liquid FX major.
- `USDCHF.DWX` — liquid FX major.
- `AUDUSD.DWX` — liquid FX major.
- `USDCAD.DWX` — liquid FX major.
- `NZDUSD.DWX` — liquid FX major.

**Explicitly NOT for:**
Any symbol not registered in `framework/registry/magic_numbers.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entries; `QM_IsNewCalendarPeriod(PERIOD_D1)` for restart-safe D1 exits |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 10 |
| Expected trade frequency | approximately 0.8–1.2 entries per month per symbol during emerging trends |
| Typical hold time | 5 to 45 trading days |
| Expected drawdown profile | occasional false breakout whipsaws during range-bound consolidating markets |
| Regime preference | strong trending markets aligned with 200-day moving average |
| Win rate target (qualitative) | moderate (40–50%) with high payoff ratio (>2.0) typical of trend following |

---

## 6. Source Citation

This strategy was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** book
**Citation:** Howard B. Bandy, *Quantitative Technical Analysis: An Integrated Approach to Trading System Development and Trade Management*, Blue Owl Press, 2015, ISBN 9780979183850; Donald Lambert, "Commodities Channel Index", *Commodities Magazine*, Oct 1980.
**Approved card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9925_bandy-cci-momentum-breakout-trend.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | `RISK_FIXED` | $1,000 per trade |
| Live burn-in (Q13) | `RISK_PERCENT` | Min-lot equivalent |
| Full live (post-Q13 PASS) | `RISK_PERCENT` | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | Initial build from card | Gemini Orchestration cycle |
