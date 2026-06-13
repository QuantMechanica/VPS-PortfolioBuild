# QM5_10354_et-crude-orb - Strategy Spec

**EA ID:** QM5_10354
**Slug:** et-crude-orb
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA builds two fixed CET opening ranges each day, 12:00-13:00 and 14:00-15:00, on M15 bars. After a range closes, it places a buy stop above the range high and a sell stop below the range low, provided the range width and spread filters pass. The initial stop is the fixed crude-oil stop distance or the opposite side of the range if that is closer; ported symbols use ATR-normalized distances. Positions exit by fixed target, stop loss, end-of-day flat at 21:00 CET, or Friday flat at 20:00 CET.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_M15` | M15 only | Base timeframe used to build the two one-hour ranges. |
| `strategy_range_a_start_cet` | `12` | 0-23 | CET hour for the first range start. |
| `strategy_range_b_start_cet` | `14` | 0-23 | CET hour for the second range start. |
| `strategy_range_minutes` | `60` | 60 | Range length; implemented as four M15 bars. |
| `strategy_oil_buffer_price` | `0.15` | >0 | XTIUSD breakout buffer in crude-oil price units. |
| `strategy_oil_stop_price` | `0.70` | >0 | XTIUSD fixed protective stop distance. |
| `strategy_oil_target_price` | `1.60` | >0 | XTIUSD fixed target distance. |
| `strategy_oil_max_range` | `1.00` | >0 | Maximum XTIUSD opening-range width. |
| `strategy_port_buffer_atr` | `0.10` | >=0 | ATR-normalized breakout buffer for non-oil ports. |
| `strategy_port_stop_atr` | `1.00` | >0 | ATR-normalized fixed stop distance for non-oil ports. |
| `strategy_port_max_range_atr` | `1.50` | >0 | Maximum range width for non-oil ports, in ATR units. |
| `strategy_port_target_r` | `2.25` | >0 | Target multiple of initial risk for non-oil ports. |
| `strategy_atr_period` | `14` | >=1 | ATR period used for non-oil normalization. |
| `strategy_spread_median_mult` | `2.50` | >0 | Skip entries when current spread exceeds this multiple of median spread. |
| `strategy_spread_median_bars` | `96` | 10-500 | Closed M15 bars used for the rolling spread median. |
| `strategy_eod_close_hour_cet` | `21` | 0-23 | Monday-Thursday end-of-day flat hour in CET. |
| `strategy_friday_close_hour_cet` | `20` | 0-23 | Friday flat hour in CET. |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - direct crude-oil CFD target from the card.
- `XAUUSD.DWX` - liquid commodity CFD port with ATR-normalized buffer and stop.
- `GDAXI.DWX` - matrix-verified DAX custom symbol used for the card's `GER40.DWX` intent.
- `NDX.DWX` - liquid index CFD port with ATR-normalized buffer and stop.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated name is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday, from range breakout to target, stop, or 21:00 CET flat |
| Expected drawdown profile | False-breakout losses cluster in low-volatility or high-spread intraday regimes |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/crude-oil-daily-breakout-trading-system.111214/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10354_et-crude-orb.md`

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
| v1 | 2026-06-13 | Initial build from card | 3cba07c9-ae8e-4f47-864d-bb32d0f80388 |
