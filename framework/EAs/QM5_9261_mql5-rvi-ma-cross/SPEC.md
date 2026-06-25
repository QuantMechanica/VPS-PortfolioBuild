# QM5_9261_mql5-rvi-ma-cross - Strategy Spec

**EA ID:** QM5_9261
**Slug:** mql5-rvi-ma-cross
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades the H1 Relative Vigor Index plus a 100-period moving-average trend filter. It opens long when a fresh RVI(10) main-line move above the signal line, or its one-bar confirmation, occurs while the last closed H1 close is above SMA(100). It opens short on the symmetric RVI move below the signal line while the last closed H1 close is below SMA(100). Positions close on an opposite RVI cross, a close back through SMA(100), the 60 H1-bar time stop, the ATR stop, the 2.2R target, Friday close, news filter, or kill-switch.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for RVI, MA, ATR, and time-stop rules. |
| `strategy_rvi_period` | `10` | `1+` | Relative Vigor Index smoothing period. |
| `strategy_ma_period` | `100` | `1+` | Simple moving average period for the close-vs-MA trend filter and exit. |
| `strategy_atr_period` | `14` | `1+` | ATR period used for the initial stop. |
| `strategy_atr_sl_mult` | `2.0` | `> 0` | Stop distance as a multiple of ATR(14). |
| `strategy_rr_target` | `2.2` | `> 0` | Initial take-profit distance as an R multiple. |
| `strategy_max_hold_bars` | `60` | `0+` | Failsafe position time stop in H1 bars; `0` disables. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card target; liquid forex pair with complete OHLC data for RVI and MA calculations.
- `GBPJPY.DWX` - Card target; liquid forex cross with complete OHLC data for RVI and MA calculations.
- `GDAXI.DWX` - Verified DWX DAX equivalent used for the card's `GER40.DWX` target because `GER40.DWX` is not present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- Non-DWX symbols - The V5 backtest pipeline and magic registry require canonical `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework entry gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Several H1 bars up to the 60 H1-bar failsafe. |
| Expected drawdown profile | Trend-following drawdowns during choppy MA/RVI whipsaw regimes. |
| Regime preference | Momentum / trend-following. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** MQL5 article
**Pointer:** Mohamed Abdelmaaboud, "Learn how to design a trading system by Relative Vigor Index", MQL5 Articles, 2022-09-15, https://www.mql5.com/en/articles/11425
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9261_mql5-rvi-ma-cross.md`

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
| v1 | 2026-06-25 | Initial build from card | fd75d892-b0c3-41b2-a0ee-0cc1c737771f |
