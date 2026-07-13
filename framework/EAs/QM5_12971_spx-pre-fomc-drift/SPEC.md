# QM5_12971_spx-pre-fomc-drift - Strategy Spec

**EA ID:** QM5_12971
**Slug:** `spx-pre-fomc-drift`
**Source:** `CEO-ANOMALY-SLATE-2026-07-03`
**Author of this spec:** Codex
**Last revised:** 2026-07-11

---

## 1. Strategy Logic

This EA trades the documented pre-FOMC equity drift on SP500.DWX. It loads scheduled Federal Funds Rate events from the local news-calendar archive, buys SP500.DWX on the first M30 bar inside the 24-hour window before the event, and closes the position at least 30 minutes before the announcement. It uses a wide ATR stop only as the V5 fixed-risk sizing and protection anchor; the strategy exit is the pre-event time close.

The approved FTMO `_v2` amendment is a parameter-locked H1 mode of the same EA.
It uses an embedded, versioned 57-date regular-decision calendar for 2018-2025,
enters at broker 21:00 on D-1, exits at broker 20:00 on D, and uses a 2.0 x
prior-D1 ATR(14) emergency stop. The legacy M30/UTC mode remains the default.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_timeframe` | M30 | M30/H1 | Chart timeframe; FTMO `_v2` requires H1. |
| `strategy_schedule_mode` | news UTC | enum | Legacy news archive or frozen broker-clock `_v2`. |
| `strategy_pre_event_entry_hours` | 24 | 1-72 | Hours before the scheduled FOMC decision when the entry window opens. |
| `strategy_pre_event_exit_min` | 30 | 1-240 | Minutes before the scheduled announcement when the EA exits. |
| `strategy_entry_hour_broker` | 21 | 0-23 | Exact D-1 entry hour in frozen `_v2`. |
| `strategy_exit_hour_broker` | 20 | 0-23 | Exact decision-day exit hour in frozen `_v2`. |
| `strategy_atr_period` | 14 | 5-50 | M30 ATR period used for the protective sizing stop. |
| `strategy_sizing_stop_atr_mult` | 6.0 | 1.0-12.0 | ATR multiple for the wide protective stop used by V5 risk sizing. |
| `strategy_calendar_path` | `D:\QM\data\news_calendar\news_calendar_2015_2025.csv` | local CSV path | Local deterministic event calendar used to find Federal Funds Rate rows. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 proxy used by the published pre-FOMC drift literature; backtest-only custom symbol in this farm.

**Explicitly NOT for:**
- `NDX.DWX` - not in this single-symbol card; use only for a separately approved validation variant.
- `GDAXI.DWX` - ECB drift is covered by sibling card QM5_12972, not this FOMC card.
- Forex pairs - the source edge is an equity-index announcement drift, not an FX reaction strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 8 |
| Typical hold time | roughly 23.5 hours |
| Expected drawdown profile | low-frequency event risk, bounded by pre-event exit and wide protective stop |
| Regime preference | news-driven scheduled rate-announcement drift |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `CEO-ANOMALY-SLATE-2026-07-03`
**Source type:** paper / OWNER anomaly slate
**Pointer:** Lucca & Moench (2015), Journal of Finance, "The Pre-FOMC Announcement Drift"; local approved card `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12971_spx-pre-fomc-drift.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12971_spx-pre-fomc-drift.md`

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
| v1 | 2026-07-03 | Initial build from card | 4a10152c-d5b1-4f5e-87dc-518c3f7f30f2 |
| v2 | 2026-07-11 | OWNER-approved FTMO event-flat amendment | Frozen H1 broker-clock schedule and complete 2018-2025 decision calendar; no live permission |
