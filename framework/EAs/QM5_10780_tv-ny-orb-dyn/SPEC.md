# QM5_10780_tv-ny-orb-dyn - Strategy Spec

**EA ID:** QM5_10780
**Slug:** `tv-ny-orb-dyn`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA builds a New York opening range from 08:30 through 08:45 NY time. After that range is complete, it enters long when the closed bar breaks above the range high, or short when the closed bar breaks below the range low, during the 08:50-12:00 NY entry window. Optional filters require the signal close to align with VWAP, 50-period SMMA, MACD, and RSI according to `strategy_filter_mode`. Each entry uses an ATR(14) stop capped by the opening-range size, a fixed R target, and a hard flat exit at 13:25 NY time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_or_start_hhmm` | 830 | 0000-2359 | New York opening-range start time. |
| `strategy_or_end_hhmm` | 845 | 0000-2359 | New York opening-range end time. |
| `strategy_entry_start_hhmm` | 850 | 0000-2359 | First New York time at which breakouts may enter. |
| `strategy_entry_end_hhmm` | 1200 | 0000-2359 | Last New York time at which breakouts may enter. |
| `strategy_hard_exit_hhmm` | 1325 | 0000-2359 | New York time to close any open strategy position. |
| `strategy_second_breakout` | false | false/true | Require a prior breakout, return into range, then second breakout. |
| `strategy_confirmation_bars` | 1 | 0-2 | Number of prior bars that must close inside the opening range. |
| `strategy_filter_mode` | 3 | 0-3 | Filter set: none, VWAP, VWAP+SMMA, or VWAP+SMMA+MACD+RSI. |
| `strategy_rsi_period` | 14 | 2-100 | RSI lookback. |
| `strategy_rsi_overbought` | 70.0 | 50-100 | Long entries require RSI below this level. |
| `strategy_rsi_oversold` | 30.0 | 0-50 | Short entries require RSI above this level. |
| `strategy_macd_fast` | 12 | 2-100 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 3-200 | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 2-100 | MACD signal period. |
| `strategy_smma_period` | 50 | 2-300 | SMMA trend filter period. |
| `strategy_atr_period` | 14 | 2-100 | ATR stop period. |
| `strategy_atr_sl_mult` | 1.0 | 0.1-10.0 | ATR multiplier for stop distance. |
| `strategy_cap_at_or_range` | true | false/true | Cap ATR stop distance by the opening-range size. |
| `strategy_or_cap_mult` | 1.0 | 0.1-10.0 | Opening-range cap multiplier. |
| `strategy_rr_target` | 2.0 | 0.1-10.0 | Fixed R profit target. |
| `strategy_max_spread_points` | 0 | 0-10000 | Optional spread gate; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed FX symbol with DWX matrix support.
- `GBPUSD.DWX` - Card-listed FX symbol with DWX matrix support.
- `USDJPY.DWX` - Card-listed FX symbol with DWX matrix support.
- `XAUUSD.DWX` - Card listed `XAUUSD`; normalized to canonical DWX suffix.
- `GDAXI.DWX` - Card listed `GER40.DWX`; mapped to available DAX symbol in the DWX matrix.
- `NDX.DWX` - Card-listed US index symbol with DWX matrix support.
- `WS30.DWX` - Card-listed US index symbol with DWX matrix support.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `XAUUSD` - Missing `.DWX` suffix; use `XAUUSD.DWX` for research and backtest.

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
| Trades / year / symbol | `100` |
| Typical hold time | Intraday, minutes to hours, forced flat at 13:25 NY. |
| Expected drawdown profile | Volatility-expansion breakout losses should cluster in false-breakout sessions. |
| Regime preference | Breakout / volatility-expansion. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy`
**Pointer:** `https://www.tradingview.com/script/SYneoMiP-NY-ORB-Full-Dynamic-System/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10780_tv-ny-orb-dyn.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-05 | Initial build from card | 8271eb35-0ba8-47f0-9ed6-773d8957ece5 |
