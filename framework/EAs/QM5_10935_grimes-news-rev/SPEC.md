# QM5_10935_grimes-news-rev - Strategy Spec

**EA ID:** QM5_10935
**Slug:** `grimes-news-rev`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (see `strategy-seeds/sources/fbfd7f6e-462a-55c8-9efa-9005a70c9f5c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades a failed news-gap breakout on M15 index CFDs. A long setup requires the session to open at least 0.75 D1 ATR below the prior D1 close, the first six M15 bars to break below prior-day or pre-open support, then a close back above the first-hour low by 0.25 M15 ATR. After that failed break, the EA builds a 4-12 bar recovery range and buys when a closed M15 bar breaks above that range by 0.10 M15 ATR. Shorts mirror the same rule after an upside gap that fails above prior-day or pre-open resistance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 20 | 2-100 | ATR lookback used on M15 and D1. |
| `strategy_gap_d1_atr_mult` | 0.75 | 0.10-3.00 | Required session gap as a multiple of D1 ATR. |
| `strategy_first_hour_bars` | 6 | 1-12 | Number of M15 bars that define the first-hour failed-break test. |
| `strategy_recovery_min_bars` | 4 | 1-12 | Minimum bars in the recovery range after failed break. |
| `strategy_recovery_max_bars` | 12 | 4-24 | Maximum bars in the recovery range after failed break. |
| `strategy_preopen_proxy_bars` | 16 | 0-64 | M15 bars before session open used as overnight/pre-open proxy. |
| `strategy_failed_reclaim_atr_mult` | 0.25 | 0.05-2.00 | Required reclaim beyond first-hour extreme after failed break. |
| `strategy_entry_buffer_atr_mult` | 0.10 | 0.00-1.00 | Recovery-range breakout buffer as a multiple of M15 ATR. |
| `strategy_stop_buffer_atr_mult` | 0.25 | 0.00-2.00 | Stop buffer beyond failed-break session extreme. |
| `strategy_target_r_mult` | 2.00 | 0.50-5.00 | R-multiple target before applying prior D1 close cap. |
| `strategy_max_stop_d1_atr_mult` | 1.25 | 0.25-5.00 | Maximum allowed stop distance as a multiple of D1 ATR. |
| `strategy_spread_stop_fraction` | 0.10 | 0.01-0.50 | Maximum spread as a fraction of stop distance. |
| `strategy_session_start_hour` | 15 | 0-23 | Broker-hour session start proxy. |
| `strategy_session_start_minute` | 30 | 0-59 | Broker-minute session start proxy. |
| `strategy_session_end_hour` | 22 | 1-24 | Broker-hour session close proxy. |
| `strategy_session_end_minute` | 0 | 0-59 | Broker-minute session close proxy. |
| `strategy_latest_entry_session_frac` | 0.75 | 0.10-1.00 | Latest permitted recovery breakout as fraction of session elapsed. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` -- do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol named in the card and valid for backtest.
- `NDX.DWX` - Nasdaq 100 liquid US index proxy in the card basket.
- `WS30.DWX` - Dow 30 liquid US index proxy in the card basket.
- `GDAXI.DWX` - available DAX custom symbol used in place of card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated target is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- `SPX500.DWX` - unavailable S&P variant; `SP500.DWX` is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `D1` prior close/high/low and ATR(20) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` |
| Typical hold time | Intraday, from recovery breakout to session close or target/stop. |
| Expected drawdown profile | Low-frequency news-gap reversal losses with bounded 1.25 D1 ATR maximum stop distance. |
| Regime preference | News-driven failed breakout reversal. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** `blog`
**Pointer:** Adam H. Grimes, "Beyond the News: A Dive Into Breakout Behavior", 2023-10-09
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10935_grimes-news-rev.md`

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
| v1 | 2026-06-06 | Initial build from card | b52e27a3-41cd-482f-bcf3-6a49bec68efb |
