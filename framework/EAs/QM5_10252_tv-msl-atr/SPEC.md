# QM5_10252_tv-msl-atr - Strategy Spec

**EA ID:** QM5_10252
**Slug:** `tv-msl-atr`
**Source:** `c84ae47e-8ea0-56f1-8b25-4436b6dda5b5` (see `strategy-seeds/sources/c84ae47e-8ea0-56f1-8b25-4436b6dda5b5/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA confirms swing highs and lows with symmetric pivots on closed H1 bars. A long signal fires when the latest closed bar closes above the most recent confirmed swing high, and a short signal fires when it closes below the most recent confirmed swing low. Signals are separated by at least 10 bars, breakout bars must have a range of at least 0.5 x ATR(14), and opposite structure breaks close the current position before attempting the reverse entry. Risk is expressed through the framework; the initial stop uses the tighter of the first closed-bar 3 x ATR trailing-stop value and the 5 x ATR catastrophic stop from entry, then the stop ratchets on closed-bar close values.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pivot_length` | 5 | `>= 1` | Bars on each side required to confirm a swing high or swing low. |
| `strategy_pivot_scan_bars` | 60 | `>= strategy_pivot_length * 2 + 2` | Bounded closed-bar search window for the most recent confirmed pivots. |
| `strategy_min_bars_between_signals` | 10 | `>= 0` | Minimum closed bars between trend signals. |
| `strategy_atr_period` | 14 | `>= 1` | ATR period for initial and trailing stops. |
| `strategy_atr_trail_mult` | 3.0 | `> 0` | ATR multiple for the ratchet trailing stop. |
| `strategy_catastrophic_atr_mult` | 5.0 | `> 0` | Catastrophic ATR stop multiple from entry; the initial protective stop is the tighter ATR trail value. |
| `strategy_min_breakout_range_atr` | 0.5 | `>= 0` | Minimum breakout-bar range as a multiple of ATR(14). |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - primary card symbol; liquid DWX gold market with OHLC and ATR data.
- `NDX.DWX` - card P2 default; liquid index trend-following candidate with DWX data.
- `WS30.DWX` - card P2 default; liquid index trend-following candidate with DWX data.
- `EURUSD.DWX` - card P2 default; liquid FX trend-following candidate with DWX data.

**Explicitly NOT for:**
- Symbols outside the registered list above - no implicit runtime universe expansion is authorized for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Expected trade frequency | not specified in card frontmatter; inferred from 45 trades/year/symbol |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | bounded by V5 fixed-risk backtest sizing and ATR protective stops |
| Regime preference | trend-following breakout |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c84ae47e-8ea0-56f1-8b25-4436b6dda5b5`
**Source type:** TradingView public open-source script
**Pointer:** `https://www.tradingview.com/script/nKDLOq2T-msl-trend-follow/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10252_tv-msl-atr.md`

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
| v1 | 2026-06-10 | Initial build from card | 7bcccbc6-a6d9-4428-83b5-d6e46c02d889 |
