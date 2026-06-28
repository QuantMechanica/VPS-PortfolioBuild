# QM5_1490_raschke-anti-pullback-reversal-h4 - Strategy Spec

**EA ID:** QM5_1490
**Slug:** `raschke-anti-pullback-reversal-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1490_raschke-anti-pullback-reversal-h4.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-28

---

## 1. Strategy Logic

The EA trades Linda Raschke's Anti setup on closed H4 bars. It builds a 3-10 oscillator from SMA(3, close) minus SMA(10, close), smooths that oscillator with a 16-bar SMA signal line, and enters when the fast oscillator retraces against a confirmed signal-line trend then re-crosses back into the D1 macro trend. Long entries require D1 close above rising D1 SMA(50), rising signal line, prior bearish retracement depth, and a bullish oscillator re-cross; shorts mirror those rules. Positions use a fixed 2.0 ATR(14) hard stop, partial profit at 1.5 ATR, and exit the remainder on signal-line slope reversal or a 24-H4-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for the 3-10 oscillator Anti trigger. |
| `strategy_macro_tf` | `PERIOD_D1` | MT5 timeframe enum | Timeframe used for the macro SMA trend gate. |
| `strategy_fast_sma_period` | `3` | `> 0` | Fast SMA period in the oscillator. |
| `strategy_slow_sma_period` | `10` | `> fast` | Slow SMA period in the oscillator. |
| `strategy_signal_sma_period` | `16` | `> 1` | SMA period applied to oscillator values. |
| `strategy_macro_sma_period` | `50` | `> 1` | D1 SMA trend period. |
| `strategy_macro_slope_bars` | `5` | `> 0` | Bars used to confirm D1 SMA slope. |
| `strategy_signal_slope_bars` | `3` | `> 0` | Bars used for signal-line slope checks. |
| `strategy_signal_confirm_bars` | `6` | `> slope` | Older signal-line sample for monotonic trend confirmation. |
| `strategy_retrace_lookback` | `8` | `> 0` | H4 bars searched for the counter-trend oscillator retracement. |
| `strategy_stdev_period` | `50` | `> 1` | Oscillator values used for retracement-depth normalization. |
| `strategy_cooldown_bars` | `30` | `> 0` | H4 bars with no prior oscillator re-cross. |
| `strategy_atr_period` | `14` | `> 0` | ATR period for stop and TP1 distance. |
| `strategy_atr_sl_mult` | `2.0` | `> 0` | Initial hard stop distance in ATR multiples. |
| `strategy_cross_sep_atr_frac` | `0.15` | `>= 0` | Minimum oscillator/signal separation as fraction of ATR. |
| `strategy_retrace_stdev_mult` | `0.40` | `> 0` | Minimum retracement depth as oscillator stdev multiple. |
| `strategy_tp1_atr_mult` | `1.5` | `> 0` | Profit distance for the 60 percent partial close. |
| `strategy_tp1_close_fraction` | `0.60` | `0-1` | Fraction of current volume closed at TP1. |
| `strategy_time_stop_bars` | `24` | `> 0` | Maximum H4 bars held without exit. |
| `strategy_max_spread_points` | `0` | `>= 0` | Optional current spread cap; zero disables to avoid DWX zero-spread fail-closed behavior. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major included by the approved card.
- `GBPUSD.DWX` - FX major included by the approved card.
- `USDJPY.DWX` - FX major included by the approved card.
- `AUDUSD.DWX` - FX major included by the approved card.
- `USDCAD.DWX` - FX major included by the approved card.
- `NDX.DWX` - index CFD included by the approved card.
- `WS30.DWX` - index CFD included by the approved card.
- `GDAXI.DWX` - European index CFD included by the approved card.
- `UK100.DWX` - European index CFD included by the approved card.
- `XAUUSD.DWX` - metal CFD included by the approved card.
- `XTIUSD.DWX` - crude oil CFD included by the approved card.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - they lack approved DWX test coverage for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` SMA(50) macro trend gate |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Hours to four trading days; time stop at 24 H4 bars. |
| Expected drawdown profile | ATR-bounded pullback-continuation system with fixed hard stop and partial profit. |
| Regime preference | Pullback-continuation inside established daily trend. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum/book
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1490_raschke-anti-pullback-reversal-h4.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1490_raschke-anti-pullback-reversal-h4.md`

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
| v1 | 2026-06-28 | Initial build from card | 7baa0340-aced-43af-9e63-aab6d2579e3f |
