# QM5_41217_tv-post-vwap-requal8 — Strategy Spec

**EA ID:** QM5_41217
**Slug:** `tv-post-vwap-requal8`
**Source:** `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_10815` (mechanics lineage: approved parent card `QM5_10815_tv-post-vwap`)
**Author of this spec:** Codex
**Last revised:** 2026-08-31

---

## 1. Strategy Logic

This EA is a new-identity, mechanically faithful port of `QM5_10815`. On each closed H1 bar it looks for a high-relative-volume absorption candle stretched away from session VWAP, followed by a confirmed reclaim of that candle's high for a long or breakdown of its low for a short. The stop remains beyond the absorption swing with the approved ATR buffer and maximum-distance cap; the default target remains session VWAP. Positions close on the parent strategy's opposite absorption condition or after 12 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | >=1 | ATR period for stretch and stop calculations. |
| `strategy_volume_lookback` | 20 | >=3 | Closed-bar tick-volume averaging window. |
| `strategy_vwap_stretch_atr` | 0.50 | >0 | Minimum distance from VWAP in ATR units. |
| `strategy_volume_ratio` | 1.50 | >0 | Minimum absorption-bar relative volume. |
| `strategy_wick_share` | 0.55 | 0-1 | Minimum opposing wick share of candle range. |
| `strategy_stop_buffer_atr` | 0.25 | >=0 | ATR buffer beyond the absorption swing. |
| `strategy_max_stop_atr` | 2.50 | >0 | Maximum stop distance in ATR units. |
| `strategy_target_rr` | 0.0 | >=0 | Optional fixed-R target; zero targets session VWAP. |
| `strategy_time_stop_m15_bars` | 24 | >=1 | Preserved parent M15 time-stop default. |
| `strategy_time_stop_h1_bars` | 12 | >=1 | H1 time-stop used by this manifest row. |
| `strategy_session_filter` | true | bool | Enables the broker-hour liquid-session filter. |
| `strategy_session_start_hour` | 7 | 0-23 | Allowed broker-hour start. |
| `strategy_session_end_hour` | 21 | 0-23 | Allowed broker-hour end. |
| `strategy_max_spread_points` | 0 | >=0 | Optional wide-spread cap; zero disables it. |

---

## 3. Symbol Universe

- `GDAXI.DWX` — exact manifest-bound requalification symbol and canonical DWX DAX proxy; active magic slot 0 is `412170000`.

No portable-basket expansion is authorized by the reservation-only recovery card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 70 (approved parent-card expectation) |
| Expected trade frequency | intraday, closed-bar signals |
| Typical hold time | up to 12 H1 bars unless VWAP, stop, or target is reached first |
| Regime preference | intraday mean reversion after volume absorption |

The Edge Lab constraints remain external admission gates: no HFT, grid, martingale, or ML mechanics are present; framework news blackout and risk controls remain enabled.

---

## 6. Source Citation

**Recovery authority:** `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_10815`  
**Approved mechanics card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10815_tv-post-vwap.md`  
**Original source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`  
**Pointer:** `https://www.tradingview.com/script/j6iKZmCf-Post-Absorption-VWAP-Reversal-Engine-V1-6/`

R1 lineage is recorded and R2–R4 are PASS in the approved parent card. The reserved recovery card is `D:/QM/strategy_farm/artifacts/cards_review/QM5_41217_tv-post-vwap-requal8.md` with `g0_status: APPROVED`; it authorizes no mechanics change.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`. This build does not authorize live deployment.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-31 | Initial governed requalification build from approved parent mechanics | `b958b565-e847-49e1-8ec9-6575f67b0d7f` |
