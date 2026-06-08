# QM5_11202_ft-adxmom - Strategy Spec

**EA ID:** QM5_11202
**Slug:** ft-adxmom
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long continuation signals on H1 closed bars. It opens a long when ADX(14) is above 25, MOM(14) is positive, PLUS_DI(25) is above 25, and PLUS_DI(25) is greater than MINUS_DI(25). It exits the long when ADX remains above 25 but MOM(14) turns negative, MINUS_DI(25) is above 25, and PLUS_DI(25) falls below MINUS_DI(25). Entries use an ATR(14) x 2.0 stop and a fixed 1% take profit from the source ROI.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_adx_period` | 14 | 10-20 | ADX period for trend-strength entry and exit checks. |
| `strategy_di_period` | 25 | 14-30 | PLUS_DI and MINUS_DI period. |
| `strategy_mom_period` | 14 | 10-20 | Closed-bar momentum lookback. |
| `strategy_adx_threshold` | 25.0 | 20.0-30.0 | Minimum ADX value required for entry and exit. |
| `strategy_di_threshold` | 25.0 | 20.0-30.0 | Minimum directional indicator value required for entry and exit. |
| `strategy_atr_stop_period` | 14 | 10-20 | ATR period for the baseline stop. |
| `strategy_atr_stop_mult` | 2.0 | 1.0-4.0 | ATR multiple used to place the initial stop. |
| `strategy_roi_pct` | 1.0 | 0.5-5.0 | Fixed take-profit percentage from entry price. |
| `strategy_max_spread_stop_frac` | 0.08 | 0.00-0.20 | Blocks entry when spread exceeds this fraction of planned stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Major FX pair with H1 OHLC history suitable for ADX, DI, and momentum rules.
- `GBPUSD.DWX` - Major FX pair with liquid H1 history for the same directional-momentum rule.
- `XAUUSD.DWX` - Gold CFD with H1 trend and momentum behavior compatible with the card's metals portability.
- `GDAXI.DWX` - Matrix-valid DAX custom symbol used as the DWX equivalent for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - Named in the card but not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Non-DWX symbols - Research and backtest artifacts must retain the `.DWX` suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | H1 continuation holds; expected hours to days depending on TP/opposite signal. |
| Expected drawdown profile | Medium risk from trend continuation with ATR-based stop. |
| Regime preference | trend / momentum continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/ADXMomentum.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11202_ft-adxmom.md`

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
| v1 | 2026-06-08 | Initial build from card | b4dbb021-c0d6-4ea2-9eea-927d2da005fd |
