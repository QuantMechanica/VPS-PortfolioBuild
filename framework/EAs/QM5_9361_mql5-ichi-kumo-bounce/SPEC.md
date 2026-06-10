# QM5_9361_mql5-ichi-kumo-bounce — Strategy Spec

**EA ID:** QM5_9361
**Slug:** `mql5-ichi-kumo-bounce`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA trades a three-bar Ichimoku cloud-bounce pattern with ADX/DI trend confirmation on M30. A long entry fires when the most recent closed bar closes above Senkou Span A, the previous bar dipped at or below Senkou Span A (touched the cloud), and the bar before that also closed above Span A — forming a V-shaped dip into the cloud — while DI+ > DI- and ADX >= 25. A short entry mirrors this pattern with an inverted-V spike into the cloud and DI- > DI+. Stops are placed below/above Senkou Span B minus/plus 0.5 × ATR(14). Exits are triggered by the opposite cloud-bounce pattern, the close crossing back through Senkou Span A against the trade, or a 64-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ichi_tenkan` | 9 | 5-20 | Ichimoku Tenkan-sen lookback period |
| `strategy_ichi_kijun` | 26 | 13-52 | Ichimoku Kijun-sen period and Senkou Span A projection offset |
| `strategy_ichi_senkou_b` | 52 | 26-104 | Ichimoku Senkou Span B lookback period |
| `strategy_adx_period` | 14 | 7-28 | ADX and DI calculation period |
| `strategy_adx_threshold` | 25.0 | 15-40 | Minimum ADX value required to enter a trade |
| `strategy_sl_atr_mult` | 0.5 | 0.25-2.0 | Multiplier of ATR(14) added beyond Senkou Span B for stop loss |
| `strategy_time_exit_bars` | 64 | 24-192 | Maximum bars before time-based position exit |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` — liquid major FX pair with clear trend/pullback structure on M30
- `EURUSD.DWX` — deepest FX liquidity; Ichimoku cloud well-respected on intraday
- `USDJPY.DWX` — Asian-session trending pair; cloud bounce historically consistent
- `XAUUSD.DWX` — trending commodity with wide ATR; cloud acts as dynamic support/resistance

**Explicitly NOT for:**
- Index symbols (NDX/WS30/SP500) — card targets FX + Gold basket; indices left for P3 expansion

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
| Trades / year / symbol | ~45 |
| Typical hold time | 2–32 hours (1–64 M30 bars) |
| Expected drawdown profile | Moderate; SL anchored to Senkou Span B provides structural buffer |
| Regime preference | trend-pullback |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 73): Using Patterns of Ichimoku and the ADX-Wilder", MQL5 Articles, 2025-07-04, Pattern 3
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9361_mql5-ichi-kumo-bounce.md`

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
| v1 | 2026-06-10 | Initial build from card | 784de71b-af42-49f9-962e-9236710c5f24 |
