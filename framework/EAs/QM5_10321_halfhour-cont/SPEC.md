# QM5_10321_halfhour-cont - Strategy Spec

**EA ID:** QM5_10321
**Slug:** halfhour-cont
**Source:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9 (see approved card source notes)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades 30-minute intraday return continuation. At the start of each eligible M30 slot, it looks at the same slot from prior trading days. It goes long when the previous same-slot return is positive and the average same-slot return over the prior five samples is non-negative, and goes short when both signs are negative or non-positive. It skips the first and final configured session slots, requires at least ten same-slot history samples, filters unusually wide same-slot spreads, uses an emergency 0.50 x ATR(14) stop, and closes after one 30-minute slot.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_slot_minutes` | 30 | 30 | Fixed slot length required by the card. |
| `strategy_session_start_hhmm` | 0 | 0-2359 | Broker-time start of the configured regular session. |
| `strategy_session_end_hhmm` | 2400 | 1-2400 | Broker-time end of the configured regular session. |
| `strategy_history_days` | 10 | 1+ | Minimum same-slot history samples required before trading. |
| `strategy_persistence_days` | 5 | 1+ | Number of prior same-slot samples averaged for the persistence filter. |
| `strategy_lookback_bars` | 800 | 400+ | M30 bars copied on each closed-bar signal evaluation to find same-slot history. |
| `strategy_atr_period` | 14 | 1+ | ATR period for the emergency stop. |
| `strategy_atr_sl_mult` | 0.50 | >0 | ATR multiplier for emergency stop placement. |
| `strategy_spread_median_mult` | 1.50 | >0 | Current spread must not exceed this multiple of the same-slot median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol explicitly allowed by the approved card and DWX matrix for backtests.
- `NDX.DWX` - Nasdaq 100 index CFD in the approved US large-cap basket.
- `WS30.DWX` - Dow 30 index CFD in the approved US large-cap basket.
- `GDAXI.DWX` - DAX 40 matrix symbol used for the card's GER40/DAX exposure.
- `UK100.DWX` - FTSE 100 index CFD in the approved global index basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; `SP500.DWX` is canonical for this build.
- Single-stock symbols - the build target is the card's DWX index-CFD port, not the original paper's stock universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | One 30-minute slot |
| Expected drawdown profile | Intraday stop-limited losses with no overnight exposure. |
| Regime preference | Intraday seasonality / return continuation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Source type:** paper
**Pointer:** SSRN abstract 1107590 and `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10321_halfhour-cont.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10321_halfhour-cont.md`

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
| v1 | 2026-06-12 | Initial build from card | ffb279ec-f463-419f-8fea-7cccacd4c36a |
