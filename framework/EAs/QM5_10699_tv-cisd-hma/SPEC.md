# QM5_10699_tv-cisd-hma - Strategy Spec

**EA ID:** QM5_10699
**Slug:** `tv-cisd-hma`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved TradingView card)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades closed-bar liquidity sweeps around confirmed swing pivots. A long setup requires price to trade below a recent confirmed swing low, close back above that level, and then print a bullish CISD close above the prior candle high within the configured window. A short setup mirrors the rule above a confirmed swing high with a bearish close below the prior candle low. If enabled, the Hull MA filter requires price and HMA slope to agree with the reversal direction; exits are handled by ATR-based stop loss and a fixed R:R take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pivot_length` | 5 | 2-10 | Left/right closed bars required to confirm a swing pivot. |
| `strategy_swing_scan_bars` | 40 | 10-100 | Maximum depth scanned for the most recent confirmed swing. |
| `strategy_cisd_window_bars` | 2 | 1-3 | Bars allowed from sweep to CISD confirmation. |
| `strategy_hma_period` | 55 | 0, 55, 100 | Hull MA filter period; 0 disables the filter. |
| `strategy_atr_period` | 14 | 5-50 | ATR lookback for stop sizing. |
| `strategy_atr_sl_mult` | 1.5 | 1.0-2.0 | ATR multiplier for the baseline stop distance. |
| `strategy_sweep_atr_buffer` | 0.1 | 0.0-0.5 | ATR buffer beyond the swept swing extreme. |
| `strategy_rr_target` | 2.0 | 1.5-3.0 | Take-profit reward:risk multiple. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - Card primary includes XAUUSD and the strategy is built around liquid intraday sweep behaviour.
- `NDX.DWX` - Card includes NDX.DWX as a liquid index CFD target.
- `GDAXI.DWX` - Registered as the DWX matrix DAX equivalent for the card's GER40.DWX target.
- `EURUSD.DWX` - Card includes EURUSD.DWX as a liquid FX target.
- `GBPUSD.DWX` - Card includes GBPUSD.DWX as a liquid FX target.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX` instead.
- `SPX500.DWX` - Not a canonical DWX symbol; this card does not request S&P 500 exposure.
- Thin or non-DWX symbols - The implementation assumes broker/tester data from the DWX matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `160` |
| Typical hold time | intraday, minutes to hours |
| Expected drawdown profile | Fast reversal strategy with slippage and spread sensitivity on metals and indices. |
| Regime preference | mean-revert / liquidity-sweep reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView protected-source strategy page
**Pointer:** `https://www.tradingview.com/script/jksy8E6M-Liquidity-Sweep-pro/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10699_tv-cisd-hma.md`

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
| v1 | 2026-05-31 | Initial build from card | d03a1514-b345-4d63-a3c3-551d6ecaa161 |
