# QM5_10509_mql5-doji-brk — Strategy Spec

**EA ID:** QM5_10509
**Slug:** `mql5-doji-brk`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates completed H1 bars. Bar #2 is a doji when the absolute open-close body is no larger than `strategy_body_size_points`; a long signal occurs when bar #1 closes above bar #2 high, and a short signal occurs when bar #1 closes below bar #2 low. The EA opens only one position per symbol and magic. It uses a hard stop based on the farther of ATR(14) distance and the doji high/low plus spread, takes profit at a fixed R multiple, and closes early if an opposite completed doji breakout appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | MT5 timeframe enum | Completed-bar timeframe used for doji detection and breakout confirmation. |
| `strategy_body_size_points` | `10` | `0+` points | Maximum open-close doji body in broker points. |
| `strategy_atr_period` | `14` | `1+` bars | ATR period for the volatility stop. |
| `strategy_atr_sl_mult` | `1.50` | `>0` | ATR multiple for the hard stop. |
| `strategy_target_rr` | `1.25` | `>0` | Take-profit distance as a multiple of initial risk. |
| `strategy_min_stop_points` | `20` | `1+` points | Minimum broker-point stop distance. |
| `strategy_max_spread_points` | `0` | `0+` points | Optional spread filter; `0` disables this card-level filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card R3 primary FX basket member with portable OHLC doji breakout logic.
- `GBPUSD.DWX` — card R3 primary FX basket member with portable OHLC doji breakout logic.
- `USDJPY.DWX` — card R3 primary FX basket member with portable OHLC doji breakout logic.
- `XAUUSD.DWX` — card R3 primary metals basket member with portable OHLC doji breakout logic.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` — unavailable to the DWX test environment.

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
| Trades / year / symbol | `110` |
| Typical hold time | Hours to days, until SL, TP, Friday close, or opposite completed doji breakout. |
| Expected drawdown profile | Breakout whipsaw risk in sideways markets, bounded by fixed initial risk. |
| Regime preference | Breakout / volatility expansion after compressed candle bodies. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/20585`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10509_mql5-doji-brk.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-28 | Initial build from card | f243a15b-2019-423c-880a-73e532657abf |
