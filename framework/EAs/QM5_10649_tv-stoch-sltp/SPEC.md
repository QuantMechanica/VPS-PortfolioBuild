# QM5_10649_tv-stoch-sltp — Strategy Spec

**EA ID:** QM5_10649
**Slug:** `tv-stoch-sltp`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Long-only mean-reversion on the Stochastic oscillator. Enter long when %K(14,
smoothed 3) crosses above %D (3-period SMA of %K) while both lines are below
20 (oversold). Exit at a fixed +6.0% take profit, a fixed -2.5% stop loss, a
momentum-reversal exit when %K crosses back below %D while both lines are
above 60, or a time stop after 96 M15 bars — whichever comes first. No
pyramiding: fresh oversold crosses are ignored while a position is open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_stoch_k_period` | 14 | fixed | Stochastic %K length |
| `strategy_stoch_d_period` | 3 | fixed | %D smoothing period |
| `strategy_stoch_slowing` | 3 | fixed | %K smoothing |
| `strategy_stoch_oversold` | 20.0 | fixed | entry threshold, both K & D below |
| `strategy_stoch_reversal` | 60.0 | fixed | exit threshold, both K & D above |
| `strategy_tp_pct` | 6.0 | fixed | take profit, % of entry price |
| `strategy_sl_pct` | 2.5 | fixed | stop loss, % of entry price |
| `strategy_time_exit_bars` | 96 | fixed | bar-count time stop |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — card lists GER40.DWX; GER40.DWX is not in `dwx_symbol_matrix.csv`, ported to the canonical DAX Custom Symbol GDAXI.DWX.
- `XAUUSD.DWX` — card primary symbol, OHLC-derived oscillator ports cleanly.
- `EURUSD.DWX` — card primary symbol.
- `GBPUSD.DWX` — card primary symbol.

**Explicitly NOT for:**
- `GER40.DWX` — not a valid Custom Symbol name in the matrix; see GDAXI.DWX above.

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
| Trades / year / symbol | ~40-80 |
| Typical hold time | minutes to ~24h (96 M15 bars max) |
| Expected drawdown profile | shallow, frequent small losses from fixed 2.5% SL |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** forum (TradingView script listing)
**Pointer:** https://www.tradingview.com/script/EVvWJ4Us-Stochastic-Bot-with-SL-TP/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10649_tv-stoch-sltp.md`

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
| v1 | 2026-08-10 | Initial build from card | agent_router task 3371d2a0 |
