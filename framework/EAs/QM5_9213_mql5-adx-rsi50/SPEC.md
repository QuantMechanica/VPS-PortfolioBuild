# QM5_9213_mql5-adx-rsi50 — Strategy Spec

**EA ID:** QM5_9213
**Slug:** `mql5-adx-rsi50`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each closed H1 bar, the EA checks two simultaneous crossing conditions. A long entry fires when the ADX(14) main line crosses from below 25 to above 25 on the same bar that RSI(14) crosses from below 50 to above 50. A short entry fires when ADX(14) similarly crosses above 25 while RSI(14) crosses from above 50 to below 50. The stop loss is placed at ATR(14)×1.8 from entry price, or beyond the signal bar's extreme (low for longs, high for shorts), whichever is wider. Take-profit is fixed at 2× the initial risk distance (2R). Long positions are closed when RSI drops back below 50 or ADX falls below 20 or a short signal forms; short positions close on the mirror conditions.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_adx_period` | 14 | 5–50 | ADX indicator period |
| `strategy_adx_threshold` | 25.0 | 15–40 | ADX level that must be crossed above for entry |
| `strategy_adx_exit_level` | 20.0 | 10–30 | ADX level below which open positions are closed |
| `strategy_adx_max_above_bars` | 5 | 1–20 | Reject entry if ADX has already been above threshold this many consecutive bars |
| `strategy_rsi_period` | 14 | 5–30 | RSI indicator period |
| `strategy_rsi_mid` | 50.0 | 40–60 | RSI midline for cross detection and exit |
| `strategy_atr_period` | 14 | 5–30 | ATR period for stop-loss sizing |
| `strategy_atr_sl_mult` | 1.8 | 1.0–4.0 | ATR multiplier for stop distance |
| `strategy_tp_rr` | 2.0 | 1.0–5.0 | Take-profit expressed as a multiple of stop-loss distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — high-liquidity major FX pair; H1 ADX trends well during London/NY sessions
- `GBPUSD.DWX` — volatile major FX pair with strong intraday trends suitable for ADX+RSI signals
- `GDAXI.DWX` — DAX 40 index; card listed GER40.DWX (not in DWX matrix); ported to canonical GDAXI.DWX

**Explicitly NOT for:**
- `GER40.DWX` — not a valid DWX symbol (matrix lists GDAXI.DWX for DAX); ported on build

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~65 |
| Typical hold time | hours to days (H1 bars, exit on RSI/ADX flip) |
| Expected drawdown profile | moderate; hard 2R TP limits upside per trade; RSI/ADX exits cap downside |
| Regime preference | trend / momentum-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** paper / article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 44): Average True Range (ATR) technical indicator", MQL5 Articles, 2024-10-25 — Pattern 8 (ADX with RSI Confirmation)
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9213_mql5-adx-rsi50.md`

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
| v1 | 2026-06-10 | Initial build from card | aed446d8-0dc2-4bad-8cf4-38691ce73b1d |
