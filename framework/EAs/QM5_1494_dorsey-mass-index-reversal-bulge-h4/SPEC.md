# QM5_1494_dorsey-mass-index-reversal-bulge-h4 - Strategy Spec

**EA ID:** QM5_1494
**Slug:** dorsey-mass-index-reversal-bulge-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-01

---

## 1. Strategy Logic

This EA trades Donald Dorsey's Mass Index reversal bulge on H4 bars. It computes Mass Index as the 25-bar rolling sum of EMA(9, high-low) divided by EMA(9, EMA(9, high-low)). A signal is armed when Mass Index peaks above 27 in the prior 16 H4 bars and fires when the latest closed H4 bar crosses below 26.5. Direction comes from the H4 EMA(9) at the bulge peak: peak close below EMA(9) gives a bullish reversal; peak close above EMA(9) gives a bearish reversal. The EA requires the trade direction to align with D1 close versus a rising or falling D1 SMA(50), requires ATR(14) to be above 0.6 times its 200-bar ATR baseline, and blocks fresh entries when another bulge trigger occurred in the prior 30 H4 bars. Entry is market on the H4 close, SL is fixed at 2.0 ATR, TP1 closes 60% at 1.5 ATR, and the remainder exits on EMA(9) recross or a 24-H4-bar time stop if TP1 never fired.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H4 only | Base timeframe for Mass Index, ATR, and EMA direction. |
| `strategy_mass_ema_period` | `9` | `>1` | EMA period used in the double-smoothed Mass Index ratio. |
| `strategy_mass_sum_period` | `25` | `>1` | Rolling-sum period for Mass Index. |
| `strategy_bulge_lookback` | `16` | `>0` | H4 bars searched for the prior Mass Index peak above 27. |
| `strategy_bulge_setup_threshold` | `27.0` | `> trigger` | Dorsey setup threshold. |
| `strategy_bulge_trigger_threshold` | `26.5` | `< setup` | Dorsey completion threshold crossed downward. |
| `strategy_atr_period` | `14` | `>0` | ATR period used for SL, TP1, and volatility floor. |
| `strategy_atr_baseline_bars` | `200` | `>=20` | H4 ATR baseline length for the volatility floor. |
| `strategy_atr_floor_mult` | `0.60` | `>0` | Minimum ATR as a multiple of the baseline ATR. |
| `strategy_daily_sma_period` | `50` | `>0` | D1 SMA trend-bias period. |
| `strategy_daily_sma_slope_bars` | `5` | `>0` | D1 bars used to confirm SMA(50) slope. |
| `strategy_cooldown_bars` | `30` | `>=0` | H4 bars that must be free of prior bulge triggers. |
| `strategy_atr_sl_mult` | `2.0` | `>0` | Fixed hard stop distance in ATR units. |
| `strategy_tp1_atr_mult` | `1.5` | `>0` | TP1 distance in ATR units. |
| `strategy_tp1_fraction` | `0.60` | `0-1` | Fraction of current position closed at TP1. |
| `strategy_time_stop_bars` | `24` | `>0` | H4 bars before closing if TP1 has not fired. |
| `strategy_spread_atr_fraction` | `0.15` | `>0` | Current spread cap as a fraction of H4 ATR. |
| `strategy_warmup_bars` | `250` | `>=250` | Required H4 warm-up depth before entry. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with reliable H/L bars.
- `GBPUSD.DWX` - liquid FX major with reliable H/L bars.
- `USDJPY.DWX` - liquid FX major with reliable H/L bars.
- `AUDUSD.DWX` - liquid FX major with reliable H/L bars.
- `USDCAD.DWX` - liquid FX major with reliable H/L bars.
- `NDX.DWX` - index CFD consistent with Dorsey's original equity-index context.
- `WS30.DWX` - index CFD consistent with Dorsey's original equity-index context.
- `GDAXI.DWX` - non-US index CFD diversifier.
- `UK100.DWX` - non-US index CFD diversifier.
- `XAUUSD.DWX` - liquid metal CFD with reliable H/L bars.
- `XTIUSD.DWX` - liquid energy CFD with reliable H/L bars.

**Explicitly NOT for:**
- Symbols without validated `.DWX` OHLC history - the Mass Index calculation requires stable high-low ranges and enough H4/D1 history.

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
| Trades / year / symbol | `~100` |
| Typical hold time | `1-5 trading days`, with a 24-H4-bar timeout if TP1 never fires |
| Expected drawdown profile | ATR-bounded reversal drawdowns during failed volatility-bulge reversals. |
| Regime preference | Volatility-expansion reversal aligned with daily trend. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum / TASC article / book cluster
**Pointer:** ForexFactory Trading Systems Mass Index cluster; Donald Dorsey, "The Mass Index: It Bulges Before Trend Reversals", TASC June 1992; Colby and Meyers, *The Encyclopedia of Technical Market Indicators*, 2nd ed.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1494_dorsey-mass-index-reversal-bulge-h4.md`

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
| v1 | 2026-07-01 | Initial build from approved card | pending build commit |
