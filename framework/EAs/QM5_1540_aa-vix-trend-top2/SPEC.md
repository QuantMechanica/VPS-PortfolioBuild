# QM5_1540_aa-vix-trend-top2 - Strategy Spec

**EA ID:** QM5_1540
**Slug:** aa-vix-trend-top2
**Source:** ede348b4-0fa7-5be1-baa8-09e9089b67b7 (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA is a monthly long/cash rotation system. It reads a daily VIX signal, classifies the volatility regime using SMA(VIX,40) and SMA(VIX,20), then ranks the registered DWX universe by the regime-specific return lookback: 10 months in green regimes, 3 months in yellow regimes, and 1 month in red regimes. At each monthly rebalance, it opens long positions only in the top two symbols with positive lookback returns and closes any held symbol that is no longer selected or no longer positive.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_vix_symbol` | `VIX.DWX` | valid signal symbol | Daily VIX close series used for regime classification. |
| `strategy_vix_sma_slow_d1` | 40 | >= 2 | Slow VIX SMA period for green/yellow/red regime logic. |
| `strategy_vix_sma_fast_d1` | 20 | >= 2 and <= slow | Fast VIX SMA period for red regime logic. |
| `strategy_vix_green_max` | 18.0 | > 0 | Green regime threshold for SMA(VIX,40). |
| `strategy_vix_red_min` | 32.0 | > 0 | Red regime threshold for SMA(VIX,20). |
| `strategy_green_lookback_mo` | 10 | >= 1 | Return ranking lookback in green regimes. |
| `strategy_yellow_lookback_mo` | 3 | >= 1 | Return ranking lookback in yellow regimes. |
| `strategy_red_lookback_mo` | 1 | >= 1 | Return ranking lookback in red regimes. |
| `strategy_month_proxy_bars` | 21 | >= 1 | D1 bars used as the month proxy because MN1 is unavailable in DWX tests. |
| `strategy_top_slots` | 2 | 1-9 | Maximum number of positive-return symbols to hold. |
| `strategy_min_daily_bars` | 220 | >= lookback | Minimum D1 history required for the 10-month ranking window. |
| `strategy_vix_stale_days` | 2 | >= 0 | Maximum allowed weekday gap between VIX and symbol D1 data before fail-closed. |
| `strategy_atr_period_d1` | 20 | >= 1 | ATR period used for initial stop placement. |
| `strategy_atr_sl_mult` | 3.0 | > 0 | Initial stop distance in ATR multiples. |
| `strategy_spread_atr_mult` | 0.25 | >= 0 | Blocks genuinely wide spreads relative to D1 ATR; zero modeled DWX spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 proxy from the card's risky universe; backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 proxy from the card's risky universe.
- `WS30.DWX` - Dow 30 proxy from the card's risky universe.
- `GDAXI.DWX` - DAX proxy from the card's risky universe.
- `XAUUSD.DWX` - Gold proxy from the card's risky universe.
- `XTIUSD.DWX` - Oil proxy used because `USOIL.DWX` is not in the DWX matrix.
- `EURUSD.DWX` - FX major from the card's risky universe.
- `GBPUSD.DWX` - FX major from the card's risky universe.
- `USDJPY.DWX` - FX major from the card's risky universe.

**Explicitly NOT for:**
- `USOIL.DWX` - not present in `dwx_symbol_matrix.csv`; mapped to `XTIUSD.DWX`.
- `SPY.DWX`, `SPX500.DWX`, `ES.DWX` - unavailable S&P variants; `SP500.DWX` is the canonical DWX symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `VIX.DWX` D1 signal symbol |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with one D1 consume in `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Monthly rotation, usually weeks to months |
| Expected drawdown profile | Trend-following rotation drawdowns during cross-asset whipsaw or broad risk-off periods |
| Regime preference | volatility-regime relative momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Source type:** blog
**Pointer:** Andrew Miller, "VIX and Trend-Following, the Killer Combo?", 2017-09-28, https://alphaarchitect.com/vix-and-trend-following-the-killer-combo/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1540_aa-vix-trend-top2.md`

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
| v1 | 2026-06-26 | Initial build from card | e6ea9918-5518-48dc-a94d-333f02e9c0f5 |
