# QM5_10414_et-stoch-scalp — Strategy Spec

**EA ID:** QM5_10414
**Slug:** `et-stoch-scalp`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades a stochastic reversal scalp on the close of M15 bars. A long setup appears when StochK(4) was below 20 on the prior bar and closes above 50 on the signal bar; it places a buy stop at the signal-bar high with the stop below the signal-bar low plus a spread buffer. A short setup mirrors the rule from above 80 to below 50 and places a sell stop at the signal-bar low. Open positions exit when price touches the nearest qualifying SMA(50) or SMA(200), or after 8 bars if no moving-average exit is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_stoch_k_period` | 4 | 4-14 | Stochastic K period from the card baseline and test grid. |
| `strategy_stoch_d_period` | 3 | 1-10 | Stochastic D period used by the framework stochastic reader. |
| `strategy_stoch_slowing` | 3 | 1-10 | Stochastic slowing used by the framework stochastic reader. |
| `strategy_oversold_level` | 20.0 | 5-40 | Prior-bar long setup threshold. |
| `strategy_overbought_level` | 80.0 | 60-95 | Prior-bar short setup threshold. |
| `strategy_midline_level` | 50.0 | 45-55 | Signal-bar stochastic trigger level. |
| `strategy_exit_bars` | 8 | 4-12 | Maximum holding time in bars. |
| `strategy_fast_sma_period` | 50 | 20-100 | First moving-average exit reference. |
| `strategy_slow_sma_period` | 200 | 100-300 | Second moving-average exit reference. |
| `strategy_atr_period` | 20 | 10-30 | ATR period for the trigger-bar stop-distance cap. |
| `strategy_max_stop_atr_mult` | 1.5 | 0.5-3.0 | Reject setup when stop distance exceeds this ATR multiple. |
| `strategy_spread_buffer_mult` | 1.0 | 0-3.0 | Spread buffer added beyond the trigger-bar stop side. |
| `strategy_max_spread_atr_mult` | 0.20 | 0.05-0.50 | Spread guard as a fraction of ATR. |
| `strategy_us_start_hhmm` | 1530 | 0-2359 | Liquid-session start for US index CFDs. |
| `strategy_us_end_hhmm` | 2200 | 0-2400 | Liquid-session end for US index CFDs. |
| `strategy_dax_start_hhmm` | 900 | 0-2359 | Liquid-session start for the DAX proxy. |
| `strategy_dax_end_hhmm` | 1730 | 0-2400 | Liquid-session end for the DAX proxy. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — card-stated S&P 500 proxy and available custom backtest symbol.
- `NDX.DWX` — card-stated Nasdaq 100 proxy using the same index CFD scalp mechanics.
- `WS30.DWX` — card-stated Dow 30 proxy using the same index CFD scalp mechanics.
- `GDAXI.DWX` — available DWX DAX custom symbol used as the matrix-valid port for card-stated `GER40.DWX`.
- `XAUUSD.DWX` — card-stated liquid metal symbol with stochastic/OHLC/SMA data available in DWX.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX proxy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday, up to 8 M15 bars |
| Expected drawdown profile | High-turnover oscillator scalp, sensitive to spread and trend days |
| Regime preference | Mean-revert / intraday stochastic reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://elitetrader.com/et/threads/a-simple-scalping-method.3759/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10414_et-stoch-scalp.md`

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
| v1 | 2026-05-25 | Initial build from card | 691c49c0-1d84-4bdc-8771-54086c799e95 |
