# QM5_11370_forex-profit-system-ema3-psar-h1 - Strategy Spec

**EA ID:** QM5_11370
**Slug:** `forex-profit-system-ema3-psar-h1`
**Source:** `becda36b-263f-5989-b5fa-f1e945c0d4bd`
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA trades H1 trend reversals from a three-EMA cascade. A long entry is allowed on a newly closed H1 bar when EMA10 crosses above EMA25, EMA10 is above EMA50, EMA25 is above EMA50, and Parabolic SAR is below price on both H1 and M15. A short entry is the mirror: EMA10 crosses below EMA25, all three EMAs align down, and Parabolic SAR is above price on both timeframes. The initial stop is just beyond EMA50 with a 30-pip cap, the stop trails behind EMA50 as the trade moves in favor, and an open trade closes when the H1 close crosses back through all three EMAs.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for EMA cross, H1 PSAR, stop, trail, and exit reads |
| `strategy_psar_confirm_tf` | `PERIOD_M15` | MT5 timeframe enum | Confirmation timeframe for the "never trade against 15 min PSAR" filter |
| `strategy_ema_fast` | `10` | `2+` | Fast EMA period |
| `strategy_ema_mid` | `25` | `3+` | Middle EMA period crossed by EMA10 |
| `strategy_ema_slow` | `50` | `4+` | Slow EMA period used for cascade alignment and stop anchor |
| `strategy_psar_step` | `0.02` | `>0` | Parabolic SAR acceleration step |
| `strategy_psar_maximum` | `0.20` | `>0` | Parabolic SAR maximum acceleration |
| `strategy_initial_sl_cap_pips` | `30` | `1+` | Maximum initial stop distance for P2 |
| `strategy_ema50_buffer_points` | `3` | `0+` | Point buffer beyond EMA50 for initial and trailing stop |
| `strategy_max_spread_pips` | `20` | `1+` | Maximum entry spread in pips |
| `strategy_session_filter_enabled` | `true` | `true/false` | Enables London and New York open entry windows |
| `strategy_london_open_hour_broker` | `8` | `0-23` | Broker-hour start of London open entry window |
| `strategy_ny_open_hour_broker` | `13` | `0-23` | Broker-hour start of New York open entry window |
| `strategy_session_window_hours` | `5` | `1-24` | Hours after each open during which entries are allowed |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-stated DWX forex major with H1 and M15 data.
- `GBPUSD.DWX` - card-stated DWX forex major with H1 and M15 data.
- `USDJPY.DWX` - card-stated DWX forex major adapted from the original USD/CHF note.

**Explicitly NOT for:**
- `SP500.DWX` - this card is a forex EMA and PSAR system, not an equity-index strategy.
- `XAUUSD.DWX` - metals were not listed in the approved symbol universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `M15` Parabolic SAR confirmation |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Not stated in card; expected hours to days from H1 EMA trend-following exits |
| Expected drawdown profile | Not stated in card; whipsaw risk in range-bound EMA cross regimes |
| Regime preference | Trend-following |
| Win rate target (qualitative) | Not stated in card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `becda36b-263f-5989-b5fa-f1e945c0d4bd`
**Source type:** `local PDF / forex system compilation`
**Pointer:** Anonymous (DayTradeForex.com compilation), "9 Forex Systems", Forex Profit System, local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\### Forex to read\452915895-9-Forex-Systems-pdf.pdf`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11370_forex-profit-system-ema3-psar-h1.md`

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
| v1 | 2026-06-08 | Initial build from card | 06c3aa7a-8b31-4c35-9895-de90c561f284 |
