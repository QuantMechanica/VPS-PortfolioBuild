# QM5_12972_gdaxi-pre-ecb-drift - Strategy Spec

**EA ID:** QM5_12972
**Slug:** `gdaxi-pre-ecb-drift`
**Source:** `CEO-ANOMALY-SLATE-2026-07-03`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

---

## 1. Strategy Logic

This EA trades the documented pre-ECB European-index drift. It loads the local news-calendar archive, selects high-impact EUR `Main Refinancing Rate` events, buys GDAXI.DWX on the M30 bar ending about 24 hours before the scheduled event, and closes on the last M30 bar ending at least 30 minutes before the event. A protective ATR stop is attached for V5 fixed-risk sizing; the primary exit is the pre-event time boundary.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pre_event_entry_hours` | 24 | 1-72 | Hours before the ECB event used to select the entry bar. |
| `strategy_pre_event_exit_minutes` | 30 | 1-240 | Minutes before the ECB event used to select the mandatory exit bar. |
| `strategy_atr_period` | 20 | 5-100 | ATR period for the protective risk-sizing stop. |
| `strategy_atr_sl_mult` | 3.0 | 0.5-10.0 | ATR multiple for the protective stop. |
| `strategy_max_hold_hours` | 30 | 1-96 | Safety time stop if the event lookup misses after entry. |
| `strategy_max_spread_points` | 0 | 0+ | Optional wide-spread guard; 0 disables it for DWX zero-spread tests. |
| `strategy_calendar_file` | `D:\QM\data\news_calendar\news_calendar_2015_2025.csv` | path | Local calendar file used for ECB event timestamps. |
| `strategy_event_name_filter` | `Main Refinancing Rate` | string | Event-name substring that identifies the ECB rate decision. |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - DAX index proxy named in the card and available in the DWX matrix.

**Explicitly NOT for:**
- `SP500.DWX` - US index, not the European ECB drift target.
- `EURUSD.DWX` - FX pair; the card targets European equity-index drift, not EUR spot.
- `XAUUSD.DWX` - metal; no ECB equity-risk premium linkage.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 8 |
| Typical hold time | roughly 23.5 to 24 hours |
| Expected drawdown profile | low-frequency scheduled-event exposure with overnight gap risk |
| Regime preference | news-driven event anomaly |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `CEO-ANOMALY-SLATE-2026-07-03`
**Source type:** research card
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12972_gdaxi-pre-ecb-drift.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12972_gdaxi-pre-ecb-drift.md`

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
| v1 | 2026-07-03 | Initial build from card | build task `6acb6c20-b556-4e4b-946b-57f3626b9396` |

