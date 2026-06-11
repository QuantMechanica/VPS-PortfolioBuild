# QM5_9943_ff-fractal-hilo-break-h4 — Strategy Spec

**EA ID:** QM5_9943
**Slug:** `ff-fractal-hilo-break-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Development
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

Identifies confirmed Bill Williams fractals on the H4 chart (requiring 2 closed bars on each side of the fractal candle). For a long entry, the EA detects a confirmed down-fractal whose low is higher than the prior confirmed down-fractal within the last 80 bars (higher-low structure). It then places a buy-stop order 5 pips above the fractal candle's high, with an ATR-scaled stop below the fractal low. The short mirror detects a confirmed up-fractal with a lower high and places a sell-stop 5 pips below the fractal candle's low. Pending orders expire after 6 H4 bars; open positions close on a time stop of 12 H4 bars or when an opposite-direction fractal setup forms.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fractal_lookback` | 80 | 20–200 | Max H4 bars to search for prior confirmed fractal |
| `strategy_entry_offset_pips` | 5 | 1–20 | Pips past fractal high/low for stop entry |
| `strategy_sl_atr_mult_min` | 1.0 | 0.5–2.0 | Minimum SL as ATR(14,H4) multiple |
| `strategy_sl_atr_buffer` | 0.15 | 0.0–0.5 | ATR buffer added to fractal-to-entry distance |
| `strategy_sl_atr_cap` | 2.2 | 1.5–4.0 | Maximum SL as ATR(14,H4) multiple |
| `strategy_tp_pips` | 100 | 50–300 | TP in pips for FX pairs; metals always use 2R |
| `strategy_expire_bars` | 6 | 2–12 | H4 bars before pending order auto-expires |
| `strategy_time_stop_bars` | 12 | 6–48 | H4 bars before open position is force-closed |
| `strategy_stale_filter_r` | 0.25 | 0.0–1.0 | Skip entry if close is within this fraction of R of entry price |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Major FX pair; fractal breakout patterns well-established, H4 liquidity sufficient
- `GBPUSD.DWX` — Major FX pair; similar trend-breakout characteristics to EURUSD
- `USDCAD.DWX` — Major FX pair; commodity-correlated moves produce clear fractal structure
- `XAUUSD.DWX` — Gold; strong structural swings on H4; TP uses 2R (metals mode) instead of fixed pips

**Explicitly NOT for:**
- Indices, energies — fractal pip offset and ATR dynamics not calibrated for these

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~32 |
| Typical hold time | 12–24 H4 bars (2–4 days) |
| Expected drawdown profile | Moderate; ATR-scaled SL limits per-trade loss |
| Regime preference | trend / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** jamesagnew, "trade fractals, this method is a winner", ForexFactory, 2025, https://www.forexfactory.com/thread/1348734-trade-fractals-this-method-is-a-winner
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9943_ff-fractal-hilo-break-h4.md`

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
| v1 | 2026-06-11 | Initial build from card | 0741b3f7-b120-4ef6-a105-957e7e624529 |
