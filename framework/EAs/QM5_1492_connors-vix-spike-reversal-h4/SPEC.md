# QM5_1492_connors-vix-spike-reversal-h4 — Strategy Spec

**EA ID:** QM5_1492
**Slug:** connors-vix-spike-reversal-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

This EA trades long-only H4 volatility-spike reversals on index CFDs. An entry fires when ATR(14) on the last closed H4 bar is more than 1.5 times its 50-bar ATR baseline, one of the two prior H4 bars is still above 1.3 times baseline, price is above a rising H4 SMA(200), the last two H4 closes are below SMA(5), and the last closed D1 bar is above a rising D1 SMA(50). The EA blocks another entry if the same complete trigger appeared in the previous 12 H4 bars, uses a fixed 2.0 ATR stop from entry, closes 60% above H4 SMA(5), closes the remainder above H4 SMA(10), and closes full size after 16 H4 bars if TP1 never fired.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H4 only | Base timeframe for all H4 entry and exit signals. |
| `strategy_atr_period` | `14` | `>0` | ATR period used for stretch and stop distance. |
| `strategy_atr_baseline_bars` | `50` | `1-80` | Number of ATR bars in the long volatility baseline. |
| `strategy_spike_threshold` | `1.5` | `>0` | Current ATR stretch required for entry. |
| `strategy_confirm_threshold` | `1.3` | `>0` | Prior-bar ATR stretch required for confirmation. |
| `strategy_long_sma_period` | `200` | `>0` | H4 long-trend SMA period. |
| `strategy_long_sma_slope_bars` | `10` | `>0` | H4 bars used to confirm the SMA(200) is rising. |
| `strategy_pullback_sma_period` | `5` | `>0` | H4 fast SMA used for pullback and TP1. |
| `strategy_daily_sma_period` | `50` | `>0` | D1 trend-confirmation SMA period. |
| `strategy_daily_sma_slope_bars` | `5` | `>0` | D1 bars used to confirm the daily SMA is rising. |
| `strategy_cooldown_bars` | `12` | `0-24` | H4 bars checked for recent prior triggers. |
| `strategy_atr_sl_mult` | `2.0` | `>0` | ATR multiple for the hard stop. |
| `strategy_time_stop_bars` | `16` | `>0` | H4 bars before time-stop if TP1 has not fired. |
| `strategy_tp2_sma_period` | `10` | `>0` | H4 SMA used for the final exit. |
| `strategy_tp1_fraction` | `0.60` | `0-1` | Fraction of current position closed at TP1. |
| `strategy_tp_done_volume_ratio` | `0.50` | `0-1` | Volume ratio used to infer TP1 has already fired. |
| `strategy_spread_atr_fraction` | `0.15` | `>0` | Current spread cap as a fraction of H4 ATR. |
| `strategy_warmup_bars` | `250` | `>=200` | Minimum H4 closed-bar depth required before entry. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — Nasdaq 100 index CFD fits the equity-index volatility-spike reversal mechanism.
- `WS30.DWX` — Dow 30 index CFD provides a second liquid US large-cap index.
- `GDAXI.DWX` — DAX 40 index CFD extends the same index microstructure to Germany.
- `UK100.DWX` — FTSE 100 index CFD extends the same index microstructure to the UK.
- `SP500.DWX` — S&P 500 custom symbol is the closest Connors/SPY analogue and is valid for backtests.

**Explicitly NOT for:**
- Forex, metals, and energy symbols — the card excludes non-index markets because the ATR-stretch port is calibrated to equity-index microstructure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` SMA(50) close and slope confirmation |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | `1-3 trading days` (`16` H4 bars maximum without TP1) |
| Expected drawdown profile | ATR-bounded mean-reversion drawdowns during failed index rebounds. |
| Regime preference | Volatility-spike mean reversion inside a rising index trend. |
| Win rate target (qualitative) | medium-high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum / book cluster
**Pointer:** ForexFactory Trading Systems Connors VIX EA cluster plus Connors and Alvarez, *Short Term Trading Strategies That Work*, chapters 9-10.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1492_connors-vix-spike-reversal-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-30 | Initial build from card | 2e52925a-f50e-4e36-8394-35738beab9bb |
