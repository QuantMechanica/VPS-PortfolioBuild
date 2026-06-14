# QM5_10729_tv-smc-mss-fvg - Strategy Spec

**EA ID:** QM5_10729
**Slug:** `tv-smc-mss-fvg`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades only during the configured London and New York windows on M5 bars. A long entry requires the last closed bar to sweep below the latest confirmed swing low, close back above that swing low, close above the prior bar high, and form a bullish fair value gap where the signal-bar low is above the high from two bars earlier. A short entry mirrors the rule against the latest confirmed swing high, the prior bar low, and a bearish fair value gap. Stops are placed at the signal-bar low or high, targets are fixed at 2R, and any remaining position is closed when the active session window ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_swing_len` | 5 | >=1 | Bars on each side required to confirm pivot highs and lows. |
| `strategy_rr` | 2.0 | >0 | Reward-to-risk multiple used for the fixed target. |
| `strategy_london_start_hhmm` | 700 | 0000-2359 | Broker-time London session start. |
| `strategy_london_end_hhmm` | 1000 | 0000-2359 | Broker-time London session end. |
| `strategy_ny_start_hhmm` | 1230 | 0000-2359 | Broker-time New York session start. |
| `strategy_ny_end_hhmm` | 1600 | 0000-2359 | Broker-time New York session end. |
| `strategy_pivot_scan_bars` | 160 | >=12 | Closed-bar scan depth used to find the latest confirmed pivot. |
| `strategy_max_spread_points` | 0 | >=0 | Optional spread ceiling; 0 disables the strategy-level spread filter. |
| `strategy_min_stop_points` | 0 | >=0 | Optional minimum signal-bar stop distance in points, combined with broker stop-level minimum. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - Primary metal symbol named in the card and available in the DWX matrix.
- `NDX.DWX` - Index CFD named in the card and available in the DWX matrix.
- `GBPUSD.DWX` - FX major named in the card and available in the DWX matrix.
- `EURUSD.DWX` - FX major named in the card and available in the DWX matrix.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts must use registered `.DWX` symbols only.

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
| Trades / year / symbol | `60` |
| Typical hold time | Intraday; exits at SL, 2R TP, or London/New York session end. |
| Expected drawdown profile | Stop-defined per-trade losses with no pyramiding. |
| Regime preference | Liquidity sweep followed by structure shift and fair-value-gap displacement. |
| Win rate target (qualitative) | Medium; fixed 2R target allows sub-50% break-even threshold before costs. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy script
**Pointer:** `https://www.tradingview.com/script/QpR7OWpA-SMC-ICT-Backtest-XAUUSD-MNQ/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10729_tv-smc-mss-fvg.md`

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
| v1 | 2026-06-14 | Initial build from card | 19c9e8dc-f0c5-45d9-bce1-a7c2a4d123ca |
