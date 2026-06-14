# QM5_10867_tv-xau-smc-0618 - Strategy Spec

**EA ID:** QM5_10867
**Slug:** tv-xau-smc-0618
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades failed breaks of recent confirmed swing levels on M5 or M15. A long signal occurs when the last closed bar sweeps below a recent pivot low, closes back above that pivot level, has a sweep wick of at least 0.4 ATR(14), and EMA(20) is sloping up. A short signal is the mirror image above a recent pivot high with EMA(20) sloping down. Entries are next-bar market orders, stops sit beyond the sweep extreme with an ATR buffer and at least 1.0 ATR distance, targets use a fixed 1.5R, and open positions close on an opposite sweep-reclaim signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_pivot_lookback | 5 | 3-8 | Bars on each side required to confirm a swing pivot. |
| strategy_pivot_scan_bars | 80 | 20-200 | Closed-bar window scanned for the most recent confirmed pivots. |
| strategy_atr_period | 14 | 5-50 | ATR period for wick, stop buffer, and minimum stop distance. |
| strategy_sweep_wick_min_atr | 0.40 | 0.25-0.60 | Minimum sweep wick beyond the pivot, expressed as ATR. |
| strategy_ema_slope_period | 20 | 0, 20, 50 | EMA slope filter period; 0 disables the filter. |
| strategy_stop_atr_buffer | 0.20 | 0.00-1.00 | ATR buffer beyond the sweep extreme. |
| strategy_min_stop_atr | 1.00 | 0.50-3.00 | Minimum stop distance in ATR units. |
| strategy_target_r | 1.50 | 1.20-2.00 | Fixed reward multiple from entry to stop distance. |
| strategy_session_start_hour | 13 | 0-23 | Broker-time start hour for London/New York overlap. |
| strategy_session_end_hour | 17 | 0-23 | Broker-time end hour for London/New York overlap. |
| strategy_cooldown_bars | 5 | 0-20 | Bars to wait after an exit before allowing a new entry. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - primary gold market named in the source and card.
- XAGUSD.DWX - liquid precious-metals analogue for sweep/reclaim testing.
- EURUSD.DWX - liquid forex baseline with full DWX OHLC coverage.
- NDX.DWX - liquid index CFD from the card basket.
- GDAXI.DWX - registered DAX proxy because `GER40.DWX` is not in the DWX matrix.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; DAX exposure uses GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 and M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | intraday, minutes to hours |
| Expected drawdown profile | High-cadence reversal system with ATR-normalized stop distance. |
| Regime preference | liquidity sweep mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/yid8vrVZ-XAUUSD-Quant-SMC-Trader-0-6-18-BETA/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10867_tv-xau-smc-0618.md`

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
| v1 | 2026-06-14 | Initial build from card | 975c3dda-3eb1-45d2-873e-0b947b197317 |
