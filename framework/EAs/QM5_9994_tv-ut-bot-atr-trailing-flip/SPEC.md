# QM5_9994_tv-ut-bot-atr-trailing-flip - Strategy Spec

**EA ID:** QM5_9994
**Slug:** tv-ut-bot-atr-trailing-flip
**Source:** 30591366-874b-5bee-b47c-da2fca20b728 (see `sources/tradingview-popular-pine-scripts`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades the TradingView UT Bot ATR trailing-stop flip on closed H1 bars. It rebuilds the ATR trailing line from the card's four-branch rule using ATR(10) and sensitivity k=1.0, then buys when the source crosses above the line and sells when the source crosses below it. An opposite closed-bar cross closes the current position and opens the reverse direction on the same next-bar event. Initial risk is a one-ATR catastrophic stop, with optional ATR take-profit, optional 48-bar time stop, optional Heikin-Ashi close source, and optional SMA200 trend gate left as disabled P3 parameters.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | H1 primary | Timeframe used for the UT Bot trail and cross signal. |
| `strategy_atr_period` | `10` | 7-14 P3 | ATR period `a` from the card. |
| `strategy_sensitivity_k` | `1.0` | 1.0-3.0 P3 | ATR trailing sensitivity multiplier. |
| `strategy_sl_atr_mult` | `1.0` | 1.0-2.0 P3 | Initial catastrophic stop distance in ATR multiples. |
| `strategy_tp_atr_mult` | `0.0` | 0.0, 2.0-4.0 P3 | Optional ATR take-profit; zero disables static TP. |
| `strategy_source_ema_period` | `1` | 1-3 P3 | EMA smoothing applied to the regular close signal. |
| `strategy_use_heikin_ashi_close` | `false` | true/false | Optional Heikin-Ashi close source toggle. |
| `strategy_use_sma200_filter` | `false` | true/false | Optional SMA200 trend filter toggle. |
| `strategy_sma_period` | `200` | 200 P3 | SMA period for the optional trend gate. |
| `strategy_max_hold_bars` | `0` | 0 or 48 P3 | Optional time stop in signal-timeframe bars; zero disables it. |
| `strategy_spread_sl_fraction` | `0.25` | 0.0-1.0 | Blocks entry only when positive modeled spread exceeds this fraction of SL distance. |
| `strategy_bootstrap_bars` | `300` | 50-1000 | Closed-bar warmup length for reconstructing the recursive trailing line. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major for instrument-agnostic H1 trend flips.
- `GBPUSD.DWX` - card-listed liquid FX major for instrument-agnostic H1 trend flips.
- `USDJPY.DWX` - card-listed liquid FX major for instrument-agnostic H1 trend flips.
- `XAUUSD.DWX` - card-listed gold CFD for portable volatility trend behavior.
- `XTIUSD.DWX` - card-listed crude oil CFD for portable volatility trend behavior.
- `NDX.DWX` - card-listed Nasdaq 100 index CFD for live-tradable US index exposure.
- `WS30.DWX` - card-listed Dow 30 index CFD for live-tradable US index exposure.
- `SP500.DWX` - card-noted supplementary S&P 500 backtest symbol; not live-routable.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - the tester has no approved DWX data source for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 90 |
| Typical hold time | about 2-3 trading days between flips; optional cap at 48 H1 bars |
| Expected drawdown profile | trend-following whipsaw risk in sideways regimes, bounded by the initial ATR stop |
| Regime preference | trend-following volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView community Pine script
**Pointer:** https://www.tradingview.com/script/n8ss8BID-UT-Bot-Alerts/ and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9994_tv-ut-bot-atr-trailing-flip.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9994_tv-ut-bot-atr-trailing-flip.md`

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
| v1 | 2026-06-25 | Initial build from card | 53abf4b2-d868-4db5-98ab-e12267b9d7e2 |
