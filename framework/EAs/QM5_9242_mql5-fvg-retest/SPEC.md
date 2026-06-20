# QM5_9242_mql5-fvg-retest - Strategy Spec

**EA ID:** QM5_9242
**Slug:** mql5-fvg-retest
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA scans confirmed three-candle fair value gaps on M15. A long setup requires a bullish gap that has not been mitigated or previously retested, an H1 same-direction fair value gap or close above H1 EMA(100), and a closed M15 retest bar that touches the gap and closes above its midpoint. A short setup mirrors the rule below the midpoint with bearish geometry and H1 bearish alignment. Exits are the fixed 2R target, an opposite retest signal, or a 32-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR period used for minimum gap height and stop offset. |
| `strategy_min_gap_atr_mult` | 0.25 | 0.05-3.00 | Minimum FVG height as a multiple of ATR. |
| `strategy_sl_atr_mult` | 0.40 | 0.05-5.00 | ATR offset beyond the FVG bound for stop placement. |
| `strategy_rr_target` | 2.00 | 0.50-10.00 | Reward-to-risk multiple for take-profit. |
| `strategy_max_hold_bars` | 32 | 1-256 | Maximum M15 bars to hold before strategy close. |
| `strategy_scan_lookback` | 96 | 12-500 | M15 closed-bar window scanned for active FVGs. |
| `strategy_htf_ema_period` | 100 | 10-300 | H1 EMA period used as alternate alignment filter. |
| `strategy_htf_scan_lookback` | 96 | 12-500 | H1 closed-bar window scanned for active same-direction FVGs. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-approved major FX symbol with DWX OHLC and ATR history.
- `GBPJPY.DWX` - card-approved FX cross with DWX OHLC and ATR history.
- `XAUUSD.DWX` - card-approved gold symbol with DWX OHLC and ATR history.

**Explicitly NOT for:**
- Non-DWX symbols - build and P2 use the Darwinex `.DWX` custom-symbol registry only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `H1` FVG scan and EMA(100) alignment |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday, capped at 32 M15 bars |
| Expected drawdown profile | ATR-bounded losses with fixed 2R target and one position per magic. |
| Regime preference | Volatility-expansion imbalance retest with higher-timeframe alignment |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** MQL5 article
**Pointer:** Amanda Vitoria De Paula Pereira, "Building an Object-Oriented FVG Scanner in MQL5", 2026-05-08, https://www.mql5.com/en/articles/22264
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9242_mql5-fvg-retest.md`

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
| v1 | 2026-06-20 | Initial build from card | 7af57d74-2e6a-45af-bf56-5eac4e854059 |
