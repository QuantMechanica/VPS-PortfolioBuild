<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_9362_mql5-ichi-chikou-span — Strategy Spec

**EA ID:** QM5_9362
**Slug:** `mql5-ichi-chikou-span`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA uses Pattern 4 from the MQL5 Ichimoku + ADX-Wilder article: it enters long when the Ichimoku Chikou Span (buffer shift=26, the close from 26 bars ago) is above the Senkou Span A cloud at the current bar (buffer shift=26, the framework-documented "current cloud" position), and the ADX(14) is at or above 25. It enters short on the mirror condition. Trades exit when the Chikou-vs-Senkou signal reverses or when the position has been open for more than 96 M30 bars (48 hours). Stop-loss is placed beyond the 10-bar swing low/high with an additional 0.5×ATR(14) buffer; lot size is risk-adjusted via the framework risk sizer.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ichimoku_tenkan` | 9 | 5–20 | Tenkan-sen period |
| `strategy_ichimoku_kijun` | 26 | 13–52 | Kijun-sen period (also controls Senkou A shift) |
| `strategy_ichimoku_senkou` | 52 | 26–104 | Senkou Span B period |
| `strategy_adx_threshold` | 25.0 | 15.0–40.0 | ADX minimum for entry |
| `strategy_adx_period` | 14 | 7–21 | ADX + ATR period |
| `strategy_swing_lookback` | 10 | 5–20 | Bars for swing high/low stop |
| `strategy_sl_atr_buffer` | 0.5 | 0.0–2.0 | ATR multiple added beyond swing SL |
| `strategy_time_exit_bars` | 96 | 48–192 | Max hold in bars before forced close |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — major FX pair, good trending behaviour and M30 liquidity
- `EURUSD.DWX` — most liquid FX pair, consistent Ichimoku trending episodes
- `USDJPY.DWX` — Yen pairs historically responsive to Ichimoku cloud signals
- `XAUUSD.DWX` — gold exhibits strong trending moves compatible with Ichimoku ADX filter

**Explicitly NOT for:**
- Index CFDs — not in the card's target universe; separate EA required

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
| Trades / year / symbol | ~30 (card: 20–45) |
| Typical hold time | 2–48 hours (96 M30 bars max) |
| Expected drawdown profile | Moderate; stop placed beyond swing structure + ATR buffer |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 73)", MQL5 Articles, 2025-07-04 — Pattern 4 "Chikou Span vs. Senkou Span A with ADX Confirmation"
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9362_mql5-ichi-chikou-span.md`

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
| v1 | 2026-06-10 | Initial build from card | 7737623e-9e5d-4dde-a9ba-e67e8dd27807 |
