# QM5_10933_grimes-cup-hndl - Strategy Spec

**EA ID:** QM5_10933
**Slug:** grimes-cup-hndl
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c (see `strategy-seeds/sources/fbfd7f6e-462a-55c8-9efa-9005a70c9f5c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA evaluates a D1 cup-and-handle or inverted cup-and-handle breakout after each closed D1 bar. A long setup requires W1 EMA(20) rising over five W1 bars, a 15-60 bar rounded D1 base with similar left and right rim highs, a 3-15 bar handle that pulls back no more than half the base depth, and a close above the right rim by 0.1 ATR(20). A short setup mirrors the same geometry with W1 EMA(20) falling, inverted base support, and a close below the right rim by 0.1 ATR(20).

The stop is placed beyond the handle extreme by 0.25 ATR(20), trades are rejected when the stop is wider than 3.5 ATR(20), and the target is 2R. The EA moves the stop to breakeven at 1R, exits after 20 D1 bars, and exits after the 0.75R trigger if the next three D1 closes fail to stay beyond the rim in the trade direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 20 | 5-100 | ATR period used for rim tolerance, breakout buffer, stop buffer, and overextension filter. |
| `strategy_w1_ema_period` | 20 | 5-100 | Weekly EMA period for higher-timeframe trend slope. |
| `strategy_w1_slope_bars` | 5 | 1-20 | Number of W1 bars used to test EMA slope direction. |
| `strategy_base_min_bars` | 15 | 5-60 | Minimum D1 rounded-base length. |
| `strategy_base_max_bars` | 60 | 15-120 | Maximum D1 rounded-base length. |
| `strategy_handle_min_bars` | 3 | 1-10 | Minimum D1 handle length. |
| `strategy_handle_max_bars` | 15 | 3-30 | Maximum D1 handle length. |
| `strategy_rim_atr_tolerance` | 1.0 | 0.1-3.0 | Maximum ATR distance between left and right rim. |
| `strategy_breakout_atr_buffer` | 0.10 | 0.0-1.0 | Required close beyond the right rim as ATR multiple. |
| `strategy_max_handle_pullback` | 0.50 | 0.1-1.0 | Maximum handle pullback as fraction of base depth. |
| `strategy_stop_atr_buffer` | 0.25 | 0.0-2.0 | ATR buffer beyond handle low or high for stop placement. |
| `strategy_max_stop_atr` | 3.50 | 0.5-10.0 | Maximum allowed stop distance as ATR multiple. |
| `strategy_overextension_atr` | 3.00 | 0.5-10.0 | Rejects breakouts too far from D1 EMA(20). |
| `strategy_target_r` | 2.00 | 0.5-10.0 | Profit target in initial-risk multiples. |
| `strategy_breakeven_r` | 1.00 | 0.1-5.0 | Move stop to entry after this R multiple. |
| `strategy_failure_trigger_r` | 0.75 | 0.1-5.0 | Starts the breakout-failure close test after this R multiple. |
| `strategy_failure_bars` | 3 | 1-10 | Number of D1 closes used for breakout-failure exit. |
| `strategy_time_exit_bars` | 20 | 1-100 | Maximum hold time in D1 bars. |
| `strategy_max_spread_stop_frac` | 0.10 | 0.0-0.5 | Maximum spread as fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX symbol with D1/W1 OHLC and ATR/EMA data.
- `GBPUSD.DWX` - card-listed major FX symbol with D1/W1 OHLC and ATR/EMA data.
- `USDJPY.DWX` - card-listed major FX symbol with D1/W1 OHLC and ATR/EMA data.
- `NDX.DWX` - card-listed liquid index CFD for large-cap trend breakouts.
- `GDAXI.DWX` - canonical DWX DAX symbol; used because the card's `GER40.DWX` is not present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- `GER40.DWX` - absent from `dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not canonical DWX S&P 500 symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | W1 EMA(20) slope over five W1 bars |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Up to 20 D1 bars by card time exit |
| Expected drawdown profile | Breakout strategy with losing trades capped by handle-plus-ATR stops and 2R targets. |
| Regime preference | D1 breakout after higher-timeframe trend shift |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "Failure is NOT always an option", 2020-07-31, https://www.adamhgrimes.com/failure-is-not-always-an-option/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10933_grimes-cup-hndl.md`

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
| v1 | 2026-06-06 | Initial build from card | 3c0f2535-f55d-47f4-8a41-cdfa4c3387a0 |
