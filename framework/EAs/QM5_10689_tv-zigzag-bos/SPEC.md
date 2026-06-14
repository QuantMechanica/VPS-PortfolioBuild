# QM5_10689_tv-zigzag-bos - Strategy Spec

**EA ID:** QM5_10689
**Slug:** `tv-zigzag-bos`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA confirms swing highs and lows with a fixed ZigZag pivot length on closed bars. A bullish BOS is a close above the latest confirmed swing high while the recent swing sequence is making higher highs and higher lows; a bearish BOS is the inverse in a lower-high/lower-low sequence. A valid BOS inside the configured New York operating window creates one pending retest setup, replacing any older setup. The EA enters at market after a closed-bar retest of the BOS level, uses the pre-BOS pivot plus 0.1 ATR(14) buffer for the stop, sets take profit at 1R, and force-closes positions and pending setups at 16:00 New York time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pivot_length` | 5 | 3-8 tested | Bars on each side required to confirm a ZigZag swing. |
| `strategy_scan_bars` | 160 | 40-240 | Closed bars scanned once per new bar for swing structure. |
| `strategy_atr_period` | 14 | 5-50 | ATR period for the last-pivot stop buffer. |
| `strategy_atr_buffer_mult` | 0.10 | 0.00-1.00 | ATR multiple added beyond the pre-BOS pivot for stop placement. |
| `strategy_target_rr` | 1.0 | 1.0-2.0 tested | Take-profit reward/risk multiple. |
| `strategy_ny_start_hour` | 8 | 0-23 | New York session start hour for BOS setup creation. |
| `strategy_ny_start_minute` | 30 | 0-59 | New York session start minute for BOS setup creation. |
| `strategy_ny_end_hour` | 11 | 0-23 | New York session end hour for BOS setup creation. |
| `strategy_ny_end_minute` | 30 | 0-59 | New York session end minute for BOS setup creation. |
| `strategy_force_close_hour` | 16 | 0-23 | New York hour when active trades and pending setups are cleared. |
| `strategy_force_close_minute` | 0 | 0-59 | New York minute when active trades and pending setups are cleared. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with DWX OHLC coverage for structural retests.
- `GBPUSD.DWX` - liquid FX major with DWX OHLC coverage for structural retests.
- `USDJPY.DWX` - liquid FX major with DWX OHLC coverage for structural retests.
- `XAUUSD.DWX` - DWX canonical metals symbol for the card's `XAUUSD` basket item.
- `GDAXI.DWX` - DWX canonical DAX symbol used as the matrix-verified port for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Symbols outside `dwx_symbol_matrix.csv` - unavailable to the DWX backtest fleet.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Intraday, retest to 1R or 16:00 New York forced close |
| Expected drawdown profile | Structure-retest losses bounded by last-pivot stops |
| Regime preference | Break-of-structure continuation with retest |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source indicator workflow
**Pointer:** `https://www.tradingview.com/script/7XkGKdmw/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10689_tv-zigzag-bos.md`

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
| v1 | 2026-06-14 | Initial build from card | 61d7b3cc-81a3-45aa-bdfc-ad8590b1bce4 |
