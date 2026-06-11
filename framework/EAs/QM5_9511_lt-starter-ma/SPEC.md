<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_9511_lt-starter-ma — Strategy Spec

**EA ID:** QM5_9511
**Slug:** `lt-starter-ma`
**Source:** `1a059d6d-84fa-5d0c-94c5-86dd0481637c` (see `strategy-seeds/sources/1a059d6d-84fa-5d0c-94c5-86dd0481637c/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each closed D1 bar, compute a 16-bar SMA and a 64-bar SMA of closing prices. Enter LONG when the fast SMA crosses above the slow SMA; enter SHORT when the fast SMA crosses below the slow SMA. The EA flips direction directly if the opposite crossover fires at the same close. Exit the LONG when the fast SMA falls below the slow SMA on a closed D1 bar; exit the SHORT when the fast SMA rises above the slow SMA. A hard emergency stop of 2.5×ATR(20, D1) is placed at entry. No new trades are taken until at least 64 bars of history are available. A spread cap blocks entries when the current spread exceeds 2× the 20-day median spread.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_period` | 16 | 5-50 | Bars for the fast SMA |
| `strategy_slow_period` | 64 | 20-200 | Bars for the slow SMA |
| `strategy_atr_period` | 20 | 10-30 | ATR period for emergency hard stop |
| `strategy_atr_sl_mult` | 2.5 | 1.0-5.0 | ATR multiplier for stop distance |
| `strategy_spread_lookback` | 20 | 5-60 | Days used to compute median spread |
| `strategy_spread_mult` | 2.0 | 1.0-5.0 | Max allowed spread as multiple of median |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major forex pair; deep liquidity, smooth daily trend structure
- `GBPUSD.DWX` — major forex pair; trending characteristics suitable for MA crossover
- `USDJPY.DWX` — major forex pair; long-running trends favoured by carry dynamics
- `AUDUSD.DWX` — commodity-linked forex pair; multi-week trending periods present
- `NDX.DWX` — Nasdaq 100 index; strong trend behaviour, daily ATR-based stop appropriate
- `WS30.DWX` — Dow Jones index; trending index with liquid DWX data
- `XAUUSD.DWX` — gold; classic trend-following instrument with large ATR stops
- `XTIUSD.DWX` — WTI crude oil; commodity with pronounced multi-week trends

**Explicitly NOT for:**
- Symbols with insufficient D1 history (< 64 bars) — EA will not trade until warmed up

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 |
| Typical hold time | days to weeks |
| Expected drawdown profile | moderate; trend-following drawdowns during choppy markets |
| Regime preference | trend |
| Win rate target (qualitative) | low (large winners offset frequent small losses) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1a059d6d-84fa-5d0c-94c5-86dd0481637c`
**Source type:** book
**Pointer:** Robert Carver, *Leveraged Trading*, Harriman House 2019, ISBN 9780857197214, Ch. 5-6; companion spreadsheet https://docs.google.com/spreadsheets/d/1Orpdm_GSXBHrFSrbHjfPti4TbJ6aL3FFBQ544I6teiA/
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_9511_lt-starter-ma.md`

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
| v1 | 2026-06-11 | Initial build from card | 664de89b-732b-4fe1-bb67-2b4b7594d554 |
