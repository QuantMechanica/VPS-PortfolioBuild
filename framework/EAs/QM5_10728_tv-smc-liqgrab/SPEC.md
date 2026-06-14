# QM5_10728_tv-smc-liqgrab - Strategy Spec

**EA ID:** QM5_10728
**Slug:** tv-smc-liqgrab
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA watches the last completed H4 candle as the active liquidity range and evaluates entries on the execution chart, default M15. A long signal occurs when the last completed execution bar trades below the H4 low and closes back above it; a short signal occurs when it trades above the H4 high and closes back below it. The stop is the most adverse low or high from the last `strategy_swing_lookback` execution bars, bounded to 0.30 to 3.00 ATR(14), and the target is fixed at `strategy_rr` times initial risk. The EA has no discretionary close beyond broker SL/TP and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_htf_timeframe` | `PERIOD_H4` | MT5 timeframe enum | Higher timeframe used for previous candle liquidity high/low. |
| `strategy_swing_lookback` | `5` | `1+` | Execution bars scanned for structure stop placement. |
| `strategy_atr_period` | `14` | `1+` | ATR period for stop-distance eligibility. |
| `strategy_min_stop_atr` | `0.30` | `0+` | Minimum accepted stop distance as ATR multiple. |
| `strategy_max_stop_atr` | `3.00` | `0+` | Maximum accepted stop distance as ATR multiple. |
| `strategy_rr` | `2.00` | `0+` | Take-profit multiple of initial stop risk. |
| `strategy_max_spread_points` | `0` | `0+` | Optional spread block in points; `0` disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with deep liquidity and H4/M15 history.
- `GBPUSD.DWX` - card-listed major FX pair with deep liquidity and H4/M15 history.
- `XAUUSD.DWX` - card-listed metal with frequent sweep/mean-reversion behavior.
- `GDAXI.DWX` - DWX matrix DAX symbol, used as the available port for card-listed `GER40.DWX`.
- `NDX.DWX` - card-listed large-cap index CFD with liquid intraday structure.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; DAX exposure is registered as `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `PERIOD_H4` previous candle high/low |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | intraday to multi-session, bounded by SL/TP and Friday close |
| Expected drawdown profile | clustered losses during trend continuation through H4 levels |
| Regime preference | liquidity-sweep mean reversion around H4 highs/lows |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source script
**Pointer:** TradingView script `SMC Liquidity Grab Pro`, author handle `Ericem`, published Jan 11, https://www.tradingview.com/script/WZ4s1MRC-SMC-Liquidity-Grab-Pro/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10728_tv-smc-liqgrab.md`

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
| v1 | 2026-06-14 | Initial build from card | acb62800-e4b2-43af-ab8d-6350c97424ca |
