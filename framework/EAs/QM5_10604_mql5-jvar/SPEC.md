# QM5_10604_mql5-jvar - Strategy Spec

**EA ID:** QM5_10604
**Slug:** `mql5-jvar`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `artifacts/cards_approved/QM5_10604_mql5-jvar.md`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA reads the MQL5 CodeBase ColorJVariation oscillator on completed D1 bars using the source default parameters. It enters long when the oscillator color state changes to bullish at bar close, and enters short when the color state changes to bearish at bar close. A long exits when the oscillator changes to bearish; a short exits when it changes to bullish. Any position still open after 20 completed D1 bars is closed by the fallback time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_jvar_period` | 12 | > 0 | ColorJVariation averaging period. |
| `strategy_jvar_ma_method` | `MODE_SMA` | MT5 `ENUM_MA_METHOD` | ColorJVariation averaging method. |
| `strategy_jvar_jlength` | 3 | > 0 | ColorJVariation JMA smoothing depth. |
| `strategy_jvar_jphase` | 100 | -100 to 100 | ColorJVariation JMA smoothing phase. |
| `strategy_atr_period` | 14 | > 0 | ATR period used for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.5 | > 0 | Stop-loss distance as ATR multiple. |
| `strategy_time_stop_bars` | 20 | > 0 | Maximum completed D1 bars to hold a position. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` - source test used AUDUSD Daily, so this is the primary target.
- `EURUSD.DWX` - liquid DWX FX major suitable for closed-bar oscillator color-state logic.
- `GBPUSD.DWX` - liquid DWX FX major suitable for the same D1 oscillator rule.
- `XAUUSD.DWX` - DWX metal CFD listed by the card as portable to the oscillator rule.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtests.
- Non-D1 setfile baselines - optional H8/H6 sweeps are P3 variants, not the Q01 baseline.

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
| Trades / year / symbol | `25` |
| Typical hold time | up to 20 D1 bars |
| Expected drawdown profile | Trend-following oscillator flips can whipsaw during sideways regimes; ATR stop caps catastrophic losses. |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/1315`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10604_mql5-jvar.md`

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
| v1 | 2026-05-31 | Initial build from card | d55557a7-3ffd-4516-bb8a-3150d11e6079 |
