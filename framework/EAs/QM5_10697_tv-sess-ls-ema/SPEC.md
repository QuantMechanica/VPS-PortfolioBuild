# QM5_10697_tv-sess-ls-ema - Strategy Spec

**EA ID:** QM5_10697
**Slug:** tv-sess-ls-ema
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-04

---

## 1. Strategy Logic

This EA trades failed breaks of a recent intraday range during a configured session. A long setup requires the closed signal bar to trade below the prior N-bar low, close back above that low, and close above EMA(50). A short setup requires the closed signal bar to trade above the prior N-bar high, close back below that high, and close below EMA(50). Stops use ATR times the configured multiplier, targets use fixed R:R, and any still-open position is flattened outside the session window.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_liquidity_lookback` | 20 | 10-30 tested | Number of prior bars used to define sweep high and low. |
| `strategy_ema_period` | 50 | 34-100 tested | EMA trend filter period. |
| `strategy_atr_period` | 14 | 14-20 tested | ATR period for stop distance and sweep-range filter. |
| `strategy_atr_stop_mult` | 1.5 | 1.0-2.0 tested | ATR multiplier for stop loss. |
| `strategy_rr_target` | 2.5 | 1.5-2.5 tested | Take-profit multiple of entry risk. |
| `strategy_session_start_hhmm` | 930 | 0-2359 | Start of allowed signal session in broker-time HHMM. |
| `strategy_session_end_hhmm` | 1100 | 0-2359 | End of allowed signal session in broker-time HHMM. |
| `strategy_min_sweep_range_atr` | 0.5 | 0.0 disables | Optional P2 skip when sweep bar range is below this ATR fraction. |
| `strategy_max_spread_points` | 0 | 0 disables | Optional spread ceiling in points for the no-trade filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with London/NY overlap behaviour.
- `GBPUSD.DWX` - liquid FX major with London/NY overlap behaviour.
- `USDJPY.DWX` - liquid FX major with London/NY overlap behaviour.
- `XAUUSD.DWX` - canonical DWX gold symbol for the card's XAUUSD target.
- `NDX.DWX` - liquid US index CFD for cash-open sweep behaviour.
- `WS30.DWX` - liquid US index CFD for cash-open sweep behaviour.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX data source.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` smoke baseline, with `M5` also generated for the card's M5-M15 range |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | Intraday, minutes to session end if TP/SL does not trigger |
| Expected drawdown profile | Repeated stop-outs possible during rangebound sessions |
| Regime preference | Intraday trend-continuation sweep strategy |
| Win rate target (qualitative) | Medium, with 2.5R target profile |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source script
**Pointer:** https://www.tradingview.com/script/o6iMtsld-Session-Liquidity-Sweep-Trend-Confirmation/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10697_tv-sess-ls-ema.md`

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
| v1 | 2026-06-04 | Initial build from card | b00da9c7-9d99-4db6-a0ed-67aea145091a |
