# QM5_10732_tv-bdns-orb - Strategy Spec

**EA ID:** QM5_10732
**Slug:** `tv-bdns-orb`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA builds the New York opening range from the M5 bar or bars between 09:30 and 09:35 ET. After the range is locked, it buys when a closed M5 bar closes above the opening-range high plus 24 ticks and sells when a closed M5 bar closes below the opening-range low minus 24 ticks. Entries require ADX at or above 24 and, when enabled, a VWAP-side bias: long closes above session VWAP and short closes below session VWAP. The full position uses TP2 as the target at 1.0 opening-range width, moves the stop to breakeven after TP1 distance at 0.5 opening-range width, and exits any remaining position at 10:30 ET.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_or_start_hhmm_ny` | 930 | 0-2359 | New York time when opening-range capture starts. |
| `strategy_or_end_hhmm_ny` | 935 | 0-2359 | New York time when opening-range capture ends. |
| `strategy_trade_end_hhmm_ny` | 1030 | 0-2359 | New York time after which new entries are blocked and open trades are flattened. |
| `strategy_breakout_offset_ticks` | 24 | 0+ | Tick offset added to the opening-range high or subtracted from the low. |
| `strategy_adx_period` | 14 | 1+ | ADX lookback used for the ADX >= threshold filter. |
| `strategy_adx_threshold` | 24.0 | 0+ | Minimum ADX value required for a breakout entry. |
| `strategy_vwap_filter_enabled` | true | true/false | When true, long entries require close above VWAP and shorts require close below VWAP. |
| `strategy_sl_or_width_mult` | 0.75 | 0+ | Stop distance as a multiple of opening-range width, capped by the opposite OR side. |
| `strategy_tp_or_width_mult` | 1.00 | 0+ | Full-position target distance as a multiple of opening-range width. |
| `strategy_be_or_width_mult` | 0.50 | 0+ | Breakeven trigger distance as a multiple of opening-range width. |
| `strategy_large_range_filter` | false | true/false | Optional large-range filter; default false because the card states this filter is not active. |
| `strategy_large_range_atr_mult` | 2.0 | 0+ | ATR multiple used only if the large-range filter is explicitly enabled. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread guard in points; 0 leaves the card behaviour unchanged. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 DWX index CFD in the card's R3 basket.
- `WS30.DWX` - Dow 30 DWX index CFD in the card's R3 basket.
- `SP500.DWX` - S&P 500 custom DWX symbol in the card's R3 basket; backtest-only caveat applies outside this build.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - not registered for this EA and not available for this build.

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
| Trades / year / symbol | `65` |
| Typical hold time | Short opening-window intraday holds, flat by 10:30 ET. |
| Expected drawdown profile | Breakout strategy with one trade per day and fixed per-trade risk. |
| Regime preference | Volatility-expansion breakout. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView script
**Pointer:** TradingView script `BDNS ORB Strategy v3`, author handle `bensabensa`, https://www.tradingview.com/script/JJhTYZ7u-BDNS-ORB-Strategy-v3/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10732_tv-bdns-orb.md`

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
| v1 | 2026-06-14 | Initial build from card | 999d8eaf-c380-43e0-9436-dd604b071c4f |
