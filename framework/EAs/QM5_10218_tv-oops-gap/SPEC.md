# QM5_10218_tv-oops-gap - Strategy Spec

**EA ID:** QM5_10218
**Slug:** `tv-oops-gap`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA implements the Larry Williams Oops gap-reversal rule from the approved card. It reads the current and prior D1 bars as a bounded daily setup cache, then on M15 bars places a buy stop just above yesterday's low when today's D1 open gaps below that low after a bearish prior day, or a sell stop just below yesterday's high when today's D1 open gaps above that high after a bullish prior day. Entries are active only during the configured intraday session and expire at session end. Open positions are force-closed at session end, with no fixed take-profit.

Stops are initialized at the current day's extreme, capped to a maximum distance of `3.0 * ATR(14)` from entry when the day-extreme stop is too wide. The trade-management hook only tightens an existing stop when the cached day-extreme stop improves; it never widens risk.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_start_hhmm` | 1630 | 0000-2359 | Broker-time start of the entry window, set to approximate the US cash open for SP500/US index use. |
| `strategy_session_end_hhmm` | 2300 | 0000-2359 | Broker-time end of session; pending entries expire and open positions are closed. |
| `strategy_tick_filter_points` | 2 | 0+ | Point offset added above yesterday's low for buy stops or subtracted below yesterday's high for sell stops. |
| `strategy_atr_period` | 14 | 1+ | Daily ATR period used for the emergency stop-distance cap. |
| `strategy_atr_emergency_mult` | 3.0 | >0 | Maximum initial stop distance expressed as a multiple of daily ATR. |
| `strategy_max_spread_points` | 80 | 0+ | Entry-only spread ceiling in points; 0 disables this strategy spread filter. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 exposure requested by the card; valid as a backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 member of the card's portable US index basket.
- `WS30.DWX` - Dow 30 member of the card's portable US index basket.
- `GDAXI.DWX` - DAX proxy for card-stated `GER40.DWX`, which is not in the DWX matrix.
- `XAUUSD.DWX` - Gold CFD requested directly in the card target symbol list.

**Explicitly NOT for:**
- `GER40.DWX` - unavailable in `dwx_symbol_matrix.csv`; this build uses `GDAXI.DWX`.
- Any symbol not registered for this EA in `magic_numbers.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `PERIOD_D1` for gap setup and daily ATR |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default skeleton gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Expected trade frequency | Infrequent intraday gap days only |
| Typical hold time | Same session; no overnight carry |
| Expected drawdown profile | Fixed-risk single-position mean-reversion losses, bounded by day-extreme stop and ATR emergency cap |
| Regime preference | Intraday mean reversion after opening gaps |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView public script
**Pointer:** TradingView script `Larry Williams Oops Strategy`, author `xtradernet`, URL cited in `artifacts/cards_approved/QM5_10218_tv-oops-gap.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10218_tv-oops-gap.md`

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
| v1 | 2026-06-10 | Initial build from card | 32506840-3271-4a18-ae9b-3b77e5516908 |
