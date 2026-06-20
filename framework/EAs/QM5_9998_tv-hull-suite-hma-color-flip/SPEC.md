# QM5_9998_tv-hull-suite-hma-color-flip — Strategy Spec

**EA ID:** QM5_9998
**Slug:** `tv-hull-suite-hma-color-flip`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades the TradingView Hull Suite color flip on closed H4 bars. It computes a Hull-family line from close prices, compares the current closed-bar value with the value a fixed number of bars back, and enters long when that slope flips from non-positive to positive or short when it flips from non-negative to negative. An opposite slope flip closes the open position and allows the framework to open the opposite side on the same new-bar pass. Initial risk is bounded by an ATR(14)-based stop, with optional ATR take-profit and optional max-hold bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for Hull, ATR, and optional SMA gate. |
| `strategy_hull_length` | `55` | `>=4`; P3 `{34,55,89,144}` | Hull-family moving-average length. |
| `strategy_hull_shift_bars` | `2` | `>=1`; P3 `{1,2,3}` | Bars back for slope comparison. |
| `strategy_hull_variant` | `0` | `0=HMA`, `1=EHMA`, `2=THMA` | Hull Suite variant selector. |
| `strategy_atr_period` | `14` | `>=1` | ATR period for stop and optional take-profit. |
| `strategy_atr_sl_mult` | `2.0` | P3 `{1.5,2.0,2.5,3.0}` | Initial stop distance in ATR multiples. |
| `strategy_atr_tp_mult` | `0.0` | `0=off`; P3 `{0,2,3,4}` | Optional take-profit distance in ATR multiples. |
| `strategy_max_hold_bars` | `0` | `0=off`; P3 may test `30` | Optional time stop in signal-timeframe bars. |
| `strategy_use_sma200_gate` | `false` | `true/false` | Optional trend-regime gate. |
| `strategy_sma_period` | `200` | `>=2` | SMA length for the optional regime gate. |
| `strategy_spread_sl_fraction` | `0.15` | `>=0`; `0=off` | Skip entries when spread exceeds this fraction of ATR stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — FX major named in the card target basket.
- `GBPUSD.DWX` — FX major named in the card target basket.
- `USDJPY.DWX` — FX major named in the card target basket.
- `XAUUSD.DWX` — liquid metal CFD named in the card target basket.
- `XTIUSD.DWX` — liquid oil CFD named in the card target basket.
- `NDX.DWX` — liquid US index target named in the card.
- `WS30.DWX` — liquid US index target named in the card.
- `SP500.DWX` — supplementary S&P 500 backtest symbol named in the card R3 notes.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — no verified DWX data.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` — non-canonical S&P 500 variants; use `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | roughly several H4 bars to about 5 trading days |
| Expected drawdown profile | medium trend-following drawdown during chop, bounded by ATR stop |
| Regime preference | trend / medium-term momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView community script`
**Pointer:** `https://www.tradingview.com/script/hg92pFwS-Hull-Suite-by-InSilico/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9998_tv-hull-suite-hma-color-flip.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | 7fa462da-a642-46d4-a5db-550496858cd1 |
