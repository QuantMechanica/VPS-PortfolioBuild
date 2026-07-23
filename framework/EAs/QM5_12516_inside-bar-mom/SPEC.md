# QM5_12516_inside-bar-mom — Strategy Spec

**EA ID:** QM5_12516
**Slug:** `inside-bar-mom`
**Source:** `3826b7f5-8cc3-536f-8093-ff36dd567ef4`
**Author of this spec:** Codex
**Last revised:** 2026-07-23

---

## 1. Strategy Logic

After an H1 candle closes fully inside the preceding candle's range, the EA uses the preceding candle's direction. A bullish preceding candle places a buy stop at its high plus 10% of its range; a bearish preceding candle places a sell stop at its low minus 10%. The stop is 20% of that range back through the preceding candle's extreme and the target is 80% beyond it. A new inside bar cancels the earlier pending order and closes any position before placing the replacement setup.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_entry_buf_pct` | 0.10 | 0.00–1.00 | Fraction of the preceding range added beyond its extreme for the stop entry. |
| `strategy_sl_pct` | 0.20 | 0.01–2.00 | Fraction of the preceding range used to offset the stop loss from its extreme. |
| `strategy_tp_pct` | 0.80 | 0.01–5.00 | Fraction of the preceding range used to offset the profit target from its extreme. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid FX major directly named by the approved card.
- `GBPUSD.DWX` — liquid FX major and a source example directly named by the card.
- `XAUUSD.DWX` — liquid gold CFD directly named by the card.
- `SP500.DWX` — S&P 500 custom symbol directly named by the card.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` — the tester has no supported tick-data contract for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 60 |
| Expected trade frequency | roughly weekly, with clustering during active markets |
| Typical hold time | hours to a few days |
| Expected drawdown profile | repeated fixed-risk losses during false breakouts, bounded by the configured stop |
| Regime preference | volatility-expansion / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `3826b7f5-8cc3-536f-8093-ff36dd567ef4`  
**Source type:** article  
**Pointer:** Backtest Rookies, “Tradingview: Inside Bar Momentum Strategy,” archived at `https://web.archive.org/web/20191020072108/https://backtest-rookies.com/2018/07/13/tradingview-inside-bar-momentum-strategy/`  
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12516_inside-bar-mom.md`

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
| v1 | 2026-07-23 | Initial build from card | 2475d5d6-98b0-441a-9757-d5c491797eff |
