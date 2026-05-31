# QM5_10501_mql5-area-macd - Strategy Spec

**EA ID:** QM5_10501
**Slug:** `mql5-area-macd`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA reads the MACD main value on each closed H1 bar and sums the last `strategy_history_bars` values above zero into `area_up`. It sums the negative MACD main values into `area_down`, then compares `area_up` with `abs(area_down)`. It opens long when positive MACD area is larger, opens short when negative MACD area is larger, and closes an existing position when the cached area balance flips to the opposite side. Every entry uses an ATR(14) hard stop at 1.5 times ATR and a 1.5R take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_macd_fast` | 12 | 1-100 | Fast EMA period used by MACD. |
| `strategy_macd_slow` | 26 | 2-200 | Slow EMA period used by MACD; must exceed fast period. |
| `strategy_macd_signal` | 9 | 1-100 | MACD signal period. |
| `strategy_macd_price` | `PRICE_CLOSE` | MT5 applied price enum | Applied price for the MACD calculation. |
| `strategy_history_bars` | 60 | 1-300 | Number of closed bars used for MACD area sums. |
| `strategy_reverse_signal` | `false` | `true` / `false` | Optional P3 axis; P2 baseline leaves source reverse mode disabled. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for stop placement. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiple used for the hard stop. |
| `strategy_take_profit_r` | 1.5 | 0.1-10.0 | Take-profit distance in multiples of initial risk. |
| `strategy_min_bars` | 120 | 30-1000 | Minimum loaded bars before the strategy is allowed to trade. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 primary FX symbol; MACD and ATR are deterministic OHLC-derived indicators.
- `GBPUSD.DWX` - Card R3 primary FX symbol; same H1 MACD area logic is portable.
- `USDJPY.DWX` - Card R3 primary FX symbol; registered directly from the approved basket.
- `XAUUSD.DWX` - Card R3 metal symbol; MACD and ATR are available on the DWX custom symbol.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - broker/custom-symbol data is not available for Q02 fanout.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | hours to days |
| Expected drawdown profile | Momentum-balance whipsaws are expected in flat MACD regimes; ATR stop caps each trade. |
| Regime preference | MACD momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** Vladimir Karputov, "Area MACD", MQL5 CodeBase, published 2018-07-13, https://www.mql5.com/en/code/21124
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10501_mql5-area-macd.md`

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
| v1 | 2026-05-28 | Initial build from card | 869771f4-4909-4ac8-bc30-d7a2bbc9f026 |
