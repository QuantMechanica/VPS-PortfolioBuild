# QM5_12916_chfjpy-carry-trend-swing - Strategy Spec

**EA ID:** QM5_12916  
**Slug:** `chfjpy-carry-trend-swing`  
**Source:** `CEO-SWING-SLATE-2026-07-02`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements the approved CHFJPY D1 carry-trend swing card. It is long
only. Regime requires the last closed D1 close above SMA(200) and above the
close 63 D1 bars earlier. Entry occurs when the last closed D1 close crosses
back above SMA(10) from below while the regime is active. Exit occurs when the
last closed D1 close is below SMA(50). A 3.0 x ATR(20) hard stop is used as
the framework risk-sizing stop.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_sma_regime_period` | 200 | Trend regime SMA |
| `strategy_momentum_lookback` | 63 | D1 momentum lookback |
| `strategy_sma_entry_period` | 10 | Pullback recovery SMA |
| `strategy_sma_exit_period` | 50 | Trend failure exit SMA |
| `strategy_atr_period` | 20 | Risk stop ATR period |
| `strategy_atr_sl_mult` | 3.0 | Risk stop ATR multiple |

## 3. Symbol Universe

- `CHFJPY.DWX`, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Entry gating: `QM_IsNewBar()`.
- Signal and exit reads use closed D1 bars.

## 5. Expected Behaviour

Expected frequency is low: about 3-6 trades per year on CHFJPY.DWX D1 with
multi-week holds. The EA should trade only on the target symbol/timeframe,
evaluate entries on new D1 bars, hold through weekends, and exit on SMA(50)
trend failure or the framework stop. Zero intraday scaling, grid, martingale,
or ML behaviour is expected.

## 6. Source Citation

Primary evidence comes from peer-reviewed FX carry and momentum literature:
Koijen, Moskowitz, Pedersen, and Vrugt (2018), "Carry", Journal of Financial
Economics 127(2); and Menkhoff et al. (2012), "Currency momentum strategies",
Journal of Financial Economics 106(3). The implemented mechanic combines
structural JPY funding/carry exposure with a deterministic D1 trend and
three-month momentum filter.

## 7. Risk Model

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`. Friday close defaults to
disabled for the approved multi-week swing hold.

Q02 queue note (2026-07-02): build task
`2d939c34-15a3-48c2-8873-5a9324ffafb2` was recorded done after strict
compile/build_check/SPEC/symbol-scope PASS. The farm has one pending Q02 work
item, `c11ef2fc-b709-405e-bbd1-c130cc3e257a`, for `CHFJPY.DWX` D1. The item
was inserted by the never-tested sweep and record-build skipped it as an
existing pending duplicate; no manual MT5 backtest was launched.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-07-02 | Initial WS3 build from approved card |
| v2 | 2026-07-02 | Q01 SPEC layout repair and raw-series build-check exception documentation |
