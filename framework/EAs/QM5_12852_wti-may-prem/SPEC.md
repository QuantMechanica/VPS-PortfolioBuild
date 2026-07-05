# QM5_12852_wti-may-prem - Strategy Spec

**EA ID:** QM5_12852
**Slug:** `wti-may-prem`
**Source:** `KHAN-WTI-BRENT-SEASON-2023`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency structural WTI month-of-year sleeve on
`XTIUSD.DWX`. On each new D1 bar, it permits a long entry only when the current
broker-calendar month is May. The position is flattened on the first subsequent
D1 bar, when the chart leaves May, or by a one-calendar-day stale-position
guard. The only price-derived input is ATR for the hard stop.

The strategy is intentionally not a duplicate of the existing WTI family:
April/August single-month premiums, broad February-September seasonality,
late-year month fades, weekday seasonality, WPSR, refinery, hurricane, OPEC,
expiry, roll, Cushing, WTI/FX, WTI/Brent, and medium-term momentum/reversal all
use different information sets or timing. This EA is a pure May calendar-premium
anomaly.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_month` | 5 | 5 | Broker-calendar May |
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.25 | 1.5-3.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 1 | 1-2 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 18-22.
- Typical hold: one D1 bar.
- Regime preference: WTI May month-of-year calendar premium.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Khan, Z., Saha, T. R. and Ekundayo, T., "Understanding the Seasonality in Crude
Oil Returns for WTI and Brent", Research Square posted content, DOI
10.21203/rs.3.rs-2569101/v1, URL
https://www.researchsquare.com/article/rs-2569101/v1.pdf.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-01 | Initial build from card | build commit pending |
| v2 | 2026-07-05 | Rebuild-in-place (DL-069): fixed OnTick news-gate ordering (2026-07-02 audit rule -- management/exit must run before the news gate, not after) and removed a per-call raw-indicator-handle re-derivation of ATR in the SL calc (`QM_StopATR` -> `QM_StopATRFromValue` reusing the already-pooled `QM_ATR` reading). Root-caused the WTI calendar-fade-family "1 trade ever, then permanent silence" defect (Q02 work item fa3c2903, FAIL/MIN_TRADES_NOT_MET, trades=1 over 6.5yr) to the `QM_StopRules.mqh` raw-handle pattern flagged by `BUILD_CHECK_DWX_ADVISORY_DWX_LAZY_INDICATOR_HANDLE`/`_INDICATOR_RELEASE`; smoke re-run (task 71d97b86) confirmed the fix: 23 trades in May 2024 alone vs the prior 1 trade across the full 2018-2024 history. | task_id 71d97b86-77aa-42f1-84bc-f40e273279ac |
