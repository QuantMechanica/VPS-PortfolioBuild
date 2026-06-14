# QM5_10719_tv-gap-or - Strategy Spec

**EA ID:** QM5_10719
**Slug:** `tv-gap-or`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades M5 index-cash session gaps after a 15-minute opening range is complete. It computes the session gap as session open minus prior daily close, requires the absolute gap to be at least 0.25 ATR(14), then enters either a gap-fill trade back toward the prior close or a continuation trade away from it when the closed M5 bar breaks the opening-range boundary. Gap-fill trades target the prior close; continuation trades target 2R, with stops beyond the opposite opening-range boundary by 0.2 ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 1+ | ATR period used for gap threshold and stop buffer. |
| `strategy_gap_atr_mult` | 0.25 | 0.0+ | Minimum absolute gap as a multiple of ATR. |
| `strategy_or_minutes` | 15 | 5+ | Opening-range construction window in minutes. |
| `strategy_stop_atr_buffer` | 0.20 | 0.0+ | ATR buffer outside the opening range for stop placement. |
| `strategy_min_stop_atr_mult` | 0.25 | 0.0+ | Minimum stop distance as a multiple of ATR. |
| `strategy_max_stop_atr_mult` | 2.50 | 0.0+ | Maximum stop distance as a multiple of ATR. |
| `strategy_continuation_rr` | 2.00 | 0.1+ | Reward/risk target for continuation trades. |
| `strategy_us_open_hour` | 15 | 0-23 | Broker-time hour for US index cash open. |
| `strategy_us_open_minute` | 30 | 0-59 | Broker-time minute for US index cash open. |
| `strategy_us_close_hour` | 22 | 0-23 | Broker-time hour for US index cash close. |
| `strategy_us_close_minute` | 0 | 0-59 | Broker-time minute for US index cash close. |
| `strategy_eu_open_hour` | 9 | 0-23 | Broker-time hour for DAX cash open. |
| `strategy_eu_open_minute` | 0 | 0-59 | Broker-time minute for DAX cash open. |
| `strategy_eu_close_hour` | 17 | 0-23 | Broker-time hour for DAX cash close. |
| `strategy_eu_close_minute` | 30 | 0-59 | Broker-time minute for DAX cash close. |
| `strategy_or_scan_bars` | 600 | 20+ | Bounded M5 bar scan used to reconstruct the current session opening range. |
| `strategy_max_spread_points` | 500 | 0+ | Maximum allowed spread for new entries; zero disables the spread gate. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol explicitly allowed for backtest-only US large-cap exposure.
- `NDX.DWX` - Nasdaq 100 index CFD in the card's US index basket.
- `WS30.DWX` - Dow 30 index CFD in the card's US index basket.
- `GDAXI.DWX` - DAX 40 matrix symbol used for the card's GER40.DWX target.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; represented by `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; the canonical available symbol is `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `PERIOD_D1` previous close and `PERIOD_M5` ATR/opening-range bars |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | intraday, from post-opening-range break until target, stop, or cash-session close |
| Expected drawdown profile | stop distances bounded between 0.25 ATR and 2.5 ATR with fixed $1,000 backtest risk |
| Regime preference | gap-fill mean reversion and opening-range breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/aydoOjNc-Gap-Fill-Opening-Range-Strategy/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10719_tv-gap-or.md`

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
| v1 | 2026-06-14 | Initial build from card | fe4fe334-e55d-4a40-b4a9-8daa248d4bd7 |
