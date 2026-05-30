# QM5_10433_mql5-range-brk - Strategy Spec

**EA ID:** QM5_10433
**Slug:** `mql5-range-brk`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

The EA measures the broker-time M1 high and low from 08:00 through 09:00 each day. After the range closes, it watches completed M5 candles: a close above the range high opens a long position, and a close below the range low opens a short position. The stop is the opposite side of the measured range, the target is one full range width from entry, and any remaining position is closed at 22:00 broker time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_start_hour` | 8 | 0-23 | Broker-time hour when M1 range measurement starts. |
| `strategy_range_end_hour` | 9 | 0-23 | Broker-time hour when M1 range measurement ends and breakout checks can begin. |
| `strategy_session_close_hour` | 22 | 0-23 | Broker-time hour for the strategy time stop. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for the range-width filter on M5. |
| `strategy_min_range_atr_mult` | 0.25 | >0 | Minimum range width as a multiple of ATR(14,M5). |
| `strategy_max_range_atr_mult` | 3.0 | >= minimum | Maximum range width as a multiple of ATR(14,M5). |
| `strategy_max_spread_range_frac` | 0.10 | >0 | Maximum current spread as a fraction of measured range width. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair with M1 range and M5 breakout data available.
- `GBPUSD.DWX` - major FX pair with M1 range and M5 breakout data available.
- `XAUUSD.DWX` - liquid metal symbol with the same range breakout mechanics.
- `NDX.DWX` - liquid index CFD with available M1/M5 DWX data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no validated DWX data source for P2.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `M1` for the 08:00-09:00 broker-time range, `M5` for ATR and breakout close |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday, from post-09:00 breakout until TP/SL or 22:00 time stop |
| Expected drawdown profile | Fixed one-range stop with one breakout attempt per daily session |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/68764`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10433_mql5-range-brk.md`

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
| v1 | 2026-05-27 | Initial build from card | e9cc76b8-fd90-4b24-be5d-38c87fb8e546 |
