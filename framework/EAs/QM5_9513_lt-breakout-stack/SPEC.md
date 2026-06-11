<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_9513_lt-breakout-stack — Strategy Spec

**EA ID:** QM5_9513
**Slug:** `lt-breakout-stack`
**Source:** `1a059d6d-84fa-5d0c-94c5-86dd0481637c` (see `strategy-seeds/sources/1a059d6d-84fa-5d0c-94c5-86dd0481637c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each closed D1 bar, the EA computes a multi-horizon breakout forecast using six
rolling lookback windows (N = 10, 20, 40, 80, 160, 320 bars). For each horizon, the
scaled price location within the N-bar high/low range is multiplied by a source scalar
and clamped to [-20, +20]. Horizons where the rolling range collapses to zero are
skipped. The combined forecast is the average of all valid horizon forecasts; if fewer
than three horizons are valid, no signal is produced.

A LONG position is opened when the combined forecast exceeds +2 and no position is
open. A SHORT position is opened when the combined forecast falls below -2. Entries
execute at market on the new bar open. An open LONG is closed when the combined
forecast drops to 0 or below; an open SHORT is closed when the forecast rises to 0 or
above. Additionally, an emergency hard stop of 2.5 × ATR(20, D1) is maintained via
the framework ATR trail helper. Lot sizing uses RISK_FIXED in backtest and
RISK_PERCENT in live, via QM_LotsForRisk. New entries are suppressed when the current
spread exceeds 2 × the 20-day median spread.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_scalar_10` | 28.6 | 1–100 | Forecast scalar for N=10 horizon (from official LT spreadsheet) |
| `strategy_scalar_20` | 31.6 | 1–100 | Forecast scalar for N=20 horizon |
| `strategy_scalar_40` | 32.7 | 1–100 | Forecast scalar for N=40 horizon |
| `strategy_scalar_80` | 33.5 | 1–100 | Forecast scalar for N=80 horizon |
| `strategy_scalar_160` | 33.5 | 1–100 | Forecast scalar for N=160 horizon |
| `strategy_scalar_320` | 33.5 | 1–100 | Forecast scalar for N=320 horizon |
| `strategy_entry_threshold` | 2.0 | 0.5–10 | Forecast magnitude required for entry |
| `strategy_exit_threshold` | 0.0 | 0–5 | Forecast crosses zero to exit (0 = exit at zero) |
| `strategy_atr_period` | 20 | 5–50 | ATR period for emergency hard stop |
| `strategy_atr_stop_mult` | 2.5 | 1–5 | ATR multiplier for emergency stop distance |
| `strategy_spread_lookback` | 20 | 5–60 | Days of spread history for median calculation |
| `strategy_spread_cap_mult` | 2.0 | 1–5 | Max spread = mult × median spread |
| `strategy_min_valid_horizons` | 3 | 1–6 | Minimum horizons required before trading |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair, liquid, D1 breakout signals well-defined
- `GBPUSD.DWX` — major FX pair, strong trending character
- `USDJPY.DWX` — major FX pair, trend-following compatible
- `GDAXI.DWX` — DAX index, trending equity index
- `NDX.DWX` — Nasdaq 100 index, strong trend regime presence
- `WS30.DWX` — Dow Jones 30 index, trending equity index
- `XAUUSD.DWX` — Gold, trending commodity
- `XTIUSD.DWX` — WTI crude oil, trending commodity

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only symbol, not broker-routable for live

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none (all computations on D1 bars) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~50 |
| Typical hold time | days to weeks |
| Expected drawdown profile | moderate; emergency stop at 2.5×ATR(20,D1) |
| Regime preference | trend / breakout |
| Win rate target (qualitative) | low (trend-following typical < 50% wins, large R:R) |

---

## 6. Source Citation

**Source ID:** `1a059d6d-84fa-5d0c-94c5-86dd0481637c`
**Source type:** book
**Pointer:** Robert Carver, *Leveraged Trading*, Harriman House 2019, ISBN 9780857197214. Chapter 8 + Appendix C. Official spreadsheet: https://docs.google.com/spreadsheets/d/15A3qW4Nx0n82gKF0BhZt7oq9a09Z4V3z7QLcIo8bkxs/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9513_lt-breakout-stack.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | task 6729921b-814b-4c0a-952d-7bf517ba8ddb |
