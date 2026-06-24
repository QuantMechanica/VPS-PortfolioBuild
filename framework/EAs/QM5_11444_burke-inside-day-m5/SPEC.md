# QM5_11444_burke-inside-day-m5 - Strategy Spec

**EA ID:** QM5_11444
**Slug:** burke-inside-day-m5
**Source:** 04305b6c-b4ce-522b-87b5-71708b6b8327 (see `strategy-seeds/sources/04305b6c-b4ce-522b-87b5-71708b6b8327/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA looks for a completed D1 inside day: the prior daily high is below the high two days ago, and the prior daily low is above the low two days ago. On the next M5 session bar, it buys when the closed M5 bar is above EMA20 and above the inside-day high, or sells when the closed M5 bar is below EMA20 and below the inside-day low. The stop is placed back inside the broken range edge by the configured pip buffer, capped by the card's range and pip limits, and the take profit projects the inside-day range from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 20 | 13-34 P3 sweep range | EMA period used for M5 entry direction. |
| `strategy_london_start_utc` | 7 | 0-23 | London session start hour in UTC, inclusive. |
| `strategy_london_end_utc` | 12 | 1-24 | London session end hour in UTC, exclusive. |
| `strategy_ny_start_utc` | 13 | 0-23 | New York session start hour in UTC, inclusive. |
| `strategy_ny_end_utc` | 17 | 1-24 | New York session end hour in UTC, exclusive. |
| `strategy_sl_buffer_pips` | 5 | 5-15 P3 sweep range | Stop buffer back inside the inside-day range. |
| `strategy_sl_range_cap_mult` | 1.5 | 0.5-3.0 | Maximum stop distance as a multiple of the inside-day range. |
| `strategy_sl_max_pips` | 80 | 1-300 | Maximum stop distance in pips. |
| `strategy_sl_min_pips` | 5 | 1-50 | Minimum stop distance in pips to avoid degenerate stops. |
| `strategy_spread_cap_pips` | 15 | 1-100 | Maximum live modeled spread before entries are blocked. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed DWX forex major with M5 and D1 history.
- `GBPUSD.DWX` - Card-listed DWX forex major with M5 and D1 history.
- `USDJPY.DWX` - Card-listed DWX forex major with M5 and D1 history.
- `AUDUSD.DWX` - Card-listed DWX forex major with M5 and D1 history.
- `USDCAD.DWX` - Card-listed DWX forex major with M5 and D1 history.

**Explicitly NOT for:**
- Non-DWX symbols - The P2 baseline and magic registry are bound to canonical `.DWX` instruments.
- Symbols outside `dwx_symbol_matrix.csv` - The broker/tester data contract does not support phantom symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | D1 inside-day high/low from closed bars |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Intraday to one session, controlled by range TP/SL and Friday close |
| Expected drawdown profile | Breakout strategy with clustered losses during false breakouts |
| Regime preference | Volatility-expansion breakout after daily compression |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 04305b6c-b4ce-522b-87b5-71708b6b8327
**Source type:** Self-published trading playbook
**Pointer:** Stacey Burke, Tradesmint.com, 2022, `707586131-1-Stacey-Burke-Best-Trade-Setups-Playbook-Notes-Part-2.pdf`, pages 51-106
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11444_burke-inside-day-m5.md`

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
| v1 | 2026-06-25 | Initial build from card | 94ec1d3d-3029-4ffb-81ab-d1f7e97c58c1 |
