# QM5_12785_timerangebreakout-orb - Strategy Spec

**EA ID:** QM5_12785
**Slug:** `timerangebreakout-orb`
**Source:** `owner-timerangebreakout-vers38-2025`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA builds a broker-time opening range from M1 bars over the symbol's configured session window. After the range closes, it waits for a closed M15 bar to break above the range high plus a range-based buffer or below the range low minus that buffer. A long or short market entry uses a hard stop equal to the range width and a fixed range-multiple take profit, with one trade per symbol per broker day and a forced flat time before the session ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_tf` | `PERIOD_M15` | M5-H1 | Timeframe used for closed-bar breakout confirmation. |
| `strategy_use_symbol_profile` | `true` | true/false | Use built-in per-symbol session windows from the approved card. |
| `strategy_range_start_hour` | 3 | 0-23 | Manual range start hour when symbol profiles are disabled. |
| `strategy_range_start_minute` | 0 | 0-59 | Manual range start minute when symbol profiles are disabled. |
| `strategy_range_duration_minutes` | 180 | 15-720 | Manual range duration when symbol profiles are disabled. |
| `strategy_close_hour` | 18 | 0-23 | Manual forced-flat hour when symbol profiles are disabled. |
| `strategy_close_minute` | 0 | 0-59 | Manual forced-flat minute when symbol profiles are disabled. |
| `strategy_entry_buffer_range_pct` | 0.05 | 0.0-0.25 | Breakout buffer as a fraction of the locked range. |
| `strategy_sl_range_mult` | 1.00 | 0.25-3.0 | Stop distance as a multiple of the locked range. |
| `strategy_tp_range_mult` | 1.60 | 0.5-5.0 | Take-profit distance as a multiple of the locked range. |
| `strategy_atr_period` | 14 | 5-50 | Daily ATR period for range-size filtering. |
| `strategy_min_range_d1_atr_mult` | 0.03 | 0.0-1.0 | Reject ranges that are too small versus D1 ATR. |
| `strategy_max_range_d1_atr_mult` | 0.90 | 0.1-3.0 | Reject ranges that are too large versus D1 ATR. |
| `strategy_min_range_m1_bars` | 8 | 2-720 | Minimum M1 bars needed to accept a range. |
| `strategy_spread_cap_points` | 80 | 0-500 | Blocks genuinely wide spreads; zero .DWX spread is allowed. |
| `strategy_allow_long` | true | true/false | Enable long breakouts. |
| `strategy_allow_short` | true | true/false | Enable short breakouts. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - US100 proxy with the card's late-morning index range window.
- `SP500.DWX` - US500/SP500 backtest-only proxy, useful for broad US index confirmation.
- `GDAXI.DWX` - GER40/DAX proxy with the overnight-into-open range window.
- `XAUUSD.DWX` - gold range breakout using the Asian-window profile from the source teardown.
- `USDJPY.DWX` - JPY FX Asian-window breakout, adding forex diversity.
- `EURJPY.DWX` - JPY FX London-window breakout, adding forex diversity.
- `AUDJPY.DWX` - JPY FX Asian-window breakout, adding forex diversity.
- `CADJPY.DWX` - JPY FX extended-session breakout, adding forex diversity.
- `GBPJPY.DWX` - JPY FX generic Asian-window profile; source listed the pair but not exact tuned minutes.
- `NZDJPY.DWX` - JPY FX generic Asian-window profile; source listed the pair but not exact tuned minutes.

**Explicitly NOT for:**
- `XTIUSD.DWX` / `XNGUSD.DWX` - the card excludes oil and gas as high-spread intraday substrates.
- Non-matrix aliases such as `GER40.DWX`, `US100.DWX`, or `US500.DWX` - mapped to matrix-backed symbols above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | M1 range reconstruction; D1 ATR range-size filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 120 daily breakout opportunities before filters |
| Typical hold time | intraday, from range break to forced-flat time or TP/SL |
| Expected drawdown profile | bounded intraday breakout drawdown with one range-risk trade per day |
| Regime preference | session breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `owner-timerangebreakout-vers38-2025`
**Source type:** OWNER code lineage
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12785_timerangebreakout-orb.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12785_timerangebreakout-orb.md`

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
| v1 | 2026-06-30 | Initial build from card | e7971930-4133-4701-9736-beaecfb48717 |
