# QM5_10438_mql5-fvg-pull - Strategy Spec

**EA ID:** QM5_10438
**Slug:** mql5-fvg-pull
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

On each completed M15 bar, the EA detects a three-bar fair-value gap: bullish when the older bar high is below the latest closed bar low, and bearish when the older bar low is above the latest closed bar high. Each gap is stored once and can trigger only once after a later candle closes back inside the stored zone. Long entries require EMA50 above EMA200 on H1 plus ADX(14) at or above 20 with DI+ greater than DI-, while short entries require the inverse EMA and DI state. Entries use a 1.5 x ATR(14,M15) stop, 2.0R target, session gating from 07:00 to 20:00 broker time, and no discretionary exit beyond SL, TP, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR period for initial stop and stop-cap checks. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiplier for the initial stop distance. |
| `strategy_rr` | 2.0 | 0.1-10.0 | Reward-to-risk multiple for the fixed target. |
| `strategy_regime_tf` | PERIOD_H1 | M15-D1 | Higher timeframe used for EMA and ADX regime confirmation. |
| `strategy_ema_fast` | 50 | 2-300 | Fast EMA period for trend regime. |
| `strategy_ema_slow` | 200 | 10-500 | Slow EMA period for trend regime. |
| `strategy_adx_period` | 14 | 2-100 | ADX/DI period for trend-strength confirmation. |
| `strategy_adx_min` | 20.0 | 1.0-80.0 | Minimum ADX value required for entries. |
| `strategy_h1_atr_stop_cap` | 3.0 | 0.5-10.0 | Skip entries if M15 stop distance exceeds this multiple of H1 ATR. |
| `strategy_spread_stop_frac` | 0.10 | 0.01-0.50 | Maximum spread as a fraction of initial stop distance. |
| `strategy_session_start_h` | 7 | 0-23 | Broker-hour session start. |
| `strategy_session_end_h` | 20 | 0-23 | Broker-hour session end, exclusive. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 primary FX symbol with DWX OHLC, EMA, ADX/DI, and ATR coverage.
- `GBPUSD.DWX` - Card R3 FX basket member with the same mechanical data requirements.
- `XAUUSD.DWX` - Card R3 metals basket member with DWX OHLC and indicator support.
- `NDX.DWX` - Card R3 index basket member for liquid index-CFD portability.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build registers only matrix-verified DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | H1 EMA50/EMA200, H1 ADX/DI, H1 ATR stop cap |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Intraday to multi-session, bounded by 2.0R TP, ATR SL, and Friday close |
| Expected drawdown profile | Conservative one-position pullback strategy with ATR-defined loss per trade |
| Regime preference | Trend-regime pullback after fair-value-gap formation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** Christopher Adie, "KSQ Fair Value Gap EA FVG with Regime Detection and Dual SL TP Mode", https://www.mql5.com/en/code/71467
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10438_mql5-fvg-pull.md`

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
| v1 | 2026-05-27 | Initial build from card | 62566f2b-c69c-42d5-8d0d-a951571047d4 |
