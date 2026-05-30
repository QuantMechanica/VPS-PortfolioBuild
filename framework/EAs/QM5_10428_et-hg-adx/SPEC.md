# QM5_10428_et-hg-adx - Strategy Spec

**EA ID:** QM5_10428
**Slug:** `et-hg-adx`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

The EA trades a completed-bar ADX pullback setup. A long setup requires ADX(14) above 30, the close below EMA(20), and SMA(5) rising; it places a buy stop at the signal bar high for the next bar. A short setup requires ADX(14) above 30, the close above EMA(20), and SMA(5) falling; it places a sell stop at the signal bar low for the next bar. Stops use the last three completed bars with a 1.0 ATR(20) minimum distance, targets use the last ten completed bars, and a fallback exit closes positions after 20 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_adx_period` | 14 | 1+ | ADX lookback for trend-strength filter |
| `strategy_adx_cutoff` | 30.0 | 0+ | Minimum ADX value required for a setup |
| `strategy_xma_period` | 20 | 1+ | EMA length used for the pullback condition |
| `strategy_sma_slope_period` | 5 | 1+ | SMA length used to measure slope direction |
| `strategy_stop_lookback` | 3 | 1+ | Completed bars used for swing stop extreme |
| `strategy_target_lookback` | 10 | 1+ | Completed bars used for target extreme |
| `strategy_atr_period` | 20 | 1+ | ATR lookback for minimum stop-distance floor |
| `strategy_atr_floor_mult` | 1.0 | 0+ | ATR multiple used as minimum stop distance |
| `strategy_max_hold_bars` | 20 | 1+ | Fallback time exit in completed bars |
| `strategy_pending_bars` | 1 | 1+ | Stop-entry validity in bars |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed FX major with DWX OHLC coverage.
- `GBPUSD.DWX` - Card-listed FX major with DWX OHLC coverage.
- `XAUUSD.DWX` - Card-listed metal with DWX OHLC coverage.
- `SP500.DWX` - Card-listed S&P 500 custom symbol, valid for backtest-only build registration.
- `NDX.DWX` - Card-listed US index with DWX OHLC coverage.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX data path for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `24` |
| Typical hold time | up to 20 D1 bars |
| Expected drawdown profile | Trend-pullback logic with weak source evidence; expect filtering by G0/P2 if edge is absent |
| Regime preference | ADX trend with countertrend pullback |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://elitetrader.com/et/posts/180289/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10428_et-hg-adx.md`

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
| v1 | 2026-05-27 | Initial build from card | 1ec5859f-4850-41e1-8431-c798ef658293 |
