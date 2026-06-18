# QM5_12350_spec-ema20-40 - Strategy Spec

**EA ID:** QM5_12350
**Slug:** spec-ema20-40
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Evaluate completed D1 bars. The EA opens a long position when EMA(20) on close is greater than EMA(40) on close and this EA has no open position for the current symbol and magic. It closes the long position when EMA(20) is less than EMA(40). The protective stop is placed at 2.0 * ATR(14) from the entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema_period` | 20 | 1-100 | Fast EMA period used for the long state. |
| `strategy_slow_ema_period` | 40 | 2-200 | Slow EMA period used for the long state. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiple for the hard stop distance. |
| `strategy_warmup_bars` | 120 | 40-500 | Minimum D1 warmup depth before trading. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - D1 close-derived EMA trend state is portable to major FX.
- `GBPUSD.DWX` - D1 close-derived EMA trend state is portable to major FX.
- `USDJPY.DWX` - D1 close-derived EMA trend state is portable to major FX.
- `XAUUSD.DWX` - D1 close-derived EMA trend state is portable to liquid metals.
- `GDAXI.DWX` - DAX exposure substitute for card-stated `GER40.DWX`, which is not in the DWX matrix.
- `NDX.DWX` - D1 close-derived EMA trend state is portable to liquid index CFDs.
- `WS30.DWX` - D1 close-derived EMA trend state is portable to liquid index CFDs.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; registered `GDAXI.DWX` instead.
- `SP500.DWX` - listed as optional only, not part of the card's primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `10` |
| Typical hold time | days to weeks |
| Expected drawdown profile | lag and sideways-market whipsaw are the main risks |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub example code
**Pointer:** Heerozh/spectre `examples/dual_ema_on_apple.py`, `AppleDualEma`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12350_spec-ema20-40.md`

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
| v1 | 2026-06-18 | Initial build from card | 11414dbe-44b7-4c75-88a2-648145f9ff10 |
