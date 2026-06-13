# QM5_1060_george-hwang-52w-high - Strategy Spec

**EA ID:** QM5_1060
**Slug:** george-hwang-52w-high
**Source:** 7ede58dd-d184-5099-9d48-7a65de230853 (see `strategy-seeds/sources/7ede58dd-d184-5099-9d48-7a65de230853/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

On each D1 month-end close, the EA computes each registered universe member's 52-week-high proximity as `Close[1] / MaxHigh(252)`. The top two proximity ranks are traded long, and the bottom two are traded short. Existing positions are closed at the next month-end rebalance. A long position is also force-closed if its proximity falls below 0.85, and every entry receives a 4x ATR(20) stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_d1_bars` | 252 | 2-1000 | D1 high lookback used as the 52-week-high proxy. |
| `strategy_rank_slots_each_side` | 2 | 1-5 | Number of highest-proximity longs and lowest-proximity shorts. |
| `strategy_atr_period` | 20 | 1-200 | ATR period for stop placement and volatility gate. |
| `strategy_atr_sl_mult` | 4.0 | 0.1-20.0 | ATR multiple used for the initial stop loss. |
| `strategy_pullback_close_ratio` | 0.85 | 0.01-1.00 | Long-position force-close threshold for proximity. |
| `strategy_volatility_gate` | 0.03 | 0.0-1.0 | Skip entries when ATR(20)/Close is above this ratio. |
| `strategy_spread_median_days` | 20 | 1-64 | D1 spread sample length for median spread filter. |
| `strategy_spread_mult` | 3.0 | 0.1-20.0 | Skip entries when current spread exceeds this multiple of median spread. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card universe FX major.
- `GBPUSD.DWX` - card universe FX major.
- `USDJPY.DWX` - card universe FX major.
- `AUDUSD.DWX` - card universe FX major.
- `USDCAD.DWX` - card universe FX major.
- `USDCHF.DWX` - card universe FX major.
- `NZDUSD.DWX` - card universe FX major.
- `XAUUSD.DWX` - card universe gold leg.
- `NDX.DWX` - card universe Nasdaq 100 index CFD.
- `WS30.DWX` - card universe Dow 30 index CFD.
- `GDAXI.DWX` - canonical DWX DAX symbol; used for the card's `GER40.DWX` reference because `GER40.DWX` is not in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SP500.DWX` - not part of this card universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | About one month, until the next month-end rebalance unless stopped or long pullback-exited. |
| Expected drawdown profile | Momentum sleeve with drawdown concentrated in cross-asset trend reversals; 4x ATR stop limits single-trade loss. |
| Regime preference | Breakout / cross-sectional momentum. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 7ede58dd-d184-5099-9d48-7a65de230853
**Source type:** paper / encyclopedia
**Pointer:** `https://quantpedia.com` and `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1060_george-hwang-52w-high.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1060_george-hwang-52w-high.md`

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
| v1 | 2026-06-13 | Initial build from card | 44c7d303-add7-4785-be4e-0143283e2e5d |
